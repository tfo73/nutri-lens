import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import '../providers/nutrition_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

/// Apple HIG (Human Interface Guidelines) compliant Manual Entry & Edit Screen
class ManualEntryScreen extends StatefulWidget {
  final String? selectedMeal;
  final FoodEntry? existingEntry;
  final bool forceAdd;
  final DateTime? date;
  final bool showMealSelection;
  final bool isOnlyEditMode;

  const ManualEntryScreen({
    super.key,
    this.selectedMeal,
    this.existingEntry,
    this.forceAdd = false,
    this.date,
    this.showMealSelection = true,
    this.isOnlyEditMode = false,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _portionCtrl = TextEditingController(text: '100');
  final _calorieCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _calorieFocusNode = FocusNode();

  File? _selectedImage;
  String? _networkImageUrl;
  final _picker = ImagePicker();
  late String _selectedMeal;
  bool _isCalorieLocked = true;

  final Map<String, TextEditingController> _microCtrls = {};

  static const List<(String, Color, List<(String, String, String)>)> _rawNutrientGroups = [
    ('VİTAMİNLER', Color(0xFFFF9500), [
      ('vit_c',        'C Vitamini',       'mg'),
      ('vit_d_mcg',    'D Vitamini',       'mcg'),
      ('vit_a_rae',    'A Vitamini (RAE)', 'mcg'),
      ('vit_e',        'E Vitamini',       'mg'),
      ('vit_k',        'K Vitamini (K1)',  'mcg'),
      ('vit_k_mena',   'K2 Vitamini',      'mcg'),
      ('thiamine',     'B1 (Tiamin)',       'mg'),
      ('riboflavin',   'B2 (Riboflavin)',   'mg'),
      ('niacin',       'B3 (Niasin)',       'mg'),
      ('pantothenic',  'B5 (Pantotenik)',   'mg'),
      ('vit_b6',       'B6 Vitamini',       'mg'),
      ('folate',       'Folat (B9)',         'mcg'),
      ('vit_b12',      'B12 Vitamini',      'mcg'),
      ('biotin',       'Biotin (B7)',        'mcg'),
      ('choline',      'Kolin',             'mg'),
      ('betaine',      'Betain',            'mg'),
    ]),
    ('MİNERALLER', Color(0xFF007AFF), [
      ('calcium',    'Kalsiyum',  'mg'),
      ('iron',       'Demir',     'mg'),
      ('magnesium',  'Magnezyum', 'mg'),
      ('phosphorus', 'Fosfor',    'mg'),
      ('potassium',  'Potasyum',  'mg'),
      ('sodium',     'Sodyum',    'mg'),
      ('zinc',       'Çinko',     'mg'),
      ('copper',     'Bakır',     'mg'),
      ('manganese',  'Manganez',  'mg'),
      ('selenium',   'Selenyum',  'mcg'),
      ('iodine',     'İyot',      'mcg'),
      ('chromium',   'Krom',      'mcg'),
      ('molybdenum', 'Molibden',  'mcg'),
      ('fluoride',   'Florür',    'mcg'),
    ]),
    ('KAROTENOİDLER', Color(0xFFFF3B30), [
      ('beta_carot',  'Beta-Karoten',       'mcg'),
      ('lycopene',    'Likopen',            'mcg'),
      ('lutein_zea',  'Lutein+Zeaksantin',  'mcg'),
      ('alpha_carot', 'Alfa-Karoten',       'mcg'),
    ]),
    ('YAĞ ASİTLERİ', Color(0xFFAF52DE), [
      ('mono_fat',   'Tekli Doymamış Yağ', 'g'),
      ('poly_fat',   'Çoklu Doymamış Yağ', 'g'),
      ('trans_fat',  'Trans Yağ',           'g'),
      ('cholesterol','Kolesterol',          'mg'),
      ('omega3',     'Omega-3 (toplam)',    'g'),
      ('omega6',     'Omega-6 (toplam)',    'g'),
      ('ala',        'ALA',                 'g'),
      ('epa',        'EPA',                 'g'),
      ('dha',        'DHA',                 'g'),
    ]),
    ('AMİNO ASİTLER', Color(0xFF34C759), [
      ('tryptophan',   'Triptofan',  'g'),
      ('threonine',    'Treonin',    'g'),
      ('isoleucine',   'İzolösin',   'g'),
      ('leucine',      'Lösin',      'g'),
      ('lysine',       'Lizin',      'g'),
      ('methionine',   'Metionin',   'g'),
      ('cystine',      'Sistin',     'g'),
      ('phenylalanine','Fenilalanin','g'),
      ('tyrosine',     'Tirozin',    'g'),
      ('valine',       'Valin',      'g'),
      ('histidine',    'Histidin',   'g'),
    ]),
  ];

  static String _normalizeMealType(String? raw) {
    if (raw == null) return 'kahvaltı';
    final m = raw.toLowerCase().trim();
    if (m.contains('kahvaltı') && m.contains('ara')) return 'kahvaltı sonrası ara öğün';
    if (m.contains('öğle') && m.contains('ara')) return 'öğle sonrası ara öğün';
    if (m == 'akşam' || m == 'akşam yemeği' || m == 'dinner') return 'akşam yemeği';
    if (m == 'öğle' || m == 'öğle yemeği' || m == 'lunch') return 'öğle yemeği';
    if (m == 'kahvaltı' || m == 'breakfast') return 'kahvaltı';
    if (m.contains('gece') || m.contains('snack')) return 'gece atıştırmalığı';
    if (m.contains('ara')) return 'kahvaltı sonrası ara öğün';
    return 'kahvaltı';
  }

  @override
  void initState() {
    super.initState();
    _selectedMeal = _normalizeMealType(widget.existingEntry?.mealType ?? widget.selectedMeal);

    // Init micro controllers
    for (final group in _rawNutrientGroups) {
      for (final item in group.$3) {
        _microCtrls[item.$1] = TextEditingController();
      }
    }

    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _nameCtrl.text = e.name;
      _portionCtrl.text = e.portionSize.round().toString();
      _selectedMeal = _normalizeMealType(e.mealType);

      final n = e.nutritionData.scaleBy(e.portionSize / 100);
      _calorieCtrl.text = n.calories.round().toString();
      _proteinCtrl.text = n.protein.toStringAsFixed(1);
      _carbCtrl.text = n.carbohydrates.toStringAsFixed(1);
      _fatCtrl.text = n.fat.toStringAsFixed(1);
      _fiberCtrl.text = n.fiber.toStringAsFixed(1);

      if (e.imagePath != null) {
        _selectedImage = File(e.imagePath!);
      } else if (e.imageUrl != null) {
        _networkImageUrl = e.imageUrl;
      }

      // Populate 65 micro fields if available
      final n65 = e.nutrition65per100g ?? e.nutritionData.to65();
      final scaled65 = n65.scaleBy(e.portionSize / 100);
      _populateMicroFieldsFrom65(scaled65);
    }

    _proteinCtrl.addListener(_autoCalcCalories);
    _carbCtrl.addListener(_autoCalcCalories);
    _fatCtrl.addListener(_autoCalcCalories);
  }

  void _populateMicroFieldsFrom65(NutritionData65 n65) {
    final Map<String, dynamic> json = n65.toJson();
    json.forEach((k, v) {
      if (_microCtrls.containsKey(k) && v is num && v > 0) {
        final dVal = v.toDouble();
        _microCtrls[k]!.text = dVal < 1 ? dVal.toStringAsFixed(2) : dVal.toStringAsFixed(1);
      }
    });
  }

  void _autoCalcCalories() {
    if (!_isCalorieLocked) return;
    final p = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final c = double.tryParse(_carbCtrl.text) ?? 0.0;
    final f = double.tryParse(_fatCtrl.text) ?? 0.0;
    final calc = (p * 4) + (c * 4) + (f * 9);
    if (calc > 0) {
      _calorieCtrl.text = calc.round().toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    _calorieFocusNode.dispose();
    for (final ctrl in _microCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _saveEntry() {
    if (!_formKey.currentState!.validate()) return;

    final portionSize = double.tryParse(_portionCtrl.text) ?? 100.0;
    final factor = portionSize / 100;
    final calories = double.tryParse(_calorieCtrl.text) ?? 0.0;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final carbs = double.tryParse(_carbCtrl.text) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0.0;
    final fiber = double.tryParse(_fiberCtrl.text) ?? 0.0;

    final entry = FoodEntry(
      id: widget.existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      portionSize: portionSize,
      nutritionData: (widget.existingEntry?.nutritionData ?? NutritionData.empty).copyWith(
        calories: factor > 0 ? calories / factor : 0,
        protein: factor > 0 ? protein / factor : 0,
        carbohydrates: factor > 0 ? carbs / factor : 0,
        fat: factor > 0 ? fat / factor : 0,
        fiber: factor > 0 ? fiber / factor : 0,
      ),
      timestamp: widget.existingEntry?.timestamp ?? DateTime.now(),
      mealType: _selectedMeal,
      imagePath: _selectedImage?.path,
      imageUrl: widget.existingEntry?.imageUrl,
      portionUnit: widget.existingEntry?.portionUnit ?? 'g',
      nutrition65per100g: _buildNutrition65(factor),
    );

    if (!widget.isOnlyEditMode) {
      final provider = context.read<NutritionProvider>();
      final isUpdate = widget.existingEntry != null && !widget.forceAdd;
      if (isUpdate) {
        provider.updateFoodEntry(entry, date: widget.date);
      } else {
        provider.addFoodEntry(entry, date: widget.date);
      }
    }

    // Return the updated FoodEntry directly back to the caller
    Navigator.pop(context, entry);
  }

  NutritionData65 _buildNutrition65(double factor) {
    final base = widget.existingEntry?.nutrition65per100g ?? widget.existingEntry?.nutritionData.to65() ?? const NutritionData65(energy: 0, protein: 0, fat: 0, carb: 0);
    final Map<String, dynamic> json = base.toJson();

    _microCtrls.forEach((key, ctrl) {
      if (ctrl.text.isNotEmpty) {
        final val = double.tryParse(ctrl.text) ?? 0.0;
        json[key] = factor > 0 ? val / factor : 0.0;
      }
    });

    return NutritionData65.fromJson(json);
  }

  void _showEnlargedImage() {
    if (_selectedImage == null && _networkImageUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.black.withValues(alpha: 0.9),
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.contain)
                      : CachedNetworkImage(imageUrl: _networkImageUrl!, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
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
    final isTr = context.watch<LanguageProvider>().isTurkish;

    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingEntry != null ? context.tr('Yemeği Düzenle') : context.tr('Manuel Giriş'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Photo & Name Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedImage != null || _networkImageUrl != null) ...[
                      GestureDetector(
                        onTap: _showEnlargedImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _selectedImage != null
                                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                                : CachedNetworkImage(imageUrl: _networkImageUrl!, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 44),
                        side: BorderSide(color: const Color(0xFF007AFF).withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: const Color(0xFF007AFF),
                        backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.05),
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(
                        _selectedImage != null
                            ? context.tr('Fotoğrafı Değiştir')
                            : context.tr('Fotoğraf Ekle (İsteğe Bağlı)'),
                        style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Food Name Field
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: context.tr('Yiyecek Adı'),
                        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
                        hintText: isTr ? 'ör. Izgara Tavuk Salatası' : 'e.g. Grilled Chicken Salad',
                        prefixIcon: const Icon(Icons.restaurant_rounded, size: 20, color: Color(0xFF007AFF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return context.tr('Lütfen yiyecek adını girin');
                        }
                        return null;
                      },
                    ),

                    if (widget.showMealSelection) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.tr('Öğün Tipi'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedMeal,
                        dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF007AFF)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        items: [
                          DropdownMenuItem(value: 'kahvaltı', child: Text(context.tr('Kahvaltı'))),
                          DropdownMenuItem(value: 'kahvaltı sonrası ara öğün', child: Text(context.tr('Kahvaltı Sonrası Ara Öğün'))),
                          DropdownMenuItem(value: 'öğle yemeği', child: Text(context.tr('Öğle Yemeği'))),
                          DropdownMenuItem(value: 'öğle sonrası ara öğün', child: Text(context.tr('Öğle Sonrası Ara Öğün'))),
                          DropdownMenuItem(value: 'akşam yemeği', child: Text(context.tr('Akşam Yemeği'))),
                          DropdownMenuItem(value: 'gece atıştırmalığı', child: Text(context.tr('Gece Atıştırmalığı'))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMeal = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Portion & Calorie Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Porsiyon ve Kalori' : 'Portion & Calories',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _portionCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: context.tr('Porsiyon Miktarı (g)'),
                              labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                              floatingLabelStyle: const TextStyle(color: Color(0xFF007AFF), fontSize: 13, fontWeight: FontWeight.bold),
                              prefixIcon: const Icon(Icons.scale_rounded, size: 20, color: Color(0xFF007AFF)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _calorieCtrl,
                            readOnly: _isCalorieLocked,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: _isCalorieLocked ? context.tr('Kalori (otomatik)') : context.tr('Kalori'),
                              labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold),
                              floatingLabelStyle: const TextStyle(color: Color(0xFFFF9500), fontSize: 13, fontWeight: FontWeight.bold),
                              prefixIcon: const Icon(Icons.local_fire_department_rounded, size: 20, color: Color(0xFFFF9500)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                      _autoCalcCalories();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Macros Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Makro Besinler (g)' : 'Macro Nutrients (g)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputTile(
                            ctrl: _proteinCtrl,
                            label: isTr ? 'Protein' : 'Protein',
                            color: const Color(0xFFFF3B30), // Red
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInputTile(
                            ctrl: _carbCtrl,
                            label: isTr ? 'Karb' : 'Carb',
                            color: const Color(0xFFFF9500), // Orange
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInputTile(
                            ctrl: _fatCtrl,
                            label: isTr ? 'Yağ' : 'Fat',
                            color: const Color(0xFFAF52DE), // Purple
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInputTile(
                            ctrl: _fiberCtrl,
                            label: isTr ? 'Lif' : 'Fiber',
                            color: const Color(0xFF34C759), // Green
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Expandable Micro Nutrients Group Card
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    iconColor: const Color(0xFF007AFF),
                    collapsedIconColor: textSecondary,
                    title: Text(
                      isTr ? 'Tüm Mikro Besin Değerlerini Düzenle' : 'Edit Full Micro Spectrum',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.3),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _rawNutrientGroups.map((group) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: group.$2,
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        group.$1,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: group.$2, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: group.$3.map((item) {
                                    return SizedBox(
                                      width: (MediaQuery.of(context).size.width - 56) / 2,
                                      child: _buildMicroInputTile(item, isDark),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 6),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action Button (Güncelle / Kaydet)
              ElevatedButton.icon(
                onPressed: _saveEntry,
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
                  widget.existingEntry != null ? context.tr('Güncelle') : context.tr('Kaydet'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputTile({
    required TextEditingController ctrl,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
          Text(
            'g',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroInputTile((String, String, String) k, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${k.$2} (${k.$3})',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          TextFormField(
            controller: _microCtrls[k.$1],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
