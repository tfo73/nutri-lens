import 'dart:io';
import 'package:flutter/material.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import 'food_entry_detail_sheet.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final List<FoodEntry> entries;
  final IconData icon;
  final VoidCallback? onAddPressed;
  final void Function(FoodEntry entry)? onEntryTap;
  final void Function(FoodEntry entry)? onEntryDelete;

  const MealCard({
    super.key,
    required this.mealName,
    required this.entries,
    required this.icon,
    this.onAddPressed,
    this.onEntryTap,
    this.onEntryDelete,
  });

  NutritionData get _totalNutrition {
    if (entries.isEmpty) return NutritionData.empty;
    return entries.fold(NutritionData.empty, (sum, entry) {
      return sum + entry.nutritionData.scaleBy(entry.portionSize / 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalNutrition;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        title: Text(mealName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: entries.isEmpty
            ? Text(
                'Henüz eklenmedi',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            : Text(
                '${total.calories.toStringAsFixed(0)} kcal  •  '
                '${entries.length} yiyecek',
                style: const TextStyle(fontSize: 12),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: colorScheme.primary, size: 22),
              onPressed: onAddPressed,
              tooltip: 'Yiyecek ekle',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (entries.isEmpty)
            _buildEmptyPlaceholder(context)
          else ...[
            ...entries.map((entry) => _buildEntryTile(context, entry)),
            _buildMealSummary(context, total),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: InkWell(
        onTap: onAddPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: colorScheme.onSurfaceVariant.withOpacity(0.45),
                size: 28,
              ),
              const SizedBox(height: 5),
              Text(
                'Eklemek için dokun',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yemeği Sil'),
        content: const Text('Bu yemeği silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onEntryDelete!(entry);
    }
  }

  Widget _buildEntryTile(BuildContext context, FoodEntry entry) {
    final nutrition = entry.nutritionData.scaleBy(entry.portionSize / 100);
    final hasImage = entry.imagePath != null;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
      leading: hasImage
          ? GestureDetector(
              onTap: () => _openFullscreenImage(context, entry.imagePath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(entry.imagePath!),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, e, s) => const SizedBox(width: 44),
                ),
              ),
            )
          : null,
      title: Text(entry.name),
      subtitle: Text('${entry.portionSize.toStringAsFixed(0)} ${entry.portionUnit}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${nutrition.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'P: ${nutrition.protein.toStringAsFixed(0)}g  '
                'K: ${nutrition.carbohydrates.toStringAsFixed(0)}g  '
                'Y: ${nutrition.fat.toStringAsFixed(0)}g',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (onEntryDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error, size: 20),
              onPressed: () => _confirmDelete(context, entry),
              tooltip: 'Sil',
            ),
        ],
      ),
      onTap: () {
        if (onEntryTap != null) {
          onEntryTap!(entry);
        } else {
          FoodEntryDetailSheet.show(context, entry: entry);
        }
      },
    );
  }

  void _openFullscreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, e, s) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealSummary(BuildContext context, NutritionData total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Toplam',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          Text(
            '${total.calories.toStringAsFixed(0)} kcal  •  '
            'P ${total.protein.toStringAsFixed(0)}g  •  '
            'K ${total.carbohydrates.toStringAsFixed(0)}g  •  '
            'Y ${total.fat.toStringAsFixed(0)}g',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
