import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/food_analysis_result.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import '../providers/nutrition_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/claude_vision_service.dart';
import '../services/food_analysis_service.dart';
import '../services/nutrition_service.dart';
import '../services/saved_foods_service.dart';
import '../services/config_service.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/analysis_widgets.dart';
import '../widgets/food_analysis_result_sheet.dart';
import 'manual_entry_screen.dart';
import '../l10n/app_localizations.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum _ViewState { scanning, analyzing, aiResult, error }

enum _FlashMode { off, on, auto }

enum CameraStartMode { normal, voice, manual }

/// Opens the voice/text entry sheet without launching the camera.
void showVoiceEntrySheet(BuildContext context, {String selectedMeal = 'kahvaltı', DateTime? date, VoidCallback? onDone}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _VoiceTextEntrySheet(
      selectedMeal: selectedMeal,
      onSave: (entry) {
        context.read<NutritionProvider>().addFoodEntry(entry, date: date);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)), behavior: SnackBarBehavior.floating),
        );
        onDone?.call();
      },
    ),
  );
}

Map<String, dynamic> buildPrefillMap(FoodAnalysisResult result, {bool isTr = true}) {
  final scaled = result.nutritionScaled;
  final factor = result.portionGrams / 100.0;
  final n65 = result.nutrition65per100g;

  double? s(double? v) => v != null && v > 0 ? v * factor : null;
  String? f(double? v, [int dec = 1]) => v != null ? v.toStringAsFixed(dec) : null;

  return {
    'name': isTr ? result.foodName : (result.foodNameEn ?? result.foodName),
    'calories': scaled.calories.toStringAsFixed(0),
    'protein': scaled.protein.toStringAsFixed(1),
    'carbs': scaled.carbohydrates.toStringAsFixed(1),
    'fat': scaled.fat.toStringAsFixed(1),
    'grams': result.portionGrams.toStringAsFixed(0),
    'fiber': scaled.fiber.toStringAsFixed(1),
    'sugar': scaled.sugar.toStringAsFixed(1),
    'satFat': scaled.saturatedFat.toStringAsFixed(1),
    if (n65 != null) ...{
      'monoFat': f(s(n65.monoFat)),
      'polyFat': f(s(n65.polyFat)),
      'transFat': f(s(n65.transFat)),
      'cholesterol': f(s(n65.cholesterol), 0),
      'sodium': f(s(n65.sodium), 0),
      'magnesium': f(s(n65.magnesium), 0),
      'calcium': f(s(n65.calcium), 0),
      'iron': f(s(n65.iron)),
      'zinc': f(s(n65.zinc)),
      'potassium': f(s(n65.potassium), 0),
      'phosphorus': f(s(n65.phosphorus), 0),
      'selenium': f(s(n65.selenium)),
      'copper': f(s(n65.copper)),
      'manganese': f(s(n65.manganese)),
      'vitA': f(s(n65.vitA_RAE), 0),
      'vitC': f(s(n65.vitC)),
      'vitD': f(s(n65.vitD_mcg)),
      'vitE': f(s(n65.vitE)),
      'vitK': f(s(n65.vitK)),
      'vitB12': f(s(n65.vitB12)),
      'thiamine': f(s(n65.thiamine)),
      'riboflavin': f(s(n65.riboflavin)),
      'niacin': f(s(n65.niacin)),
      'pantothenic': f(s(n65.pantothenic)),
      'vitB6': f(s(n65.vitB6)),
      'folate': f(s(n65.folate), 0),
      'choline': f(s(n65.choline), 0),
      'biotin': f(s(n65.biotin), 0),
      'omega3': f(s(n65.omega3)),
      'omega6': f(s(n65.omega6)),
      'ala': f(s(n65.ala)),
      'epa': f(s(n65.epa)),
      'dha': f(s(n65.dha)),
      'betaCarot': f(s(n65.betaCarot), 0),
      'lycopene': f(s(n65.lycopene), 0),
      'luteinZea': f(s(n65.luteinZea), 0),
      'alphaCarot': f(s(n65.alphaCarot), 0),
      'tryptophan': f(s(n65.tryptophan)),
      'threonine': f(s(n65.threonine)),
      'isoleucine': f(s(n65.isoleucine)),
      'leucine': f(s(n65.leucine)),
      'lysine': f(s(n65.lysine)),
      'methionine': f(s(n65.methionine)),
      'phenylalanine': f(s(n65.phenylalanine)),
      'valine': f(s(n65.valine)),
      'histidine': f(s(n65.histidine)),
      'cystine': f(s(n65.cystine)),
      'tyrosine': f(s(n65.tyrosine)),
    }
  };
}

/// Opens the manual entry sheet without launching the camera.
void showManualEntrySheet(BuildContext context, {String selectedMeal = 'kahvaltı', DateTime? date, VoidCallback? onDone}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => _ManualEntryBottomSheet(
        scrollCtrl: scrollCtrl,
        selectedMeal: selectedMeal,
        onSave: (entry) {
          context.read<NutritionProvider>().addFoodEntry(entry, date: date);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)), behavior: SnackBarBehavior.floating),
          );
          onDone?.call();
        },
      ),
    ),
  );
}

