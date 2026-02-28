import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Use a variable to manage the timer so we can cancel it if needed
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  void _navigateToNext() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // A nice fade-in effect for a professional feel
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the timer to prevent memory leaks
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // UPDATED: Using your actual logo from assets
            Image.asset(
              'assets/images/logo.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to Icon if image fails to load
                return const Icon(
                  Icons.account_balance_wallet,
                  size: 100,
                  color: Color(0xFF2B90B6),
                );
              },
            ),
            const SizedBox(height: 24),

            const Text(
              "SMART STUDENT",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B90B6),
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              "BUDGET TRACKER",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 50),

            // Animated Loading Indicator (Lime Green)
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