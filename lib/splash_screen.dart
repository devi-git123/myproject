import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circle icon — just the graphic part, no text inside image
            Image.asset(
              'assets/images/logo_icon.png',
              width: screenWidth * 0.55,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.account_balance_wallet,
                size: screenWidth * 0.3,
                color: const Color(0xFF1A6B8A),
              ),
            ),

            const SizedBox(height: 20),

            // "SMART STUDENT" — bold dark teal matching the logo font
            const Text(
              'SMART STUDENT',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A5276),
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 4),

            // "BUDGET TRACKER" — lighter, smaller, spaced
            const Text(
              'BUDGET TRACKER',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B90B6),
                letterSpacing: 5,
              ),
            ),

            const SizedBox(height: 60),

            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFADCF35)),
            ),
          ],
        ),
      ),
    );
  }
}