import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../providers/nutrition_provider.dart';
import '../services/nutrition_service.dart';

class BarcodeScreen extends StatefulWidget {
  final String? selectedMeal;
  final VoidCallback? onFoodAdded;

  const BarcodeScreen({super.key, this.selectedMeal, this.onFoodAdded});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final NutritionService _nutritionService = NutritionService();

  bool _isScanned = false;
  bool _isLoading = false;
  FoodProduct? _product;
  String? _errorMessage;

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
      _errorMessage = null;
    });
    await _controller.stop();

    try {
      final product = await _nutritionService.searchByBarcode(barcode);
      setState(() {
        _product = product;
        _isLoading = false;
        if (product == null) {
          _errorMessage = 'Ürün bulunamadı, manuel giriş yapın';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Barkod okunamadı: $e';
      });
    }
  }

  Future<void> _resetScanner() async {
    setState(() {
      _isScanned = false;
      _isLoading = false;
      _product = null;
      _errorMessage = null;
    });
    await _controller.start();
  }

  void _showAddSheet() {
    if (_product == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductAddSheet(
        product: _product!,
        selectedMeal: widget.selectedMeal,
        onAdd: _addToMeal,
      ),
    );
  }

  void _addToMeal(double portionGrams, String mealType) {
    if (_product == null) return;
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _product!.name,
      brand: _product!.brand,
      portionSize: portionGrams,
      nutritionData: _product!.nutritionPer100g,
      timestamp: DateTime.now(),
      mealType: mealType,
      imageUrl: _product!.imageUrl,
    );

    context.read<NutritionProvider>().addFoodEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.name} eklendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onFoodAdded?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tara'),
        centerTitle: true,
      ),
      body: _isScanned ? _buildResultArea() : _buildScannerArea(),
    );
  }

  Widget _buildScannerArea() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
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
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ürünün barkodunu kameraya tutun',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildResultArea() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ürün aranıyor...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 72,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Tekrar Tara'),
              ),
            ],
          ),
        ),
      );
    }

    if (_product != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_product!.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _product!.imageUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _product!.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_product!.brand != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _product!.brand!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const Divider(height: 24),
                    Text(
                      '100g başına besin değerleri',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildNutrRow('Kalori',
                        '${_product!.nutritionPer100g.calories.toStringAsFixed(0)} kcal'),
                    _buildNutrRow('Protein',
                        '${_product!.nutritionPer100g.protein.toStringAsFixed(1)} g'),
                    _buildNutrRow('Karbonhidrat',
                        '${_product!.nutritionPer100g.carbohydrates.toStringAsFixed(1)} g'),
                    _buildNutrRow('Yağ',
                        '${_product!.nutritionPer100g.fat.toStringAsFixed(1)} g'),
                    if (_product!.nutritionPer100g.fiber > 0)
                      _buildNutrRow('Lif',
                          '${_product!.nutritionPer100g.fiber.toStringAsFixed(1)} g'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Öğüne Ekle'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _resetScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Farklı Barkod Tara'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNutrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Ürün Ekleme Sayfası ──────────────────────────────────────────────────────

class _ProductAddSheet extends StatefulWidget {
  final FoodProduct product;
  final String? selectedMeal;
  final void Function(double portionGrams, String meal) onAdd;

  const _ProductAddSheet({
    required this.product,
    this.selectedMeal,
    required this.onAdd,
  });

  @override
  State<_ProductAddSheet> createState() => _ProductAddSheetState();
}

class _ProductAddSheetState extends State<_ProductAddSheet> {
  final _portionCtrl = TextEditingController(text: '100');
  late String _selectedMeal;

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.selectedMeal ?? 'kahvaltı';
  }

  @override
  void dispose() {
    _portionCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final portion = double.tryParse(_portionCtrl.text) ?? 100.0;
    if (portion <= 0) return;
    Navigator.pop(context);
    widget.onAdd(portion, _selectedMeal);
  }

  @override
  Widget build(BuildContext context) {
    const meals = <(String, IconData, String)>[
      ('kahvaltı', Icons.wb_sunny_outlined, 'Kahvaltı'),
      ('öğle', Icons.wb_cloudy_outlined, 'Öğle'),
      ('akşam', Icons.nights_stay_outlined, 'Akşam'),
      ('ara öğün', Icons.coffee_outlined, 'Ara Öğün'),
    ];

    final portionGrams = double.tryParse(_portionCtrl.text) ?? 100.0;
    final factor = portionGrams / 100;
    final n = widget.product.nutritionPer100g;

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
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.product.brand != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.product.brand!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _portionCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Porsiyon miktarı',
                border: OutlineInputBorder(),
                suffixText: 'g',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _infoRow(context, 'Kalori',
                      '${(n.calories * factor).toStringAsFixed(0)} kcal'),
                  _infoRow(context, 'Protein',
                      '${(n.protein * factor).toStringAsFixed(1)} g'),
                  _infoRow(context, 'Karbonhidrat',
                      '${(n.carbohydrates * factor).toStringAsFixed(1)} g'),
                  _infoRow(context, 'Yağ',
                      '${(n.fat * factor).toStringAsFixed(1)} g'),
                ],
              ),
            ),
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
            FilledButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.add),
              label: const Text('Öğüne Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
