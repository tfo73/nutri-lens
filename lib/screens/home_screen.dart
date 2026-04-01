import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_widgets.dart';
import 'camera_screen.dart';
import 'coach_screen.dart';
import 'dashboard_screen.dart';
import 'monthly_program_screen.dart';
import 'profile_screen.dart' show ProfileScreen, openNewProfileWizard;
import 'suggestions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _selectedMeal;

  late final AnimationController _fabCtrl;
  late final Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut),
    );
    // Slight delay so FAB pops in after page loads
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fabCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  void _navigateToCamera({String? meal}) {
    setState(() {
      _selectedMeal = meal;
      _selectedIndex = 1;
    });
  }

  void _openProfileWizard() {
    setState(() => _selectedIndex = 4);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openNewProfileWizard(context);
    });
  }

  void _openCoach() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'coach',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.90,
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: const CoachScreen(isDialog: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProfileProvider>();
    context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: _AnimatedTabStack(
        selectedIndex: _selectedIndex,
        reduceMotion: reduceMotion,
        children: [
          DashboardScreen(
            onMealAddPressed: (meal) => _navigateToCamera(meal: meal),
            onProfileSetupPressed: _openProfileWizard,
          ),
          CameraScreen(
            key: ValueKey(_selectedMeal),
            selectedMeal: _selectedMeal,
            onFoodAdded: () => setState(() {
              _selectedIndex = 0;
              _selectedMeal = null;
            }),
          ),
          const MonthlyProgramScreen(),
          const SuggestionsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: AnimatedPressButton(
          scaleTo: 0.88,
          onPressed: _openCoach,
          child: FloatingActionButton(
            onPressed: null, // handled by AnimatedPressButton
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            tooltip: l10n.tr('Beslenme Koçu'),
            child: const Icon(Icons.psychology),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 1) _selectedMeal = null;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.tr('Özet'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.camera_alt_outlined),
            selectedIcon: const Icon(Icons.camera_alt),
            label: l10n.tr('Fotoğraf'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.tr('Program'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.lightbulb_outlined),
            selectedIcon: const Icon(Icons.lightbulb),
            label: l10n.tr('Öneriler'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tr('Profil'),
          ),
        ],
      ),
    );
  }
}

/// Preserves all tab states (like IndexedStack) but fades between tabs.
class _AnimatedTabStack extends StatelessWidget {
  final int selectedIndex;
  final List<Widget> children;
  final bool reduceMotion;

  const _AnimatedTabStack({
    required this.selectedIndex,
    required this.children,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (i) {
        final isActive = i == selectedIndex;
        return AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !isActive,
            child: children[i],
          ),
        );
      }),
    );
  }
}