// ─── CameraScreen ─────────────────────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  final VoidCallback? onFoodAdded;
  final VoidCallback? onBack;
  final String? selectedMeal;
  final CameraStartMode startMode;
  final DateTime? date;

  const CameraScreen({
    super.key,
    this.onFoodAdded,
    this.onBack,
    this.selectedMeal,
    this.startMode = CameraStartMode.normal,
    this.date,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scanner;
  final GlobalKey _cameraKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final FoodAnalysisService _analysisService = FoodAnalysisService();
  final NutritionService _nutritionService = NutritionService();

  _ViewState _viewState = _ViewState.scanning;
  _FlashMode _flashMode = _FlashMode.off;
  bool _scannerDisposed = false;
  bool _isCapturing = false;

  File? _capturedImage;
  FoodAnalysisResult? _analysisResult;
  String? _errorMessage;
  bool _barcodeDetected = false;
  bool _barcodeHandling = false;
  File? _lastImage;
  bool _isOffline = false;
  String _selectedMeal = 'kahvaltı';
  bool _feedbackGiven = false;
  bool _isSaved = false;
  bool _saving = false;
  bool _editingFromResult = false;

  late final Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _selectedMeal = widget.selectedMeal ?? 'kahvaltı';
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnectivity();
    _connectivityStream.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _isOffline = offline);
    });
    if (widget.startMode != CameraStartMode.normal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.startMode == CameraStartMode.voice) _openVoiceTextEntry();
        if (widget.startMode == CameraStartMode.manual) _openManualEntry();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_scannerDisposed) _scanner.stop();
    } else if (state == AppLifecycleState.resumed &&
        _viewState == _ViewState.scanning) {
      if (!_scannerDisposed) _scanner.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_scannerDisposed) _scanner.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final offline = !await ClaudeVisionService.hasConnection();
    if (mounted) setState(() => _isOffline = offline);
  }

  // ── Flash ──────────────────────────────────────────────────────────────────

  Future<void> _cycleFlash() async {
    final next = _FlashMode.values[(_flashMode.index + 1) % 3];
    setState(() => _flashMode = next);
    try {
      final torchOn =
          _scanner.value.torchState == TorchState.on;
      if (next == _FlashMode.on && !torchOn) {
        await _scanner.toggleTorch();
      } else if (next != _FlashMode.on && torchOn) {
        await _scanner.toggleTorch();
      }
    } catch (_) {}
  }

  // ── Barcode ────────────────────────────────────────────────────────────────

  Future<void> _onBarcodeDetected(String rawValue) async {
    if (_barcodeHandling || _viewState != _ViewState.scanning) return;
    setState(() {
      _barcodeHandling = true;
      _barcodeDetected = true;
    });
    HapticFeedback.mediumImpact();
    await _scanner.stop();
    setState(() => _viewState = _ViewState.analyzing);

    try {
      final product = await _nutritionService.searchByBarcode(rawValue);
      if (!mounted) return;

      if (product != null) {
        setState(() {
          _viewState = _ViewState.scanning;
          _barcodeDetected = false;
          _barcodeHandling = false;
        });
        await _scanner.start();
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _BarcodeProductSheet(
            product: product,
            selectedMeal: _selectedMeal,
            onAdd: (portionGrams, mealType) =>
                _addBarcodeProduct(product, portionGrams, mealType),
          ),
        );
      } else {
        setState(() {
          _viewState = _ViewState.scanning;
          _barcodeDetected = false;
          _barcodeHandling = false;
        });
        _showProductNotFoundDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _ViewState.scanning;
        _barcodeDetected = false;
        _barcodeHandling = false;
      });
      _showProductNotFoundDialog();
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
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                await _scanner.start();
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
                Navigator.pop(context); // Close CameraScreen
                showVoiceEntrySheet(
                  context,
                  selectedMeal: _selectedMeal ?? 'kahvaltı',
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
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                await _scanner.start(); // Restart scanner
              },
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

  // Helper to crop the full screen capture to a central square (the food boundary)
  Future<ui.Image> _cropToSquare(ui.Image source) async {
    final size = source.width < source.height ? source.width : source.height;
    final x = (source.width - size) / 2.0;
    final y = (source.height - size) / 2.0;
    
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(x, y, size.toDouble(), size.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint(),
    );
    
    return await recorder.endRecording().toImage(size, size);
  }

  // ── Photo capture ──────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    if (_viewState != _ViewState.scanning || _isCapturing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);

    try {
      // Small delay to allow the haptic feedback and UI update to register
      await Future.delayed(const Duration(milliseconds: 50));
      
      final boundary = _cameraKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Kamera görünümü bulunamadı');

      // Capture at a high pixel ratio for better quality
      final fullImage = await boundary.toImage(pixelRatio: 2.0);
      
      // Crop to a square to focus on the food boundaries
      final image = await _cropToSquare(fullImage);
      
      // Grab references needed before the widget is unmounted
      final provider = context.read<NutritionProvider>();
      final meal = _selectedMeal;
      final onAdded = widget.onFoodAdded;

      // Close the camera screen IMMEDIATELY
      if (mounted) {
        Navigator.pop(context);
        onAdded?.call();
      }

      // Process and save the image asynchronously in the background
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Fotoğraf işlenemedi');

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      provider.analyzeAndAddImage(file, meal);
      provider.enableHomeResult();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = context.tr('Fotoğraf çekilemedi. Tekrar deneyin.');
          _viewState = _ViewState.error;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Release camera so image_picker can use it
    try { await _scanner.stop(); } catch (_) {}
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) {
        // User cancelled — resume scanner
        if (_viewState == _ViewState.scanning) {
          try { await _scanner.start(); } catch (_) {}
        }
        return;
      }
      final file = File(picked.path);
      
      // Start background analysis and exit
      final provider = context.read<NutritionProvider>();
      provider.analyzeAndAddImage(file, _selectedMeal);
      provider.enableHomeResult();
      
      if (mounted) {
        Navigator.pop(context);
        widget.onFoodAdded?.call();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fotoğraf seçilemedi: $e';
        _viewState = _ViewState.error;
        _capturedImage = null;
      });
    }
  }

  Future<void> _analyzeWithAI(Uint8List bytes) async {
    if (_isOffline) {
      setState(() {
        _errorMessage = context.tr('Çevrimdışısın — AI analiz devre dışı');
        _viewState = _ViewState.error;
      });
      return;
    }
    
    final file = _capturedImage;
    if (file == null) return;

    setState(() => _viewState = _ViewState.analyzing);

    // NutritionProvider üzerinden analizi yap
    final provider = context.read<NutritionProvider>();
    await provider.analyzeAndAddImage(file, _selectedMeal);

    if (!mounted) return;

    // Eğer işlem bittiğinde hala bu ekrandaysak sonucu göster
    if (provider.lastResult != null) {
      setState(() {
        _analysisResult = provider.lastResult;
        _viewState = _ViewState.scanning;
        _editingFromResult = false;
      });

      FoodAnalysisResultSheet.show(
        context,
        result: provider.lastResult!,
        image: _capturedImage,
        isFullScreen: true,
        onEdit: () {
          _editingFromResult = true;
          // Önce modal'ı kapat (bu context camera screen'e ait, top route olan modal'ı pop eder)
          Navigator.pop(context);
          // Hemen ardından ManualEntryScreen'i push et
          final res = provider.lastResult!;
          final nd = res.nutritionPer100g; // 100g bazında — initState factor ile çarpar
          final isTr = context.read<LanguageProvider>().isTurkish;
          final entry = FoodEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: isTr ? res.foodName : (res.foodNameEn ?? res.foodName),
            portionSize: res.portionGrams,
            nutritionData: nd,
            nutrition65per100g: res.nutrition65per100g,
            timestamp: DateTime.now(),
            mealType: _selectedMeal,
            imagePath: _capturedImage?.path,
          );
          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ManualEntryScreen(
                existingEntry: entry,
                selectedMeal: _selectedMeal,
                forceAdd: true,
              ),
            ),
          ).then((saved) {
            _editingFromResult = false;
            if (saved == true) {
              _resetToScanning();
              widget.onFoodAdded?.call();
            }
          });
        },
        onConfirm: (entry) {
          context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);
          Navigator.pop(context);
          _resetToScanning();
          widget.onFoodAdded?.call();
        },
      ).then((val) {
        if (val is String && _capturedImage != null && mounted) {
          provider.analyzeAndAddImage(_capturedImage!, _selectedMeal, extraContext: val);
          provider.enableHomeResult();
          Navigator.pop(context);
        } else if (!_editingFromResult) {
          _resetToScanning();
        }
      });
    } else {
      setState(() {
        _errorMessage = context.tr('Analiz başarısız oldu veya yarıda kesildi.');
        _viewState = _ViewState.error;
      });
    }
  }

  void _resetToScanning() {
    setState(() {
      _viewState = _ViewState.scanning;
      _capturedImage = null;
      _analysisResult = null;
      _errorMessage = null;
      _barcodeDetected = false;
      _barcodeHandling = false;
      _feedbackGiven = false;
      _isSaved = false;
    });
    _scanner.start();
  }

  static (String, Color) _sourceInfo(String src) => switch (src) {
    'USDA_API' || 'USDA_LOCAL' => ('USDA DB', Color(0xFF3FB950)),
    'OpenFoodFacts' => ('OpenFoodFacts', Color(0xFF58A6FF)),
    'Geçmiş' => ('Geçmiş', Color(0xFFD2A8FF)),
    _ => ('AI Analiz', Color(0xFF26D0CE)),
  };

  Future<void> _toggleSave() async {
    final result = _analysisResult;
    if (result == null) return;
    setState(() => _saving = true);
    if (_isSaved) {
      await SavedFoodsService.remove(result.foodName);
      if (mounted) setState(() { _isSaved = false; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Kayıtlı yiyeceklerden kaldırıldı')), duration: const Duration(seconds: 2)),
        );
      }
    } else {
      final food = SavedFood(
        id: result.foodName,
        name: result.foodName,
        portionGrams: result.portionGrams,
        nutritionPer100g: result.nutritionPer100g,
        sources: result.sources,
        savedAt: DateTime.now(),
        imagePath: _capturedImage?.path,
      );
      await SavedFoodsService.save(food);
      if (mounted) setState(() { _isSaved = true; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Kayıtlı yiyeceklere eklendi')), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _checkIfSaved(String foodName) async {
    final saved = await SavedFoodsService.isSaved(foodName);
    if (mounted) setState(() => _isSaved = saved);
  }

  void _showMicroNutrients(FoodAnalysisResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.5,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => _MicroNutrientsSheet(result: result, scrollCtrl: ctrl),
      ),
    );
  }

  void _showAiBadgeExplanation(Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: Text('AI Analiz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(width: 12),
                  Text(context.tr('Nasıl çalışır?'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Bu besin bilgisi, yüklediğiniz görseli analiz eden yapay zeka (Claude Vision) tarafından oluşturulmuştur.'),
                style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.8), height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('AI tahmini, gerçek laboratuvar ölçümü değildir. Porsiyon büyüklüğü, pişirme yöntemi ve malzeme farklılıkları sonucu etkileyebilir. Kesin değerler için ürün etiketini kontrol edin.'),
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55), height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onFeedbackCorrect(FoodAnalysisResult result) {
    _analysisService.saveCorrection(result.foodName, result.nutritionPer100g);
    setState(() => _feedbackGiven = true);
  }

  void _onFeedbackEdit(FoodAnalysisResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _ManualEntryBottomSheet(
          scrollCtrl: scrollCtrl,
          selectedMeal: _selectedMeal,
          isAnalysis: true,
          prefill: buildPrefillMap(result, isTr: ctx.read<LanguageProvider>().isTurkish),
          onSave: (entry) {
            _analysisService.saveCorrection(result.foodName, entry.nutritionData);
            context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)),
                  behavior: SnackBarBehavior.floating),
            );
            _resetToScanning();
            widget.onFoodAdded?.call();
          },
        ),
      ),
    );
  }

  void _addAIResult(FoodAnalysisResult result, String mealType) {
    // nutritionPer100g kaydet — DailyLog.totalNutrition portionSize/100 ile
    // ölçeklediği için scaled kaydetmek çift-ölçeklemeye yol açardı.
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result.foodName,
      portionSize: result.portionGrams,
      nutritionData: result.nutritionPer100g,
      nutrition65per100g: result.nutrition65per100g,
      timestamp: DateTime.now(),
      mealType: mealType,
      imagePath: _capturedImage?.path,
      novaGroup: result.offProduct?.novaGroup,
    );
    context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)),
          behavior: SnackBarBehavior.floating),
    );
    _resetToScanning();
    widget.onFoodAdded?.call();
  }

  void _addBarcodeProduct(
      FoodProduct product, double portionGrams, String mealType) {
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
          behavior: SnackBarBehavior.floating),
    );
    widget.onFoodAdded?.call();
  }

  void _openVoiceTextEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _VoiceTextEntrySheet(
        selectedMeal: _selectedMeal,
        onSave: (entry) {
          context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onFoodAdded?.call();
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _openManualEntry({Map<String, dynamic>? prefill}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _ManualEntryBottomSheet(
          scrollCtrl: scrollCtrl,
          selectedMeal: _selectedMeal,
          prefill: prefill,
          onSave: (entry) {
            context.read<NutritionProvider>().addFoodEntry(entry, date: widget.date);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(context.tr('{} eklendi').replaceFirst('{}', entry.name)),
                  behavior: SnackBarBehavior.floating),
            );
            if (_viewState != _ViewState.scanning) _resetToScanning();
            widget.onFoodAdded?.call();
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionProvider>();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && provider.isAnalyzing) {
          provider.enableHomeResult();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case _ViewState.scanning:
        return _buildCameraView();
      case _ViewState.analyzing:
        return _buildAnalyzingView();
      case _ViewState.aiResult:
        return _buildResultView();
      case _ViewState.error:
        return _buildErrorView();
    }
  }

  // ── Camera view ────────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera preview
        RepaintBoundary(
          key: _cameraKey,
          child: MobileScanner(
            controller: _scanner,
          ),
        ),
        // 2. Focus frame
        Center(child: _FocusFrame(barcodeDetected: false)),
        // 3. Back button
        Positioned(
          top: topPad + 8,
          left: 16,
          child: GestureDetector(
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        // 3b. Offline banner
        if (_isOffline)
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 64,
            child: const _OfflineBanner(),
          ),
        // 4. Flash button
        Positioned(
          top: topPad + 8,
          right: 16,
          child: _FlashButton(
            flashMode: _flashMode,
            onPressed: _cycleFlash,
          ),
        ),
        // 5. Bottom controls
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: _BottomControls(
            lastImage: _lastImage,
            onShutter: _isOffline ? null : _capturePhoto,
            onGallery:
                _isOffline ? null : () => _pickImage(ImageSource.gallery),
          ),
        ),
        // 6. Capture overlay — blocks input and shows spinner while taking photo
        if (_isCapturing)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Analyzing view ─────────────────────────────────────────────────────────

  Widget _buildAnalyzingView() {
    return AnalysisProgressView(
      image: _capturedImage,
      onBack: () {
        context.read<NutritionProvider>().enableHomeResult();
        Navigator.of(context).pop();
      },
    );
  }

  // ── AI result view ─────────────────────────────────────────────────────────

  Widget _buildResultView() {
    final result = _analysisResult!;
    final scaled = result.nutritionScaled;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top 55% — image
        Expanded(
          flex: 55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_capturedImage != null)
                Image.file(_capturedImage!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Colors.black),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: _BackButton(onPressed: _resetToScanning),
              ),
              // Star/save button — top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: GestureDetector(
                  onTap: _saving ? null : _toggleSave,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.50),
                    ),
                    child: _saving
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _isSaved ? const Color(0xFFF0A500) : Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Bottom 45% — result card
        Expanded(
          flex: 45,
          child: ColoredBox(
            color: cs.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık + güven badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.foodName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ConfidenceBadge(score: result.confidenceScore),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Kalori + aralık
                  Text(
                    '${scaled.calories.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    '~${result.alternativeMin.round()} – ${result.alternativeMax.round()} kcal aralığı',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  // Makro hap
                  Row(
                    children: [
                      _MacroPill(
                        label: 'Protein',
                        value: '${scaled.protein.toStringAsFixed(1)}g',
                        color: const Color(0xFF7EE787),
                      ),
                      const SizedBox(width: 6),
                      _MacroPill(
                        label: 'Karb',
                        value:
                            '${scaled.carbohydrates.toStringAsFixed(1)}g',
                        color: const Color(0xFF58A6FF),
                      ),
                      const SizedBox(width: 6),
                      _MacroPill(
                        label: 'Yağ',
                        value: '${scaled.fat.toStringAsFixed(1)}g',
                        color: const Color(0xFFF0A500),
                      ),
                    ],
                  ),
                  // OFF: NutriScore + NOVA badge
                  if (result.offProduct != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (result.offProduct!.nutriscoreGrade != null)
                          _NutriScoreBadge(
                              grade: result.offProduct!.nutriscoreGrade!),
                        if (result.offProduct!.nutriscoreGrade != null &&
                            result.offProduct!.novaGroup != null)
                          const SizedBox(width: 6),
                        if (result.offProduct!.novaGroup != null)
                          _NovaBadge(group: result.offProduct!.novaGroup!),
                      ],
                    ),
                    // Alerjenler
                    if (result.offProduct!.allergens.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: result.offProduct!.allergens
                            .take(6)
                            .map((a) => _AllergenChip(label: a))
                            .toList(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 6),
                  // Kaynak badge'leri
                  Wrap(
                    spacing: 4,
                    children: result.sources.map((src) {
                      final (label, color) = _sourceInfo(src);
                      final isAI = label == 'AI Analiz';
                      final badge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
                        ),
                        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                      );
                      if (!isAI) return badge;
                      return GestureDetector(
                        onTap: () => _showAiBadgeExplanation(color),
                        child: badge,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  // Daha Fazla Detay
                  OutlinedButton.icon(
                    onPressed: () => _showMicroNutrients(result),
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Mikro Besinleri Gör', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Geri bildirim
                  if (!_feedbackGiven)
                    Row(
                      children: [
                        Text(
                          'Bu doğru mu?',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Doğru', style: TextStyle(fontSize: 12)),
                          onPressed: () => _onFeedbackCorrect(result),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.close_rounded, size: 14),
                          label: const Text('Hayır', style: TextStyle(fontSize: 12)),
                          onPressed: () => _onFeedbackEdit(result),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Geri bildirim kaydedildi',
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ],
                    ),
                  const Divider(height: 14),
                  // Öğün seçici
                  if (widget.selectedMeal == null) ...[
                    _MealChipRow(
                      selected: _selectedMeal,
                      onChanged: (m) => setState(() => _selectedMeal = m),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => _openManualEntry(prefill: {
                      'name': result.foodName,
                      'calories': result.nutritionScaled.calories.toStringAsFixed(0),
                      'protein': result.nutritionScaled.protein.toStringAsFixed(1),
                      'carbs': result.nutritionScaled.carbohydrates.toStringAsFixed(1),
                      'fat': result.nutritionScaled.fat.toStringAsFixed(1),
                      'grams': result.portionGrams.toStringAsFixed(0),
                    }),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Yemeği Düzenle'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _addAIResult(result, _selectedMeal),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Öğüne Ekle'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Error view ─────────────────────────────────────────────────────────────

  Widget _buildErrorView() {
    final cs = Theme.of(context).colorScheme;
    final hasImage = _capturedImage != null;
    return Column(
      children: [
        if (hasImage)
          Expanded(
            flex: 55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_capturedImage!, fit: BoxFit.cover),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: _BackButton(onPressed: _resetToScanning),
                ),
              ],
            ),
          ),
        Expanded(
          flex: hasImage ? 45 : 100,
          child: ColoredBox(
            color: cs.surface,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hasImage)
                    Align(
                      alignment: Alignment.topLeft,
                      child: _BackButton(onPressed: _resetToScanning),
                    ),
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'Bir hata oluştu',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: cs.onSurface, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: _resetToScanning,
                        child: const Text('Yeniden Dene'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _openManualEntry(),
                        child: const Text('Manuel Giriş'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

// ─── Flash Button ─────────────────────────────────────────────────────────────

class _FlashButton extends StatelessWidget {
  final _FlashMode flashMode;
  final VoidCallback onPressed;
  const _FlashButton({required this.flashMode, required this.onPressed});

  IconData get _icon => switch (flashMode) {
        _FlashMode.off => Icons.flash_off_rounded,
        _FlashMode.on => Icons.flash_on_rounded,
        _FlashMode.auto => Icons.flash_auto_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: 0.70),
        ),
        child: Icon(_icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Bottom Controls ──────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final File? lastImage;
  final VoidCallback? onShutter;
  final VoidCallback? onGallery;

  const _BottomControls({
    required this.lastImage,
    required this.onShutter,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GalleryThumb(lastImage: lastImage, onTap: onGallery),
        const SizedBox(width: 48),
        _ShutterButton(onPressed: onShutter),
        const SizedBox(width: 48),
        const SizedBox(width: 56), // simetri
      ],
    );
  }
}

// ─── Gallery Thumb ────────────────────────────────────────────────────────────

class _GalleryThumb extends StatefulWidget {
  final File? lastImage;
  final VoidCallback? onTap;
  const _GalleryThumb({required this.lastImage, required this.onTap});

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadLatestPhoto();
  }

  Future<void> _loadLatestPhoto() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) return;

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
        onlyAll: true,
      );
      if (albums.isEmpty) return;

      final assets = await albums.first.getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) return;

      final thumb = await assets.first.thumbnailDataWithSize(
        const ThumbnailSize(112, 112),
      );
      if (mounted && thumb != null) {
        setState(() => _thumbnail = thumb);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.lastImage != null) {
      return Image.file(widget.lastImage!, fit: BoxFit.cover);
    }
    if (_thumbnail != null) {
      return Image.memory(_thumbnail!, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.70),
      child: const Icon(Icons.photo_library_rounded,
          color: Colors.white, size: 26),
    );
  }
}

// ─── Shutter Button ───────────────────────────────────────────────────────────

class _ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const _ShutterButton({required this.onPressed});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final fillColor = isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => _ctrl.forward(),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              _ctrl.reverse().then((_) => widget.onPressed?.call());
            },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: primary, width: 4),
          ),
        ),
      ),
    );
  }
}

