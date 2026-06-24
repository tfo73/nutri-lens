import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/food_entry.dart';
import '../providers/nutrition_provider.dart';
import '../services/saved_foods_service.dart';
import '../l10n/app_localizations.dart';

class SavedFoodsScreen extends StatefulWidget {
  final String? selectedMeal;
  final bool pickMode;

  const SavedFoodsScreen({super.key, this.selectedMeal, this.pickMode = false});

  @override
  State<SavedFoodsScreen> createState() => _SavedFoodsScreenState();
}

class _SavedFoodsScreenState extends State<SavedFoodsScreen> {
  List<SavedFood> _foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final foods = await SavedFoodsService.load();
    if (mounted) setState(() { _foods = foods; _loading = false; });
  }

  Future<void> _delete(SavedFood food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Emin misin?')),
        content: Text(context.tr('"{}" kayıtlı yiyeceklerden silinecek.').replaceFirst('{}', food.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('İptal'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF85149)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Sil')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SavedFoodsService.remove(food.id);
    setState(() => _foods.removeWhere((f) => f.id == food.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Kayıtlı yiyeceklerden kaldırıldı')), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _addToMeal(SavedFood food) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _MealPickerSheet(
        food: food,
        initialMeal: widget.selectedMeal ?? 'kahvaltı',
        onConfirm: (meal) {
          final entry = FoodEntry(
            id: '${DateTime.now().millisecondsSinceEpoch}',
            name: food.name,
            mealType: meal,
            portionSize: food.portionGrams,
            nutritionData: food.nutritionPer100g,
            timestamp: DateTime.now(),
          );
          context.read<NutritionProvider>().addFoodEntry(entry);
          Navigator.pop(ctx);
          if (widget.pickMode) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('{} eklendi').replaceFirst('{}', food.name)), duration: const Duration(seconds: 2)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Kayıtlı Yiyecekler')),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _foods.isEmpty
              ? _buildEmpty(cs)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _foods.length,
                  itemBuilder: (ctx, i) => _FoodCard(
                    food: _foods[i],
                    isDark: isDark,
                    cs: cs,
                    onAdd: () => _addToMeal(_foods[i]),
                    onDelete: () => _delete(_foods[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 64, color: cs.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            context.tr('Kayıtlı yiyecek yok'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Görsel analiz ekranındaki kaydet simgesine tıklayarak yiyecek kaydedebilirsiniz.'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final SavedFood food;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  const _FoodCard({
    required this.food,
    required this.isDark,
    required this.cs,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scaled = food.nutritionScaled;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: food.imagePath != null && File(food.imagePath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(food.imagePath!),
                  width: 52, height: 52,
                  fit: BoxFit.cover,
                ),
              )
            : (food.imageUrl != null && food.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: food.imageUrl!,
                      width: 52, height: 52,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 52, height: 52,
                        color: cs.primary.withValues(alpha: 0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.fastfood_rounded, color: cs.primary.withValues(alpha: 0.5), size: 26),
                      ),
                    ),
                  )
                : Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fastfood_rounded, color: cs.primary.withValues(alpha: 0.5), size: 26),
                  )),
        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${scaled.calories.round()} kcal · ${food.portionGrams.round()}g  |  P: ${scaled.protein.toStringAsFixed(1)}g  K: ${scaled.carbohydrates.toStringAsFixed(1)}g  Y: ${scaled.fat.toStringAsFixed(1)}g',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
              onPressed: onAdd,
              tooltip: context.tr('Öğüne Ekle'),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: cs.error.withValues(alpha: 0.7)),
              onPressed: onDelete,
              tooltip: context.tr('Kaldır'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealPickerSheet extends StatefulWidget {
  final SavedFood food;
  final String initialMeal;
  final void Function(String meal) onConfirm;

  const _MealPickerSheet({required this.food, required this.initialMeal, required this.onConfirm});

  @override
  State<_MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends State<_MealPickerSheet> {
  late String _selected;

  static const _meals = ['kahvaltı', 'öğle yemeği', 'akşam yemeği', 'atıştırmalık'];
  List<String> get _mealLabels => [context.tr('kahvaltı'), context.tr('öğle'), context.tr('akşam'), context.tr('ara öğün')];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMeal;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.food.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.food.nutritionScaled.calories.round()} kcal · ${widget.food.portionGrams.round()}g ${context.tr('porsiyon')}',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(context.tr('Öğün seç:'), style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_meals.length, (i) {
                final sel = _selected == _meals[i];
                return GestureDetector(
                  onTap: () => setState(() => _selected = _meals[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? cs.primary : cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _mealLabels[i],
                      style: TextStyle(
                        color: sel ? Colors.white : cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => widget.onConfirm(_selected),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('Öğüne Ekle')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ),
      ),
    );
  }
}
