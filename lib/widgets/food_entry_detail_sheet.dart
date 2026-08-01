import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import '../models/nutrition_data_65.dart';
import '../providers/nutrition_provider.dart';
import '../providers/language_provider.dart';
import '../screens/manual_entry_screen.dart';

class FoodEntryDetailSheet extends StatefulWidget {
  final FoodEntry entry;
  final DateTime? date;

  const FoodEntryDetailSheet({
    super.key,
    required this.entry,
    this.date,
  });

  static Future<T?> show<T>(BuildContext context, {required FoodEntry entry, DateTime? date}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => FoodEntryDetailSheet(entry: entry, date: date),
    );
  }

  @override
  State<FoodEntryDetailSheet> createState() => _FoodEntryDetailSheetState();
}

class _FoodEntryDetailSheetState extends State<FoodEntryDetailSheet> {
  late FoodEntry _currentEntry;
  List<String> _starredKeys = [];
  bool _showAllMicros = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _loadStarredKeys();
  }

  Future<void> _loadStarredKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _starredKeys = prefs.getStringList('starred_micro_keys') ?? [];
    });
  }

  String? _successBanner;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  void _handleEdit() async {
    final result = await Navigator.push<FoodEntry>(
      context,
      PageRouteBuilder<FoodEntry>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => ManualEntryScreen(
          existingEntry: _currentEntry,
          date: widget.date,
          showMealSelection: true,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.08),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      final isTr = context.read<LanguageProvider>().isTurkish;
      setState(() {
        _currentEntry = result;
        _successBanner = isTr ? '${result.name} güncellendi' : '${result.name} updated';
      });
      _loadStarredKeys();

      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successBanner = null;
          });
        }
      });
    }
  }

  void _confirmDelete() {
    final isTr = context.read<LanguageProvider>().isTurkish;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isTr ? 'Yemeği Sil' : 'Delete Food'),
        content: Text(
          isTr
              ? '${_currentEntry.name} öğününüzden silinecek. Emin misiniz?'
              : 'Are you sure you want to delete ${_currentEntry.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTr ? 'Vazgeç' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NutritionProvider>().removeFoodEntry(_currentEntry.id, date: widget.date);
              Navigator.pop(context);
            },
            child: Text(
              isTr ? 'Sil' : 'Delete',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenImage(String path) {
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
                  child: Image.file(File(path), fit: BoxFit.contain),
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

  IconData _getMealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'kahvaltı':
        return Icons.wb_sunny_rounded;
      case 'öğle yemeği':
      case 'öğle':
        return Icons.wb_twilight_rounded;
      case 'akşam yemeği':
      case 'akşam':
        return Icons.nights_stay_rounded;
      case 'ara öğün':
      case 'kahvaltı sonrası ara öğün':
      case 'öğle sonrası ara öğün':
        return Icons.bakery_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  String _formatMealType(String raw, bool isTr) {
    switch (raw.toLowerCase()) {
      case 'kahvaltı':
        return isTr ? 'Kahvaltı' : 'Breakfast';
      case 'kahvaltı sonrası ara öğün':
        return isTr ? 'Kahvaltı Sonrası Ara Öğün' : 'Morning Snack';
      case 'öğle yemeği':
      case 'öğle':
        return isTr ? 'Öğle Yemeği' : 'Lunch';
      case 'öğle sonrası ara öğün':
        return isTr ? 'Öğle Sonrası Ara Öğün' : 'Afternoon Snack';
      case 'akşam yemeği':
      case 'akşam':
        return isTr ? 'Akşam Yemeği' : 'Dinner';
      case 'ara öğün':
        return isTr ? 'Ara Öğün' : 'Snack';
      case 'gece atıştırmalığı':
        return isTr ? 'Gece Atıştırmalığı' : 'Night Snack';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = context.watch<LanguageProvider>().isTurkish;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final innerBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF8E8E93);

    final hasImage = _currentEntry.imagePath != null &&
        _currentEntry.imagePath!.isNotEmpty &&
        File(_currentEntry.imagePath!).existsSync();

    final nutrition = _currentEntry.nutritionData.scaleBy(_currentEntry.portionSize / 100);
    final n65 = _currentEntry.nutrition65per100g?.scaleBy(_currentEntry.portionSize / 100) ??
        _currentEntry.nutritionData.to65().scaleBy(_currentEntry.portionSize / 100);

    final time = _currentEntry.timestamp;
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark ? const Color(0xFF121212).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.96),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Top Drag Handle & Apple Bar
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Success Toast Banner (when updated)
                  if (_successBanner != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF34C759), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successBanner!,
                                  style: const TextStyle(
                                    color: Color(0xFF34C759),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Header Photo / Hero Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Stack(
                        children: [
                          if (hasImage)
                            GestureDetector(
                              onTap: () => _openFullscreenImage(_currentEntry.imagePath!),
                              child: Container(
                                height: 210,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        File(_currentEntry.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPlaceholderBanner(isDark, cardBg),
                                      ),
                                      Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text('Büyüt', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            _buildPlaceholderBanner(isDark, cardBg),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // Title & Eye-friendly Calorie Badge
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentEntry.name,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    if (_currentEntry.brand != null && _currentEntry.brand!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          _currentEntry.brand!,
                                          style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Eye-friendly Muted Calorie Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      nutrition.calories.round().toString(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD97706),
                                      ),
                                    ),
                                    Text(
                                      'kcal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Badges Row (Meal Type, Portion, Time) with Dark/Solid Background
                          Row(
                            children: [
                              _buildPillBadge(
                                icon: _getMealIcon(_currentEntry.mealType),
                                label: _formatMealType(_currentEntry.mealType, isTr),
                                color: const Color(0xFF007AFF),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPillBadge(
                                icon: Icons.scale_rounded,
                                label: '${_currentEntry.portionSize.round()} ${_currentEntry.portionUnit}',
                                color: const Color(0xFF34C759),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPillBadge(
                                icon: Icons.access_time_rounded,
                                label: timeStr,
                                color: const Color(0xFFAF52DE),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 22)),

                  // Macro Nutrient Summary (Protein, Carbs, Fat, Fiber) with Proportional Progress Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTr ? 'Makro Besin Özeti' : 'Macro Nutrient Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildMacroCard(
                                    title: isTr ? 'Protein' : 'Protein',
                                    amount: '${nutrition.protein.toStringAsFixed(1)}g',
                                    color: const Color(0xFF30B0C7),
                                    icon: Icons.fitness_center_rounded,
                                    bgColor: innerBg,
                                    textPrimary: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMacroCard(
                                    title: isTr ? 'Karbonhidrat' : 'Carbs',
                                    amount: '${nutrition.carbohydrates.toStringAsFixed(1)}g',
                                    color: const Color(0xFFFFCC00),
                                    icon: Icons.grain_rounded,
                                    bgColor: innerBg,
                                    textPrimary: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMacroCard(
                                    title: isTr ? 'Yağ' : 'Fat',
                                    amount: '${nutrition.fat.toStringAsFixed(1)}g',
                                    color: const Color(0xFFFF2D55),
                                    icon: Icons.water_drop_rounded,
                                    bgColor: innerBg,
                                    textPrimary: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMacroCard(
                                    title: isTr ? 'Lif' : 'Fiber',
                                    amount: '${nutrition.fiber.toStringAsFixed(1)}g',
                                    color: const Color(0xFF34C759),
                                    icon: Icons.grass_rounded,
                                    bgColor: innerBg,
                                    textPrimary: textPrimary,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Multi-segment Proportional Progress Bar
                            _buildMacroProgressBar(nutrition, isDark),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Starred Nutrients Box (Strictly in original user-starred order)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _buildStarredNutrientsBox(isTr, isDark, textPrimary, nutrition, n65),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Expandable Micro Spectrum (Show top by default, button for full list)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTr ? 'Mikro Besin Değerleri' : 'Micro Nutrients',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Minerals
                            _buildNutrientCategory(
                              title: isTr ? 'MİNERALLER' : 'MINERALS',
                              items: [
                                ('Kalsiyum', '${n65.calcium.toStringAsFixed(0)} mg'),
                                ('Demir', '${n65.iron.toStringAsFixed(1)} mg'),
                                ('Magnezyum', '${n65.magnesium.toStringAsFixed(0)} mg'),
                                ('Potasyum', '${n65.potassium.toStringAsFixed(0)} mg'),
                                ('Sodyum', '${n65.sodium.toStringAsFixed(0)} mg'),
                                ('Çinko', '${n65.zinc.toStringAsFixed(1)} mg'),
                                ('Fosfor', '${n65.phosphorus.toStringAsFixed(0)} mg'),
                                ('Bakır', '${n65.copper.toStringAsFixed(2)} mg'),
                                ('Manganez', '${n65.manganese.toStringAsFixed(2)} mg'),
                                ('Selenyum', '${n65.selenium.toStringAsFixed(1)} mcg'),
                              ],
                              isDark: isDark,
                              textPrimary: textPrimary,
                            ),

                            // Vitamins
                            _buildNutrientCategory(
                              title: isTr ? 'VİTAMİNLER' : 'VITAMINS',
                              items: [
                                ('C Vitamini', '${n65.vitC.toStringAsFixed(1)} mg'),
                                ('D Vitamini', '${n65.vitD_mcg.toStringAsFixed(1)} mcg'),
                                ('E Vitamini', '${n65.vitE.toStringAsFixed(1)} mg'),
                                ('A Vitamini', '${n65.vitA_RAE.toStringAsFixed(0)} mcg'),
                                ('B12 Vitamini', '${n65.vitB12.toStringAsFixed(2)} mcg'),
                                ('B6 Vitamini', '${n65.vitB6.toStringAsFixed(2)} mg'),
                                ('Folat (B9)', '${n65.folate.toStringAsFixed(0)} mcg'),
                                ('B1 (Tiamin)', '${n65.thiamine.toStringAsFixed(2)} mg'),
                                ('B2 (Riboflavin)', '${n65.riboflavin.toStringAsFixed(2)} mg'),
                                ('B3 (Niasin)', '${n65.niacin.toStringAsFixed(2)} mg'),
                                ('B5 (Pantotenik)', '${n65.pantothenic.toStringAsFixed(2)} mg'),
                                ('Biotin', '${n65.biotin.toStringAsFixed(1)} mcg'),
                                ('Kolin', '${n65.choline.toStringAsFixed(0)} mg'),
                              ],
                              isDark: isDark,
                              textPrimary: textPrimary,
                            ),

                            // Additional Categories shown when _showAllMicros is true
                            if (_showAllMicros) ...[
                              _buildNutrientCategory(
                                title: isTr ? 'YAĞ ASİTLERİ & LİPİTLER' : 'FATTY ACIDS & LIPIDS',
                                items: [
                                  ('Omega-3', '${n65.omega3.toStringAsFixed(2)} g'),
                                  ('Omega-6', '${n65.omega6.toStringAsFixed(2)} g'),
                                  ('Tekli Doymamış Yağ', '${n65.monoFat.toStringAsFixed(1)} g'),
                                  ('Çoklu Doymamış Yağ', '${n65.polyFat.toStringAsFixed(1)} g'),
                                  ('Kolesterol', '${n65.cholesterol.toStringAsFixed(0)} mg'),
                                ],
                                isDark: isDark,
                                textPrimary: textPrimary,
                              ),

                              _buildNutrientCategory(
                                title: isTr ? 'TEMEL AMİNO ASİTLER' : 'ESSENTIAL AMINO ACIDS',
                                items: [
                                  ('Lizin', '${n65.lysine.toStringAsFixed(2)} g'),
                                  ('Lösin', '${n65.leucine.toStringAsFixed(2)} g'),
                                  ('Valin', '${n65.valine.toStringAsFixed(2)} g'),
                                  ('İzolösin', '${n65.isoleucine.toStringAsFixed(2)} g'),
                                  ('Treonin', '${n65.threonine.toStringAsFixed(2)} g'),
                                  ('Metionin', '${n65.methionine.toStringAsFixed(2)} g'),
                                ],
                                isDark: isDark,
                                textPrimary: textPrimary,
                              ),
                            ],

                            const SizedBox(height: 8),

                            // Expand / Collapse Toggle Button
                            Center(
                              child: TextButton.icon(
                                onPressed: () => setState(() => _showAllMicros = !_showAllMicros),
                                icon: Icon(
                                  _showAllMicros ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  _showAllMicros
                                      ? (isTr ? 'Daha Az Göster' : 'Show Less')
                                      : (isTr ? 'Daha Fazlasını Göster' : 'Show More'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Action Buttons (Edit & Delete)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleEdit,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: isDark ? Colors.white38 : Colors.black26),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(
                                isTr ? 'Düzenle' : 'Edit',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _confirmDelete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.12),
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: Text(
                                isTr ? 'Yemeği Sil' : 'Delete',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroProgressBar(NutritionData n, bool isDark) {
    final p = n.protein > 0 ? n.protein : 0.0;
    final c = n.carbohydrates > 0 ? n.carbohydrates : 0.0;
    final f = n.fat > 0 ? n.fat : 0.0;
    final fib = n.fiber > 0 ? n.fiber : 0.0;
    final total = p + c + f + fib;

    if (total <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 6,
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        child: Row(
          children: [
            if (p > 0) Expanded(flex: (p * 100).round(), child: Container(color: const Color(0xFF30B0C7))),
            if (c > 0) Expanded(flex: (c * 100).round(), child: Container(color: const Color(0xFFFFCC00))),
            if (f > 0) Expanded(flex: (f * 100).round(), child: Container(color: const Color(0xFFFF2D55))),
            if (fib > 0) Expanded(flex: (fib * 100).round(), child: Container(color: const Color(0xFF34C759))),
          ],
        ),
      ),
    );
  }

  Widget _buildStarredNutrientsBox(bool isTr, bool isDark, Color textPrimary, NutritionData nutrition, NutritionData65? n65) {
    final Map<String, (String, double, String)> rawDict = {};

    void add(List<String> keys, String name, double val, String unit) {
      for (final k in keys) {
        rawDict[k.toLowerCase().trim()] = (name, val, unit);
      }
    }

    final n = nutrition;
    final n6 = n65 ?? n.to65();

    add(['c_vitamini', 'vit_c', 'vitc', 'c vitamini', 'c vitamin', 'c-vit'], 'C Vitamini', n6.vitC, 'mg');
    add(['d_vitamini', 'vit_d_mcg', 'vit_d', 'vitd', 'd vitamini', 'd vitamin', 'd-vit'], 'D Vitamini', n6.vitD_mcg, 'mcg');
    add(['e_vitamini', 'vit_e', 'vite', 'e vitamini', 'e vitamin', 'e-vit'], 'E Vitamini', n6.vitE, 'mg');
    add(['a_vitamini', 'vit_a_rae', 'vit_a', 'vita', 'a vitamini', 'a vitamin', 'a-vit'], 'A Vitamini', n6.vitA_RAE, 'mcg');
    add(['b12_vitamini', 'vit_b12', 'vitb12', 'b12 vitamini', 'b12 vitamin', 'b12'], 'B12 Vitamini', n6.vitB12, 'mcg');
    add(['b6_vitamini', 'vit_b6', 'vitb6', 'b6 vitamini', 'b6 vitamin', 'b6'], 'B6 Vitamini', n6.vitB6, 'mg');
    add(['folat', 'folate', 'folat (b9)', 'b9', 'b9 (folat)'], 'Folat (B9)', n6.folate, 'mcg');
    add(['kalsiyum', 'calcium', 'kalsiyum (ca)', 'ca'], 'Kalsiyum', n6.calcium, 'mg');
    add(['demir', 'iron', 'demir (fe)', 'fe'], 'Demir', n6.iron, 'mg');
    add(['magnezyum', 'magnesium', 'magnezyum (mg)', 'mg'], 'Magnezyum', n6.magnesium, 'mg');
    add(['potasyum', 'potassium', 'potasyum (k)', 'k+', 'k'], 'Potasyum', n6.potassium, 'mg');
    add(['sodyum', 'sodium', 'sodyum (na)', 'na'], 'Sodyum', n6.sodium, 'mg');
    add(['çinko', 'cinko', 'zinc', 'çinko (zn)', 'zn'], 'Çinko', n6.zinc, 'mg');
    add(['fosfor', 'phosphorus', 'fosfor (p)', 'p'], 'Fosfor', n6.phosphorus, 'mg');
    add(['bakır', 'bakir', 'copper', 'bakır (cu)', 'cu'], 'Bakır', n6.copper, 'mg');
    add(['manganez', 'manganese', 'manganez (mn)', 'mn'], 'Manganez', n6.manganese, 'mg');
    add(['selenyum', 'selenium', 'selenyum (se)', 'se'], 'Selenyum', n6.selenium, 'mcg');
    add(['thiamine', 'b1 (tiamin)', 'b1', 'tiamin'], 'B1 (Tiamin)', n6.thiamine, 'mg');
    add(['riboflavin', 'b2 (riboflavin)', 'b2'], 'B2 (Riboflavin)', n6.riboflavin, 'mg');
    add(['niacin', 'b3 (niasin)', 'b3', 'niasin'], 'B3 (Niasin)', n6.niacin, 'mg');
    add(['pantothenic', 'b5 (pantotenik)', 'b5'], 'B5 (Pantotenik)', n6.pantothenic, 'mg');
    add(['biotin', 'b7', 'b7 (biyotin)', 'biotin (b7)'], 'Biotin', n6.biotin, 'mcg');
    add(['choline', 'kolin'], 'Kolin', n6.choline, 'mg');
    add(['omega3', 'omega-3', 'omg3'], 'Omega-3', n6.omega3, 'g');
    add(['omega6', 'omega-6', 'omg6'], 'Omega-6', n6.omega6, 'g');
    add(['ala'], 'ALA', n6.ala, 'g');
    add(['epa'], 'EPA', n6.epa, 'g');
    add(['dha'], 'DHA', n6.dha, 'g');
    add(['kolesterol', 'chol', 'cholesterol'], 'Kolesterol', n6.cholesterol, 'mg');
    add(['doymuş yağ', 'doymus yag', 'sat', 'sat_fat', 'satfat'], 'Doymuş Yağ', n.saturatedFat, 'g');
    add(['tekli doymamış', 'mono', 'mono_fat'], 'Tekli Doymamış Yağ', n6.monoFat, 'g');
    add(['çoklu doymamış', 'poly', 'poly_fat'], 'Çoklu Doymamış Yağ', n6.polyFat, 'g');
    add(['trans yağ', 'trns', 'trans_fat'], 'Trans Yağ', n6.transFat, 'g');
    add(['beta-karoten', 'bcar', 'beta_carot'], 'Beta-Karoten', n6.betaCarot, 'mcg');
    add(['likopen', 'lyc', 'lycopene'], 'Likopen', n6.lycopene, 'mcg');
    add(['lutein-zea', 'lut', 'lutein & zeaksantin', 'lutein_zea'], 'Lutein & Zeaksantin', n6.luteinZea, 'mcg');
    add(['alfa-karoten', 'acar', 'alpha_carot'], 'Alfa-Karoten', n6.alphaCarot, 'mcg');
    add(['lösin', 'losin', 'leu', 'leucine'], 'Lösin', n6.leucine, 'g');
    add(['lizin', 'lys', 'lysine'], 'Lizin', n6.lysine, 'g');
    add(['izolösin', 'izolosin', 'ile', 'isoleucine'], 'İzolösin', n6.isoleucine, 'g');
    add(['valin', 'val', 'valine'], 'Valin', n6.valine, 'g');
    add(['treonin', 'thr', 'threonine'], 'Treonin', n6.threonine, 'g');
    add(['metiyonin', 'metionin', 'met', 'methionine'], 'Metiyonin', n6.methionine, 'g');
    add(['fenilalanin', 'phe', 'phenylalanine'], 'Fenilalanin', n6.phenylalanine, 'g');
    add(['triptofan', 'trp', 'tryptophan'], 'Triptofan', n6.tryptophan, 'g');
    add(['sistin', 'cystine'], 'Sistin', n6.cystine, 'g');
    add(['tirozin', 'tyrosine'], 'Tirozin', n6.tyrosine, 'g');
    add(['histidin', 'histidine'], 'Histidin', n6.histidine, 'g');
    add(['lif', 'fiber'], 'Lif', n.fiber, 'g');
    add(['seker', 'şeker', 'sugar'], 'Şeker', n.sugar, 'g');

    final List<(String, String, String)> starredItems = [];

    for (final rawKey in _starredKeys) {
      final k = rawKey.toLowerCase().trim();
      if (rawDict.containsKey(k)) {
        final item = rawDict[k]!;
        final val = item.$2;
        if (val > 0) {
          final str = val < 1
              ? val.toStringAsFixed(2)
              : (val >= 100 ? val.toStringAsFixed(0) : val.toStringAsFixed(1));
          starredItems.add((item.$1, str, item.$3));
        }
      }
    }

    if (starredItems.isEmpty) {
      return Column(
        children: [
          _buildListRow(
            title: isTr ? 'Şeker' : 'Sugar',
            value: '${nutrition.sugar.toStringAsFixed(1)} g',
            textPrimary: textPrimary,
          ),
          _buildDivider(isDark),
          _buildListRow(
            title: isTr ? 'Doymuş Yağ' : 'Saturated Fat',
            value: '${nutrition.saturatedFat.toStringAsFixed(1)} g',
            textPrimary: textPrimary,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                isTr ? 'Yıldızlanan Besin Ögeleri' : 'Starred Nutrients',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.amber),
              ),
            ],
          ),
        ),
        Column(
          children: starredItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == starredItems.length - 1;
            return Column(
              children: [
                _buildListRow(
                  title: item.$1,
                  value: '${item.$2} ${item.$3}',
                  textPrimary: textPrimary,
                ),
                if (!isLast) _buildDivider(isDark),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlaceholderBanner(bool isDark, Color cardBg) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E2638), const Color(0xFF111827)]
              : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : const Color(0xFF0284C7)).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getMealIcon(_currentEntry.mealType),
                size: 40,
                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
    required Color bgColor,
    required Color textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientCategory({
    required String title,
    required List<(String, String)> items,
    required bool isDark,
    required Color textPrimary,
  }) {
    final validItems = items.where((i) => !i.$2.startsWith('0')).toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...validItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == validItems.length - 1;
          return Column(
            children: [
              _buildListRow(
                title: item.$1,
                value: item.$2,
                textPrimary: textPrimary,
              ),
              if (!isLast) _buildDivider(isDark),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildListRow({
    required String title,
    required String value,
    required Color textPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}
