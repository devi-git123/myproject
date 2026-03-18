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
  // Brand Colors
  final Color kTealColor = const Color(0xFF2B90B6); // Expense Mode
  final Color kGreenColor = const Color(0xFF2E7D32); // Income Mode

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessing = false;
  String _selectedType = 'Expense';
  IconData _selectedIcon = Icons.restaurant;

  // Curated list of icons for budget categories
  final List<IconData> _availableIcons = [
    Icons.restaurant, Icons.directions_bus, Icons.shopping_bag, Icons.school,
    Icons.health_and_safety, Icons.home, Icons.movie, Icons.flight,
    Icons.fitness_center, Icons.receipt_long, Icons.pets, Icons.electric_bolt,
    Icons.water_drop, Icons.coffee, Icons.build, Icons.subscriptions,
    Icons.payments, Icons.trending_up, Icons.work, Icons.redeem
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Color get _activeColor => _selectedType == 'Expense' ? kTealColor : kGreenColor;

  /// Saves the category and the initial transaction to Firestore atomically
  Future<void> _saveData() async {
    final String name = _nameController.text.trim();
    final String amountStr = _amountController.text.trim();

    if (name.isEmpty || amountStr.isEmpty) {
      HapticFeedback.vibrate();
      _showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    final double? amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showSnackBar("Please enter a valid amount", isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final batch = FirebaseFirestore.instance.batch();

      // 1. Create Category Reference
      final categoryRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('categories').doc();

      // 2. Create Transaction Reference
      final transactionRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('transactions').doc();

      // 3. Global User Reference (to update total balance)
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      batch.set(categoryRef, {
        'name': name,
        'allocatedAmount': amount,
        'type': _selectedType,
        'iconCode': _selectedIcon.codePoint,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(transactionRef, {
        'title': name,
        'amount': amount,
        'type': _selectedType,
        'category': name,
        'iconCode': _selectedIcon.codePoint,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update total balance: subtract if expense, add if income
      double balanceChange = _selectedType == 'Expense' ? -amount : amount;
      batch.update(userRef, {
        'totalBalance': FieldValue.increment(balanceChange),
      });

      await batch.commit();

      if (mounted) {
        _showSnackBar("Successfully added!");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _activeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Add $_selectedType", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeToggle(),
            const SizedBox(height: 30),
            _sectionLabel("General Info"),
            const SizedBox(height: 12),
            _buildInputContainer(
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Category Name (e.g. Rent, Salary)",
                  prefixIcon: Icon(Icons.label_outline, color: _activeColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInputContainer(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "0.00",
                  prefixText: "LKR ",
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: _activeColor),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _sectionLabel("Visual Representation"),
            const SizedBox(height: 12),
            _buildIconSelectionGrid(),
            const SizedBox(height: 40),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _toggleButton("Expense", kTealColor),
          _toggleButton("Income", kGreenColor),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, Color color) {
    bool isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1));
  }

  Widget _buildIconSelectionGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: _availableIcons.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedIcon == _availableIcons[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = _availableIcons[index]),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? _activeColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _activeColor : Colors.grey[300]!),
              ),
              child: Icon(_availableIcons[index], color: isSelected ? Colors.white : Colors.black45, size: 20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _saveData,
        style: ElevatedButton.styleFrom(
          backgroundColor: _activeColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : Text("Confirm $_selectedType", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}