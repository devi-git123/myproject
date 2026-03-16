import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoalContributionScreen extends StatefulWidget {
  final String uid;
  final double incomeAmount;

  const GoalContributionScreen({
    super.key,
    required this.uid,
    required this.incomeAmount,
  });

  @override
  State<GoalContributionScreen> createState() => _GoalContributionScreenState();
}

class _GoalContributionScreenState extends State<GoalContributionScreen> {
  static const Color kGreen = Color(0xFF2E7D32);
  static const Color kGreenLight = Color(0xFF4CAF50);
  static const Color kTeal = Color(0xFF2B90B6);

  List<Map<String, dynamic>> _goals = [];
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _currencySymbol = "LKR";

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      // Fetch user's currency
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>?;
        _currencySymbol = userData?['currencySymbol'] ?? userData?['currencyCode'] ?? "LKR";
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('goals')
          .get();

      final goals = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      for (final goal in goals) {
        _controllers[goal['id']] = TextEditingController();
      }

      if (mounted) setState(() { _goals = goals; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _contribute() async {
    setState(() => _isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final List<String> completedGoals = [];
      bool anyContribution = false;

      for (final goal in _goals) {
        final controller = _controllers[goal['id']];
        if (controller == null || controller.text.isEmpty) continue;
        final amount = double.tryParse(controller.text);
        if (amount == null || amount <= 0) continue;

        anyContribution = true;
        final currentSaved = (goal['savedAmount'] ?? 0).toDouble();
        final targetAmount = (goal['targetAmount'] ?? 0).toDouble();
        final newSaved = currentSaved + amount;

        if (currentSaved < targetAmount && newSaved >= targetAmount) {
          completedGoals.add(goal['title'] ?? 'Goal');
          
          // Create notification for goal completion
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid)
                .collection('notifications')
                .add({
              'title': '🎉 Goal Completed!',
              'message': 'Congratulations! You achieved your "${goal['title']}" goal of $_currencySymbol ${targetAmount.toStringAsFixed(0)}!',
              'type': 'success',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
          } catch (e) {
            debugPrint('❌ Error creating notification: $e');
          }
        }

        batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .collection('goals')
              .doc(goal['id']),
          {'savedAmount': newSaved},
        );
      }

      if (anyContribution) await batch.commit();

      if (!mounted) return;

      // Navigate to celebration screen or just go back
      if (completedGoals.isNotEmpty) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GoalCelebrationScreen(completedGoals: completedGoals),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSaving = false; _errorMessage = e.toString(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        title: const Text('Contribute to Goals',
            style: TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kGreen),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _goals.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No goals yet', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Create a goal first to start saving!',
              style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up, color: kGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Income Added!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kGreen)),
                    Text(
                      '$_currencySymbol ${widget.incomeAmount.toStringAsFixed(0)} — allocate to your goals',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
            ),
          ),

        // Goals list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _goals.length,
            itemBuilder: (context, index) {
              final goal = _goals[index];
              final double saved = (goal['savedAmount'] ?? 0).toDouble();
              final double target = (goal['targetAmount'] ?? 1).toDouble();
              final double progress = (saved / target).clamp(0.0, 1.0);
              final bool isComplete = progress >= 1.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isComplete ? kGreenLight.withValues(alpha: 0.4) : const Color(0xFFE8F5E9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(goal['title'] ?? 'Goal',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (isComplete)
                          const Icon(Icons.check_circle, color: kGreenLight, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFE8F5E9),
                        color: isComplete ? kGreenLight : kTeal,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_currencySymbol ${saved.toStringAsFixed(0)} of ${target.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (!isComplete) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controllers[goal['id']],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount to add ($_currencySymbol)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.add, size: 18, color: kGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: kGreen),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      const Text('Goal completed! 🎉',
                          style: TextStyle(color: kGreenLight, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom actions
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE8F5E9))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Skip', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _contribute,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Contribute',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Celebration screen — shown after goal is completed. Full screen, no dialogs.
// ─────────────────────────────────────────────────────────────────────────────
class GoalCelebrationScreen extends StatelessWidget {
  final List<String> completedGoals;
  const GoalCelebrationScreen({super.key, required this.completedGoals});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                '🎉 Goal Completed! 🎉',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...completedGoals.map((title) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'You achieved: "$title"',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    // Pop back to wherever we came from (AddCategoryScreen already popped itself)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
