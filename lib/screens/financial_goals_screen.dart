import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FinancialGoalsScreen extends StatelessWidget {
  const FinancialGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    const Color kTealColor = Color(0xFF2B90B6);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financial Goals", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kTealColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('goals')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No goals set yet. Tap + to start!"));
          }

          final goals = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            // FIXED: Used .length instead of .size
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index].data() as Map<String, dynamic>;
              double target = (goal['targetAmount'] ?? 1).toDouble();
              double saved = (goal['savedAmount'] ?? 0).toDouble();
              double progress = (saved / target).clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goal['title'] ?? "Goal",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: progress,
                      // FIXED: Used .withValues instead of .withOpacity
                      backgroundColor: kTealColor.withValues(alpha: 0.1),
                      color: kTealColor,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "LKR ${saved.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.w600, color: kTealColor),
                        ),
                        Text(
                          "Target: LKR ${target.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTealColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddGoalDialog(context, uid),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, String? uid) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    const Color kTealColor = Color(0xFF2B90B6);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("New Financial Goal", style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Goal Name (e.g., New Car)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Target Amount (LKR)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('goals')
                    .add({
                  'title': titleController.text,
                  'targetAmount': double.parse(amountController.text),
                  'savedAmount': 0.0, // Starting at 0
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Add Goal", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
