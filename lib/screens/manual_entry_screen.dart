import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../providers/nutrition_provider.dart';

class ManualEntryScreen extends StatefulWidget {
  final String? selectedMeal;

  const ManualEntryScreen({super.key, this.selectedMeal});

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

  File? _selectedImage;
  final _picker = ImagePicker();
  late String _selectedMeal;
  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
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

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      portionSize: portionSize,
      nutritionData: NutritionData(
        calories: factor > 0 ? calories / factor : 0,
        protein: factor > 0 ? protein / factor : 0,
        carbohydrates: factor > 0 ? carbs / factor : 0,
        fat: factor > 0 ? fat / factor : 0,
      ),
      timestamp: DateTime.now(),
      mealType: _selectedMeal,
      imagePath: _selectedImage?.path,
    );

    context.read<NutritionProvider>().addFoodEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.name} eklendi'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuel Giriş'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fotoğraf alanı
              if (_selectedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 180,
                    fit: BoxFit.cover,
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
              const SizedBox(height: 12),

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
              const SizedBox(height: 12),

              // Kalori
              TextFormField(
                controller: _calorieCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              const SizedBox(height: 12),

              // Protein / Karbonhidrat / Yağ
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _carbCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Karb. (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Yağ (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Öğün seçimi
              Text('Öğün', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _meals
                    .map((m) => ChoiceChip(
                          avatar: Icon(m.$2, size: 16),
                          label: Text(m.$3),
                          selected: _selectedMeal == m.$1,
                          onSelected: (_) =>
                              setState(() => _selectedMeal = m.$1),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
