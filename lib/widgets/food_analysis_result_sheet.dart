import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/food_analysis_result.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';

class FoodAnalysisResultSheet extends StatefulWidget {
  final FoodAnalysisResult result;
  final File? image;
  final String? mealType;
  final bool isFullScreen;
  final VoidCallback? onEdit;
  final Function(FoodEntry) onConfirm;
  final ScrollController? scrollController;
  final DraggableScrollableController? draggableController;

  const FoodAnalysisResultSheet({
    super.key,
    required this.result,
    this.image,
    this.mealType,
    this.isFullScreen = false,
    this.onEdit,
    required this.onConfirm,
    this.scrollController,
    this.draggableController,
  });

  @override
  State<FoodAnalysisResultSheet> createState() => _FoodAnalysisResultSheetState();

  static Future<void> show(
    BuildContext context, {
    required FoodAnalysisResult result,
    File? image,
    String? mealType,
    bool isFullScreen = false,
    VoidCallback? onEdit,
    required Function(FoodEntry) onConfirm,
  }) {
    if (isFullScreen) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (context) => FoodAnalysisResultSheet(
          result: result,
          image: image,
          mealType: mealType,
          isFullScreen: true,
          onEdit: onEdit,
          onConfirm: onConfirm,
        ),
      );
    }

    final draggableCtrl = DraggableScrollableController();

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => DraggableScrollableSheet(
        controller: draggableCtrl,
        initialChildSize: 0.76,
        minChildSize: 0.1,
        maxChildSize: 0.95,
        expand: false,
        snap: false,
        builder: (ctx, scrollCtrl) => FoodAnalysisResultSheet(
          result: result,
          image: image,
          mealType: mealType,
          isFullScreen: false,
          onEdit: onEdit,
          onConfirm: onConfirm,
          scrollController: scrollCtrl,
          draggableController: draggableCtrl,
        ),
      ),
    );
  }
}

class _FoodAnalysisResultSheetState extends State<FoodAnalysisResultSheet> {
  late String _selectedMeal;
  bool _isSaved = false;
  bool _confirmedExit = false;
  bool _isShowingExitDialog = false;
  String? _suggestedImageUrl;
  bool _useSuggestedImage = true;
  bool _imageSearching = false;

  final _calorieCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();
  bool _isCalorieManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.mealType ?? 'kahvaltı';
    if (widget.image == null && !widget.isFullScreen) {
      _fetchSuggestedImage(widget.result.foodName);
    }

    _nameCtrl.text = widget.result.foodName;
    _gramsCtrl.text = widget.result.portionGrams.toStringAsFixed(0);
    
    final scaled = widget.result.nutritionScaled;
    _calorieCtrl.text = scaled.calories.toStringAsFixed(0);
    _proteinCtrl.text = scaled.protein.toStringAsFixed(1);
    _carbCtrl.text = scaled.carbohydrates.toStringAsFixed(1);
    _fatCtrl.text = scaled.fat.toStringAsFixed(1);
    _fiberCtrl.text = scaled.fiber.toStringAsFixed(1);

