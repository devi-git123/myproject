import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Required for saving state


class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  // --- Logic to save first-time state ---
  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false); // Mark onboarding as seen

    if (!context.mounted) return;

    // Use pushReplacementNamed to go to login so the user can't "Go Back" to onboarding
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    const Color kTealColor = Color(0xFF2B90B6);
    const Color kLimeColor = Color(0xFFADCF35);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Image Section
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.teal.withValues(alpha: .1),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      "assets/images/onboarding.png",
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Headline & Description
              const Text(
                "Track Your Daily\nExpenses Easily",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kTealColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Manage your student budget, save money, and reach your financial goals with ease.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const Spacer(),

              // Progress Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(isActive: true, color: kLimeColor),
                  _buildDot(isActive: false, color: Colors.grey.shade300),
                  _buildDot(isActive: false, color: Colors.grey.shade300),
                ],
              ),
              const SizedBox(height: 40),

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLimeColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                  onPressed: () => _completeOnboarding(context), // Logic call
                  child: const Text(
                      "Next",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold
                      )
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot({required bool isActive, required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}