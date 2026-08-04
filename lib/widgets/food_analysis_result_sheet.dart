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
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/saved_foods_service.dart';
import '../services/config_service.dart';
import '../screens/manual_entry_screen.dart';
import '../services/food_analysis_service.dart';

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

  static Future<dynamic> show(
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
  final _detailsController = TextEditingController();

  bool _isCalorieManuallyEdited = false;
  FoodAnalysisResult? _localResult;
  bool _showDetailsForm = false;
  bool _isReanalyzing = false;

  @override
  void initState() {
    super.initState();
    _localResult = widget.result;
    _selectedMeal = widget.mealType ?? 'kahvaltı';
    if (widget.image == null && !widget.isFullScreen) {
      _fetchSuggestedImage(widget.result.foodName, widget.result.foodNameEn);
    }

    final isTr = Provider.of<LanguageProvider>(context, listen: false).isTurkish;
    _nameCtrl.text = isTr ? widget.result.foodName : (widget.result.foodNameEn ?? widget.result.foodName);
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
    _checkIfSaved();
  }

  void _checkIfSaved() async {
    final name = _nameCtrl.text.trim().isEmpty ? widget.result.foodName : _nameCtrl.text.trim();
    final saved = await SavedFoodsService.isSaved(name);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaveFood() async {
    final name = _nameCtrl.text.trim().isEmpty ? widget.result.foodName : _nameCtrl.text.trim();
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
      final portionGrams = double.tryParse(_gramsCtrl.text) ?? widget.result.portionGrams;
      final factor = portionGrams / 100;
      final food = SavedFood(
        id: name,
        name: name,
        portionGrams: portionGrams,
        nutritionPer100g: NutritionData(
          calories: factor > 0 ? (double.tryParse(_calorieCtrl.text) ?? 0.0) / factor : 0,
          protein: factor > 0 ? (double.tryParse(_proteinCtrl.text) ?? 0.0) / factor : 0,
          carbohydrates: factor > 0 ? (double.tryParse(_carbCtrl.text) ?? 0.0) / factor : 0,
          fat: factor > 0 ? (double.tryParse(_fatCtrl.text) ?? 0.0) / factor : 0,
          fiber: factor > 0 ? (double.tryParse(_fiberCtrl.text) ?? 0.0) / factor : 0,
        ),
        sources: widget.result.sources,
        savedAt: DateTime.now(),
        imagePath: widget.image?.path,
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
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestedImage(String foodName, String? foodNameEn) async {
    final apiKey = ConfigService.pixabayKey;
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _imageSearching = false;
          _suggestedImageUrl = null;
        });
      }
      return;
    }

    if (mounted) setState(() => _imageSearching = true);
    try {
      final nameForSearch = foodNameEn ?? foodName;
      final query = Uri.encodeComponent('$nameForSearch food');
      final resp = await http.get(Uri.parse(
        'https://pixabay.com/api/?key=$apiKey&q=$query&image_type=photo&per_page=3'
      )).timeout(const Duration(seconds: 8));
      
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final hits = data['hits'] as List<dynamic>?;
        if (hits != null && hits.isNotEmpty) {
          final url = hits[0]['webformatURL'] as String?;
          if (mounted) setState(() => _suggestedImageUrl = url);
        } else {
          if (mounted) setState(() => _suggestedImageUrl = null);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _suggestedImageUrl = null);
    }
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
    final isTr = context.read<LanguageProvider>().isTurkish;
    final currentRes = _localResult ?? widget.result;
    final portionGrams = double.tryParse(_gramsCtrl.text) ?? currentRes.portionGrams;
    final factor = portionGrams / 100;

    // Download suggested image or copy uploaded image persistently to application documents directory
    String? resolvedImagePath;
    if (widget.image != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await File(widget.image!.path).copy(file.path);
        resolvedImagePath = file.path;
      } catch (_) {
        resolvedImagePath = widget.image!.path;
      }
    } else if (_useSuggestedImage && _suggestedImageUrl != null) {
      try {
        final imgResp = await http.get(Uri.parse(_suggestedImageUrl!))
            .timeout(const Duration(seconds: 10));
        if (imgResp.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(imgResp.bodyBytes);
          resolvedImagePath = file.path;
        }
      } catch (_) {}
    }
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim().isEmpty 
          ? (isTr ? currentRes.foodName : (currentRes.foodNameEn ?? currentRes.foodName)) 
          : _nameCtrl.text.trim(),
      portionSize: portionGrams,
      nutritionData: currentRes.nutritionPer100g.copyWith(
        calories: factor > 0 ? (double.tryParse(_calorieCtrl.text) ?? 0.0) / factor : 0,
        protein: factor > 0 ? (double.tryParse(_proteinCtrl.text) ?? 0.0) / factor : 0,
        carbohydrates: factor > 0 ? (double.tryParse(_carbCtrl.text) ?? 0.0) / factor : 0,
        fat: factor > 0 ? (double.tryParse(_fatCtrl.text) ?? 0.0) / factor : 0,
        fiber: factor > 0 ? (double.tryParse(_fiberCtrl.text) ?? 0.0) / factor : 0,
      ),
      nutrition65per100g: currentRes.nutrition65per100g,
      timestamp: DateTime.now(),
      mealType: _selectedMeal,
      imagePath: resolvedImagePath,
      novaGroup: currentRes.offProduct?.novaGroup,
    );
    widget.onConfirm(entry);
  }

  void _toggleDetailsForm(bool show) {
    setState(() {
      _showDetailsForm = show;
    });
    if (widget.draggableController != null) {
      widget.draggableController!.animateTo(
        show ? 0.58 : 0.85,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleEdit() async {
    final currentRes = _localResult ?? widget.result;
    
    final currentEntry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      portionSize: double.tryParse(_gramsCtrl.text) ?? currentRes.portionGrams,
      nutritionData: NutritionData(
        calories: double.tryParse(_calorieCtrl.text) ?? 0.0,
        protein: double.tryParse(_proteinCtrl.text) ?? 0.0,
        carbohydrates: double.tryParse(_carbCtrl.text) ?? 0.0,
        fat: double.tryParse(_fatCtrl.text) ?? 0.0,
        fiber: double.tryParse(_fiberCtrl.text) ?? 0.0,
        sodium: currentRes.nutritionPer100g.sodium,
        sugar: currentRes.nutritionPer100g.sugar,
        saturatedFat: currentRes.nutritionPer100g.saturatedFat,
        vitaminA: currentRes.nutritionPer100g.vitaminA,
        vitaminC: currentRes.nutritionPer100g.vitaminC,
        vitaminD: currentRes.nutritionPer100g.vitaminD,
        vitaminE: currentRes.nutritionPer100g.vitaminE,
        vitaminK: currentRes.nutritionPer100g.vitaminK,
        vitaminB6: currentRes.nutritionPer100g.vitaminB6,
        vitaminB12: currentRes.nutritionPer100g.vitaminB12,
        folate: currentRes.nutritionPer100g.folate,
        calcium: currentRes.nutritionPer100g.calcium,
        iron: currentRes.nutritionPer100g.iron,
        magnesium: currentRes.nutritionPer100g.magnesium,
        potassium: currentRes.nutritionPer100g.potassium,
        zinc: currentRes.nutritionPer100g.zinc,
        selenium: currentRes.nutritionPer100g.selenium,
        omega3: currentRes.nutritionPer100g.omega3,
        omega6: currentRes.nutritionPer100g.omega6,
      ),
      nutrition65per100g: currentRes.nutrition65per100g,
      timestamp: DateTime.now(),
      mealType: _selectedMeal,
      imagePath: widget.image?.path,
    );

    final updatedEntry = await Navigator.push<FoodEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          existingEntry: currentEntry,
          selectedMeal: _selectedMeal,
          forceAdd: true,
          isOnlyEditMode: true,
        ),
      ),
    );

    if (updatedEntry != null && mounted) {
      setState(() {
        _nameCtrl.text = updatedEntry.name;
        _gramsCtrl.text = updatedEntry.portionSize.toStringAsFixed(0);
        
        final portionGrams = updatedEntry.portionSize;
        final factor = portionGrams / 100;
        
        _calorieCtrl.text = (updatedEntry.nutritionData.calories * factor).toStringAsFixed(0);
        _proteinCtrl.text = (updatedEntry.nutritionData.protein * factor).toStringAsFixed(1);
        _carbCtrl.text = (updatedEntry.nutritionData.carbohydrates * factor).toStringAsFixed(1);
        _fatCtrl.text = (updatedEntry.nutritionData.fat * factor).toStringAsFixed(1);
        _fiberCtrl.text = (updatedEntry.nutritionData.fiber * factor).toStringAsFixed(1);

        _localResult = FoodAnalysisResult(
          foodName: updatedEntry.name,
          foodNameEn: currentRes.foodNameEn,
          portionGrams: updatedEntry.portionSize,
          nutritionPer100g: updatedEntry.nutritionData,
          nutrition65per100g: updatedEntry.nutrition65per100g ?? currentRes.nutrition65per100g,
          sources: currentRes.sources,
          confidenceScore: currentRes.confidenceScore,
          confidenceReason: currentRes.confidenceReason,
          confidenceReasonEn: currentRes.confidenceReasonEn,
          alternativeMin: updatedEntry.nutritionData.calories * factor * 0.9,
          alternativeMax: updatedEntry.nutritionData.calories * factor * 1.1,
        );
      });
    }
  }

  String _getDynamicExamplesText(String foodName, bool isTr) {
    final n = foodName.trim().toLowerCase();

    // Identify food category for relevant examples
    final isPizza = n.contains('pizza');
    final isBurger = n.contains('burger') || n.contains('hamburger') || n.contains('cheeseburger');
    final isSushi = n.contains('sushi') || n.contains('maki') || n.contains('nigiri') || n.contains('kimbap') || n.contains('onigiri');
    final isPasta = n.contains('pasta') || n.contains('spaghetti') || n.contains('makarna') || n.contains('noodle') || n.contains('erişte');
    final isSalad = n.contains('salata') || n.contains('salad');
    final isSoup = n.contains('çorba') || n.contains('soup');
    final isRice = n.contains('pilav') || n.contains('rice') || n.contains('fried rice');
    final isWrap = n.contains('wrap') || n.contains('dürüm') || n.contains('tortilla') || n.contains('burrito');
    final isDessert = n.contains('kek') || n.contains('cake') || n.contains('çikolata') || n.contains('chocolate') || n.contains('tatlı') || n.contains('dessert') || n.contains('waffle') || n.contains('tiramisu');
    final isChicken = n.contains('tavuk') || n.contains('chicken');
    final isSandwich = n.contains('sandviç') || n.contains('sandwich') || n.contains('tost') || n.contains('toast');

    if (isTr) {
      if (isPizza) return '2 dilim pizza yedim, ekstra peynirli\nPepperoni değil, karışık malzemeli pizza\nTam buğday hamurlu pizzaydı';
      if (isBurger) return '1 adet yedim, çift köfte vardı\nBüyük boy menü, patates kızartması ile\nCheeseburger değil, çıtlı tavuk burger';
      if (isSushi) return '8 parça yedim, soya sosuyla tükettim\nWasabi ekledim, avokadolu ruloydu\nKimbap değil, ızgara somon nigiri';
      if (isPasta) return 'Büyük porsiyon yedim, kremalı soslu makarna\nYanında ekmek yedim\nTavuklu makarna değil, deniz mahsüllü makarna';
      if (isSalad) return 'Büyük porsiyon, içinde tavuk da vardı\nÜzerine zeytinyağı ve limon sıktım\nSezar salata değil, Akdeniz salata';
      if (isSoup) return '1 kase içtim, yanında ekmek yedim\nMercimek çorbası değil, ezogelin çorba\nİçine krema katıldı, çok baharatlıydı';
      if (isRice) return '1 porsiyon yedim, tereyağlı pişirildi\nYanında tavuk ızgara ile yedim\nPilavın altında et suyu vardı';
      if (isWrap) return '1 adet yedim, büyük boy dürüm\nİçinde soğan, biber ve kaşar vardı\nYanında ayran içtim';
      if (isDessert) return '1 dilim yedim, üzerine dondurma eklendi\nYanında süt içtim\nYoğun çikolatalı, şeker oranı yüksek';
      if (isChicken) return '200 gram yedim, fırında pişirildi\nYanında salata ile yedim\nSoslu tavuk göğsüydü, baharat eklendi';
      if (isSandwich) return '1 adet yedim, içinde kaşar ve domates vardı\nTam buğday ekmekten yapıldı\nYanında çay içtim';
      final cleanName = foodName.trim();
      return '1 porsiyon $cleanName yedim\nYanında farklı bir şey de yedim\n$cleanName değil, farklı bir yemekti';
    } else {
      if (isPizza) return 'I had 2 slices of pizza, extra cheese on top\nNot pepperoni, it was a mixed topping pizza\nWhole wheat crust, not regular';
      if (isBurger) return 'I had 1 burger, double patty\nLarge meal combo with fries\nNot a cheeseburger, it was a crispy chicken burger';
      if (isSushi) return 'I ate 8 pieces, consumed with soy sauce\nWasabi added, it was an avocado roll\nNot kimbap, it was grilled salmon nigiri';
      if (isPasta) return 'Large portion, creamy sauce pasta\nHad bread on the side\nNot chicken pasta, it was seafood pasta';
      if (isSalad) return 'Large portion, it also had chicken\nAdded olive oil and lemon on top\nNot caesar salad, it was a Mediterranean salad';
      if (isSoup) return '1 bowl, had bread on the side\nNot lentil soup, it was tomato soup\nCream was added, heavily spiced';
      if (isRice) return '1 serving, cooked with butter\nHad it with grilled chicken\nChicken broth was used in the rice';
      if (isWrap) return '1 piece, large size wrap\nHad onions, peppers and cheddar inside\nHad yogurt drink on the side';
      if (isDessert) return '1 slice, ice cream was added on top\nHad milk with it\nHigh sugar, intensely chocolatey';
      if (isChicken) return '200 grams, baked in the oven\nHad it with salad\nSauced chicken breast with spices';
      if (isSandwich) return '1 piece, had cheddar and tomato inside\nMade from whole wheat bread\nHad tea with it';
      final cleanName = foodName.trim();
      return '1 portion of $cleanName\nI also had something on the side\nNot $cleanName, it was a different dish';
    }

  }



  @override
  Widget build(BuildContext context) {
    final result = _localResult ?? widget.result;
    final scaled = result.nutritionScaled;
    final cs = Theme.of(context).colorScheme;
    final isTr = context.watch<LanguageProvider>().isTurkish;
    final displayName = isTr ? result.foodName : (result.foodNameEn ?? result.foodName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detailsList = <Widget>[];
    final n65 = result.nutrition65per100g;
    final factor = result.portionGrams / 100.0;
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


    Future<bool?> _showDeleteConfirmation() async {
      return await showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Analizi Sil?')),
          content: Text(context.tr('Bu analizi silmek istediğinizden emin misiniz?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Vazgeç'), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Sil'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    Future<bool?> _showDismissConfirmation() async {
      return await showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('Analizden Çıkılsın mı?')),
          content: Text(context.tr('Henüz kaydetmediniz. Devam etmek mi istersiniz yoksa silip çıkmak mı?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Çık'), style: const TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('Kaydetmeye Devam Et')),
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

    final sheetContent = SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showDetailsForm
            ? Column(
                key: const ValueKey('details_view'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.add_comment_rounded, color: Color(0xFF007AFF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Detay Ekle'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Dynamic Contextual Examples
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTr ? 'Örnek:' : 'Examples:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getDynamicExamplesText(result.foodName, isTr),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text Box
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: TextField(
                      controller: _detailsController,
                      maxLines: 4,
                      minLines: 3,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: context.tr('Yemeğin porsiyonu, ismi veya malzemeleri hakkında detay yazın...'),
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _toggleDetailsForm(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.black54,
                            side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(context.tr('Vazgeç'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final text = _detailsController.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr('Lütfen detay girin.')),
                                  backgroundColor: const Color(0xFFFF3B30),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context, text);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(context.tr('Yeniden Analiz Et'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                key: const ValueKey('main_view'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title row
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, color: const Color(0xFF007AFF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Görselden Analiz'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                        color: _isSaved ? const Color(0xFFF0A500) : cs.onSurface.withValues(alpha: 0.6),
                        onPressed: _toggleSaveFood,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 20),
                        onPressed: () async {
                          final ok = await _showDeleteConfirmation();
                          if (ok == true && context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // User's added image
                  if (widget.image != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          widget.image!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Food name & portion card
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
                              child: TextField(
                                controller: _nameCtrl,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${context.tr('Porsiyon: ')}~',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                            IntrinsicWidth(
                              child: TextField(
                                controller: _gramsCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Text(
                              'g',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Calorie display
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            IntrinsicWidth(
                              child: TextField(
                                controller: _calorieCtrl,
                                onTap: () => _isCalorieManuallyEdited = true,
                                onChanged: (_) => _isCalorieManuallyEdited = true,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 40,
                                  color: Color(0xFFFF6B35),
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'kcal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B35),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '~${result.alternativeMin.round()} – ${result.alternativeMax.round()} kcal aralığı',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Macros
                  Row(
                    children: [
                      _EditableMacro(controller: _proteinCtrl, label: context.tr('Protein'), color: const Color(0xFFFF3B30)),
                      const SizedBox(width: 6),
                      _EditableMacro(controller: _carbCtrl, label: context.tr('Karb'), color: const Color(0xFFFF9500)),
                      const SizedBox(width: 6),
                      _EditableMacro(controller: _fatCtrl, label: context.tr('Yağ'), color: const Color(0xFFAF52DE)),
                      const SizedBox(width: 6),
                      _EditableMacro(controller: _fiberCtrl, label: context.tr('Lif'), color: const Color(0xFF34C759)),
                    ],
                  ),
                  if (result.offProduct != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (result.offProduct!.nutriscoreGrade != null) _NutriScoreBadge(grade: result.offProduct!.nutriscoreGrade!),
                        if (result.offProduct!.nutriscoreGrade != null && result.offProduct!.novaGroup != null) const SizedBox(width: 6),
                        if (result.offProduct!.novaGroup != null) _NovaBadge(group: result.offProduct!.novaGroup!),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Details expander
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(context.tr('Hangi öğüne eklensin?'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  _MealChipRow(selected: _selectedMeal, onChanged: (m) => setState(() => _selectedMeal = m)),
                  const SizedBox(height: 24),

                  // Restructured Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF007AFF),
                            side: const BorderSide(color: Color(0xFF007AFF), width: 1.2),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(context.tr('Düzenle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleDetailsForm(true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF34C759),
                            side: const BorderSide(color: Color(0xFF34C759), width: 1.2),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_comment_rounded, size: 16),
                          label: Text(context.tr('Detay Ekle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.tr('Evet, Kaydet'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
      ),
    );

    if (widget.isFullScreen) {
      return PopScope(
        canPop: _confirmedExit,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final choice = await _showDismissConfirmation();
          if (choice == null) return;
          if (choice == false && context.mounted) exitSheet();
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF131520) : Colors.white,
          body: SafeArea(
            child: sheetContent,
          ),
        ),
      );
    }

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
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131520) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: sheetContent,
      ),
    );
  }

  Widget _infoRow(BuildContext ctx, String label, String value) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMacro extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _EditableMacro({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
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
        final isTr = context.read<LanguageProvider>().isTurkish;
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
                    child: Text(context.tr('Yapay Zeka Analizi'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF26D0CE))),
                  ),
                  const SizedBox(width: 12),
                  Text(context.tr('Nasıl hesaplandı?'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Bu besin bilgisi, yüklediğiniz görseli analiz eden gelişmiş yapay zeka modelleri (Claude Vision) ve besin veritabanları (Edamam, OpenFoodFacts) kullanılarak oluşturulmuştur.'),
                style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.8), height: 1.5),
              ),
              Builder(builder: (ctx) {
                final confidenceReasonText = isTr 
                    ? result.confidenceReason 
                    : (result.confidenceReasonEn != null && result.confidenceReasonEn!.isNotEmpty 
                        ? result.confidenceReasonEn 
                        : result.confidenceReason);
                if (confidenceReasonText != null && confidenceReasonText.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        context.tr('ANALİZ DETAYI'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        confidenceReasonText,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6), height: 1.5, fontStyle: FontStyle.italic),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),
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
    final color = displayedScore >= 75
        ? const Color(0xFF34C759) // Apple Green
        : displayedScore >= 50
            ? const Color(0xFFFF9500) // Apple Orange
            : const Color(0xFFFF3B30); // Apple Red

    return InkWell(
      onTap: () => _showAiExplanation(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(
              '${context.tr('Doğruluk %')}$displayedScore',
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

  List<_NutriSection> _buildSections(BuildContext context, NutritionData65 n, double factor) {
    double s(double v) => v * factor;

    return [
      _NutriSection(context.tr('MİNERALLER'), const Color(0xFF58A6FF), [
        _NutriEntry(context.tr('Kalsiyum'),    s(n.calcium),    'mg',  decimals: 0, dri: 1000),
        _NutriEntry(context.tr('Demir'),       s(n.iron),       'mg',  dri: 18),
        _NutriEntry(context.tr('Magnezyum'),   s(n.magnesium),  'mg',  decimals: 0, dri: 420),
        _NutriEntry(context.tr('Fosfor'),      s(n.phosphorus), 'mg',  decimals: 0, dri: 700),
        _NutriEntry(context.tr('Potasyum'),    s(n.potassium),  'mg',  decimals: 0, dri: 3500),
        _NutriEntry(context.tr('Sodyum'),      s(n.sodium),     'mg',  decimals: 0, dri: 2300),
        _NutriEntry(context.tr('Çinko'),       s(n.zinc),       'mg',  dri: 11),
        _NutriEntry(context.tr('Bakır'),       s(n.copper),     'mg',  dri: 0.9),
        _NutriEntry(context.tr('Manganez'),    s(n.manganese),  'mg',  dri: 2.3),
        _NutriEntry(context.tr('Selenyum'),    s(n.selenium),   'mcg', dri: 55),
        _NutriEntry(context.tr('İyot'),        s(n.iodine),     'mcg', dri: 150),
        _NutriEntry(context.tr('Krom'),        s(n.chromium),   'mcg', dri: 35),
        _NutriEntry(context.tr('Molibden'),    s(n.molybdenum), 'mcg', dri: 45),
        _NutriEntry(context.tr('Florür'),      s(n.fluoride),   'mcg', decimals: 0),
      ]),

      _NutriSection(context.tr('VİTAMİNLER'), const Color(0xFFFFA726), [
        _NutriEntry(context.tr('Vitamin C'),             s(n.vitC),        'mg',  dri: 90),
        _NutriEntry(context.tr('Vitamin D'),             s(n.vitD_mcg),    'mcg', dri: 20),
        _NutriEntry(context.tr('Vitamin A'),             s(n.vitA_RAE),    'mcg RAE', dri: 900),
        _NutriEntry(context.tr('Vitamin E'),             s(n.vitE),        'mg',  dri: 15),
        _NutriEntry(context.tr('Vitamin K'),             s(n.vitK),        'mcg', dri: 120),
        _NutriEntry(context.tr('B1 (Tiamin)'),           s(n.thiamine),    'mg',  dri: 1.2),
        _NutriEntry(context.tr('B2 (Riboflavin)'),       s(n.riboflavin),  'mg',  dri: 1.3),
        _NutriEntry(context.tr('B3 (Niasin)'),           s(n.niacin),      'mg',  dri: 16),
        _NutriEntry(context.tr('B5 (Pantotenik)'),       s(n.pantothenic), 'mg',  dri: 5),
        _NutriEntry(context.tr('B6'),                   s(n.vitB6),       'mg',  dri: 1.7),
        _NutriEntry(context.tr('Folat (B9)'),           s(n.folate),      'mcg', decimals: 0, dri: 400),
        _NutriEntry(context.tr('B12'),                  s(n.vitB12),      'mcg', dri: 2.4),
        _NutriEntry(context.tr('Biotin (B7)'),          s(n.biotin),      'mcg', dri: 30),
        _NutriEntry(context.tr('Kolin'),               s(n.choline),     'mg',  decimals: 0, dri: 550),
      ]),

      _NutriSection(context.tr('KAROTENOİDLER'), const Color(0xFFFF6B00), [
        _NutriEntry(context.tr('Beta-Karoten'),          s(n.betaCarot),   'mcg', decimals: 0, dri: 3000),
        _NutriEntry(context.tr('Likopen'),             s(n.lycopene),    'mcg', decimals: 0, dri: 10000),
        _NutriEntry(context.tr('Lutein + Zeaksantin'), s(n.luteinZea),   'mcg', decimals: 0, dri: 6000),
        _NutriEntry(context.tr('Alfa-Karoten'),        s(n.alphaCarot),  'mcg', decimals: 0, dri: 2000),
      ]),

      _NutriSection(context.tr('YAĞ & KOLESTEROl'), const Color(0xFF3FB950), [
        _NutriEntry(context.tr('Doymuş Yağ'),      s(n.satFat),    'g', dri: 20),
        _NutriEntry(context.tr('Tekli Doymamiş'),  s(n.monoFat),   'g', dri: 30),
        _NutriEntry(context.tr('Çoklu Doymamış'),  s(n.polyFat),   'g', dri: 20),
        _NutriEntry(context.tr('Trans Yağ'),       s(n.transFat),  'g', dri: 2),
        _NutriEntry(context.tr('Kolesterol'),      s(n.cholesterol), 'mg', decimals: 0, dri: 300),
        _NutriEntry(context.tr('Omega-3'),         s(n.omega3),    'g',  dri: 1.6),
        _NutriEntry(context.tr('Omega-6'),         s(n.omega6),    'g',  dri: 15),
        _NutriEntry(context.tr('ALA'),             s(n.ala),       'g',  dri: 1.6),
        _NutriEntry(context.tr('EPA'),             s(n.epa),       'g',  dri: 0.5),
        _NutriEntry(context.tr('DHA'),             s(n.dha),       'g',  dri: 0.5),
        _NutriEntry(context.tr('Linoleik'),        s(n.linoleic),  'g',  dri: 15),
      ]),

      _NutriSection(context.tr('AMİNO ASİTLER'), const Color(0xFFD2A8FF), [
        _NutriEntry(context.tr('Lösin'),          s(n.leucine),       'g', dri: 2.7),
        _NutriEntry(context.tr('Lizin'),          s(n.lysine),        'g', dri: 2.1),
        _NutriEntry(context.tr('Valin'),          s(n.valine),        'g', dri: 1.8),
        _NutriEntry(context.tr('İzolösin'),       s(n.isoleucine),    'g', dri: 1.4),
        _NutriEntry(context.tr('Treonin'),        s(n.threonine),     'g', dri: 1.0),
        _NutriEntry(context.tr('Metionin'),       s(n.methionine),    'g', dri: 0.9),
        _NutriEntry(context.tr('Fenilalanin'),    s(n.phenylalanine), 'g', dri: 2.3),
        _NutriEntry(context.tr('Triptofan'),      s(n.tryptophan),    'g', dri: 0.3),
        _NutriEntry(context.tr('Histidin'),       s(n.histidine),     'g', dri: 0.7),
        _NutriEntry(context.tr('Sistein'),        s(n.cystine),       'g', dri: 0.4),
        _NutriEntry(context.tr('Tirozin'),        s(n.tyrosine),      'g', dri: 0.8),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n65 = result.nutrition65per100g;
    final isTr = context.watch<LanguageProvider>().isTurkish;
    final displayName = isTr ? result.foodName : (result.foodNameEn ?? result.foodName);

    // Aktif bölümleri belirle (en az 1 besin değeri >= 0.01 olanlar)
    final factor = result.portionGrams / 100.0;
    final sections = n65 != null ? _buildSections(context, n65, factor) : <_NutriSection>[];
    final activeSections = sections.where((sec) => sec.entries.any((e) => e.value >= 0.01)).toList();
    
    // Toplam mineral + vitamin sayısı
    final totalCount = activeSections.fold<int>(0, (sum, sec) => sum + sec.entries.where((e) => e.value >= 0.01).length);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
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
                Expanded(child: Text(displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${result.portionGrams.round()}${context.tr('g porsiyon')}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                    if (totalCount > 0)
                      Text('$totalCount ${context.tr('besin tespit edildi')}', style: TextStyle(fontSize: 10, color: cs.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
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
                      child: Text(context.tr('Detaylı besin bilgisi mevcut değil'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
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
