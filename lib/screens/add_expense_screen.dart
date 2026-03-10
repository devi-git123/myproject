import 'package:flutter/material.dart';
import 'upload_receipt_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? initialAmount;

  const AddExpenseScreen({super.key, this.initialAmount});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2B90B6); // Teal color

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Expense"),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "What did you buy?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Amount input with Scan Button
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount",
                prefixText: "LKR ",

                suffixIcon: IconButton(
                  icon: const Icon(Icons.document_scanner, color: primaryColor),
                  onPressed: () async {

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UploadReceiptScreen()),
                    );


                    if (result != null) {
                      setState(() {
                        _amountController.text = result;
                      });
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFADCF35)), // Lime color
                onPressed: () {

                  print("Saving Expense: ${_titleController.text} - ${_amountController.text}");
                  Navigator.pop(context);
                },
                child: const Text("Save Expense", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}