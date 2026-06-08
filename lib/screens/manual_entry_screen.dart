import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import '../providers/nutrition_provider.dart';

class ManualEntryScreen extends StatefulWidget {
  final String? selectedMeal;
  final FoodEntry? existingEntry;
  final bool forceAdd;
  final DateTime? date;
  final bool showMealSelection;

  const ManualEntryScreen({
    super.key,
    this.selectedMeal,
    this.existingEntry,
    this.forceAdd = false,
    this.date,
    this.showMealSelection = true,
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

  File? _selectedImage;
  String? _networkImageUrl;
  final _picker = ImagePicker();
  late String _selectedMeal;
  bool _isSaving = false;
  bool _showMore = false;
  bool _isCalorieManuallyEdited = false;

  final Map<String, TextEditingController> _microCtrls = {};
  
  // Groups for UI rendering with section headers
  static const _nutrientGroups = <(String, List<(String, String, String)>)>[
    ('MİNERALLER', [
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
    ('VİTAMİNLER', [
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
    ('KAROTENOİDLER', [
      ('beta_carot',  'Beta-Karoten',       'mcg'),
      ('lycopene',    'Likopen',            'mcg'),
      ('lutein_zea',  'Lutein+Zeaksantin',  'mcg'),
      ('alpha_carot', 'Alfa-Karoten',       'mcg'),
    ]),
    ('YAĞ ASİTLERİ', [
      ('mono_fat',   'Tekli Doymamış Yağ', 'g'),
      ('poly_fat',   'Çoklu Doymamış Yağ', 'g'),
      ('trans_fat',  'Trans Yağ',           'g'),
      ('cholesterol','Kolesterol',          'mg'),
      ('omega3',     'Omega-3 (toplam)',    'g'),
      ('omega6',     'Omega-6 (toplam)',    'g'),
      ('ala',        'ALA',                 'g'),
      ('epa',        'EPA',                 'g'),
      ('dha',        'DHA',                 'g'),
      ('linoleic',   'Linoleik',            'g'),
    ]),
    ('AMİNO ASİTLER', [
      ('leucine',       'Lösin',       'g'),
      ('lysine',        'Lizin',       'g'),
      ('isoleucine',    'İzolösin',    'g'),
      ('valine',        'Valin',       'g'),
      ('threonine',     'Treonin',     'g'),
      ('methionine',    'Metionin',    'g'),
      ('phenylalanine', 'Fenilalanin', 'g'),
      ('tryptophan',    'Triptofan',   'g'),
      ('histidine',     'Histidin',    'g'),
      ('cystine',       'Sistein',     'g'),
      ('tyrosine',      'Tirozin',     'g'),
    ]),
  ];

  // Flat list derived from groups — used by initState and _buildNutrition65
  static final _nutrientKeys = [
    for (final g in _nutrientGroups) ...g.$2,
  ];

  static const _meals = <(String, IconData, String)>[
    ('kahvaltı', Icons.wb_sunny_outlined, 'Kahvaltı'),
    ('öğle', Icons.wb_cloudy_outlined, 'Öğle'),
    ('akşam', Icons.nights_stay_outlined, 'Akşam'),
    ('ara öğün', Icons.coffee_outlined, 'Ara Öğün'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.selectedMeal ?? 'kahvaltı';

    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _nameCtrl.text = e.name;
      _portionCtrl.text = e.portionSize.toStringAsFixed(1);
      _selectedMeal = e.mealType ?? _selectedMeal;
      
      // Nutrition values in FoodEntry are per portionSize, but form expects values for that portion
      // Actually ManualEntryScreen's _save logic divides input values by (portionSize/100) to get per 100g.
      // So here we should provide the values for the portion size.
      final factor = e.portionSize / 100;
      _calorieCtrl.text = (e.nutritionData.calories * factor).toStringAsFixed(1);
      _proteinCtrl.text = (e.nutritionData.protein * factor).toStringAsFixed(1);
      _carbCtrl.text = (e.nutritionData.carbohydrates * factor).toStringAsFixed(1);
      _fatCtrl.text = (e.nutritionData.fat * factor).toStringAsFixed(1);
      _fiberCtrl.text = (e.nutritionData.fiber.toStringAsFixed(1));

      if (e.imagePath != null && e.imagePath!.isNotEmpty) {
        _selectedImage = File(e.imagePath!);
      } else if (e.imageUrl != null && e.imageUrl!.isNotEmpty) {
        _networkImageUrl = e.imageUrl;
      }

      // Initialize micro controls
      final n65 = e.nutrition65per100g ?? e.nutritionData.to65();
      if (n65 != null) {
        final factor = e.portionSize / 100;
        final json = n65.toJson();
        for (var k in _nutrientKeys) {
          final val = (json[k.$1] as num? ?? 0.0).toDouble() * factor;
          _microCtrls[k.$1] = TextEditingController(text: val > 0 ? val.toStringAsFixed(2) : '0');
        }
      }
    }

    // Ensure all controllers exist
    for (var k in _nutrientKeys) {
      _microCtrls.putIfAbsent(k.$1, () => TextEditingController(text: '0'));
    }

    _proteinCtrl.addListener(_autoCalcCalories);
    _carbCtrl.addListener(_autoCalcCalories);
    _fatCtrl.addListener(_autoCalcCalories);
    _fiberCtrl.addListener(_autoCalcCalories);
    
    // Detect manual calorie edits
    _calorieCtrl.addListener(() {
      if (_calorieCtrl.text.isNotEmpty && FocusScope.of(context).focusedChild == null) {
        // This is tricky in Flutter to detect if text change came from user or code.
        // Usually, checking if the field has focus is a good indicator.
      }
    });
  }

  void _autoCalcCalories() {
    if (_isCalorieManuallyEdited) return;
    
    final p = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final c = double.tryParse(_carbCtrl.text) ?? 0.0;
    final f = double.tryParse(_fatCtrl.text) ?? 0.0;
    final fi = double.tryParse(_fiberCtrl.text) ?? 0.0;
    
    final total = (p * 4) + (c * 4) + (f * 9) + (fi * 2);
    if (total > 0) {
      _calorieCtrl.text = total.toStringAsFixed(0);
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
    for (var c in _microCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

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
      nutritionData: NutritionData(
        calories: factor > 0 ? calories / factor : 0,
        protein: factor > 0 ? protein / factor : 0,
        carbohydrates: factor > 0 ? carbs / factor : 0,
        fat: factor > 0 ? fat / factor : 0,
        fiber: factor > 0 ? fiber / factor : 0,
      ),
      timestamp: widget.existingEntry?.timestamp ?? DateTime.now(),
      mealType: _selectedMeal,
      imagePath: _selectedImage?.path,
      // Keep existing extra data if editing
      imageUrl: widget.existingEntry?.imageUrl,
      portionUnit: widget.existingEntry?.portionUnit ?? 'g',
      nutrition65per100g: _buildNutrition65(factor),
    );

    if (widget.existingEntry != null && !widget.showMealSelection) {
      // If we're editing from analysis result and meal selection is hidden, 
      // just return the entry instead of saving.
      Navigator.pop(context, entry);
      return;
    }

    final provider = context.read<NutritionProvider>();
    final isUpdate = widget.existingEntry != null && !widget.forceAdd;
    if (isUpdate) {
      provider.updateFoodEntry(entry, date: widget.date);
    } else {
      provider.addFoodEntry(entry, date: widget.date);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isUpdate ? '${entry.name} güncellendi' : '${entry.name} eklendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yemeği Sil', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${widget.existingEntry!.name} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<NutritionProvider>().removeFoodEntry(
      widget.existingEntry!.id,
      date: widget.date,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  NutritionData65? _buildNutrition65(double factor) {
    if (factor <= 0) return null;
    
    // Map existing or default N65
    final base = widget.existingEntry?.nutrition65per100g ?? const NutritionData65(energy: 0, protein: 0, fat: 0, carb: 0);
    final json = base.toJson();
    
    // Update from controllers (scaled back to 100g)
    for (var k in _nutrientKeys) {
      final val = double.tryParse(_microCtrls[k.$1]!.text) ?? 0.0;
      json[k.$1] = val / factor;
    }
    
    // Update main macros too (scaled back to 100g)
    json['energy'] = (double.tryParse(_calorieCtrl.text) ?? 0.0) / factor;
    json['protein'] = (double.tryParse(_proteinCtrl.text) ?? 0.0) / factor;
    json['carb'] = (double.tryParse(_carbCtrl.text) ?? 0.0) / factor;
    json['fat'] = (double.tryParse(_fatCtrl.text) ?? 0.0) / factor;
    json['fiber'] = (double.tryParse(_fiberCtrl.text) ?? 0.0) / factor;

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

  Widget _buildMicroInput((String, String, String) k) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: TextFormField(
        controller: _microCtrls[k.$1],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${k.$2} (${k.$3})',
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Yemeği Düzenle' : 'Manuel Giriş'),
        centerTitle: true,
        actions: widget.existingEntry != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Sil',
                  onPressed: _confirmDelete,
                ),
              ]
            : const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fotoğraf alanı
              if (_selectedImage != null || _networkImageUrl != null) ...[
                GestureDetector(
                  onTap: _showEnlargedImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: _networkImageUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_selectedImage != null
                    ? 'Fotoğrafı Değiştir'
                    : 'Fotoğraf Ekle (İsteğe Bağlı)'),
              ),
              const SizedBox(height: 20),

              // Yiyecek adı
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Yiyecek Adı *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Yiyecek adı gerekli' : null,
              ),
              const SizedBox(height: 16),

              // Kalori (Yemek adının altında, bütün satırı kaplar)
              TextFormField(
                controller: _calorieCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () {
                  // If user taps/edits, stop auto-calculation
                  _isCalorieManuallyEdited = true;
                },
                onChanged: (v) {
                   _isCalorieManuallyEdited = true;
                },
                decoration: const InputDecoration(
                  labelText: 'Kalori (kcal) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Kalori gerekli';
                  if (double.tryParse(v) == null) return 'Geçerli sayı girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Porsiyon
              TextFormField(
                controller: _portionCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Porsiyon Miktarı (g) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Porsiyon gerekli';
                  if (double.tryParse(v) == null) return 'Geçerli sayı girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Makro Alanları (Grid)
              // Üst Satır: Protein / Karbonhidrat
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Karb. (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Alt Satır: Yağ / Lif
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Yağ (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fiberCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Lif (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daha Fazla (Mikro Besinler) - Collapsible
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text('Mikro Besinler (Daha Fazla)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final group in _nutrientGroups) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                              child: Row(
                                children: [
                                  Container(width: 3, height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
                                  const SizedBox(width: 6),
                                  Text(group.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                            for (int i = 0; i < group.$2.length; i += 2)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: _buildMicroInput(group.$2[i])),
                                    if (i + 1 < group.$2.length) ...[
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildMicroInput(group.$2[i + 1])),
                                    ] else
                                      const Expanded(child: SizedBox.shrink()),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (widget.showMealSelection) ...[
                // Öğün seçimi
                Text('Öğün', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _meals.map((m) {
                    final isSelected = _selectedMeal == m.$1;
                    return ChoiceChip(
                      label: Text(m.$3, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedMeal = m.$1),
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      showCheckmark: true,
                      side: BorderSide(
                        color: isSelected 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) 
                          : Colors.transparent,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(widget.existingEntry != null ? 'Güncelle' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

