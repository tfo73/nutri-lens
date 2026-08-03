import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/fasting_provider.dart';
import '../providers/achievement_provider.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/analysis_widgets.dart';
import '../l10n/app_localizations.dart';
import '../models/food_analysis_result.dart';
import '../models/food_entry.dart';
import '../models/food_entry.dart';
import '../models/nutrition_data.dart';
import 'manual_entry_screen.dart';
import 'camera_screen.dart';
import 'barcode_screen.dart';
import 'coach_screen.dart';
import 'dashboard_screen.dart';
import 'fasting_screen.dart';

import 'profile_screen.dart' show ProfileScreen, openNewProfileWizard;
import 'saved_foods_screen.dart';
import 'suggestions_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/saved_foods_service.dart';
import '../widgets/food_analysis_result_sheet.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  late PageController _pageController;
  DateTime _currentDashboardDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _checkOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final profile = context.read<ProfileProvider>();
    if (profile.isProfileComplete) {
      // Profil tamamsa, bekleyen senkronizasyon var mı bak
      SyncService.instance.checkAndSyncPendingOnboarding(profile.activeProfile!);
    }
    // Oruç verilerini buluttan yükle/senkronize et
    try {
      context.read<FastingProvider>().load();
    } catch (_) {}
  }



  void _onTabSelected(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _isMenuOpen = false;
      _currentDashboardDate = DateTime.now();
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutQuint,
    );
  }

  Future<bool> _checkYesterdayLockWarning(BuildContext context, DateTime targetDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (target.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gelecek tarihler için kayıt eklenemez veya değiştirilemez.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (target.isBefore(today)) {
      final dateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(targetDate);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C2128) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Color(0xFFD97706), size: 22),
              SizedBox(width: 8),
              Text('Tarih Değişiklik Onayı', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Değişikliği $dateStr tarihi için yapıyorsunuz. Emin misiniz?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hayır', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    return true;
  }

  void _showAddMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _handleMenuAction(String mode, {String? meal, DateTime? date}) async {
    if (mode == 'saved') {
      setState(() => _isMenuOpen = false);
      _showSavedMealsSheet();
      return;
    }

    final targetDate = date ?? _currentDashboardDate;
    final proceed = await _checkYesterdayLockWarning(context, targetDate);
    if (!proceed) return;

    // Check fasting
    final fasting = context.read<FastingProvider>();
    if (fasting.isFasting) {
      _showFastingWarningAndProceed(mode, meal: meal, date: targetDate);
      return;
    }
    _doMenuAction(mode, meal: meal, date: targetDate);
  }

  Future<void> _showFastingWarningAndProceed(String mode, {String? meal, DateTime? date}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('Oruç Devam Ediyor'), style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          context.tr('Şu an oruç tutuyorsunuz. Yemek eklemek orucu etkileyebilir. Devam etmek istiyor musunuz?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Devam Et')),
          ),
        ],
      ),
    );
    if ((result ?? false) && context.mounted) {
      setState(() => _isMenuOpen = false);
      _doMenuAction(mode, meal: meal, date: date);
    }
  }

  void _doMenuAction(String mode, {String? meal, DateTime? date}) {
    setState(() => _isMenuOpen = false);
    if (mode == 'camera') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => CameraScreen(selectedMeal: meal, date: date)),
      );
    } else if (mode == 'barcode') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => BarcodeScreen(selectedMeal: meal, date: date)),
      );
    } else if (mode == 'manual') {
      showManualEntrySheet(context, selectedMeal: meal ?? 'kahvaltı', date: date);
    } else if (mode == 'voice') {
      showVoiceEntrySheet(context, selectedMeal: meal ?? 'kahvaltı', date: date);
    }
  }

  void _showSavedMealsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedMealsSheet(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final nutritionProvider = context.watch<NutritionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;
    final textTert = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final divider = Theme.of(context).dividerColor;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    final screens = [
      _KeepAlivePage(child: DashboardScreen(
        isCurrentTab: _selectedIndex == 0,
        onMealAddPressed: (meal, mode, date) => _handleMenuAction(mode, meal: meal, date: date),
        onProfileSetupPressed: () => _onTabSelected(2),
        onFastingPressed: () => _onTabSelected(1),
        onCoachPressed: () => _onTabSelected(1),
        onDateChanged: (date) => setState(() => _currentDashboardDate = date),
      )),
      const _KeepAlivePage(child: CoachScreen()),
      const _KeepAlivePage(child: ProfileScreen()),
    ];

    // Listen for background analysis results
    if (!nutritionProvider.isAnalyzing && nutritionProvider.lastResult != null) {
      final result = nutritionProvider.lastResult!;
      final image = nutritionProvider.lastAnalyzedImage;
      final meal = nutritionProvider.lastMealType;
      
      // Sadece ana ekrandaysak (CameraScreen açık değilse) göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _showAnalysisResult(context, result, image, meal);
          nutritionProvider.clearLastResult();
        }
      });
    }

    // Listen for background analysis errors
    if (!nutritionProvider.isAnalyzing && nutritionProvider.analysisError != null) {
      final errorMsg = nutritionProvider.analysisError!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(context.tr('Analiz Hatası')),
              content: Text(errorMsg),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    nutritionProvider.clearAnalysisError();
                  },
                  child: Text(context.tr('Tamam')),
                )
              ],
            ),
          );
        }
      });
    }

    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBody: true,
      drawer: const CoachDrawer(),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _selectedIndex = index;
                _currentDashboardDate = DateTime.now();
              });
            },
            children: screens,
          ),
          // Backdrop for Menu
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: AnimatedOpacity(
                  opacity: _isMenuOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_selectedIndex == 0) ...[
            // Floating Menu Items (positioned above the 68x68 + button)
            Positioned(
              right: 16,
              bottom: 165 + safeAreaBottom,
              child: _FloatingAddMenu(
                isOpen: _isMenuOpen,
                onTap: _handleMenuAction,
              ),
            ),

            // Floating Add (+) Button (Just above Tab Bar, original 68x68 style & colors)
            Positioned(
              right: 16,
              bottom: 85 + safeAreaBottom,
              child: GestureDetector(
                onTap: nutritionProvider.isAnalyzing ? null : _showAddMenu,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                        ? [Colors.white, Colors.grey.shade300] 
                        : [Colors.black, Colors.grey.shade900],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _isMenuOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Arkaplanda analiz statusu
          if (nutritionProvider.isAnalyzing)
            Positioned(
              bottom: 85 + safeAreaBottom,
              left: 16,
              right: 16,
              child: _AnalysisStatusBox(
                image: nutritionProvider.lastAnalyzedImage,
                primaryColor: primary,
                surfaceColor: surface,
                isDark: isDark,
              ),
            ),

          // Achievement unlock overlay
          Consumer<AchievementProvider>(
            builder: (ctx, ach, _) {
              if (ach.newlyEarned.isEmpty) return const SizedBox.shrink();
              final achDef = AchievementProvider.achievements.firstWhere(
                (a) => ach.newlyEarned.contains(a.id),
                orElse: () => AchievementProvider.achievements.first,
              );
              return _AchievementOverlay(
                achievement: achDef,
                onDismiss: () => ach.clearNewlyEarned(),
              );
            },
          ),

        ],
      ),
      bottomNavigationBar: _HigTabBar(
        selectedIndex: _selectedIndex,
        onTap: _onTabSelected,
        isMenuOpen: _isMenuOpen,
        isAnalyzing: nutritionProvider.isAnalyzing,
        surface: surface,
        primary: primary,
        textTert: textTert,
        divider: divider,
        safeAreaBottom: safeAreaBottom,
        isDark: isDark,
      ),
    );
  }

  void _showAnalysisResult(BuildContext context, FoodAnalysisResult result, File? image, String? meal) {
    FoodAnalysisResultSheet.show(
      context,
      result: result,
      image: image,
      mealType: meal,
      onEdit: () async {
        // Convert result to FoodEntry and open ManualEntryScreen
        final nd = result.nutritionPer100g;
        final isTr = context.read<LanguageProvider>().isTurkish;
        final entry = FoodEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: isTr ? result.foodName : (result.foodNameEn ?? result.foodName),
          portionSize: result.portionGrams,
          nutritionData: nd,
          nutrition65per100g: result.nutrition65per100g,
          timestamp: DateTime.now(),
          mealType: meal ?? 'kahvaltı',
          imagePath: image?.path,
        );

        // Close result sheet first
        Navigator.pop(context);

        // Open ManualEntryScreen and wait for result
        final updatedEntry = await Navigator.push<FoodEntry>(
          context,
          MaterialPageRoute(
            builder: (_) => ManualEntryScreen(
              existingEntry: entry,
              selectedMeal: meal ?? 'kahvaltı',
              forceAdd: true,
              showMealSelection: false, // Hide meal selection as requested
            ),
          ),
        );

        if (updatedEntry != null && context.mounted) {
          // Re-show analysis result sheet with updated data
          final updatedResult = result.copyWith(
            foodName: updatedEntry.name,
            portionGrams: updatedEntry.portionSize,
            nutritionPer100g: updatedEntry.nutritionData,
          );
          _showAnalysisResult(context, updatedResult, image, updatedEntry.mealType);
        } else if (context.mounted) {
          // User cancelled edit, re-show original sheet
          _showAnalysisResult(context, result, image, meal);
        }
      },
      onConfirm: (entry) {
        context.read<NutritionProvider>().addFoodEntry(entry, date: _currentDashboardDate);
        Navigator.pop(context);
      },
    );
  }
}

