import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class SelectCurrencyScreen extends StatefulWidget {
  const SelectCurrencyScreen({super.key});

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  // Brand Colors to match your Login/Signup
  static const Color kTealColor = Color(0xFF2B90B6);

  // Default selection
  String _selectedCurrency = "LKR - Sri Lankan Rupee";

  final List<String> _currencies = [
    "USD - US Dollar",
    "LKR - Sri Lankan Rupee",
    "EUR - Euro",
    "INR - Indian Rupee",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Base Currency", style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // Top Icon/Illustration
              Image.asset(
                'assets/images/currency.png',
                height: 100,
              ),

              const SizedBox(height: 15),
              const Text(
                "Select your primary currency",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A535C),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "This will be used for all your budget tracking and reports.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),

              const SizedBox(height: 30),

              // Currency List Selection
              Expanded(
                child: ListView.builder(
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final currency = _currencies[index];
                    final isSelected = _selectedCurrency == currency;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? kTealColor.withValues(alpha: .05) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? kTealColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Text(
                          currency,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? kTealColor : Colors.black87,
                          ),
                        ),
                        value: currency,
                        groupValue: _selectedCurrency,
                        activeColor: kTealColor,
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() => _selectedCurrency = value);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // Use pushAndRemoveUntil to prevent user from going back to onboarding/login
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text(
                    "Confirm Selection",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
}

