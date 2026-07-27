import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../providers/nutrition_provider.dart';
import '../services/nutrition_service.dart';
import '../services/saved_foods_service.dart';
import '../l10n/app_localizations.dart';
import 'camera_screen.dart';

class BarcodeScreen extends StatefulWidget {
  final String? selectedMeal;
  final VoidCallback? onFoodAdded;
  final DateTime? date;

  const BarcodeScreen({super.key, this.selectedMeal, this.onFoodAdded, this.date});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final NutritionService _nutritionService = NutritionService();

  bool _isScanned = false;
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited || status.isRestricted) {
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _checkingPermission = false;
        });
      }
    } else {
      final result = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _permissionGranted = result.isGranted || result.isLimited || result.isRestricted;
          _checkingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_isScanned) return;
    setState(() {
      _isScanned = true;
      _isLoading = true;
    });

    try {
      final product = await _nutritionService.searchByBarcode(barcode);
      setState(() {
        _isLoading = false;
      });
      if (product == null) {
        setState(() {
          _isScanned = false;
        });
        _showProductNotFoundDialog();
      } else {
        _showBarcodeResultSheet(product);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isScanned = false;
      });
      _showErrorDialog('${context.tr('Barkod okunamadı')}: $e');
    }
  }

  void _showProductNotFoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.search_off_rounded, color: Colors.orange, size: 48),
        title: Text(
          context.tr('Ürün Bulunamadı'),
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.tr('Bu barkoda ait ürün bulunamadı. Alternatif yöntemlerle analiz edebilirsiniz:'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(context.tr('Görselden Analiz')),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CameraScreen(selectedMeal: widget.selectedMeal),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.mic_rounded),
              label: Text(context.tr('Tarif Ederek Analiz')),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                final navigator = Navigator.of(context);
                navigator.pop(); // Close BarcodeScreen
                showVoiceEntrySheet(
                  navigator.context,
                  selectedMeal: widget.selectedMeal ?? 'kahvaltı',
                  onDone: widget.onFoodAdded,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.tr('Tamam'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
        title: Text(context.tr('Ürün Bulunamadı'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Tamam')),
          ),
        ],
      ),
    );
  }

  void _showBarcodeResultSheet(FoodProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BarcodeResultSheet(
        product: product,
        selectedMeal: widget.selectedMeal,
        onAdd: (portionGrams, mealType) {
          _addToMeal(product, portionGrams, mealType);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isScanned = false; // Resume scanning when sheet is closed
        });
      }
    });
  }

  void _addToMeal(FoodProduct product, double portionGrams, String mealType) {
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: product.name,
      brand: product.brand,
      portionSize: portionGrams,
      nutritionData: product.nutritionPer100g,
      timestamp: DateTime.now(),
      mealType: mealType,
      imageUrl: product.imageUrl,
    );

    context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onFoodAdded?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildScannerArea(),
    );
  }

  Widget _buildScannerArea() {
    final topPad = MediaQuery.of(context).padding.top;

    if (_checkingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_permissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.tr('Barkod taramak için kamera izni vermeniz gerekmektedir.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                openAppSettings();
              },
              child: Text(context.tr('Ayarlara Git')),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_isScanned) return;
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final rawValue = barcodes.first.rawValue;
              if (rawValue != null) _handleBarcode(rawValue);
            }
          },
        ),
        Center(
          child: _FocusFrame(barcodeDetected: _isScanned),
        ),
        // Back Button
        Positioned(
          top: topPad + 8,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
        ),
        // Flash Button
        Positioned(
          top: topPad + 8,
          right: 16,
          child: GestureDetector(
            onTap: () => _controller.toggleTorch(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
        // Instruction text
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.tr('Ürünün barkodunu kameraya tutun'),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(context.tr('Ürün aranıyor...'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Barcode Result Sheet ───────────────────────────────────────────────────

class _BarcodeResultSheet extends StatefulWidget {
  final FoodProduct product;
  final String? selectedMeal;
  final void Function(double portionGrams, String meal) onAdd;

  const _BarcodeResultSheet({
    required this.product,
    this.selectedMeal,
    required this.onAdd,
  });

  @override
  State<_BarcodeResultSheet> createState() => _BarcodeResultSheetState();
}

class _BarcodeResultSheetState extends State<_BarcodeResultSheet> {
  late final TextEditingController _portionCtrl;
  late String _meal;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final initialPortion = widget.product.portionSizeGrams;
    final initialPortionText = initialPortion != null && initialPortion > 0
        ? initialPortion.toStringAsFixed(0)
        : '100';
    _portionCtrl = TextEditingController(text: initialPortionText);
    _meal = widget.selectedMeal ?? 'kahvaltı';
    _checkIfSaved();
  }

  @override
  void dispose() {
    _portionCtrl.dispose();
    super.dispose();
  }

  void _checkIfSaved() async {
    final saved = await SavedFoodsService.isSaved(widget.product.name);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaveFood() async {
    final name = widget.product.name;
    if (_isSaved) {
      await SavedFoodsService.remove(name);
      if (mounted) {
        setState(() => _isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Kayıtlı yiyeceklerden kaldırıldı')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final portionGrams = double.tryParse(_portionCtrl.text) ?? 100.0;
      final food = SavedFood(
        id: name,
        name: name,
        brand: widget.product.brand,
        portionGrams: portionGrams,
        nutritionPer100g: widget.product.nutritionPer100g,
        sources: ['barcode'],
        savedAt: DateTime.now(),
        imagePath: null,
        imageUrl: widget.product.imageUrl,
      );
      await SavedFoodsService.save(food);
      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Kayıtlı yiyeceklere eklendi')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirm() {
    final portion = double.tryParse(_portionCtrl.text) ?? 100.0;
    if (portion <= 0) return;
    Navigator.pop(context);
    widget.onAdd(portion, _meal);
  }

  Widget _buildMicroNutrientList(BuildContext context, NutritionData n, double factor) {
    final scaled = n.scaleBy(factor);
    final cs = Theme.of(context).colorScheme;

    bool hasVal(double? v) => v != null && v > 0.0;
    
    final vitamins = <(String, double, String)>[
      if (hasVal(scaled.vitaminC)) ('Vitamin C', scaled.vitaminC!, 'mg'),
      if (hasVal(scaled.vitaminD)) ('Vitamin D', scaled.vitaminD!, 'mcg'),
      if (hasVal(scaled.vitaminA)) ('Vitamin A', scaled.vitaminA!, 'mcg'),
      if (hasVal(scaled.vitaminE)) ('Vitamin E', scaled.vitaminE!, 'mg'),
      if (hasVal(scaled.vitaminK)) ('Vitamin K', scaled.vitaminK!, 'mcg'),
      if (hasVal(scaled.vitaminB6)) ('Vitamin B6', scaled.vitaminB6!, 'mg'),
      if (hasVal(scaled.vitaminB12)) ('Vitamin B12', scaled.vitaminB12!, 'mcg'),
      if (hasVal(scaled.folate)) ('Folat', scaled.folate!, 'mcg'),
      if (hasVal(scaled.thiamine)) ('Tiamin (B1)', scaled.thiamine!, 'mg'),
      if (hasVal(scaled.riboflavin)) ('Riboflavin (B2)', scaled.riboflavin!, 'mg'),
      if (hasVal(scaled.niacin)) ('Niasin (B3)', scaled.niacin!, 'mg'),
      if (hasVal(scaled.pantothenic)) ('Pantotenik Asit (B5)', scaled.pantothenic!, 'mg'),
    ];

    final minerals = <(String, double, String)>[
      if (hasVal(scaled.calcium)) ('Kalsiyum', scaled.calcium!, 'mg'),
      if (hasVal(scaled.iron)) ('Demir', scaled.iron!, 'mg'),
      if (hasVal(scaled.magnesium)) ('Magnezyum', scaled.magnesium!, 'mg'),
      if (hasVal(scaled.zinc)) ('Çinko', scaled.zinc!, 'mg'),
      if (hasVal(scaled.potassium)) ('Potasyum', scaled.potassium!, 'mg'),
      if (hasVal(scaled.sodium)) ('Sodyum', scaled.sodium!, 'mg'),
      if (hasVal(scaled.phosphorus)) ('Fosfor', scaled.phosphorus!, 'mg'),
      if (hasVal(scaled.selenium)) ('Selenyum', scaled.selenium!, 'mcg'),
      if (hasVal(scaled.copper)) ('Bakır', scaled.copper!, 'mg'),
      if (hasVal(scaled.manganese)) ('Manganez', scaled.manganese!, 'mg'),
    ];

    final fats = <(String, double, String)>[
      if (hasVal(scaled.monoFat)) ('Tekli Doymamış Yağ', scaled.monoFat!, 'g'),
      if (hasVal(scaled.polyFat)) ('Çoklu Doymamış Yağ', scaled.polyFat!, 'g'),
      if (hasVal(scaled.transFat)) ('Trans Yağ', scaled.transFat!, 'g'),
      if (hasVal(scaled.omega3)) ('Omega-3', scaled.omega3!, 'g'),
      if (hasVal(scaled.omega6)) ('Omega-6', scaled.omega6!, 'g'),
      if (hasVal(scaled.cholesterol)) ('Kolesterol', scaled.cholesterol!, 'mg'),
    ];

    if (vitamins.isEmpty && minerals.isEmpty && fats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            context.tr('Mikro besin verisi bulunamadı'),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    Widget section(String title, Color color) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            context.tr(title),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
        );

    Widget row(String label, double value, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(label),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(value < 0.1 ? 2 : 1),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vitamins.isNotEmpty) ...[
          section('VİTAMİNLER', const Color(0xFFFFA726)),
          ...vitamins.map((v) => row(v.$1, v.$2, v.$3)),
        ],
        if (minerals.isNotEmpty) ...[
          section('MİNERALLER', const Color(0xFF58A6FF)),
          ...minerals.map((m) => row(m.$1, m.$2, m.$3)),
        ],
        if (fats.isNotEmpty) ...[
          section('YAĞLAR', const Color(0xFF3FB950)),
          ...fats.map((f) => row(f.$1, f.$2, f.$3)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final portionGrams = double.tryParse(_portionCtrl.text) ?? 100.0;
    final factor = portionGrams / 100.0;
    final n = widget.product.nutritionPer100g;
    final hasImage = widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty;

    final hasMicros = [
      n.monoFat, n.polyFat, n.transFat, n.cholesterol,
      n.selenium, n.magnesium, n.iron, n.zinc, n.calcium, n.potassium, n.sodium, n.phosphorus, n.copper, n.manganese,
      n.vitaminA, n.vitaminC, n.vitaminD, n.vitaminE, n.vitaminK, n.vitaminB12, n.thiamine, n.riboflavin, n.niacin, n.pantothenic, n.vitaminB6, n.folate,
      n.omega3, n.omega6,
    ].any((v) => v != null && v > 0.0);

    final meals = <(String, String, String)>[
      ('kahvaltı', '☀️', 'Kahvaltı'),
      ('öğle', '🌤', 'Öğle'),
      ('akşam', '🌙', 'Akşam'),
      ('ara öğün', '☕', 'Ara Öğün'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Image Stack
            Stack(
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.product.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: cs.primary.withValues(alpha: 0.06),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        size: 56,
                        color: cs.primary.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _toggleSaveFood,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Icon(
                        _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: _isSaved ? const Color(0xFFF0A500) : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.product.brand != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.product.brand!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _portionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('Porsiyon Miktarı (g) *'),
                border: const OutlineInputBorder(),
                suffixText: 'g',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _infoRow(context, 'Kalori', '${(n.calories * factor).toStringAsFixed(0)} kcal'),
                  _infoRow(context, 'Protein', '${(n.protein * factor).toStringAsFixed(1)} g'),
                  _infoRow(context, 'Karbonhidrat', '${(n.carbohydrates * factor).toStringAsFixed(1)} g'),
                  _infoRow(context, 'Yağ', '${(n.fat * factor).toStringAsFixed(1)} g'),
                ],
              ),
            ),
            if (hasMicros) ...[
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    context.tr('Daha fazlası'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  children: [
                    _buildMicroNutrientList(context, widget.product.nutritionPer100g, factor),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(context.tr('Öğün Seçin'), style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: meals.map((m) {
                final isSelected = _meal == m.$1;
                return ChoiceChip(
                  label: Text('${m.$2} ${context.tr(m.$3)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? cs.primary : null,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      )),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _meal = m.$1),
                  selectedColor: cs.primary.withValues(alpha: 0.12),
                  checkmarkColor: cs.primary,
                  showCheckmark: true,
                  side: BorderSide(
                    color: isSelected 
                      ? cs.primary.withValues(alpha: 0.3) 
                      : Colors.transparent,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr('Öğüne Ekle')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(ctx.tr(label),
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Focus Frame ──────────────────────────────────────────────────────────────

class _FocusFrame extends StatelessWidget {
  final bool barcodeDetected;
  const _FocusFrame({this.barcodeDetected = false});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: barcodeDetected ? color : Colors.amber,
        end: barcodeDetected ? Colors.amber : color,
      ),
      duration: const Duration(milliseconds: 300),
      builder: (ctx, c, _) => CustomPaint(
        size: const Size(280, 280),
        painter: _FocusFramePainter(color: c ?? color),
      ),
    );
  }
}

class _FocusFramePainter extends CustomPainter {
  final Color color;
  const _FocusFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const len = 24.0;
    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(w, h - len), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
  }

  @override
  bool shouldRepaint(_FocusFramePainter old) => old.color != color;
}
