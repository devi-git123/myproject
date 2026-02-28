import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  // Colors for different types
  final Color kExpenseColor = const Color(0xFF2B90B6); // Original Teal
  final Color kIncomeColor = const Color(0xFF2E7D32);  // Green

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessing = false;
  String _selectedType = 'Expense'; // Default type
  IconData _selectedIcon = Icons.restaurant;

  final List<IconData> _availableIcons = [
    Icons.restaurant, Icons.directions_bus, Icons.shopping_bag, Icons.school,
    Icons.health_and_safety, Icons.home, Icons.movie, Icons.flight,
    Icons.fitness_center, Icons.receipt_long, Icons.pets, Icons.electric_bolt,
    Icons.water_drop, Icons.coffee, Icons.build, Icons.subscriptions,
    Icons.payments, Icons.trending_up, Icons.work, Icons.redeem // Added income-friendly icons
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Get current theme color based on selection
  Color get _currentColor => _selectedType == 'Expense' ? kExpenseColor : kIncomeColor;

  Future<void> _saveCategory() async {
    final String name = _nameController.text.trim();
    final String amountStr = _amountController.text.trim();

    if (name.isEmpty || amountStr.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final double amount = double.tryParse(amountStr) ?? 0.0;
      final int iconCode = _selectedIcon.codePoint;

      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference categoryRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('categories').doc();

      DocumentReference transactionRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('transactions').doc();

      batch.set(categoryRef, {
        'name': name,
        'amount': amount,
        'type': _selectedType, // Saved type here
        'iconCode': iconCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(transactionRef, {
        'categoryName': name,
        'amount': amount,
        'type': _selectedType, // Saved type here
        'iconCode': iconCode,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.commit().catchError((error) => debugPrint("Sync failed: $error"));

      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Create $_selectedType", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _currentColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NEW: TYPE TOGGLE ---
            _buildTypeToggle(),
            const SizedBox(height: 25),

            _buildLabel("Category Name"),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputStyle("e.g. ${_selectedType == 'Expense' ? 'Groceries' : 'Salary'}", Icons.edit_note),
            ),
            const SizedBox(height: 25),

            _buildLabel("Select Icon"),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  bool isSelected = _selectedIcon == _availableIcons[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIcon = _availableIcons[index]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected ? _currentColor : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: isSelected ? [BoxShadow(color: _currentColor.withValues(alpha: .3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                      ),
                      child: Icon(
                        _availableIcons[index],
                        color: isSelected ? Colors.white : Colors.black45,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            _buildLabel("Initial Amount"),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputStyle("0.00", Icons.account_balance_wallet_outlined).copyWith(
                prefixText: "LKR ",
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Create $_selectedType", style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _typeButton("Expense"),
          _typeButton("Income"),
        ],
      ),
    );
  }

  Widget _typeButton(String type) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _selectedType = type);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? (type == 'Expense' ? kExpenseColor : kIncomeColor) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Text(
            type,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
    );
  }

  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _currentColor, size: 22),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}