    _proteinCtrl.addListener(_autoCalcCalories);
    _carbCtrl.addListener(_autoCalcCalories);
    _fatCtrl.addListener(_autoCalcCalories);
    _fiberCtrl.addListener(_autoCalcCalories);
  }

  void _autoCalcCalories() {
    if (_isCalorieManuallyEdited) return;
    final p = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final c = double.tryParse(_carbCtrl.text) ?? 0.0;
    final f = double.tryParse(_fatCtrl.text) ?? 0.0;
    final fi = double.tryParse(_fiberCtrl.text) ?? 0.0;
    final total = (p * 4) + (c * 4) + (f * 9) + (fi * 2);
    if (total > 0) _calorieCtrl.text = total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    _nameCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestedImage(String foodName) async {
    if (mounted) setState(() => _imageSearching = true);
    try {
      final query = Uri.encodeComponent('$foodName yemek');
      final resp = await http.get(Uri.parse(
        'https://commons.wikimedia.org/w/api.php?action=query&prop=pageimages'
        '&format=json&piprop=thumbnail&pithumbsize=600'
        '&generator=search&gsrnamespace=6&gsrlimit=5&gsrsearch=$query',
      )).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null) {
          for (final page in pages.values) {
            final thumb = page['thumbnail']?['source'] as String?;
            if (thumb != null) {
              if (mounted) setState(() => _suggestedImageUrl = thumb);
              break;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _imageSearching = false);
  }

  void _showMicroNutrients() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => MicroNutrientsSheet(
          result: widget.result,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final portionGrams = double.tryParse(_gramsCtrl.text) ?? widget.result.portionGrams;
    final factor = portionGrams / 100;

    // Download suggested image if user opted in and no user image
    String? resolvedImagePath = widget.image?.path;
    if (resolvedImagePath == null && _useSuggestedImage && _suggestedImageUrl != null) {
      try {
        final imgResp = await http.get(Uri.parse(_suggestedImageUrl!))
            .timeout(const Duration(seconds: 10));
        if (imgResp.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(imgResp.bodyBytes);
          resolvedImagePath = file.path;
        }
      } catch (_) {}
    }

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim().isEmpty ? widget.result.foodName : _nameCtrl.text.trim(),
      portionSize: portionGrams,
      nutritionData: NutritionData(
        calories: factor > 0 ? (double.tryParse(_calorieCtrl.text) ?? 0.0) / factor : 0,
        protein: factor > 0 ? (double.tryParse(_proteinCtrl.text) ?? 0.0) / factor : 0,
        carbohydrates: factor > 0 ? (double.tryParse(_carbCtrl.text) ?? 0.0) / factor : 0,
        fat: factor > 0 ? (double.tryParse(_fatCtrl.text) ?? 0.0) / factor : 0,
        fiber: factor > 0 ? (double.tryParse(_fiberCtrl.text) ?? 0.0) / factor : 0,
      ),
      nutrition65per100g: widget.result.nutrition65per100g,
      timestamp: DateTime.now(),
      mealType: _selectedMeal,
      imagePath: resolvedImagePath,
      novaGroup: widget.result.offProduct?.novaGroup,
    );
    widget.onConfirm(entry);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final scaled = result.nutritionScaled;
    final cs = Theme.of(context).colorScheme;

    Future<bool?> _showDeleteConfirmation() async {
      return await showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Analizi Sil?'),
          content: const Text('Bu analizi silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    Future<bool?> _showDismissConfirmation() async {
      return await showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Analizden Çıkılsın mı?'),
          content: const Text('Henüz kaydetmediniz. Devam etmek mi istersiniz yoksa silip çıkmak mı?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Çık', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydetmeye Devam Et'),
            ),
          ],
        ),
      );
    }

    void exitSheet() {
      setState(() => _confirmedExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final content = NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= notification.minExtent + 0.01 && !_isShowingExitDialog) {
          _isShowingExitDialog = true;
          _showDismissConfirmation().then((choice) {
            _isShowingExitDialog = false;
            if (choice == null) {
              // User dismissed dialog by clicking outside (if possible) or back button
              // Bring it back up a bit so it doesn't get stuck at 0.1
              widget.draggableController?.animateTo(0.8, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              return;
            }
            if (choice == true && context.mounted) {
              // Stay on page as requested by user
              widget.draggableController?.animateTo(0.8, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            } else if (choice == false && context.mounted) {
              exitSheet();
            }
          });
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isFullScreen)
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (widget.image != null && !widget.isFullScreen) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: Image.file(
                    widget.image!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (!widget.isFullScreen) ...[
              if (_imageSearching)
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: cs.primary.withValues(alpha: 0.06),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                        const SizedBox(height: 8),
                        Text('Görsel aranıyor...', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              else if (_suggestedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: _suggestedImageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Önerilen görsel kullanılsın mı?',
                          style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w500)),
                      ),
                      Switch.adaptive(
                        value: _useSuggestedImage,
                        onChanged: (v) => setState(() => _useSuggestedImage = v),
                        activeColor: cs.primary,
                      ),
                    ],
                  ),
                ),
              ] else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: cs.primary.withValues(alpha: 0.06),
                  ),
                  child: Center(child: Icon(Icons.restaurant_menu_rounded, size: 56, color: cs.primary.withValues(alpha: 0.25))),
                ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ConfidenceBadge(result: result),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Porsiyon: ', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
                IntrinsicWidth(
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface.withValues(alpha: 0.7)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(' g', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: _calorieCtrl,
                    onTap: () => _isCalorieManuallyEdited = true,
                    onChanged: (v) => _isCalorieManuallyEdited = true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 32, color: cs.primary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('kcal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary.withValues(alpha: 0.7))),
              ],
            ),
            Text('~${result.alternativeMin.round()} – ${result.alternativeMax.round()} kcal aralığı', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 16),
            Row(
              children: [
                _EditableMacro(controller: _proteinCtrl, label: 'Protein', color: const Color(0xFF7EE787)),
                const SizedBox(width: 6),
                _EditableMacro(controller: _carbCtrl, label: 'Karbonhidrat', color: const Color(0xFF58A6FF)),
                const SizedBox(width: 6),
                _EditableMacro(controller: _fatCtrl, label: 'Yağ', color: const Color(0xFFF0A500)),
                const SizedBox(width: 6),
                _EditableMacro(controller: _fiberCtrl, label: 'Lif', color: const Color(0xFFFF6B6B)),
              ],
            ),
            if (result.offProduct != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (result.offProduct!.nutriscoreGrade != null) _NutriScoreBadge(grade: result.offProduct!.nutriscoreGrade!),
                  if (result.offProduct!.nutriscoreGrade != null && result.offProduct!.novaGroup != null) const SizedBox(width: 6),
                  if (result.offProduct!.novaGroup != null) _NovaBadge(group: result.offProduct!.novaGroup!),
                ],
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showMicroNutrients,
              icon: const Icon(Icons.equalizer_rounded, size: 18),
              label: const Text('Mikro Besinleri Gör', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('Hangi öğüne eklensin?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            _MealChipRow(selected: _selectedMeal, onChanged: (m) => setState(() => _selectedMeal = m)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                if (widget.onEdit != null) {
                  widget.onEdit?.call();
                } else {
                  _confirm();
                }
              },
              icon: const Icon(Icons.edit_note_rounded, size: 22),
              label: const Text('Yemeği Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded, size: 22),
              label: const Text('Öğüne Ekle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ],
        ),
      ),
    );

    if (!widget.isFullScreen) {
      return PopScope(
        canPop: _confirmedExit,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final choice = await _showDismissConfirmation();
          if (choice == null) {
            widget.draggableController?.animateTo(0.8, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            return;
          }
          if (choice == true && context.mounted) {
            widget.draggableController?.animateTo(0.8, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          } else if (choice == false && context.mounted) {
            exitSheet();
          }
        },
        child: Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: content,
        ),
      );
    }

    return PopScope(
      canPop: _confirmedExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final choice = await _showDismissConfirmation();
        if (choice == null) return;
        if (choice == true && context.mounted) {
          // stay on page
        } else if (choice == false && context.mounted) {
          exitSheet();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Expanded(
              flex: 55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.image != null) Image.file(widget.image!, fit: BoxFit.cover) else const ColoredBox(color: Colors.black),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    child: GestureDetector(
                      onTap: () async {
                        final choice = await _showDismissConfirmation();
                        if (choice == null) return;
                        if (choice == true && context.mounted) { /* Stay on page */ }
                        else if (choice == false && context.mounted) { Navigator.of(context).pop(); }
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 50,
                    child: GestureDetector(
                      onTap: _confirm,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
                        child: const Icon(Icons.turned_in_rounded, color: Color(0xFF7EE787), size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        final ok = await _showDeleteConfirmation();
                        if (ok == true && context.mounted) Navigator.pop(context);
                      },
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFF85149), size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 45, child: Container(color: cs.surface, child: content)),
          ],
        ),
      ),
    );
  }
}