// ─── Manual Entry Button ──────────────────────────────────────────────────────

class _ManualEntryButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ManualEntryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '✏️ Manuel Giriş',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Offline Banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Çevrimdışı — AI kapalı',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Back Button ─────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Analyzing Overlay (image-top skeleton + label) ──────────────────────────

class _AnalyzingOverlay extends StatefulWidget {
  const _AnalyzingOverlay();

  @override
  State<_AnalyzingOverlay> createState() => _AnalyzingOverlayState();
}

class _AnalyzingOverlayState extends State<_AnalyzingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _skeletonBar(double width) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white.withValues(alpha: 0.25 + 0.4 * _anim.value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
        const SizedBox(height: 14),
        const Text(
          'Görsel işleniyor...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 16),
        _skeletonBar(160),
        const SizedBox(height: 8),
        _skeletonBar(120),
        const SizedBox(height: 8),
        _skeletonBar(80),
      ],
    );
  }
}

// ─── Shimmer Banner ───────────────────────────────────────────────────────────



// ─── Macro Pill ───────────────────────────────────────────────────────────────

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose high-contrast color choices in Light Mode to ensure accessibility
    Color displayColor;
    if (isDark) {
      displayColor = color;
    } else {
      if (color == const Color(0xFF7EE787)) {
        displayColor = const Color(0xFF1B6A27); // Protein: Dark Green
      } else if (color == const Color(0xFF58A6FF)) {
        displayColor = const Color(0xFF0969DA); // Carbs: Dark Blue
      } else if (color == const Color(0xFFF0A500)) {
        displayColor = const Color(0xFFB57C00); // Fat: Dark Amber/Gold
      } else if (color == const Color(0xFFD2A8FF)) {
        displayColor = const Color(0xFF6F42C1); // Fiber/Purple: Dark Purple
      } else if (color == const Color(0xFFFF6B6B)) {
        displayColor = const Color(0xFFCF222E); // Fiber/Red: Dark Red
      } else {
        displayColor = color;
      }
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: isDark ? null : Border.all(color: displayColor.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: displayColor)),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: displayColor.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }
}

// ─── Meal Chip Row ────────────────────────────────────────────────────────────

class _MealChipRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _MealChipRow({required this.selected, required this.onChanged});

  Widget _buildMealChip(BuildContext context, (String, String, String) m, bool isDark) {
    final isSelected = selected == m.$1 || 
        (m.$1 == 'öğle yemeği' && selected == 'öğle') || 
        (m.$1 == 'akşam yemeği' && selected == 'akşam');
    
    return GestureDetector(
      onTap: () => onChanged(m.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF007AFF).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m.$2, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                m.$3,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected 
                      ? const Color(0xFF007AFF)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSnacks = context.watch<ProfileProvider>().activeProfile?.showSnacks ?? true;

    final meals = showSnacks
        ? [
            ('kahvaltı', '☀️', context.tr('Kahvaltı')),
            ('kahvaltı sonrası ara öğün', '☕️', context.tr('Kahvaltı Sonrası Ara Öğün')),
            ('öğle yemeği', '🌤', context.tr('Öğle Yemeği')),
            ('öğle sonrası ara öğün', '🍵', context.tr('Öğle Sonrası Ara Öğün')),
            ('akşam yemeği', '🌙', context.tr('Akşam Yemeği')),
            ('gece atıştırmalığı', '🍿', context.tr('Gece Atıştırmalığı')),
          ]
        : [
            ('kahvaltı', '☀️', context.tr('Kahvaltı')),
            ('öğle yemeği', '🌤', context.tr('Öğle Yemeği')),
            ('akşam yemeği', '🌙', context.tr('Akşam Yemeği')),
          ];

    final rows = <Widget>[];
    for (int i = 0; i < meals.length; i += 2) {
      final item1 = meals[i];
      final hasSecond = i + 1 < meals.length;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildMealChip(context, item1, isDark)),
            const SizedBox(width: 8),
            if (hasSecond)
              Expanded(child: _buildMealChip(context, meals[i + 1], isDark))
            else
              const Spacer(),
          ],
        ),
      );
      if (i + 2 < meals.length) {
        rows.add(const SizedBox(height: 8));
      }
    }

    return Column(children: rows);
  }
}

// ─── Barcode Product Sheet ────────────────────────────────────────────────────

class _BarcodeProductSheet extends StatefulWidget {
  final FoodProduct product;
  final String selectedMeal;
  final void Function(double portionGrams, String meal) onAdd;

  const _BarcodeProductSheet({
    required this.product,
    required this.selectedMeal,
    required this.onAdd,
  });

  @override
  State<_BarcodeProductSheet> createState() => _BarcodeProductSheetState();
}

