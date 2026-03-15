import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FinancialGoalsScreen extends StatefulWidget {
  const FinancialGoalsScreen({super.key});

  @override
  State<FinancialGoalsScreen> createState() => _FinancialGoalsScreenState();
}

class _FinancialGoalsScreenState extends State<FinancialGoalsScreen> {
  static const Color kTealColor = Color(0xFF2B90B6);

  // Track whether a dialog is currently open so we can pause stream rebuilds
  bool _dialogOpen = false;
  List<QueryDocumentSnapshot>? _cachedGoals;

  Future<void> _withDialog(Future<void> Function() fn) async {
    setState(() => _dialogOpen = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financial Goals", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kTealColor,
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
                .collection('goals')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _cachedGoals == null) {
                return const Center(child: CircularProgressIndicator());
              }

              // Only update cache when no dialog is open — prevents mid-dialog rebuilds
          if (!_dialogOpen && snapshot.hasData) {
            _cachedGoals = snapshot.data!.docs;
          }

          final goals = _cachedGoals ?? [];

          if (goals.isEmpty) {
            return const Center(child: Text("No goals set yet. Tap + to start!"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
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
                        Expanded(
                          child: Text(
                            goal['title'] ?? "Goal",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              color: Colors.grey[600],
                              onPressed: () => _withDialog(() => _showEditGoalDialog(uid, goals[index].id, goal)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              color: Colors.redAccent,
                              onPressed: () => _withDialog(() => _showDeleteConfirmation(uid, goals[index].id, goal['title'])),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: kTealColor.withValues(alpha: 0.1),
                      color: progress >= 1.0 ? Colors.green : kTealColor,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    if (progress >= 1.0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 5),
                            Text(
                              "Goal Completed! 🎉",
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$currencySymbol ${saved.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.w600, color: kTealColor),
                        ),
                        Text(
                          "Target: $currencySymbol ${target.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTealColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Money"),
                        onPressed: () => _withDialog(() => _showAddMoneyDialog(uid, goals[index].id, goal, currencySymbol)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTealColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _withDialog(() => _showAddGoalDialog(uid)),
      ),
    );
  }

  Future<void> _showAddGoalDialog(String? uid) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    // Fetch user's currency
    String currencySymbol = "LKR";
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>?;
        currencySymbol = userData?['currencySymbol'] ?? userData?['currencyCode'] ?? "LKR";
      }
    } catch (e) {
      debugPrint('Error fetching currency: $e');
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("New Financial Goal",
            style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
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
              decoration: InputDecoration(labelText: "Target Amount ($currencySymbol)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
                  'savedAmount': 0.0,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: const Text("Add Goal", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMoneyDialog(String? uid, String goalId, Map<String, dynamic> goal, String currencySymbol) async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add Money to Goal",
                style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Goal: ${goal['title']}",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text("Current: $currencySymbol ${(goal['savedAmount'] ?? 0).toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Amount to Add ($currencySymbol)",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTealColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (amountController.text.isEmpty) return;
                        setDialogState(() => isSaving = true);

                        final double addAmount = double.parse(amountController.text);
                        final double currentSaved = (goal['savedAmount'] ?? 0).toDouble();
                        final double targetAmount = (goal['targetAmount'] ?? 0).toDouble();
                        final double newSaved = currentSaved + addAmount;
                        final bool goalJustCompleted =
                            currentSaved < targetAmount && newSaved >= targetAmount;

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('goals')
                            .doc(goalId)
                            .update({'savedAmount': newSaved});

                        // Create notification when goal is completed
                        if (goalJustCompleted) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('notifications')
                                .add({
                              'title': '🎉 Goal Completed!',
                              'message': 'Congratulations! You achieved your "${goal['title']}" goal of $currencySymbol ${targetAmount.toStringAsFixed(0)}!',
                              'type': 'success',
                              'timestamp': FieldValue.serverTimestamp(),
                              'read': false,
                            });
                          } catch (e) {
                            debugPrint('❌ Error creating notification: $e');
                          }
                        }

                        if (goalJustCompleted && dialogCtx.mounted) {
                          await showDialog(
                            context: dialogCtx,
                            barrierDismissible: false,
                            builder: (celebCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                                  const SizedBox(height: 20),
                                  const Text("🎉 Goal Completed! 🎉",
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 15),
                                  Text(
                                    'Congratulations! You achieved your "${goal['title']}" goal!',
                                    style: const TextStyle(fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTealColor,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => Navigator.pop(celebCtx),
                                  child: const Text("Awesome!",
                                      style: TextStyle(color: Colors.white, fontSize: 16)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Add", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditGoalDialog(String? uid, String goalId, Map<String, dynamic> goal) async {
    final titleController = TextEditingController(text: goal['title']);
    final targetController = TextEditingController(text: goal['targetAmount'].toString());

    // Fetch user's currency
    String currencySymbol = "LKR";
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>?;
        currencySymbol = userData?['currencySymbol'] ?? userData?['currencyCode'] ?? "LKR";
      }
    } catch (e) {
      debugPrint('Error fetching currency: $e');
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Goal",
            style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Goal Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Target Amount ($currencySymbol)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (titleController.text.isNotEmpty && targetController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('goals')
                    .doc(goalId)
                    .update({
                  'title': titleController.text,
                  'targetAmount': double.parse(targetController.text),
                });
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(String? uid, String goalId, String goalTitle) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Goal",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete \'$goalTitle\'? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('goals')
                  .doc(goalId)
                  .delete();
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Goal deleted successfully")),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
