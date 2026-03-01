import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';

class SelectCurrencyScreen extends StatefulWidget {
  const SelectCurrencyScreen({super.key});

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  static const Color kTealColor = Color(0xFF2B90B6);

  bool _isSaving = false;
  String _selectedCurrency = "LKR - Sri Lankan Rupee";

  final List<Map<String, String>> _currencies = [
    {"code": "LKR", "name": "Sri Lankan Rupee", "symbol": "Rs"},
    {"code": "USD", "name": "US Dollar", "symbol": "\$"},
    {"code": "EUR", "name": "Euro", "symbol": "€"},
    {"code": "INR", "name": "Indian Rupee", "symbol": "₹"},
    {"code": "GBP", "name": "British Pound", "symbol": "£"},
  ];

  Future<void> _saveCurrencyAndFinish() async {
    // Prevent multiple clicks
    if (_isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User session not found. Please log in again.");

      // Find the selected currency object
      final selectedData = _currencies.firstWhere(
              (c) => "${c['code']} - ${c['name']}" == _selectedCurrency
      );

      // --- IMMEDIATE NAVIGATION FIX ---
      // We trigger the Firestore write but DON'T 'await' the server response.
      // This saves to the local cache immediately so the user doesn't wait for the internet.
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'currencyCode': selectedData['code'],
        'currencySymbol': selectedData['symbol'],
        'setupComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Give it a tiny moment to ensure the local write instruction is registered
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Force navigation to Dashboard immediately
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Action failed: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            children: [
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: kTealColor.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/Currency.png', // Ensure this matches your file case exactly
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.payments_rounded, size: 50, color: kTealColor),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),
              const Text(
                "Pick Your Currency",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A535C)),
              ),
              const SizedBox(height: 8),
              const Text(
                "All your transactions and reports will be shown in this currency.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),

              const SizedBox(height: 25),

              Expanded(
                child: ListView.builder(
                  itemCount: _currencies.length,
                  itemBuilder: (context, index) {
                    final currency = _currencies[index];
                    final String displayString = "${currency['code']} - ${currency['name']}";
                    final isSelected = _selectedCurrency == displayString;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCurrency = displayString),
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? kTealColor.withValues(alpha: .08) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected ? kTealColor : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: RadioListTile<String>(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            title: Text(
                              displayString,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? kTealColor : Colors.black87,
                              ),
                            ),
                            secondary: Text(
                              currency['symbol']!,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? kTealColor : Colors.grey
                              ),
                            ),
                            value: displayString,
                            groupValue: _selectedCurrency,
                            activeColor: kTealColor,
                            onChanged: (val) => setState(() => _selectedCurrency = val!),
                          ),
                        ),
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
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveCurrencyAndFinish,
                  child: _isSaving
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    "Confirm & Get Started",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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