class _BarcodeProductSheetState extends State<_BarcodeProductSheet> {
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
    _meal = widget.selectedMeal;
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
            Row(
              children: [
                Icon(Icons.qr_code_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            if (widget.product.brand != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.product.brand!,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
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
            _MealChipRow(
              selected: _meal,
              onChanged: (m) => setState(() => _meal = m),
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

// ─── Manual Entry Bottom Sheet ────────────────────────────────────────────────

class _ManualEntryBottomSheet extends StatefulWidget {
  final String selectedMeal;
  final Map<String, dynamic>? prefill;
  final void Function(FoodEntry entry) onSave;
  final bool isAnalysis;
  final ScrollController scrollCtrl;

  const _ManualEntryBottomSheet({
    required this.selectedMeal,
    required this.onSave,
    required this.scrollCtrl,
    this.prefill,
    this.isAnalysis = false,
  });

  @override
  State<_ManualEntryBottomSheet> createState() =>
      _ManualEntryBottomSheetState();
}

class _ManualEntryBottomSheetState extends State<_ManualEntryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _calorieCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _fatCtrl;

  // Detaylar — 44 alan
  final _fiberCtrl       = TextEditingController();
  final _sugarCtrl       = TextEditingController();
  final _satFatCtrl      = TextEditingController();
  final _monoFatCtrl     = TextEditingController();
  final _polyFatCtrl     = TextEditingController();
  final _transFatCtrl    = TextEditingController();
  final _cholCtrl        = TextEditingController();
  final _seleniumCtrl    = TextEditingController();
  final _magCtrl         = TextEditingController();
  final _ironCtrl        = TextEditingController();
  final _zincCtrl        = TextEditingController();
  final _calciumCtrl     = TextEditingController();
  final _potassiumCtrl   = TextEditingController();
  final _sodiumCtrl      = TextEditingController();
  final _phosphCtrl      = TextEditingController();
  final _copperCtrl      = TextEditingController();
  final _mangCtrl        = TextEditingController();
  final _vitACtrl        = TextEditingController();
  final _vitCCtrl        = TextEditingController();
  final _vitDCtrl        = TextEditingController();
  final _vitECtrl        = TextEditingController();
  final _vitKCtrl        = TextEditingController();
  final _b12Ctrl         = TextEditingController();
  final _thiamineCtrl    = TextEditingController();
  final _riboflavCtrl    = TextEditingController();
  final _niacinCtrl      = TextEditingController();
  final _pantCtrl        = TextEditingController();
  final _vitB6Ctrl        = TextEditingController();
  final _folateCtrl      = TextEditingController();
  final _cholineCtrl     = TextEditingController();
  final _biotinCtrl      = TextEditingController();
  final _omega3Ctrl      = TextEditingController();
  final _omega6Ctrl      = TextEditingController();
  final _alaCtrl         = TextEditingController();
  final _epaCtrl         = TextEditingController();
  final _dhaCtrl         = TextEditingController();
  final _betaCarotCtrl   = TextEditingController();
  final _lycopeneCtrl    = TextEditingController();
  final _luteinZeaCtrl   = TextEditingController();
  final _alphaCarotCtrl  = TextEditingController();
  final _tryptCtrl       = TextEditingController();
  final _threonCtrl      = TextEditingController();
  final _isolCtrl        = TextEditingController();
  final _leucCtrl        = TextEditingController();
  final _lysCtrl         = TextEditingController();
  final _metCtrl         = TextEditingController();
  final _phenCtrl        = TextEditingController();
  final _valCtrl         = TextEditingController();
  final _histCtrl        = TextEditingController();
  final _cystineCtrl     = TextEditingController();
  final _tyrosineCtrl    = TextEditingController();

  late String _meal;
  bool _isCalorieLocked = true;
  File? _photoFile;
  final ImagePicker _picker = ImagePicker();

  String _str(String key) {
    final p = widget.prefill;
    if (p == null) return '';
    final v = p[key];
    if (v == null) return '';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    return v.toString();
  }

  void _onMacroChanged() {
    if (!_isCalorieLocked) return;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0;
    final carbs = double.tryParse(_carbCtrl.text) ?? 0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0;
    final calories = FoodAnalysisService.calculateCalories(
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
    _calorieCtrl.text = calories.round().toString();
  }

  @override
  void initState() {
    super.initState();
    _meal = widget.selectedMeal;
    _nameCtrl = TextEditingController(text: _str('name'));
    _proteinCtrl = TextEditingController(text: _str('protein'));
    _carbCtrl = TextEditingController(text: _str('carbs'));
    _fatCtrl = TextEditingController(text: _str('fat'));

    _calorieCtrl = TextEditingController(text: _str('calories'));
    if (_calorieCtrl.text.isEmpty) _onMacroChanged();

    _fiberCtrl.text = _str('fiber');
    _sugarCtrl.text = _str('sugar');
    _satFatCtrl.text = _str('satFat');
    _monoFatCtrl.text = _str('monoFat');
    _polyFatCtrl.text = _str('polyFat');
    _transFatCtrl.text = _str('transFat');
    _cholCtrl.text = _str('cholesterol');
    _sodiumCtrl.text = _str('sodium');
    _magCtrl.text = _str('magnesium');
    _calciumCtrl.text = _str('calcium');
    _ironCtrl.text = _str('iron');
    _zincCtrl.text = _str('zinc');
    _potassiumCtrl.text = _str('potassium');
    _phosphCtrl.text = _str('phosphorus');
    _seleniumCtrl.text = _str('selenium');
    _copperCtrl.text = _str('copper');
    _mangCtrl.text = _str('manganese');
    _vitACtrl.text = _str('vitA');
    _vitCCtrl.text = _str('vitC');
    _vitDCtrl.text = _str('vitD');
    _vitECtrl.text = _str('vitE');
    _vitKCtrl.text = _str('vitK');
    _b12Ctrl.text = _str('vitB12');
    _thiamineCtrl.text = _str('thiamine');
    _riboflavCtrl.text = _str('riboflavin');
    _niacinCtrl.text = _str('niacin');
    _pantCtrl.text = _str('pantothenic');
    _vitB6Ctrl.text = _str('vitB6');
    _folateCtrl.text = _str('folate');
    _cholineCtrl.text = _str('choline');
    _biotinCtrl.text = _str('biotin');
    _omega3Ctrl.text = _str('omega3');
    _omega6Ctrl.text = _str('omega6');
    _alaCtrl.text = _str('ala');
    _epaCtrl.text = _str('epa');
    _dhaCtrl.text = _str('dha');
    _betaCarotCtrl.text = _str('betaCarot');
    _lycopeneCtrl.text = _str('lycopene');
    _luteinZeaCtrl.text = _str('luteinZea');
    _alphaCarotCtrl.text = _str('alphaCarot');
    _tryptCtrl.text = _str('tryptophan');
    _threonCtrl.text = _str('threonine');
    _isolCtrl.text = _str('isoleucine');
    _leucCtrl.text = _str('leucine');
    _lysCtrl.text = _str('lysine');
    _metCtrl.text = _str('methionine');
    _phenCtrl.text = _str('phenylalanine');
    _valCtrl.text = _str('valine');
    _histCtrl.text = _str('histidine');
    _cystineCtrl.text = _str('cystine');
    _tyrosineCtrl.text = _str('tyrosine');

    _proteinCtrl.addListener(_onMacroChanged);
    _carbCtrl.addListener(_onMacroChanged);
    _fatCtrl.addListener(_onMacroChanged);
  }

  @override
  void dispose() {
    _proteinCtrl.removeListener(_onMacroChanged);
    _carbCtrl.removeListener(_onMacroChanged);
    _fatCtrl.removeListener(_onMacroChanged);
    for (final c in [
      _nameCtrl, _calorieCtrl, _proteinCtrl, _carbCtrl, _fatCtrl,
      _fiberCtrl, _sugarCtrl, _satFatCtrl, _monoFatCtrl, _polyFatCtrl,
      _transFatCtrl, _cholCtrl, _seleniumCtrl, _magCtrl, _ironCtrl,
      _zincCtrl, _calciumCtrl, _potassiumCtrl, _sodiumCtrl, _phosphCtrl,
      _copperCtrl, _mangCtrl, _vitACtrl, _vitCCtrl, _vitDCtrl, _vitECtrl,
      _vitKCtrl, _b12Ctrl, _thiamineCtrl, _riboflavCtrl, _niacinCtrl,
      _pantCtrl, _vitB6Ctrl, _folateCtrl, _cholineCtrl, _biotinCtrl,
      _omega3Ctrl, _omega6Ctrl, _alaCtrl, _epaCtrl, _dhaCtrl,
      _betaCarotCtrl, _lycopeneCtrl, _luteinZeaCtrl, _alphaCarotCtrl,
      _tryptCtrl, _threonCtrl, _isolCtrl, _leucCtrl, _lysCtrl,
      _metCtrl, _phenCtrl, _valCtrl, _histCtrl, _cystineCtrl, _tyrosineCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 800);
    if (picked != null && mounted) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    double? nd(TextEditingController c) => _toNullableDouble(c.text);
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      portionSize: 100,
      nutritionData: NutritionData(
        calories: double.tryParse(_calorieCtrl.text) ?? 0,
        protein: double.tryParse(_proteinCtrl.text) ?? 0,
        carbohydrates: double.tryParse(_carbCtrl.text) ?? 0,
        fat: double.tryParse(_fatCtrl.text) ?? 0,
        fiber: double.tryParse(_fiberCtrl.text) ?? 0,
        sugar: double.tryParse(_sugarCtrl.text) ?? 0,
        saturatedFat: double.tryParse(_satFatCtrl.text) ?? 0,
        monoFat: nd(_monoFatCtrl), polyFat: nd(_polyFatCtrl),
        transFat: nd(_transFatCtrl), cholesterol: nd(_cholCtrl),
        selenium: nd(_seleniumCtrl), magnesium: nd(_magCtrl),
        iron: nd(_ironCtrl), zinc: nd(_zincCtrl),
        calcium: nd(_calciumCtrl), potassium: nd(_potassiumCtrl),
        sodium: nd(_sodiumCtrl), phosphorus: nd(_phosphCtrl),
        copper: nd(_copperCtrl), manganese: nd(_mangCtrl),
        vitaminA: nd(_vitACtrl), vitaminC: nd(_vitCCtrl),
        vitaminD: nd(_vitDCtrl), vitaminE: nd(_vitECtrl),
        vitaminK: nd(_vitKCtrl), vitaminB12: nd(_b12Ctrl),
        thiamine: nd(_thiamineCtrl), riboflavin: nd(_riboflavCtrl),
        niacin: nd(_niacinCtrl), pantothenic: nd(_pantCtrl),
        vitaminB6: nd(_vitB6Ctrl), folate: nd(_folateCtrl),
        choline: nd(_cholineCtrl), biotin: nd(_biotinCtrl),
        omega3: nd(_omega3Ctrl), omega6: nd(_omega6Ctrl),
        ala: nd(_alaCtrl), epa: nd(_epaCtrl), dha: nd(_dhaCtrl),
        betaCarotene: nd(_betaCarotCtrl),
        lycopene: nd(_lycopeneCtrl),
        luteinZeaxanthin: nd(_luteinZeaCtrl),
        alphaCarotene: nd(_alphaCarotCtrl),
        tryptophan: nd(_tryptCtrl), threonine: nd(_threonCtrl),
        isoleucine: nd(_isolCtrl), leucine: nd(_leucCtrl),
        lysine: nd(_lysCtrl), methionine: nd(_metCtrl),
        phenylalanine: nd(_phenCtrl), valine: nd(_valCtrl),
        histidine: nd(_histCtrl),
      ),
      timestamp: DateTime.now(),
      mealType: _meal,
      imagePath: _photoFile?.path,
    );
    Navigator.pop(context);
    widget.onSave(entry);
  }

  double? _toNullableDouble(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _formKey,
        child: ListView(
          controller: widget.scrollCtrl,
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5)),
              ),
            ),
            Text(
              widget.isAnalysis ? context.tr('Analizi Düzenle') : context.tr('Manuel Giriş'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            // ── Zorunlu alanlar ───────────────────────────────────────
            _Field(
                controller: _nameCtrl,
                label: 'Yemek Adı',
                required: true,
                textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 8),
            TextFormField(
              controller: _calorieCtrl,
              readOnly: _isCalorieLocked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                labelText: _isCalorieLocked ? context.tr('Kalori (otomatik)') : context.tr('Kalori'),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                floatingLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9500),
                ),
                suffixText: 'kcal',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF9500)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: const Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFFF9500)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isCalorieLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: const Color(0xFFFF9500),
                  ),
                  onPressed: () {
                    setState(() {
                      _isCalorieLocked = !_isCalorieLocked;
                      if (_isCalorieLocked) {
                        _onMacroChanged();
                      }
                    });
                  },
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Gerekli') : null,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _Field(
                        controller: _proteinCtrl,
                        label: 'Protein',
                        suffix: 'g',
                        numeric: true,
                        required: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Field(
                        controller: _carbCtrl,
                        label: 'Karbonhidrat',
                        suffix: 'g',
                        numeric: true,
                        required: true)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _Field(
                        controller: _fatCtrl,
                        label: 'Yağ',
                        suffix: 'g',
                        numeric: true,
                        required: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Field(
                        controller: _fiberCtrl,
                        label: 'Lif',
                        suffix: 'g',
                        numeric: true,
                        required: false)),
              ],
            ),
            const SizedBox(height: 12),
            // ── İsteğe bağlı alanlar ──────────────────────────────────
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                iconColor: const Color(0xFF007AFF),
                collapsedIconColor: isDark ? Colors.white60 : Colors.black54,
                title: Text(
                  context.tr('Detaylar (opsiyonel)'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                children: [
                  const SizedBox(height: 4),
                  _DetailSection(context.tr('Vitaminler'), const Color(0xFFFFA726), cs, [
                    _FieldDef(_vitACtrl,     'A Vitamini',  'μg'),
                    _FieldDef(_vitCCtrl,     'C Vitamini',  'mg'),
                    _FieldDef(_vitDCtrl,     'D Vitamini',  'μg'),
                    _FieldDef(_vitECtrl,     'E Vitamini',  'mg'),
                    _FieldDef(_vitKCtrl,     'K Vitamini',  'μg'),
                    _FieldDef(_b12Ctrl,      'B12',         'μg'),
                    _FieldDef(_thiamineCtrl, 'B1 (Tiamin)', 'mg'),
                    _FieldDef(_riboflavCtrl, 'B2 (Riboflavin)','mg'),
                    _FieldDef(_niacinCtrl,   'B3 (Niasin)','mg'),
                    _FieldDef(_pantCtrl,     'B5 (Pantotenik)','mg'),
                    _FieldDef(_vitB6Ctrl,       'B6',          'mg'),
                    _FieldDef(_folateCtrl,   'Folat',       'μg'),
                    _FieldDef(_cholineCtrl,  'Kolin',       'mg'),
                    _FieldDef(_biotinCtrl,   'Biyotin',     'μg'),
                  ]),
                  _DetailSection(context.tr('Mineraller'), const Color(0xFF58A6FF), cs, [
                    _FieldDef(_sodiumCtrl,   'Sodyum',    'mg'),
                    _FieldDef(_magCtrl,      'Magnezyum', 'mg'),
                    _FieldDef(_calciumCtrl,  'Kalsiyum',  'mg'),
                    _FieldDef(_ironCtrl,     'Demir',     'mg'),
                    _FieldDef(_zincCtrl,     'Çinko',     'mg'),
                    _FieldDef(_potassiumCtrl,'Potasyum',  'mg'),
                    _FieldDef(_phosphCtrl,   'Fosfor',    'mg'),
                    _FieldDef(_seleniumCtrl, 'Selenyum',  'μg'),
                    _FieldDef(_copperCtrl,   'Bakır',     'mg'),
                    _FieldDef(_mangCtrl,     'Manganez',  'mg'),
                  ]),
                  _DetailSection(context.tr('Karotenoidler'), const Color(0xFFFF6B00), cs, [
                    _FieldDef(_betaCarotCtrl, 'Beta-Karoten', 'μg'),
                    _FieldDef(_lycopeneCtrl,  'Likopen',      'μg'),
                    _FieldDef(_luteinZeaCtrl, 'Lutein+Zeaksantin',   'μg'),
                    _FieldDef(_alphaCarotCtrl,'Alfa-Karoten', 'μg'),
                  ]),
                  _DetailSection(context.tr('Karbonhidrat & Yağlar'), const Color(0xFF3FB950), cs, [
                    _FieldDef(_sugarCtrl,    'Şeker',             'g'),
                    _FieldDef(_satFatCtrl,   'Doymuş Yağ',        'g'),
                    _FieldDef(_monoFatCtrl,  'Tekli Doymamış Yağ','g'),
                    _FieldDef(_polyFatCtrl,  'Çoklu Doymamış Yağ','g'),
                    _FieldDef(_transFatCtrl, 'Trans Yağ',         'g'),
                    _FieldDef(_cholCtrl,     'Kolesterol',        'mg'),
                  ]),
                  _DetailSection(context.tr('Yağ Asitleri'), const Color(0xFF3FB950), cs, [
                    _FieldDef(_omega3Ctrl,   'Omega-3', 'g'),
                    _FieldDef(_omega6Ctrl,   'Omega-6', 'g'),
                    _FieldDef(_alaCtrl,      'ALA',     'g'),
                    _FieldDef(_epaCtrl,      'EPA',     'g'),
                    _FieldDef(_dhaCtrl,      'DHA',     'g'),
                  ]),
                  _DetailSection(context.tr('Amino Asitler'), const Color(0xFFD2A8FF), cs, [
                    _FieldDef(_tryptCtrl,  'Triptofan',    'g'),
                    _FieldDef(_threonCtrl, 'Treonin',      'g'),
                    _FieldDef(_isolCtrl,   'İzolösin',     'g'),
                    _FieldDef(_leucCtrl,   'Lösin',        'g'),
                    _FieldDef(_lysCtrl,    'Lizin',        'g'),
                    _FieldDef(_metCtrl,    'Metionin',     'g'),
                    _FieldDef(_phenCtrl,   'Fenilalanin',  'g'),
                    _FieldDef(_valCtrl,    'Valin',        'g'),
                    _FieldDef(_histCtrl,   'Histidin',     'g'),
                    _FieldDef(_cystineCtrl, 'Sistein',      'g'),
                    _FieldDef(_tyrosineCtrl,'Tirozin',      'g'),
                  ]),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // ── Fotoğraf ekleme ───────────────────────────────────────
            const SizedBox(height: 12),
            if (_photoFile != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_photoFile!,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _photoFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF007AFF)),
                          title: Text(context.tr('Kamera')),
                          onTap: () {
                            Navigator.pop(context);
                            _pickPhoto(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF007AFF)),
                          title: Text(context.tr('Galeriden Seç')),
                          onTap: () {
                            Navigator.pop(context);
                            _pickPhoto(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: const Color(0xFF007AFF).withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: const Color(0xFF007AFF),
                  backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.05),
                ),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  context.tr('Fotoğraf Ekle'),
                  style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
              ),
            const SizedBox(height: 16),
            // ── Öğün seçici ───────────────────────────────────────────
            Text(
              context.tr('Öğün Seçimi'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            _MealChipRow(
                selected: _meal,
                onChanged: (m) => setState(() => _meal = m)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                context.tr('Kaydet'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Field Helper ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool numeric;
  final bool required;
  final bool readOnly;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.controller,
    required this.label,
    this.suffix,
    this.numeric = false,
    this.required = false,
    this.readOnly = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color? labelColor;
    IconData? prefixIcon;
    final lLower = label.toLowerCase();
    if (lLower.contains('protein')) {
      labelColor = const Color(0xFFFF3B30); // Protein: Red
      prefixIcon = Icons.fitness_center_rounded;
    } else if (lLower.contains('karbonhidrat') || lLower.contains('karb')) {
      labelColor = const Color(0xFFFF9500); // Karb: Orange
      prefixIcon = Icons.cookie_rounded;
    } else if (lLower.contains('yağ')) {
      labelColor = const Color(0xFFAF52DE); // Yağ: Purple
      prefixIcon = Icons.opacity_rounded;
    } else if (lLower.contains('lif')) {
      labelColor = const Color(0xFF34C759); // Lif: Green
      prefixIcon = Icons.eco_rounded;
    } else if (lLower.contains('yemek') || lLower.contains('adı')) {
      prefixIcon = Icons.restaurant_menu_rounded;
    } else if (lLower.contains('kalori')) {
      prefixIcon = Icons.local_fire_department_rounded;
      labelColor = const Color(0xFFFF9500);
    }

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: context.tr(label),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black54,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: labelColor ?? (isDark ? Colors.white70 : Colors.black87),
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: labelColor ?? cs.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, size: 18, color: labelColor ?? cs.primary)
            : null,
        suffixIcon: readOnly
            ? Icon(Icons.lock_rounded, size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5))
            : null,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? context.tr('Gerekli') : null
          : null,
    );
  }
}

// ─── Detail section helpers ───────────────────────────────────────────────────

class _FieldDef {
  final TextEditingController ctrl;
  final String label;
  final String suffix;
  const _FieldDef(this.ctrl, this.label, this.suffix);
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Color sectionColor;
  final ColorScheme cs;
  final List<_FieldDef> fields;
  const _DetailSection(this.title, this.sectionColor, this.cs, this.fields);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: sectionColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ];
    for (int i = 0; i < fields.length; i += 2) {
      final left = fields[i];
      final right = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: _Field(controller: left.ctrl, label: left.label, suffix: left.suffix, numeric: true)),
            const SizedBox(width: 8),
            Expanded(child: right != null
                ? _Field(controller: right.ctrl, label: right.label, suffix: right.suffix, numeric: true)
                : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

// ─── Confidence Badge ─────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final int score;
  const _ConfidenceBadge({required this.score});

  Color _color() {
    if (score >= 80) return const Color(0xFF7EE787);
    if (score >= 60) return const Color(0xFFF0A500);
    return const Color(0xFFF85149);
  }

  String _label() {
    if (score >= 80) return 'Yüksek';
    if (score >= 60) return 'Orta';
    return 'Düşük';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '${_label()} ($score%)',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── NutriScore Badge ─────────────────────────────────────────────────────────

class _NutriScoreBadge extends StatelessWidget {
  final String grade; // a-e
  const _NutriScoreBadge({required this.grade});

  Color _color() {
    switch (grade.toLowerCase()) {
      case 'a': return const Color(0xFF038141);
      case 'b': return const Color(0xFF85BB2F);
      case 'c': return const Color(0xFFFECC02);
      case 'd': return const Color(0xFFEE8100);
      default:  return const Color(0xFFE63E11);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'NutriScore ${grade.toUpperCase()}',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── NOVA Badge ───────────────────────────────────────────────────────────────

class _NovaBadge extends StatelessWidget {
  final int group; // 1-4
  const _NovaBadge({required this.group});

  Color _color() {
    switch (group) {
      case 1: return const Color(0xFF038141);
      case 2: return const Color(0xFF85BB2F);
      case 3: return const Color(0xFFEE8100);
      default: return const Color(0xFFE63E11);
    }
  }

  String _label() {
    switch (group) {
      case 1: return 'NOVA 1 · İşlenmemiş';
      case 2: return 'NOVA 2 · Az İşlenmiş';
      case 3: return 'NOVA 3 · İşlenmiş';
      default: return 'NOVA 4 · Ultra İşlenmiş';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Allergen Chip ────────────────────────────────────────────────────────────

class _AllergenChip extends StatelessWidget {
  final String label;
  const _AllergenChip({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE63E11);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '⚠ $label',
        style: const TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Bottom Text Button ───────────────────────────────────────────────────────

class _BottomTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BottomTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Voice / Text Entry Sheet ─────────────────────────────────────────────────

enum _VoiceSheetState { input, listening, analyzing, confirming }

class _VoiceTextEntrySheet extends StatefulWidget {
  final String selectedMeal;
  final void Function(FoodEntry entry) onSave;

  const _VoiceTextEntrySheet({
    required this.selectedMeal,
    required this.onSave,
  });

  @override
  State<_VoiceTextEntrySheet> createState() => _VoiceTextEntrySheetState();
}

class _VoiceTextEntrySheetState extends State<_VoiceTextEntrySheet> {
  static const _speechChannel = MethodChannel('com.lenseat.app/speech');

  final _textCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _claudeService = ClaudeVisionService();
  final _analysisService = FoodAnalysisService();

  _VoiceSheetState _sheetState = _VoiceSheetState.input;
  late String _meal;

  FoodAnalysisResult? _result;
  String? _errorMsg;

  // Iteratif iyileştirme: her turda kullanıcının girdiği metinler birikir
  final List<String> _conversationHistory = [];

  // Kullanıcının seçtiği yemek fotoğrafı (isteğe bağlı)
  File? _selectedFoodImage;

  // İnternet fotoğrafı
  String? _foundImageUrl;
  bool _photoSearching = false;
  bool _useFoundPhoto = true;

  final List<String> _selectedSuggestions = [];

  @override
  void initState() {
    super.initState();
    _meal = widget.selectedMeal;

    final allSuggestions = [
      '2 adet köfte, yanında pilav 200g',
      '1 bardak süt ve 2 dilim ekmek',
      'Izgara tavuk göğsü 150g, salata',
      'Yulaf ezmesi, muz ve fıstık ezmesi',
      'Fırında levrek ve haşlanmış sebze',
      'Mercimek çorbası ve 1 dilim ekmek',
      'Muzlu protein shake ve 10 badem',
      'Zeytinyağlı taze fasulye ve yoğurt',
    ];
    allSuggestions.shuffle();
    _selectedSuggestions.addAll(allSuggestions.take(3));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() => _sheetState = _VoiceSheetState.listening);
    try {
      final result = await _speechChannel.invokeMethod<String>('listen');
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        _textCtrl.text = result;
        _textCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _textCtrl.text.length),
        );
      }
    } catch (_) {
      // Ses tanıma desteklenmiyor ya da iptal edildi
    }
    if (mounted) setState(() => _sheetState = _VoiceSheetState.input);
  }

  void _toggleListening() {
    if (_sheetState == _VoiceSheetState.listening) {
      // Zaten bekleniyor — iptal et
      if (mounted) setState(() => _sheetState = _VoiceSheetState.input);
    } else {
      _startListening();
    }
  }

  Future<void> _pickFoodImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
    if (picked != null && mounted) {
      setState(() => _selectedFoodImage = File(picked.path));
    }
  }

  Future<void> _analyze() async {
    final desc = _textCtrl.text.trim();
    if (desc.isEmpty) return;

    FocusScope.of(context).unfocus();

    // If user attached a photo: background analysis, pop immediately
    if (_selectedFoodImage != null) {
      _conversationHistory.add(desc);
      final provider = context.read<NutritionProvider>();
      provider.analyzeAndAddImage(_selectedFoodImage!, _meal, extraContext: desc);
      provider.enableHomeResult();
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Check minimum description length
    if (desc.split(' ').length < 2 && desc.length < 6) {
      setState(() => _errorMsg = context.tr('Lütfen yemeği daha detaylı tarif edin (en az 2-3 kelime).'));
      return;
    }

    _conversationHistory.add(desc);
    setState(() {
      _sheetState = _VoiceSheetState.analyzing;
      _errorMsg = null;
    });

    try {
      final result = await _analysisService.analyzeText(
        _conversationHistory.join(' | ayrıca: '),
      );
      if (!mounted) return;

      final score = result.confidenceScore;
      final foodName = result.foodName;
      final calories = result.nutritionScaled.calories;

      // Insufficient result — ask for more detail
      if (score < 35 || foodName.isEmpty || calories < 5) {
        setState(() {
          _sheetState = _VoiceSheetState.input;
          _errorMsg = context.tr('Tarif anlaşılamadı. Lütfen yemek adı, miktar ve pişirme yöntemini daha net belirtin.');
        });
        return;
      }

      setState(() {
        _result = result;
        _sheetState = _VoiceSheetState.confirming;
      });
      _searchFoodImage(foodName, result.foodNameEn);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sheetState = _VoiceSheetState.input;
          _errorMsg = '${context.tr('Analiz başarısız: {}').replaceFirst('{}', e.toString())}.';
        });
      }
    }
  }

  String _translateForImageSearch(String name) {
    final lower = name.toLowerCase().trim();
    const trToEn = {
      'haşlanmış': 'boiled', 'haslanmis': 'boiled',
      'ızgara': 'grilled', 'izgara': 'grilled',
      'kızartılmış': 'fried', 'kizartilmis': 'fried',
      'kızartma': 'fried', 'kizartma': 'fried',
      'fırında': 'baked', 'firinda': 'baked',
      'fırın': 'baked', 'firin': 'baked',
      'sahanda': 'fried',
      'haşlama': 'boiled', 'hashlama': 'boiled',
      'bütün': 'whole', 'butun': 'whole',
      'yumurta': 'egg',
      'tavuk': 'chicken',
      'köfte': 'meatball', 'kofte': 'meatball',
      'pilav': 'rice',
      'makarna': 'pasta',
      'salata': 'salad',
      'çorba': 'soup', 'corba': 'soup',
      'ekmek': 'bread',
      'peynir': 'cheese',
      'yoğurt': 'yogurt', 'yogurt': 'yogurt',
      'süt': 'milk', 'sut': 'milk',
      'et': 'meat',
      'balık': 'fish', 'balik': 'fish',
      'somon': 'salmon',
      'ton balığı': 'tuna', 'ton baligi': 'tuna',
      'patates': 'potato',
      'domates': 'tomato',
      'zeytin': 'olive',
      'elma': 'apple',
      'muz': 'banana',
      'portakal': 'orange',
      'salatalık': 'cucumber', 'salatalik': 'cucumber',
      'soğan': 'onion', 'sogan': 'onion',
      'biber': 'pepper',
      'ıspanak': 'spinach', 'ispanak': 'spinach',
      'çilek': 'strawberry', 'cilek': 'strawberry',
      'üzüm': 'grape', 'uzum': 'grape',
      'badem': 'almond',
      'ceviz': 'walnut',
      'avokado': 'avocado',
      'pirinç': 'rice', 'pirinc': 'rice',
      'mercimek': 'lentil',
      'nohut': 'chickpea',
      'fasulye': 'beans',
      'bezelye': 'peas',
      'mısır': 'corn', 'misir': 'corn',
      'sucuk': 'sausage',
      'salam': 'salami',
      'sosis': 'sausage',
      'pastırma': 'pastrami', 'pastirma': 'pastrami',
      'bal': 'honey',
      'tereyağı': 'butter', 'tereyagi': 'butter',
      'zeytinyağı': 'olive oil', 'zeytinyagi': 'olive oil',
    };

    String result = lower;
    for (final entry in trToEn.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  Future<void> _searchFoodImage(String foodName, String? foodNameEn) async {
    if (mounted) setState(() => _photoSearching = true);
    try {
      final nameForSearch = foodNameEn ?? foodName;
      
      // 1. Try Pixabay first if key is available
      final pixabayApiKey = ConfigService.pixabayKey;
      if (pixabayApiKey.isNotEmpty) {
        try {
          final query = Uri.encodeComponent('$nameForSearch food');
          final response = await http.get(Uri.parse(
            'https://pixabay.com/api/?key=$pixabayApiKey&q=$query&image_type=photo&per_page=3'
          )).timeout(const Duration(seconds: 6));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final hits = data['hits'] as List<dynamic>?;
            if (hits != null && hits.isNotEmpty) {
              final url = hits[0]['webformatURL'] as String?;
              if (url != null && url.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _foundImageUrl = url;
                    _photoSearching = false;
                  });
                }
                return; // Found on Pixabay, return immediately
              }
            }
          }
        } catch (e) {
          debugPrint('Pixabay search error: $e');
        }
      }

      // 2. Fallback to Wikimedia Commons if not found on Pixabay
      final query = Uri.encodeComponent('${foodNameEn ?? _translateForImageSearch(foodName)} food');
      final response = await http.get(Uri.parse(
        'https://commons.wikimedia.org/w/api.php?action=query&prop=pageimages'
        '&format=json&piprop=thumbnail&pithumbsize=400'
        '&generator=search&gsrnamespace=6&gsrlimit=5&gsrsearch=$query',
      )).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          String? url;
          for (final page in pages.values) {
            final thumb = page['thumbnail']?['source'] as String?;
            if (thumb != null) {
              final lowerThumb = thumb.toLowerCase();
              if (lowerThumb.contains('.svg') ||
                  lowerThumb.contains('flag') ||
                  lowerThumb.contains('map') ||
                  lowerThumb.contains('logo') ||
                  lowerThumb.contains('icon') ||
                  lowerThumb.contains('diagram') ||
                  lowerThumb.contains('chart') ||
                  lowerThumb.contains('portrait') ||
                  lowerThumb.contains('emblem') ||
                  lowerThumb.contains('shield') ||
                  lowerThumb.contains('person') ||
                  lowerThumb.contains('graph') ||
                  lowerThumb.contains('blank')) {
                continue;
              }
              url = thumb;
              break;
            }
          }
          if (mounted) setState(() => _foundImageUrl = url);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _photoSearching = false);
  }

  Future<void> _saveResult() async {
    final r = _result;
    if (r == null) return;

    // Fotoğrafı indir (varsa ve kullanıcı kabul ettiyse)
    String? imagePath;
    if (_useFoundPhoto && _foundImageUrl != null) {
      try {
        final imgResp = await http.get(Uri.parse(_foundImageUrl!))
            .timeout(const Duration(seconds: 10));
        if (imgResp.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(imgResp.bodyBytes);
          imagePath = file.path;
        }
      } catch (_) {}
    }

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: r.foodName,
      portionSize: r.portionGrams,
      nutritionData: r.nutritionPer100g,
      nutrition65per100g: r.nutrition65per100g,
      timestamp: DateTime.now(),
      mealType: _meal,
      imagePath: imagePath,
    );
    if (mounted) {
      Navigator.pop(context);
    }
    widget.onSave(entry);
  }

  void _askForMoreDetails() {
    setState(() {
      _sheetState = _VoiceSheetState.input;
      _textCtrl.text = '';
    });
  }

  void _openEditSheet(FoodAnalysisResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _ManualEntryBottomSheet(
          scrollCtrl: scrollCtrl,
          selectedMeal: _meal,
          isAnalysis: true,
          prefill: buildPrefillMap(result, isTr: ctx.read<LanguageProvider>().isTurkish),
          onSave: (entry) {
            setState(() {
              _result = FoodAnalysisResult(
                foodName: entry.name,
                foodNameEn: entry.name,
                portionGrams: entry.portionSize,
                nutritionPer100g: entry.nutritionData,
                nutrition65per100g: NutritionData65(
                  energy: entry.nutritionData.calories,
                  protein: entry.nutritionData.protein,
                  fat: entry.nutritionData.fat,
                  carb: entry.nutritionData.carbohydrates,
                  fiber: entry.nutritionData.fiber,
                  sugar: entry.nutritionData.sugar,
                  satFat: entry.nutritionData.saturatedFat,
                  monoFat: entry.nutritionData.monoFat ?? 0,
                  polyFat: entry.nutritionData.polyFat ?? 0,
                  transFat: entry.nutritionData.transFat ?? 0,
                  cholesterol: entry.nutritionData.cholesterol ?? 0,
                  water: 0,
                  calcium: entry.nutritionData.calcium ?? 0,
                  iron: entry.nutritionData.iron ?? 0,
                  magnesium: entry.nutritionData.magnesium ?? 0,
                  phosphorus: entry.nutritionData.phosphorus ?? 0,
                  potassium: entry.nutritionData.potassium ?? 0,
                  sodium: entry.nutritionData.sodium ?? 0,
                  zinc: entry.nutritionData.zinc ?? 0,
                  copper: entry.nutritionData.copper ?? 0,
                  manganese: entry.nutritionData.manganese ?? 0,
                  selenium: entry.nutritionData.selenium ?? 0,
                  vitC: entry.nutritionData.vitaminC ?? 0,
                  vitD_mcg: entry.nutritionData.vitaminD ?? 0,
                  vitE: entry.nutritionData.vitaminE ?? 0,
                  vitK: entry.nutritionData.vitaminK ?? 0,
                  vitA_RAE: entry.nutritionData.vitaminA ?? 0,
                  thiamine: entry.nutritionData.thiamine ?? 0,
                  riboflavin: entry.nutritionData.riboflavin ?? 0,
                  niacin: entry.nutritionData.niacin ?? 0,
                  pantothenic: entry.nutritionData.pantothenic ?? 0,
                  vitB6: entry.nutritionData.vitaminB6 ?? 0,
                  folate: entry.nutritionData.folate ?? 0,
                  vitB12: entry.nutritionData.vitaminB12 ?? 0,
                  choline: entry.nutritionData.choline ?? 0,
                  biotin: entry.nutritionData.biotin ?? 0,
                  omega3: entry.nutritionData.omega3 ?? 0,
                  omega6: entry.nutritionData.omega6 ?? 0,
                  ala: entry.nutritionData.ala ?? 0,
                  epa: entry.nutritionData.epa ?? 0,
                  dha: entry.nutritionData.dha ?? 0,
                  tryptophan: entry.nutritionData.tryptophan ?? 0,
                  threonine: entry.nutritionData.threonine ?? 0,
                  isoleucine: entry.nutritionData.isoleucine ?? 0,
                  leucine: entry.nutritionData.leucine ?? 0,
                  lysine: entry.nutritionData.lysine ?? 0,
                  methionine: entry.nutritionData.methionine ?? 0,
                  phenylalanine: entry.nutritionData.phenylalanine ?? 0,
                  valine: entry.nutritionData.valine ?? 0,
                  histidine: entry.nutritionData.histidine ?? 0,
                  dataSource: 'Düzenlendi',
                ),
                sources: const ['Düzenlendi'],
                confidenceScore: 100,
                confidenceReason: 'Kullanıcı tarafından elle düzenlendi.',
                alternativeMin: FoodAnalysisService.calculateCalories(
                  proteinG: entry.nutritionData.protein * entry.portionSize / 100,
                  carbsG: entry.nutritionData.carbohydrates * entry.portionSize / 100,
                  fatG: entry.nutritionData.fat * entry.portionSize / 100,
                ) * 0.9,
                alternativeMax: FoodAnalysisService.calculateCalories(
                  proteinG: entry.nutritionData.protein * entry.portionSize / 100,
                  carbsG: entry.nutritionData.carbohydrates * entry.portionSize / 100,
                  fatG: entry.nutritionData.fat * entry.portionSize / 100,
                ) * 1.1,
              );
              _sheetState = _VoiceSheetState.confirming;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: _sheetState == _VoiceSheetState.analyzing ? 0.35 : 0.7,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Üst başlık ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        if (_sheetState == _VoiceSheetState.input && _result != null) ...[
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: cs.primary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              setState(() {
                                _sheetState = _VoiceSheetState.confirming;
                                _errorMsg = null;
                              });
                            },
                          ),
                        ] else ...[
                          Icon(Icons.restaurant_menu_rounded, color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('Anlatarak Analiz'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                        const Spacer(),
                        if (_sheetState == _VoiceSheetState.confirming && _result != null)
                          IconButton(
                            icon: Icon(Icons.edit_rounded, color: cs.primary, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: context.tr('Düzenle'),
                            onPressed: () => _openEditSheet(_result!),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
              // ── Kaydırılabilir içerik ──
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
                  child: _buildContent(cs, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ColorScheme cs, bool isDark) {
    switch (_sheetState) {
      case _VoiceSheetState.analyzing:
        return _buildAnalyzing(cs);
      case _VoiceSheetState.confirming:
        return _buildConfirming(cs);
      case _VoiceSheetState.input:
      case _VoiceSheetState.listening:
        return _buildInput(cs);
    }
  }

  Widget _buildInput(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isListening = _sheetState == _VoiceSheetState.listening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Örnekler (sadece ilk turda)
        if (_conversationHistory.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Örnekler:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ..._selectedSuggestions.map((key) => context.tr(key)).map((e) => GestureDetector(
                      onTap: () {
                        _textCtrl.text = e;
                        _textCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: e.length),
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          )
        else
          // İkinci turda — önceki bilgiyi göster
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr('Önceki tarif: {}').replaceFirst('{}', _conversationHistory.join(' + ')),
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        if (_errorMsg != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
            ),
            child: Text(
              _errorMsg!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
            ),
          ),
        // Metin alanı + mikrofon butonu
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textCtrl,
                builder: (_, __, ___) => TextField(
                  controller: _textCtrl,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: _conversationHistory.isEmpty
                        ? context.tr('Yemeği tarif et... gramajı, miktar ve yemek adını yaz')
                        : context.tr('Daha fazla detay ekle...'),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF007AFF),
                  boxShadow: isListening
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                            blurRadius: 14,
                            spreadRadius: 3,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        if (isListening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: 8),
                const Text(
                  'Dinleniyor... konuşun',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // İsteğe bağlı yemek fotoğrafı
        GestureDetector(
          onTap: _pickFoodImage,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _selectedFoodImage != null ? const Color(0xFF007AFF) : Colors.transparent),
            ),
            child: Row(
              children: [
                if (_selectedFoodImage != null) ...[
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), bottomLeft: Radius.circular(13)),
                    child: Image.file(_selectedFoodImage!, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.tr('Fotoğraf seçildi'), style: const TextStyle(fontSize: 13, color: Color(0xFF007AFF), fontWeight: FontWeight.w600))),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: isDark ? Colors.white60 : Colors.black54),
                    onPressed: () => setState(() => _selectedFoodImage = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ] else ...[
                  const SizedBox(width: 14),
                  Icon(Icons.add_photo_alternate_outlined, size: 20, color: isDark ? Colors.white54 : Colors.black54),
                  const SizedBox(width: 10),
                  Text(context.tr('Yemek fotoğrafı ekle (isteğe bağlı)'), style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _MealChipRow(
          selected: _meal,
          onChanged: (m) => setState(() => _meal = m),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textCtrl,
          builder: (_, val, __) => FilledButton.icon(
            onPressed: val.text.trim().isEmpty ? null : _analyze,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _conversationHistory.isEmpty ? context.tr('AI ile Hesapla') : context.tr('Tekrar Hesapla'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzing(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            context.tr('Besin değerleri hesaplanıyor...'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('AI tarifinizi analiz ediyor'),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirming(ColorScheme cs) {
    final r = _result!;
    final name = r.foodName;
    final portion = r.portionGrams;
    final scaled = r.nutritionScaled;
    final calories = scaled.calories;
    final protein = scaled.protein;
    final carbs = scaled.carbohydrates;
    final fat = scaled.fat;
    final fiber = scaled.fiber;
    final score = r.confidenceScore;
    final displayedScore = score < 85 ? 85 : (score > 100 ? 100 : score);
    final isTr = context.watch<LanguageProvider>().isTurkish;
    final confReason = isTr
        ? (r.confidenceReason ?? '')
        : (r.confidenceReasonEn != null && r.confidenceReasonEn!.isNotEmpty
            ? r.confidenceReasonEn!
            : (r.confidenceReason ?? ''));
    final minKcal = r.alternativeMin.toInt();
    final maxKcal = r.alternativeMax.toInt();
    final porsAcik = r.portionDescription ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confColor = displayedScore >= 75
        ? const Color(0xFF34C759) // Apple Green
        : displayedScore >= 50
            ? const Color(0xFFFF9500) // Apple Orange
            : const Color(0xFFFF3B30); // Apple Red

    final detailsList = <Widget>[];
    final n65 = r.nutrition65per100g;
    final factor = r.portionGrams / 100.0;
    if (n65 != null) {
      void addIf(String label, double val, String unit, {int dec = 1}) {
        final scaledVal = val * factor;
        if (scaledVal > 0.01) {
          detailsList.add(_infoRow(context, context.tr(label), '${scaledVal.toStringAsFixed(dec)} $unit'));
        }
      }
      addIf('Doymuş Yağ', n65.satFat, 'g');
      addIf('Tekli Doymamış Yağ', n65.monoFat, 'g');
      addIf('Çoklu Doymamış Yağ', n65.polyFat, 'g');
      addIf('Kolesterol', n65.cholesterol, 'mg', dec: 0);
      addIf('Sodyum', n65.sodium, 'mg', dec: 0);
      addIf('Kalsiyum', n65.calcium, 'mg', dec: 0);
      addIf('Demir', n65.iron, 'mg');
      addIf('Magnezyum', n65.magnesium, 'mg', dec: 0);
      addIf('Potasyum', n65.potassium, 'mg', dec: 0);
      addIf('Çinko', n65.zinc, 'mg');
      addIf('Fosfor', n65.phosphorus, 'mg', dec: 0);
      addIf('Selenyum', n65.selenium, 'mcg');
      addIf('Bakır', n65.copper, 'mg');
      addIf('Manganez', n65.manganese, 'mg');
      addIf('Vitamin A', n65.vitA_RAE, 'mcg RAE', dec: 0);
      addIf('Vitamin C', n65.vitC, 'mg');
      addIf('Vitamin D', n65.vitD_mcg, 'mcg');
      addIf('Vitamin E', n65.vitE, 'mg');
      addIf('Vitamin K', n65.vitK, 'mcg');
      addIf('B1 (Tiamin)', n65.thiamine, 'mg');
      addIf('B2 (Riboflavin)', n65.riboflavin, 'mg');
      addIf('B3 (Niasin)', n65.niacin, 'mg');
      addIf('B5 (Pantotenik)', n65.pantothenic, 'mg');
      addIf('B6', n65.vitB6, 'mg');
      addIf('Folat (B9)', n65.folate, 'mcg', dec: 0);
      addIf('B12', n65.vitB12, 'mcg');
      addIf('Biotin (B7)', n65.biotin, 'mcg');
      addIf('Kolin', n65.choline, 'mg', dec: 0);
      addIf('Omega-3', n65.omega3, 'g');
      addIf('Omega-6', n65.omega6, 'g');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: confColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: confColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      context.tr('Doğruluk: %{}').replaceFirst('{}', displayedScore.toString()),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: confColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (porsAcik.isNotEmpty || portion > 0) ...[
                const SizedBox(height: 6),
                Text(
                  porsAcik.isNotEmpty
                      ? porsAcik
                      : context.tr('Porsiyon: ~{}g').replaceFirst('{}', portion.toStringAsFixed(0)),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 40,
                  color: Color(0xFFFF6B35),
                  letterSpacing: -0.5,
                ),
              ),
              if (minKcal > 0 && maxKcal > 0) ...[
                const SizedBox(height: 2),
                Text(
                  context.tr('~{} – {} kcal aralığı').replaceFirst('{}', minKcal.toString()).replaceFirst('{}', maxKcal.toString()),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MacroCard(label: context.tr('Protein'), value: '${protein.toStringAsFixed(1)}g', color: const Color(0xFFFF3B30), isDark: isDark),
            const SizedBox(width: 8),
            _MacroCard(label: context.tr('Karb'), value: '${carbs.toStringAsFixed(1)}g', color: const Color(0xFFFF9500), isDark: isDark),
            const SizedBox(width: 8),
            _MacroCard(label: context.tr('Yağ'), value: '${fat.toStringAsFixed(1)}g', color: const Color(0xFFAF52DE), isDark: isDark),
            const SizedBox(width: 8),
            _MacroCard(label: context.tr('Lif'), value: '${fiber.toStringAsFixed(1)}g', color: const Color(0xFF34C759), isDark: isDark),
          ],
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              title: Text(
                context.tr('Detaylar'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: detailsList.isNotEmpty
                        ? detailsList
                        : [
                            Text(
                              context.tr('Mikro besin verisi bulunamadı.'),
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                            )
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (score < 75) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: confColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: confColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Daha Fazla Detay Eklenebilir'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: confColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        confReason.isNotEmpty
                            ? confReason
                            : context.tr('Girdiğiniz tarif çok kısa veya yetersiz olduğu için ortalama değerler hesaplanmıştır. Daha kesin sonuçlar için pişirme yöntemi, miktar veya marka belirterek detay ekleyebilirsiniz.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (confReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            confReason,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
        const SizedBox(height: 14),
        // ── İnternet fotoğrafı bölümü ──
        if (_photoSearching)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Text(context.tr('Fotoğraf aranıyor...'), style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          )
        else if (_foundImageUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _foundImageUrl!,
                    width: 72, height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (ctx, url, e) => Container(
                      width: 72, height: 72,
                      color: cs.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.broken_image_outlined, color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Bu fotoğrafı kullan?'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('İnternetten bulunan fotoğraf'),
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _useFoundPhoto,
                  onChanged: (v) => setState(() => _useFoundPhoto = v),
                  activeThumbColor: cs.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _MealChipRow(
          selected: _meal,
          onChanged: (m) => setState(() => _meal = m),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _askForMoreDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0xFFFF3B30), width: 1.2),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  context.tr('Detay Ekle'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saveResult,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  context.tr('Evet, Kaydet'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
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

// ─── Pulsing Dot (ses dinleme animasyonu) ─────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(
            const Color(0xFFF85149).withValues(alpha: 0.4),
            const Color(0xFFF85149),
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ─── Micro Nutrients Sheet ────────────────────────────────────────────────────

class _MicroNutrientsSheet extends StatelessWidget {
  final FoodAnalysisResult result;
  final ScrollController scrollCtrl;

  const _MicroNutrientsSheet({required this.result, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n65 = result.nutrition65per100g;
    final factor = result.portionGrams / 100.0;

    double s(double v) => v * factor;
    String fmt(double v, {int decimals = 1}) =>
        v < 0.01 ? '—' : v.toStringAsFixed(decimals);

    Widget section(String title, Color color) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        );

    Widget row(String label, String value, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Text(result.foodName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${result.portionGrams.round()}g porsiyon', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: n65 == null
                  ? [
                      const SizedBox(height: 40),
                      Center(child: Text('Detaylı besin bilgisi mevcut değil', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)))),
                    ]
                  : [
                      section('VİTAMİNLER', const Color(0xFFFFA726)),
                      row('Vitamin C', fmt(s(n65.vitC)), 'mg'),
                      row('Vitamin D', fmt(s(n65.vitD_mcg)), 'mcg'),
                      row('Vitamin A', fmt(s(n65.vitA_RAE)), 'mcg RAE'),
                      row('Vitamin E', fmt(s(n65.vitE)), 'mg'),
                      row('Vitamin K', fmt(s(n65.vitK)), 'mcg'),
                      row('Vitamin B6', fmt(s(n65.vitB6)), 'mg'),
                      row('Vitamin B12', fmt(s(n65.vitB12)), 'mcg'),
                      row('Folat', fmt(s(n65.folate)), 'mcg'),
                      row('Tiamin (B1)', fmt(s(n65.thiamine)), 'mg'),
                      row('Riboflavin (B2)', fmt(s(n65.riboflavin)), 'mg'),
                      row('Niasin (B3)', fmt(s(n65.niacin)), 'mg'),
                      row('Pantotenik Asit (B5)', fmt(s(n65.pantothenic)), 'mg'),
                      section('MİNERALLER', const Color(0xFF58A6FF)),
                      row('Kalsiyum', fmt(s(n65.calcium), decimals: 0), 'mg'),
                      row('Demir', fmt(s(n65.iron)), 'mg'),
                      row('Magnezyum', fmt(s(n65.magnesium), decimals: 0), 'mg'),
                      row('Çinko', fmt(s(n65.zinc)), 'mg'),
                      row('Potasyum', fmt(s(n65.potassium), decimals: 0), 'mg'),
                      row('Sodyum', fmt(s(n65.sodium), decimals: 0), 'mg'),
                      row('Fosfor', fmt(s(n65.phosphorus), decimals: 0), 'mg'),
                      row('Selenyum', fmt(s(n65.selenium)), 'mcg'),
                      row('Bakır', fmt(s(n65.copper)), 'mg'),
                      row('Manganez', fmt(s(n65.manganese)), 'mg'),
                      section('YAĞLAR', const Color(0xFF3FB950)),
                      row('Doymuş Yağ', fmt(s(n65.satFat)), 'g'),
                      row('Tekli Doymamış', fmt(s(n65.monoFat)), 'g'),
                      row('Çoklu Doymamış', fmt(s(n65.polyFat)), 'g'),
                      row('Omega-3', fmt(s(n65.omega3)), 'g'),
                      row('Omega-6', fmt(s(n65.omega6)), 'g'),
                      row('Kolesterol', fmt(s(n65.cholesterol), decimals: 0), 'mg'),
                      const SizedBox(height: 20),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── In-App Camera Capture Screen ────────────────────────────────────────────

class _InAppCaptureScreen extends StatefulWidget {
  const _InAppCaptureScreen();
  @override
  State<_InAppCaptureScreen> createState() => _InAppCaptureScreenState();
}

class _InAppCaptureScreenState extends State<_InAppCaptureScreen> {
  CameraController? _ctrl;
  bool _ready = false;
  bool _capturing = false;
  bool _permissionGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _checkingPermission = false;
        });
      }
      _init();
    } else {
      final result = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _permissionGranted = result.isGranted;
          _checkingPermission = false;
        });
      }
      if (result.isGranted) {
        _init();
      }
    }
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { if (mounted) Navigator.pop(context); return; }
      final ctrl = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      _ctrl = ctrl;
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || _ctrl == null || !_ready) return;
    setState(() => _capturing = true);
    try {
      final photo = await _ctrl!.takePicture();
      if (mounted) Navigator.pop(context, File(photo.path));
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;

    if (_checkingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_permissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
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
            ),
            Positioned(
              top: safe.top + 12,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55)),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready && _ctrl != null)
            CameraPreview(_ctrl!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // Close
          Positioned(
            top: safe.top + 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55)),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
          // Shutter
          Positioned(
            bottom: safe.bottom + 36,
            left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 4),
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
