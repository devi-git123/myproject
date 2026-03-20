import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTransactionsScreen extends StatelessWidget {
  final String? filterCategory;
  
  const MyTransactionsScreen({super.key, this.filterCategory});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    const Color primaryColor = Color(0xFF2B90B6);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          filterCategory == null ? "My Transactions" : "$filterCategory Transactions",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          // Get user's currency symbol (default to "LKR" if not set)
          String currencySymbol = "LKR";
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            currencySymbol = userData?['currencySymbol'] ?? userData?['currencyCode'] ?? "LKR";
          }

          return StreamBuilder<QuerySnapshot>(
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

          // Filter by category if specified
          final allDocs = snapshot.data!.docs;
          final docs = filterCategory == null
              ? allDocs
              : allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['category'] == filterCategory;
                }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No transactions in $filterCategory",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final t = docs[index].data() as Map<String, dynamic>;

              // Extract data safely
              final String type = t['type'] ?? "Transaction";
              final String category = t['category'] ?? "General";
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
                    type,
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
                    "${isExpense ? '-' : '+'} $currencySymbol ${amount.toStringAsFixed(2)}",
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
      );
        },
      ),
    );
  }
}