class _FloatingAddMenu extends StatefulWidget {
  final bool isOpen;
  final Function(String) onTap;

  const _FloatingAddMenu({required this.isOpen, required this.onTap});

  @override
  State<_FloatingAddMenu> createState() => _FloatingAddMenuState();
}

class _FloatingAddMenuState extends State<_FloatingAddMenu> {
  bool _hasSavedFoods = false;

  @override
  void initState() {
    super.initState();
    _checkSavedFoods();
  }

  @override
  void didUpdateWidget(_FloatingAddMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _checkSavedFoods();
    }
  }

  Future<void> _checkSavedFoods() async {
    final list = await SavedFoodsService.load();
    if (mounted) {
      setState(() {
        _hasSavedFoods = list.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildMenuItem(
          context,
          index: 4,
          icon: _hasSavedFoods ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: context.tr('Kaydedilen Yemekler'),
          description: context.tr('Favori öğünlerini hızlıca ekle'),
          color: Colors.redAccent,
          onTap: () => widget.onTap('saved'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 3,
          icon: Icons.qr_code_scanner_rounded,
          label: context.tr('Barkoddan Analiz'),
          description: context.tr('Paketli gıdaları tara'),
          color: Colors.orange,
          onTap: () => widget.onTap('barcode'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 2,
          icon: Icons.edit_note_rounded,
          label: context.tr('Manuel Analiz'),
          description: context.tr('Besin değerlerini elle gir'),
          color: Colors.green,
          onTap: () => widget.onTap('manual'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 1,
          icon: Icons.mic_rounded,
          label: context.tr('Tarif Ederek Analiz'),
          description: context.tr('Tarif ederek veya yazarak ekle'),
          color: Colors.purple,
          onTap: () => widget.onTap('voice'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 0,
          icon: Icons.camera_alt_rounded,
          label: context.tr('Görselden Analiz'),
          description: context.tr('Fotoğrafını çekerek ekle'),
          color: Colors.blue,
          onTap: () => widget.onTap('camera'),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSub = isDark ? Colors.white70 : Colors.black54;
    
    const duration = Duration(milliseconds: 300);
    
    return AnimatedSlide(
      offset: widget.isOpen ? Offset.zero : const Offset(0, 0.5),
      duration: duration,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: widget.isOpen ? 1 : 0,
        duration: duration,
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !widget.isOpen,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D333B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 9,
                                color: textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }
}

class _HigTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isMenuOpen;
  final bool isAnalyzing;
  final Color surface;
  final Color primary;
  final Color textTert;
  final Color divider;
  final double safeAreaBottom;
  final bool isDark;

  const _HigTabBar({
    required this.selectedIndex,
    required this.onTap,
    required this.isMenuOpen,
    required this.isAnalyzing,
    required this.surface,
    required this.primary,
    required this.textTert,
    required this.divider,
    required this.safeAreaBottom,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> labels = [
      context.tr('Ana Menü'),
      context.tr('Dijital İkiz'),
      context.tr('Profil'),
    ];
    final List<IconData> iconsOutlined = [
      Icons.dashboard_outlined,
      Icons.psychology_outlined,
      Icons.person_outline_rounded,
    ];
    final List<IconData> iconsFilled = [
      Icons.dashboard_rounded,
      Icons.psychology_rounded,
      Icons.person_rounded,
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        margin: EdgeInsets.fromLTRB(16, 0, 16, math.max(8, safeAreaBottom)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2128).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTab(0, labels[0], iconsOutlined[0], iconsFilled[0]),
            _buildTab(1, labels[1], iconsOutlined[1], iconsFilled[1]),
            _buildTab(2, labels[2], iconsOutlined[2], iconsFilled[2]),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData outlined, IconData filled) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? primary : textTert;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? filled : outlined,
              color: color,
              size: 24,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisStatusBox extends StatefulWidget {
  final File? image;
  final Color primaryColor;
  final Color surfaceColor;
  final bool isDark;

  const _AnalysisStatusBox({
    this.image,
    required this.primaryColor,
    required this.surfaceColor,
    required this.isDark,
  });

  @override
  State<_AnalysisStatusBox> createState() => _AnalysisStatusBoxState();
}

class _AnalysisStatusBoxState extends State<_AnalysisStatusBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showFullProgress(BuildContext context) {
    Navigator.of(context).push(
      slidePageRoute((context) => _FullProgressPage(image: widget.image)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isDark ? const Color(0xFF1C2128) : const Color(0xFFF0F0F0);
    final highlight = widget.isDark ? const Color(0xFF2D333B) : const Color(0xFFFFFFFF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          height: 70,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1C2128) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: BorderTracePainter(
                      progress: _ctrl.value,
                      color: widget.primaryColor.withValues(alpha: 0.9),
                      borderRadius: 14,
                      strokeWidth: 4.0,
                    ),
                    size: Size(constraints.maxWidth, 70),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (widget.image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          widget.image!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.fastfood, size: 22, color: widget.primaryColor),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔄 ${context.tr('Yemek analizi yapılıyor...')}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('Lütfen bekleyin, sonuçlar yakında hazır olacak.'),
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoachFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CoachFloatingButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(3.14159), // 180 degrees in radians
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 4),
            Text(
              context.tr('Dijital İkiz'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMealsSheet extends StatefulWidget {
  @override
  State<_SavedMealsSheet> createState() => _SavedMealsSheetState();
}

class _SavedMealsSheetState extends State<_SavedMealsSheet> {
  List<SavedFood> _savedFoods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final list = await SavedFoodsService.load();
    if (mounted) {
      setState(() {
        _savedFoods = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('Kaydedilen Yemekler'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Favori öğünlerini hızlıca ekle'),
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedFoods.isEmpty
                    ? _buildEmpty(context, cs)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _savedFoods.length,
                        itemBuilder: (context, i) {
                          final food = _savedFoods[i];
                          final meal = FoodEntry(
                            id: food.id,
                            name: food.name,
                            portionSize: food.portionGrams,
                            portionUnit: 'g',
                            nutritionData: food.nutritionScaled,
                            timestamp: food.savedAt,
                            mealType: 'kahvaltı', // fallback
                            imagePath: food.imagePath,
                            imageUrl: food.imageUrl,
                          );
                          return _SavedMealItem(
                            meal: meal,
                            onDeleted: () async {
                              await SavedFoodsService.remove(food.id);
                              _loadFoods();
                            },
                          );
                        },
                      ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 48, color: cs.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            context.tr('Henüz kaydedilmiş yemek yok'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              context.tr('Yemek detaylarından favorilere ekleyerek burada görebilirsiniz.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMealItem extends StatelessWidget {
  final FoodEntry meal;
  final VoidCallback onDeleted;
  const _SavedMealItem({required this.meal, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final itemBg = isDark
        ? const Color(0xFF21262D).withValues(alpha: 0.6)
        : const Color(0xFFF6F8FA);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: meal.imagePath != null && File(meal.imagePath!).existsSync()
                  ? Image.file(File(meal.imagePath!), fit: BoxFit.cover)
                  : (meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: meal.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: cs.primary.withValues(alpha: 0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            child: Icon(Icons.restaurant_rounded, color: cs.primary.withValues(alpha: 0.3)),
                          ),
                        )
                      : Container(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          child: Icon(Icons.restaurant_rounded, color: cs.primary.withValues(alpha: 0.3)),
                        )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(meal.nutritionData.scaleBy(meal.portionSize / 100).calories).toStringAsFixed(0)} kcal · ${meal.portionSize.toStringAsFixed(0)}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDeleted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showMealPicker(context, meal),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.add_rounded, size: 20, color: cs.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMealPicker(BuildContext context, FoodEntry meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedMealPicker(meal: meal),
    );
  }
}

class _SavedMealPicker extends StatelessWidget {
  final FoodEntry meal;
  const _SavedMealPicker({required this.meal});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final nutrition = context.read<NutritionProvider>();

    final meals = [
      ('kahvaltı', Icons.wb_sunny_outlined, context.tr('Kahvaltı')),
      ('öğle', Icons.wb_cloudy_outlined, context.tr('Öğle')),
      ('akşam', Icons.nights_stay_outlined, context.tr('Akşam')),
      ('ara öğün', Icons.coffee_outlined, context.tr('Ara Öğün')),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Hangi öğüne eklensin?'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: meals.map((m) {
              return GestureDetector(
                onTap: () {
                  final entry = meal.copyWith(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    mealType: m.$1,
                    timestamp: DateTime.now(),
                  );
                  nutrition.addFoodEntry(entry);
                  Navigator.pop(context); // Close picker
                  Navigator.pop(context); // Close saved meals sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${meal.name} ${context.tr('eklendi')}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(m.$2, color: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m.$3,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FullProgressPage extends StatelessWidget {
  final File? image;
  const _FullProgressPage({this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnalysisProgressView(
        image: image,
        onBack: () => Navigator.pop(context),
      ),
    );
  }
}

class _AchievementOverlay extends StatefulWidget {
  final AchievementDef achievement;
  final VoidCallback onDismiss;
  const _AchievementOverlay({required this.achievement, required this.onDismiss});

  @override
  State<_AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<_AchievementOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: GestureDetector(
          onTap: () {
            _ctrl.reverse().then((_) {
              if (mounted) widget.onDismiss();
            });
          },
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('Yeni Rozet Kazandın!'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.achievement.emoji,
                          style: const TextStyle(fontSize: 56),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(widget.achievement.name),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(widget.achievement.description),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Devam et!'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
