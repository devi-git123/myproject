import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? initialAmount;
  final String? receiptUrl;


  const AddExpenseScreen({super.key, this.initialAmount, this.receiptUrl});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  late TextEditingController _amountController;
  final TextEditingController _titleController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(text: widget.initialAmount ?? "");
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }


  Future<void> _saveExpense() async {
    if (_amountController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .add({
        'title': _titleController.text.isEmpty ? "Scanned Receipt" : _titleController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'type': 'Expense',
        'category': 'General',
        'receiptUrl': widget.receiptUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense saved successfully!")),
        );

        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Firestore Error: $e");
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color kTealColor = Color(0xFF2B90B6);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify & Save"),
        backgroundColor: kTealColor,
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Confirm the details below:"),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: "Amount (LKR)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.receiptUrl != null)
              const Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.green),
                  SizedBox(width: 10),
                  Text("Receipt image linked successfully", style: TextStyle(color: Colors.green)),
                ],
              ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTealColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveExpense,
                child: const Text("Save Transaction", style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}