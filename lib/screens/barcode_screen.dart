import 'package:cached_network_image/cached_network_image.dart';
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
      backgroundColor: Colors.black,
      body: _isScanned ? _buildResultArea() : _buildScannerArea(),
    );
  }

  Widget _buildScannerArea() {
    final topPad = MediaQuery.of(context).padding.top;
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
              child: const Text(
                'Ürünün barkodunu kameraya tutun',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
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
                        child: CachedNetworkImage(
                          imageUrl: _product!.imageUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorWidget: (ctx, url, e) => const SizedBox.shrink(),
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

    // Top-left
    canvas.drawLine(Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w, h - len), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
  }

  @override
  bool shouldRepaint(_FocusFramePainter old) => old.color != color;
}
