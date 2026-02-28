import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTransactionsScreen extends StatelessWidget {
  const MyTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    const Color primaryColor = Color(0xFF2B90B6);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Transactions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No transactions found."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final t = docs[index].data() as Map<String, dynamic>;

              // Extract data safely
              final String category = t['categoryName'] ?? "Unknown";
              final String note = t['note'] ?? "Transaction";
              final double amount = (t['amount'] ?? 0).toDouble();
              final bool isExpense = t['type'] == 'Expense';

              // Timestamp formatting
              final Timestamp? timestamp = t['timestamp'] as Timestamp?;
              String dateDisplay = "No Date";
              String timeDisplay = "";

              if (timestamp != null) {
                DateTime dt = timestamp.toDate();
                dateDisplay = "${dt.day.toString().padLeft(2, '0')}/"
                    "${dt.month.toString().padLeft(2, '0')}/"
                    "${dt.year}";
                timeDisplay =
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
              }

              // Icon fallback for safety
              final int iconCode = t['iconCode'] ?? 58947;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: .1),
                    child: Icon(
                      IconData(iconCode, fontFamily: 'MaterialIcons'),
                      color: primaryColor,
                    ),
                  ),
                  title: Text(
                    note,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category,
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(dateDisplay, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(timeDisplay, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    "${isExpense ? '-' : '+'} LKR ${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                        color: isExpense ? Colors.redAccent : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}