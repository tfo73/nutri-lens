import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _screens = [
      _KeepAlivePage(child: DashboardScreen(
        onMealAddPressed: (meal, mode) => _handleMenuAction(mode, meal: meal),
        onProfileSetupPressed: () => _onTabSelected(3),
        onFastingPressed: () => _onTabSelected(1),
      )),
      const _KeepAlivePage(child: FastingScreen()),
      _KeepAlivePage(child: SuggestionsScreen(
        onNavigateBack: () => _onTabSelected(1),
        onNavigateForward: () => _onTabSelected(3),
      )),
      const _KeepAlivePage(child: ProfileScreen()),
    ];
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
  }

  void _onTabSelected(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _isMenuOpen = false;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutQuint,
    );
  }

  void _showAddMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _handleMenuAction(String mode, {String? meal}) {
    if (mode == 'saved') {
      setState(() => _isMenuOpen = false);
      _showSavedMealsSheet();
      return;
    }
    // Check fasting
    final fasting = context.read<FastingProvider>();
    if (fasting.isFasting) {
      _showFastingWarningAndProceed(mode, meal: meal);
      return;
    }
    _doMenuAction(mode, meal: meal);
  }

  Future<void> _showFastingWarningAndProceed(String mode, {String? meal}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oruç Devam Ediyor', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Şu an oruç tutuyorsunuz. Yemek eklemek orucu etkileyebilir. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
    if ((result ?? false) && context.mounted) {
      setState(() => _isMenuOpen = false);
      _doMenuAction(mode, meal: meal);
    }
  }

  void _doMenuAction(String mode, {String? meal}) {
    setState(() => _isMenuOpen = false);
    if (mode == 'camera') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => CameraScreen(selectedMeal: meal)),
      );
    } else if (mode == 'barcode') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const BarcodeScreen()),
      );
    } else if (mode == 'manual') {
      showManualEntrySheet(context, selectedMeal: meal ?? 'kahvaltı');
    } else if (mode == 'voice') {
      showVoiceEntrySheet(context, selectedMeal: meal ?? 'kahvaltı');
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


    // Listen for background analysis results
    if (!nutritionProvider.isAnalyzing && nutritionProvider.lastResult != null) {
      final result = nutritionProvider.lastResult!;
      final image = nutritionProvider.lastAnalyzedImage;
      final meal = nutritionProvider.lastMealType;
      
      // Sadece ana ekrandaysak (CameraScreen açık değilse) göster
      // Not: Bu basit bir kontrol, daha sağlamı ModalRoute.of(context).isCurrent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _showAnalysisResult(context, result, image, meal);
        }
        nutritionProvider.clearLastResult();
      });
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          PageView(
            controller: _pageController,
            physics: (_isMenuOpen || _selectedIndex == 2) ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (index) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                _selectedIndex = index;
              });
            },
            children: _screens,
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

          // Floating Menu Items
          Positioned(
            right: 16,
            bottom: 85 + safeAreaBottom,
            child: _FloatingAddMenu(
              isOpen: _isMenuOpen,
              onTap: _handleMenuAction,
            ),
          ),

          // Arkaplanda analiz statusu (Tab barın hemen üstünde)
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
        onAddPressed: _showAddMenu,
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
        final entry = FoodEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.foodName,
          portionSize: result.portionGrams,
          nutritionData: NutritionData(
            calories: nd.calories,
            protein: nd.protein,
            carbohydrates: nd.carbohydrates,
            fat: nd.fat,
            fiber: nd.fiber,
            sugar: nd.sugar,
            saturatedFat: nd.saturatedFat,
            sodium: nd.sodium,
          ),
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
        context.read<NutritionProvider>().addFoodEntry(entry);
        Navigator.pop(context);
      },
    );
  }
}

class _FloatingAddMenu extends StatelessWidget {
  final bool isOpen;
  final Function(String) onTap;

