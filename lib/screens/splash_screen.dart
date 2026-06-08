import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache heavy asset images so they're ready when first shown
    for (final path in const [
      'assets/onboarding/intro.webp',
      'assets/onboarding/suggest.webp',
      'assets/onboarding/premium.webp',
      'assets/profilepic/pp1.webp',
      'assets/profilepic/pp2.webp',
      'assets/profilepic/pp3.webp',
      'assets/icon/icon.webp',
    ]) {
      precacheImage(AssetImage(path), context);
    }
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    bool onboardingDone = false;
    bool isRealUser = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      isRealUser = user != null && !user.isAnonymous;
      
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool('onboarding_done') ?? false;
    } catch (_) {}

    if (!mounted) return;

    if (isRealUser || onboardingDone) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(
            mode: OnboardingMode.fresh,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/icon.webp',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'LensEat',
              style: TextStyle(
                color: const Color(0xFF58A6FF),
                fontSize: 14,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
