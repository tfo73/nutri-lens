import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringsCtrl;
  late final AnimationController _textCtrl;

  late final Animation<double> _outerRingScale;
  late final Animation<double> _midRingScale;
  late final Animation<double> _innerRingScale;

  late final Animation<double> _nlFade;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();

    _ringsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Rings scale from 1.5 → 1.0, staggered outer→inner
    _outerRingScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringsCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _midRingScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringsCtrl,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _innerRingScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringsCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Logo scale 0.0 → 1.0, subtitle fade in
    _nlFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _ringsCtrl.forward().then((_) {
      if (mounted) _textCtrl.forward();
    });

    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ringsCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2E1A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_ringsCtrl, _textCtrl]),
        builder: (context, _) {
          return Stack(
            children: [
              // 4-directional dot & line details
              ..._buildDirectionalDetails(),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring: #2E7D32
                          Transform.scale(
                            scale: _outerRingScale.value,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF2E7D32),
                                  width: 8,
                                ),
                              ),
                            ),
                          ),
                          // Inner ring: #4CAF50
                          Transform.scale(
                            scale: _midRingScale.value,
                            child: Container(
                              width: 148,
                              height: 148,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF4CAF50),
                                  width: 6,
                                ),
                              ),
                            ),
                          ),
                          // Innermost circle background
                          Transform.scale(
                            scale: _innerRingScale.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1A2E1A),
                              ),
                            ),
                          ),
                          // Logo icon scale 0.0 → 1.0
                          Transform.scale(
                            scale: _nlFade.value.clamp(0.0, 1.0),
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Image.asset(
                                'assets/icon/icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // "NutriLens" subtitle
                    Opacity(
                      opacity: _subtitleFade.value.clamp(0.0, 1.0),
                      child: const Text(
                        'NutriLens',
                        style: TextStyle(
                          color: Color(0xFFA5D6A7),
                          fontSize: 14,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDirectionalDetails() {
    const dotColor = Color(0xFFA5D6A7);
    const lineColor = Color(0xFFA5D6A7);
    const lineOpacity = 0.35;
    const dotOpacity = 0.5;

    return [
      // Top
      Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Column(
          children: [
            Opacity(
              opacity: dotOpacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: lineOpacity,
              child: Container(
                width: 1,
                height: 40,
                color: lineColor,
              ),
            ),
          ],
        ),
      ),
      // Bottom
      Positioned(
        bottom: 80,
        left: 0,
        right: 0,
        child: Column(
          children: [
            Opacity(
              opacity: lineOpacity,
              child: Container(
                width: 1,
                height: 40,
                color: lineColor,
              ),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: dotOpacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ),
          ],
        ),
      ),
      // Left
      Positioned(
        left: 48,
        top: 0,
        bottom: 0,
        child: Row(
          children: [
            Opacity(
              opacity: dotOpacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Opacity(
              opacity: lineOpacity,
              child: Container(
                width: 40,
                height: 1,
                color: lineColor,
              ),
            ),
          ],
        ),
      ),
      // Right
      Positioned(
        right: 48,
        top: 0,
        bottom: 0,
        child: Row(
          children: [
            Opacity(
              opacity: lineOpacity,
              child: Container(
                width: 40,
                height: 1,
                color: lineColor,
              ),
            ),
            const SizedBox(width: 4),
            Opacity(
              opacity: dotOpacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