  const _FloatingAddMenu({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final hasFavorites = nutrition.savedMeals.isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildMenuItem(
          context,
          index: 4,
          icon: hasFavorites ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: 'Kaydedilen Yemekler',
          description: 'Favori öğünlerini hızlıca ekle',
          color: Colors.redAccent,
          onTap: () => onTap('saved'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 3,
          icon: Icons.qr_code_scanner_rounded,
          label: 'Barkoddan Analiz',
          description: 'Paketli gıdaları tara',
          color: Colors.orange,
          onTap: () => onTap('barcode'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 2,
          icon: Icons.edit_note_rounded,
          label: 'Manuel Analiz',
          description: 'Besin değerlerini elle gir',
          color: Colors.green,
          onTap: () => onTap('manual'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 1,
          icon: Icons.mic_rounded,
          label: 'Anlatarak Analiz',
          description: 'Sesinle veya yazarak ekle',
          color: Colors.purple,
          onTap: () => onTap('voice'),
        ),
        const SizedBox(height: 10),
        _buildMenuItem(
          context,
          index: 0,
          icon: Icons.camera_alt_rounded,
          label: 'Görselden Analiz',
          description: 'Fotoğrafını çekerek ekle',
          color: Colors.blue,
          onTap: () => onTap('camera'),
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
      offset: isOpen ? Offset.zero : const Offset(0, 0.5),
      duration: duration,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: isOpen ? 1 : 0,
        duration: duration,
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !isOpen,
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
  final VoidCallback onAddPressed;
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
    required this.onAddPressed,
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
    final List<String> labels = ['Özet', 'Oruç', 'Öneriler', 'Profil'];
    final List<IconData> iconsOutlined = [
      Icons.dashboard_outlined,
      Icons.timer_outlined,
      Icons.lightbulb_outlined,
      Icons.person_outline,
    ];
    final List<IconData> iconsFilled = [
      Icons.dashboard,
      Icons.timer,
      Icons.lightbulb,
      Icons.person,
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Ana Sekmeler: Özet, Öneriler, Profil
            Expanded(
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2128).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16), // Daha az yuvarlak kenarlar
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
                    _buildTab(3, labels[3], iconsOutlined[3], iconsFilled[3]),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // "+" Butonu (Ayrı yuvarlak bar)
            GestureDetector(
              onTap: isAnalyzing ? null : onAddPressed,
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
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _buildAddButton(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData outlined, IconData filled) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? filled : outlined, color: isSelected ? primary : textTert, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isSelected ? primary : textTert, fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return AnimatedOpacity(
      opacity: isAnalyzing ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: 52,
        height: 52,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            isMenuOpen ? Icons.close_rounded : Icons.add_rounded,
            key: ValueKey(isMenuOpen),
            color: isDark ? Colors.black : Colors.white,
            size: 30,
          ),
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
                            '🔄 Yemek analizi yapılıyor...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lütfen bekleyin, sonuçlar yakında hazır olacak.',
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
            const Text(
              'Beslenme Koçu',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMealsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final savedMeals = nutrition.savedMeals;

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
          const Text(
            'Kaydedilen Yemekler',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Favori öğünlerini hızlıca ekle',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: savedMeals.isEmpty
                ? _buildEmpty(cs)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: savedMeals.length,
                    itemBuilder: (context, i) {
                      final meal = savedMeals[i];
                      return _SavedMealItem(meal: meal);
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 48, color: cs.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'Henüz kaydedilmiş yemek yok',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Yemek detaylarından favorilere ekleyerek burada görebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMealItem extends StatelessWidget {
  final FoodEntry meal;
  const _SavedMealItem({required this.meal});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final nutrition = context.read<NutritionProvider>();

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
                  : Container(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      child: Icon(Icons.restaurant_rounded, color: cs.primary.withValues(alpha: 0.3)),
                    ),
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
                onPressed: () => nutrition.removeSavedMeal(meal.id),
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
      ('kahvaltı', Icons.wb_sunny_outlined, 'Kahvaltı'),
      ('öğle', Icons.wb_cloudy_outlined, 'Öğle'),
      ('akşam', Icons.nights_stay_outlined, 'Akşam'),
      ('ara öğün', Icons.coffee_outlined, 'Ara Öğün'),
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
          const Text(
            'Hangi öğüne eklensin?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      content: Text('${meal.name} eklendi'),
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
                          'Yeni Rozet Kazandın!',
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
                          widget.achievement.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.achievement.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Devam et!',
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
