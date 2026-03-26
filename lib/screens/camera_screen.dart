import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/claude_vision_service.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/animated_widgets.dart';
import 'manual_entry_screen.dart';
import 'barcode_screen.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onFoodAdded;
  final String? selectedMeal;

  const CameraScreen({super.key, this.onFoodAdded, this.selectedMeal});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  final ClaudeVisionService _visionService = ClaudeVisionService();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _analysisResult = null;
          _errorMessage = null;
        });
        await _analyzeImage();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });
    try {
      final result = await _visionService.analyzeFood(_selectedImage!);
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
      if (mounted) {
        _showConfirmationSheet();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Analiz başarısız: $e';
        _isAnalyzing = false;
      });
    }
  }

  void _showConfirmationSheet() {
    if (_analysisResult == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ConfirmationSheet(
        analysisData: _analysisResult!,
        selectedMeal: widget.selectedMeal,
        onConfirm: (editedData, meal) {
          _addToMeal(editedData, meal);
        },
      ),
    );
  }

  void _addToMeal(Map<String, dynamic> data, String mealType) {
    final portionGram = (data['porsiyon_gram'] as num?)?.toDouble() ?? 100.0;
    final factor = portionGram / 100.0;

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: data['yemek_adi']?.toString() ?? 'Bilinmeyen',
      portionSize: portionGram,
      nutritionData: NutritionData(
        calories: factor > 0
            ? ((data['kalori'] as num?)?.toDouble() ?? 0) / factor
            : 0,
        protein: factor > 0
            ? ((data['protein'] as num?)?.toDouble() ?? 0) / factor
            : 0,
        carbohydrates: factor > 0
            ? ((data['karbonhidrat'] as num?)?.toDouble() ?? 0) / factor
            : 0,
        fat: factor > 0
            ? ((data['yag'] as num?)?.toDouble() ?? 0) / factor
            : 0,
      ),
      timestamp: DateTime.now(),
      mealType: mealType,
      imagePath: _selectedImage?.path,
    );

    context.read<NutritionProvider>().addFoodEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.name} eklendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedImage = null;
      _analysisResult = null;
    });

    widget.onFoodAdded?.call();
  }

  void _openManualEntry() {
    Navigator.push(
      context,
      slidePageRoute(
        (_) => ManualEntryScreen(selectedMeal: widget.selectedMeal),
      ),
    ).then((added) {
      if (added == true) widget.onFoodAdded?.call();
    });
  }

  void _openBarcodeScanner() {
    Navigator.push(
      context,
      slidePageRoute(
        (_) => BarcodeScreen(
          selectedMeal: widget.selectedMeal,
          onFoodAdded: widget.onFoodAdded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('Yemek Fotoğrafla')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageArea(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 16),
            if (_isAnalyzing) _buildLoadingIndicator(),
            if (_errorMessage != null) _buildErrorCard(),
            if (_analysisResult != null)
              _AnimatedResultCard(
                key: ValueKey(_analysisResult.hashCode),
                child: _buildResultCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: _selectedImage == null
              ? Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: _selectedImage != null
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: _selectedImage != null
            ? Image.file(_selectedImage!, fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 52,
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yemeğin fotoğrafını çek',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'veya galeriden seç',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.65),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _BigActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Kamera',
                filled: true,
                color: colorScheme.primary,
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Galeri',
                filled: false,
                color: colorScheme.primary,
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BigActionButton(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Barkod',
                filled: false,
                color: colorScheme.secondary,
                onPressed: _openBarcodeScanner,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Manuel',
                filled: false,
                color: colorScheme.secondary,
                onPressed: _openManualEntry,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF4CAF50),
                ),
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Yemek analiz ediliyor...',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI ile besin değerleri hesaplanıyor',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final data = _analysisResult!;
    final volumeAciklamasi = data['volume_aciklamasi']?.toString();
    final referansNesne = data['referans_nesne']?.toString();
    final hacimMl = data['hacim_ml'];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 3,
      shadowColor: const Color(0xFF4CAF50).withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['yemek_adi']?.toString() ?? 'Bilinmeyen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              'Tahmini porsiyon: ${data['porsiyon_gram']}g',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (referansNesne != null) ...[
              const SizedBox(height: 2),
              Text(
                'Referans: $referansNesne',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const Divider(height: 24),
            _buildNutritionRow('Kalori', '${data['kalori']} kcal'),
            _buildNutritionRow('Protein', '${data['protein']} g'),
            _buildNutritionRow('Karbonhidrat', '${data['karbonhidrat']} g'),
            _buildNutritionRow('Yağ', '${data['yag']} g'),
            if (hacimMl != null)
              _buildNutritionRow('Hacim', '$hacimMl ml'),
            if (volumeAciklamasi != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Nasıl hesaplandı?'),
                      content: Text(volumeAciklamasi),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Nasıl hesaplandı?'),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _AddToMealButton(onPressed: _showConfirmationSheet),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Result Card ────────────────────────────────────────────────────

class _AnimatedResultCard extends StatefulWidget {
  final Widget child;
  const _AnimatedResultCard({super.key, required this.child});

  @override
  State<_AnimatedResultCard> createState() => _AnimatedResultCardState();
}

class _AnimatedResultCardState extends State<_AnimatedResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationStarted) {
      _animationStarted = true;
      if (MediaQuery.of(context).disableAnimations) {
        _ctrl.value = 1.0;
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Big Action Button ────────────────────────────────────────────────────────

class _BigActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<_BigActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse().then((_) => widget.onPressed());
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.filled
                ? widget.color
                : widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: widget.filled
                ? null
                : Border.all(
                    color: widget.color.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 26,
                color: widget.filled ? Colors.white : widget.color,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.filled ? Colors.white : widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Öğüne Ekle Butonu (with tick animation) ─────────────────────────────────

class _AddToMealButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddToMealButton({required this.onPressed});

  @override
  State<_AddToMealButton> createState() => _AddToMealButtonState();
}

class _AddToMealButtonState extends State<_AddToMealButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _showTick = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    await _ctrl.forward();
    setState(() => _showTick = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await _ctrl.reverse();
    if (mounted) {
      setState(() => _showTick = false);
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _showTick ? Icons.check_rounded : Icons.add_rounded,
                  key: ValueKey(_showTick),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Öğüne Ekle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Onay Sayfası ────────────────────────────────────────────────────────────

class _ConfirmationSheet extends StatefulWidget {
  final Map<String, dynamic> analysisData;
  final String? selectedMeal;
  final void Function(Map<String, dynamic> editedData, String meal) onConfirm;

  const _ConfirmationSheet({
    required this.analysisData,
    required this.selectedMeal,
    required this.onConfirm,
  });

  @override
  State<_ConfirmationSheet> createState() => _ConfirmationSheetState();
}

class _ConfirmationSheetState extends State<_ConfirmationSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _calorieCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;
  late String _selectedMeal;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    final d = widget.analysisData;
    _nameCtrl = TextEditingController(text: d['yemek_adi']?.toString() ?? '');
    _portionCtrl = TextEditingController(text: (d['porsiyon_gram'] ?? 100).toString());
    _calorieCtrl = TextEditingController(text: (d['kalori'] ?? 0).toString());
    _proteinCtrl = TextEditingController(text: (d['protein'] ?? 0).toString());
    _carbCtrl = TextEditingController(text: (d['karbonhidrat'] ?? 0).toString());
    _fatCtrl = TextEditingController(text: (d['yag'] ?? 0).toString());
    _selectedMeal = widget.selectedMeal ?? 'kahvaltı';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final editedData = {
      'yemek_adi': _nameCtrl.text.trim().isEmpty
          ? (widget.analysisData['yemek_adi'] ?? 'Bilinmeyen')
          : _nameCtrl.text.trim(),
      'porsiyon_gram': double.tryParse(_portionCtrl.text) ?? 100.0,
      'kalori': double.tryParse(_calorieCtrl.text) ?? 0.0,
      'protein': double.tryParse(_proteinCtrl.text) ?? 0.0,
      'karbonhidrat': double.tryParse(_carbCtrl.text) ?? 0.0,
      'yag': double.tryParse(_fatCtrl.text) ?? 0.0,
    };
    Navigator.pop(context);
    widget.onConfirm(editedData, _selectedMeal);
  }

  Widget _buildStaticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    if (!_isEditMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(ctrl.text,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const meals = <(String, IconData, String)>[
      ('kahvaltı', Icons.wb_sunny_outlined, 'Kahvaltı'),
      ('öğle', Icons.wb_cloudy_outlined, 'Öğle'),
      ('akşam', Icons.nights_stay_outlined, 'Akşam'),
      ('ara öğün', Icons.coffee_outlined, 'Ara Öğün'),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // AI uyarı banner'ı
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu veriler yapay zeka tarafından tahmin edilmiştir. '
                      'Porsiyon miktarı ve besin değerleri yaklaşık olup '
                      'hatalı hesaplamalar içerebilir. Lütfen değerleri '
                      'kontrol edip gerekirse düzenleyin.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text('Bu değerler yaklaşıktır',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('Düzenlemek ister misiniz?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 16),
            _buildRow('Yemek Adı', _nameCtrl),
            _buildRow('Porsiyon (g)', _portionCtrl,
                keyboardType: TextInputType.number),
            _buildRow('Kalori (kcal)', _calorieCtrl,
                keyboardType: TextInputType.number),
            _buildRow('Protein (g)', _proteinCtrl,
                keyboardType: TextInputType.number),
            _buildRow('Karbonhidrat (g)', _carbCtrl,
                keyboardType: TextInputType.number),
            _buildRow('Yağ (g)', _fatCtrl,
                keyboardType: TextInputType.number),
            // Volume bilgisi (salt okunur)
            if (!_isEditMode) ...[
              if (widget.analysisData['referans_nesne'] != null)
                _buildStaticRow(
                    'Referans Nesne',
                    widget.analysisData['referans_nesne'].toString()),
              if (widget.analysisData['hacim_ml'] != null)
                _buildStaticRow(
                    'Hacim', '${widget.analysisData['hacim_ml']} ml'),
              if (widget.analysisData['volume_aciklamasi'] != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nasıl hesaplandı?'),
                        content: Text(
                            widget.analysisData['volume_aciklamasi'].toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Nasıl hesaplandı?'),
                ),
              ],
            ],
            if (widget.selectedMeal == null) ...[
              const SizedBox(height: 16),
              Text('Öğün Seçin',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: meals
                    .map((m) => ChoiceChip(
                          avatar: Icon(m.$2, size: 16),
                          label: Text(m.$3),
                          selected: _selectedMeal == m.$1,
                          onSelected: (_) =>
                              setState(() => _selectedMeal = m.$1),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (!_isEditMode) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _isEditMode = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Düzenle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Onayla ve Ekle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