class _EditableMacro extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;
  const _EditableMacro({required this.controller, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text('g', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
              ],
            ),
            Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final FoodAnalysisResult result;
  const _ConfidenceBadge({required this.result});

  void _showAiExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26D0CE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF26D0CE).withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: const Text('Yapay Zeka Analizi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF26D0CE))),
                  ),
                  const SizedBox(width: 12),
                  Text('Nasıl hesaplandı?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Bu besin bilgisi, yüklediğiniz görseli analiz eden gelişmiş yapay zeka modelleri (Claude Vision) ve besin veritabanları (Edamam, OpenFoodFacts) kullanılarak oluşturulmuştur.',
                style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.8), height: 1.5),
              ),
              if (result.confidenceReason != null) ...[
                const SizedBox(height: 20),
                Text(
                  'ANALİZ DETAYI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 1.1),
                ),
                const SizedBox(height: 8),
                Text(
                  result.confidenceReason!,
                  style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6), height: 1.5, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = result.confidenceScore;
    final displayedScore = score < 85 ? 85 : (score > 100 ? 100 : score);
    final color = Color.lerp(const Color(0xFFF85149), const Color(0xFF7EE787), displayedScore / 100) ?? const Color(0xFF7EE787);
    return InkWell(
      onTap: () => _showAiExplanation(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              'Doğruluk %$displayedScore',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutriScoreBadge extends StatelessWidget {
  final String grade;
  const _NutriScoreBadge({required this.grade});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (grade.toLowerCase()) {
      case 'a': color = const Color(0xFF038141); break;
      case 'b': color = const Color(0xFF85BB2F); break;
      case 'c': color = const Color(0xFFFECC02); break;
      case 'd': color = const Color(0xFFEE8100); break;
      default: color = const Color(0xFFE63E11);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text('NutriScore ${grade.toUpperCase()}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _NovaBadge extends StatelessWidget {
  final int group;
  const _NovaBadge({required this.group});
  @override
  Widget build(BuildContext context) {
    Color color; String label;
    switch (group) {
      case 1: color = const Color(0xFF038141); label = 'NOVA 1'; break;
      case 2: color = const Color(0xFF85BB2F); label = 'NOVA 2'; break;
      case 3: color = const Color(0xFFEE8100); label = 'NOVA 3'; break;
      default: color = const Color(0xFFE63E11); label = 'NOVA 4';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _MealChipRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _MealChipRow({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const meals = [('kahvaltı', '☀️', 'Kahvaltı'), ('öğle', '🌤', 'Öğle'), ('akşam', '🌙', 'Akşam'), ('ara öğün', '☕', 'Ara Öğün')];
    return Wrap(
      spacing: 6,
      children: meals.map((m) => ChoiceChip(
        label: Text('${m.$2} ${m.$3}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        selected: selected == m.$1,
        onSelected: (_) => onChanged(m.$1),
        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        showCheckmark: true,
        side: BorderSide(
          color: selected == m.$1 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) 
            : Colors.transparent,
        ),
        labelStyle: TextStyle(
          color: selected == m.$1 ? Theme.of(context).colorScheme.primary : null,
          fontSize: 12,
          fontWeight: selected == m.$1 ? FontWeight.w700 : FontWeight.w600,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      )).toList(),
    );
  }
}

// ── Veri modeli ────────────────────────────────────────────────────────────────

class _NutriEntry {
  final String label;
  final double value;
  final String unit;
  final int decimals;
  // Günlük referans değeri (sıfırsa bar gösterilmez)
  final double dri;

  const _NutriEntry(this.label, this.value, this.unit, {this.decimals = 1, this.dri = 0});
}

class _NutriSection {
  final String title;
  final Color color;
  final List<_NutriEntry> entries;
  const _NutriSection(this.title, this.color, this.entries);
  bool get hasData => entries.any((e) => e.value >= 0.01);
}

// ── Sheet ──────────────────────────────────────────────────────────────────────

class MicroNutrientsSheet extends StatelessWidget {
  final FoodAnalysisResult result;
  final ScrollController? scrollController;
  const MicroNutrientsSheet({super.key, required this.result, this.scrollController});

  List<_NutriSection> _buildSections(NutritionData65 n, double factor) {
    double s(double v) => v * factor;

    return [
      _NutriSection('MİNERALLER', const Color(0xFF58A6FF), [
        _NutriEntry('Kalsiyum',    s(n.calcium),    'mg',  decimals: 0, dri: 1000),
        _NutriEntry('Demir',       s(n.iron),       'mg',  dri: 18),
        _NutriEntry('Magnezyum',   s(n.magnesium),  'mg',  decimals: 0, dri: 420),
        _NutriEntry('Fosfor',      s(n.phosphorus), 'mg',  decimals: 0, dri: 700),
        _NutriEntry('Potasyum',    s(n.potassium),  'mg',  decimals: 0, dri: 3500),
        _NutriEntry('Sodyum',      s(n.sodium),     'mg',  decimals: 0, dri: 2300),
        _NutriEntry('Çinko',       s(n.zinc),       'mg',  dri: 11),
        _NutriEntry('Bakır',       s(n.copper),     'mg',  dri: 0.9),
        _NutriEntry('Manganez',    s(n.manganese),  'mg',  dri: 2.3),
        _NutriEntry('Selenyum',    s(n.selenium),   'mcg', dri: 55),
        _NutriEntry('İyot',        s(n.iodine),     'mcg', dri: 150),
        _NutriEntry('Krom',        s(n.chromium),   'mcg', dri: 35),
        _NutriEntry('Molibden',    s(n.molybdenum), 'mcg', dri: 45),
        _NutriEntry('Florür',      s(n.fluoride),   'mcg', decimals: 0),
      ]),

      _NutriSection('VİTAMİNLER', const Color(0xFFFFA726), [
        _NutriEntry('Vitamin C',             s(n.vitC),        'mg',  dri: 90),
        _NutriEntry('Vitamin D',             s(n.vitD_mcg),    'mcg', dri: 20),
        _NutriEntry('Vitamin A',             s(n.vitA_RAE),    'mcg RAE', dri: 900),
        _NutriEntry('Vitamin E',             s(n.vitE),        'mg',  dri: 15),
        _NutriEntry('Vitamin K',             s(n.vitK),        'mcg', dri: 120),
        _NutriEntry('B1 (Tiamin)',           s(n.thiamine),    'mg',  dri: 1.2),
        _NutriEntry('B2 (Riboflavin)',       s(n.riboflavin),  'mg',  dri: 1.3),
        _NutriEntry('B3 (Niasin)',           s(n.niacin),      'mg',  dri: 16),
        _NutriEntry('B5 (Pantotenik)',       s(n.pantothenic), 'mg',  dri: 5),
        _NutriEntry('B6',                   s(n.vitB6),       'mg',  dri: 1.7),
        _NutriEntry('Folat (B9)',           s(n.folate),      'mcg', decimals: 0, dri: 400),
        _NutriEntry('B12',                  s(n.vitB12),      'mcg', dri: 2.4),
        _NutriEntry('Biotin (B7)',          s(n.biotin),      'mcg', dri: 30),
        _NutriEntry('Kolin',               s(n.choline),     'mg',  decimals: 0, dri: 550),
      ]),

      _NutriSection('KAROTENOİDLER', const Color(0xFFFF6B00), [
        _NutriEntry('Beta-Karoten',          s(n.betaCarot),   'mcg', decimals: 0, dri: 3000),
        _NutriEntry('Likopen',             s(n.lycopene),    'mcg', decimals: 0, dri: 10000),
        _NutriEntry('Lutein + Zeaksantin', s(n.luteinZea),   'mcg', decimals: 0, dri: 6000),
        _NutriEntry('Alfa-Karoten',        s(n.alphaCarot),  'mcg', decimals: 0, dri: 2000),
      ]),

      _NutriSection('YAĞ & KOLESTEROl', const Color(0xFF3FB950), [
        _NutriEntry('Doymuş Yağ',      s(n.satFat),    'g', dri: 20),
        _NutriEntry('Tekli Doymamiş',  s(n.monoFat),   'g', dri: 30),
        _NutriEntry('Çoklu Doymamış',  s(n.polyFat),   'g', dri: 20),
        _NutriEntry('Trans Yağ',       s(n.transFat),  'g', dri: 2),
        _NutriEntry('Kolesterol',      s(n.cholesterol), 'mg', decimals: 0, dri: 300),
        _NutriEntry('Omega-3',         s(n.omega3),    'g',  dri: 1.6),
        _NutriEntry('Omega-6',         s(n.omega6),    'g',  dri: 15),
        _NutriEntry('ALA',             s(n.ala),       'g',  dri: 1.6),
        _NutriEntry('EPA',             s(n.epa),       'g',  dri: 0.5),
        _NutriEntry('DHA',             s(n.dha),       'g',  dri: 0.5),
        _NutriEntry('Linoleik',        s(n.linoleic),  'g',  dri: 15),
      ]),

      _NutriSection('AMİNO ASİTLER', const Color(0xFFD2A8FF), [
        _NutriEntry('Lösin',          s(n.leucine),       'g', dri: 2.7),
        _NutriEntry('Lizin',          s(n.lysine),        'g', dri: 2.1),
        _NutriEntry('Valin',          s(n.valine),        'g', dri: 1.8),
        _NutriEntry('İzolösin',       s(n.isoleucine),    'g', dri: 1.4),
        _NutriEntry('Treonin',        s(n.threonine),     'g', dri: 1.0),
        _NutriEntry('Metionin',       s(n.methionine),    'g', dri: 0.9),
        _NutriEntry('Fenilalanin',    s(n.phenylalanine), 'g', dri: 2.3),
        _NutriEntry('Triptofan',      s(n.tryptophan),    'g', dri: 0.3),
        _NutriEntry('Histidin',       s(n.histidine),     'g', dri: 0.7),
        _NutriEntry('Sistein',        s(n.cystine),       'g', dri: 0.4),
        _NutriEntry('Tirozin',        s(n.tyrosine),      'g', dri: 0.8),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n65 = result.nutrition65per100g;
    final factor = result.portionGrams / 100.0;

    final sections = n65 != null ? _buildSections(n65, factor) : <_NutriSection>[];
    final activeSections = sections.where((s) => s.hasData).toList();

    int totalCount = activeSections.fold(0, (sum, s) => sum + s.entries.where((e) => e.value >= 0.01).length);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Text(result.foodName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${result.portionGrams.round()}g porsiyon', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                    if (totalCount > 0)
                      Text('$totalCount besin tespit edildi', style: TextStyle(fontSize: 10, color: cs.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Flexible(
            child: n65 == null || activeSections.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Detaylı besin bilgisi mevcut değil', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: activeSections.length,
                    itemBuilder: (ctx, si) {
                      final section = activeSections[si];
                      final visible = section.entries.where((e) => e.value >= 0.01).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 6),
                            child: Row(
                              children: [
                                Container(width: 3, height: 14, decoration: BoxDecoration(color: section.color, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 6),
                                Text(section.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: section.color, letterSpacing: 0.8)),
                              ],
                            ),
                          ),
                          ...visible.map((e) => _NutriRow(entry: e, sectionColor: section.color, cs: cs)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NutriRow extends StatelessWidget {
  final _NutriEntry entry;
  final Color sectionColor;
  final ColorScheme cs;

  const _NutriRow({required this.entry, required this.sectionColor, required this.cs});

  @override
  Widget build(BuildContext context) {
    final valueStr = entry.value.toStringAsFixed(entry.decimals);
    final pct = entry.dri > 0 ? (entry.value / entry.dri).clamp(0.0, 1.0) : 0.0;
    final pctInt = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(entry.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Text(valueStr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 3),
              SizedBox(width: 50, child: Text(entry.unit, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.45)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: sectionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('%$pctInt', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sectionColor)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct > 0 ? pct : 0.001, // Show a tiny line even if 0
              minHeight: 3,
              backgroundColor: sectionColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(sectionColor.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}
