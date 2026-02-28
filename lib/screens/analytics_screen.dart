import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Spending Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2B90B6),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          double totalIncome = 0;
          double totalExpense = 0;
          Map<String, double> categoryMap = {};

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            double amount = (data['amount'] ?? 0).toDouble();
            String type = data['type'] ?? 'Expense';
            String category = data['categoryName'] ?? 'Other';

            if (type == 'Income') {
              totalIncome += amount;
            } else {
              totalExpense += amount;
              categoryMap[category] = (categoryMap[category] ?? 0) + amount;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightMessage(totalIncome, totalExpense),
                const SizedBox(height: 20),
                const Text("Expense Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildPieChart(categoryMap),
                const SizedBox(height: 30),
                const Text("Income vs Expense Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildLineChart(totalIncome, totalExpense),
              ],
            ),
          );
        },
      ),
    );
  }

  // 1. SMART MESSAGE DISPLAY
  Widget _buildInsightMessage(double income, double expense) {
    String message;
    Color color;

    if (expense > income && income > 0) {
      message = "Warning: You've spent more than your income this month! Try to cut down unnecessary costs.";
      color = Colors.redAccent;
    } else if (expense > 0 && expense < income * 0.5) {
      message = "Great job! You've saved over 50% of your income. Keep it up!";
      color = Colors.green;
    } else {
      message = "Keep tracking your daily expenses to see your financial health accurately.";
      color = const Color(0xFF2B90B6);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // 2. PIE CHART (Expenses by Category)
  Widget _buildPieChart(Map<String, double> categoryMap) {
    if (categoryMap.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No data for pie chart")));

    List<Color> colors = [Colors.teal, Colors.orange, Colors.red, Colors.blue, Colors.purple];
    int colorIndex = 0;

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: categoryMap.entries.map((entry) {
            final color = colors[colorIndex % colors.length];
            colorIndex++;
            return PieChartSectionData(
              color: color,
              value: entry.value,
              title: '${entry.key}\n${entry.value.toStringAsFixed(0)}',
              radius: 50,
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 3. LINE CHART (Income vs Expense)
  Widget _buildLineChart(double income, double expense) {
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
          lineBarsData: [
            // Income Line (Green)
            LineChartBarData(
              spots: [const FlSpot(0, 0), FlSpot(1, income)],
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: .1)),
            ),
            // Expense Line (Red)
            LineChartBarData(
              spots: [const FlSpot(0, 0), FlSpot(1, expense)],
              isCurved: true,
              color: Colors.red,
              barWidth: 4,
              belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: .1)),
            ),
          ],
        ),
      ),
    );
  }
}