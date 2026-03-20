import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/theme_provider_screen.dart';
import 'edit_profile_screen.dart';
import 'add_category_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'my_transactions_screen.dart';
import 'categories_screen.dart';
import 'analytics_screen.dart';
import 'notifications_screen.dart';
import 'financial_goals_screen.dart';
import 'upload_receipt_screen.dart';
import 'add_expense_screen.dart';
import '../services/savings_streak_service.dart';

const Color kTealColor = Color(0xFF2B90B6);
const Color kLightTeal = Color(0xFF76C8D5);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  bool _pauseStreams = false;
  final double _cachedBalance = 0;
  final double _cachedIncome = 0;
  final double _cachedExpense = 0;

  Future<T?> _pushAndPauseStreams<T>(Widget screen) async {
    setState(() => _pauseStreams = true);
    final result = await Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) setState(() => _pauseStreams = false);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildSidebar(context, isDark, themeProvider),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadReceiptScreen()),
          );
          if (result != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddExpenseScreen(initialAmount: result.toString()),
              ),
            );
          }
        },
        label: const Text("Scan Receipt", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        backgroundColor: kTealColor,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => {},
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnapshot) {
              // Get user's currency symbol (default to "LKR" if not set)
              String currencySymbol = "LKR";
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                currencySymbol = userData?['currencySymbol'] ?? userData?['currencyCode'] ?? "LKR";
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, scaffoldKey, isDark, uid),
                    const SizedBox(height: 30),

                    // BALANCE CARD
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').snapshots(),
                      builder: (context, snapshot) {
                        double balance = 0;
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            double amt = (data['amount'] ?? 0).toDouble();
                            data['type'] == 'Income' ? balance += amt : balance -= amt;
                          }
                        }
                        return _buildBalanceCard("$currencySymbol ${balance.toStringAsFixed(2)}", isDark);
                      },
                    ),

                    const SizedBox(height: 30),

                    // STAT CARDS (INCOME/EXPENSE)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').snapshots(),
                      builder: (context, snapshot) {
                        double totalIncome = 0;
                        double totalExpense = 0;
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            double amount = (data['amount'] ?? 0).toDouble();
                            data['type'] == 'Income' ? totalIncome += amount : totalExpense += amount;
                          }
                        }
                        return Row(
                          children: [
                            _buildStatCard("Income", "$currencySymbol ${totalIncome.toStringAsFixed(0)}", Icons.arrow_downward, Colors.green, isDark),
                            const SizedBox(width: 15),
                            _buildStatCard("Expense", "$currencySymbol ${totalExpense.toStringAsFixed(0)}", Icons.arrow_upward, Colors.redAccent, isDark),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // FINANCIAL GOAL PROGRESS CARD
                    _buildSectionHeader("Financial Goal Progress", () {
                      _pushAndPauseStreams(const FinancialGoalsScreen());
                    }),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').limit(1).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text("No active goals found.");
                        }
                        var goal = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        double target = (goal['targetAmount'] ?? 1).toDouble();
                        double saved = (goal['savedAmount'] ?? 0).toDouble();
                        double percent = (saved / target).clamp(0.0, 1.0);
                        bool isCompleted = saved >= target;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            goal['title'] ?? "Savings Goal",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isCompleted) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(percent * 100).toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted ? Colors.green : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: percent,
                                backgroundColor: isCompleted 
                                    ? Colors.green.withOpacity(0.1)
                                    : kTealColor.withOpacity(0.1),
                                color: isCompleted ? Colors.green : kTealColor,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isCompleted
                                    ? "Goal Completed! 🎉"
                                    : "$currencySymbol ${saved.toStringAsFixed(0)} of ${target.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCompleted ? Colors.green : Colors.grey,
                                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Categories", () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
                    }),
                    const SizedBox(height: 10),
                    _buildCategoryList(isDark, uid, currencySymbol),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Recent Transactions", () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTransactionsScreen()));
                    }),
                    const SizedBox(height: 15),
                    _buildTransactionList(isDark, uid, currencySymbol),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  // UI HELPERS (Header, Sidebar, Cards etc.)

  Widget _buildHeader(BuildContext context, GlobalKey<ScaffoldState> key, bool isDark, String? uid) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: kTealColor, size: 30),
          onPressed: () => key.currentState?.openDrawer(),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome back,", style: TextStyle(fontSize: 14, color: Colors.grey)),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                String name = "User";
                if (snapshot.hasData && snapshot.data!.exists) {
                  name = (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? "User";
                }
                return Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTealColor));
              },
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
          child: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.notifications_none_rounded, color: kTealColor),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(String balanceText, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kTealColor, kLightTeal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: kTealColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          const Text("Current Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          Text(balanceText, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String amount, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  FittedBox(child: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        TextButton(onPressed: onSeeAll, child: const Text("See All", style: TextStyle(color: kTealColor))),
      ],
    );
  }

  Widget _buildCategoryList(bool isDark, String? uid, String currencySymbol) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50);
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("No categories");
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final int iconCode = data['iconCode'] ?? 58947;
              return Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: kTealColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), color: kTealColor, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(data['name'] ?? "", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTransactionList(bool isDark, String? uid, String currencySymbol) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').orderBy('timestamp', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No transactions yet."));
        return Column(
          children: docs.map((doc) {
            final t = doc.data() as Map<String, dynamic>;
            final bool isExpense = t['type'] == 'Expense';
            final int iconCode = t['iconCode'] ?? 58947;
            
            // Format timestamp
            final Timestamp? timestamp = t['timestamp'] as Timestamp?;
            String dateDisplay = "No Date";
            String timeDisplay = "";
            
            if (timestamp != null) {
              DateTime dt = timestamp.toDate();
              dateDisplay = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
              timeDisplay = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isExpense ? kTealColor.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), color: isExpense ? kTealColor : Colors.green, size: 20),
                ),
                title: Text(t['title'] ?? t['category'] ?? "Transaction", style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(dateDisplay, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(timeDisplay, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Text("${isExpense ? '-' : '+'} $currencySymbol ${t['amount']}", style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? Colors.redAccent : Colors.green)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, bool isDark, ThemeProvider themeProvider) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Drawer(
      child: Column(
        children: [
          // ── Profile Header ──────────────────────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              String name = "User";
              String email = FirebaseAuth.instance.currentUser?.email ?? "";
              String? profileImg;
              double monthlyLimit = 0;
              String currencySymbol = "LKR";
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? "User";
                profileImg = data['profileImage'];
                monthlyLimit = (data['monthlyBudgetLimit'] ?? 0).toDouble();
                currencySymbol = data['currencySymbol'] ?? data['currencyCode'] ?? "LKR";
              }
              return Column(
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(color: kTealColor),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: profileImg != null
                          ? MemoryImage(base64Decode(profileImg)) as ImageProvider
                          : null,
                      child: profileImg == null
                          ? const Icon(Icons.person, color: kTealColor, size: 40)
                          : null,
                    ),
                    accountName: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    accountEmail: Text(email),
                  ),

                  // ── 1. Dark Mode Toggle ──────────────────────────
                  SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: kTealColor,
                    ),
                    title: const Text("Dark Mode"),
                    value: isDark,
                    activeThumbColor: kTealColor,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      themeProvider.toggleTheme(val);
                    },
                  ),
                  const Divider(height: 1),

                  // ── 2. Savings Streak ────────────────────────────
                  FutureBuilder<int>(
                    future: uid != null
                        ? SavingsStreakService.calculateStreak(uid)
                        : Future.value(0),
                    builder: (context, streakSnap) {
                      final int streak = streakSnap.data ?? 0;
                      final String streakText = streak == 0
                          ? "Set a budget limit to start!"
                          : streak == 1
                              ? "1 day under budget 🔥"
                              : "$streak days under budget 🔥";
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_fire_department,
                              color: Colors.orange, size: 22),
                        ),
                        title: const Text("Savings Streak",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(streakText,
                            style: TextStyle(
                              fontSize: 12,
                              color: streak > 0 ? Colors.orange : Colors.grey,
                              fontWeight: streak > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // ── 3. Quick Stats ───────────────────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('transactions')
                        .snapshots(),
                    builder: (context, txSnap) {
                      double todaySpent = 0;
                      double monthSpent = 0;
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final monthStart = DateTime(now.year, now.month, 1);

                      if (txSnap.hasData) {
                        for (final doc in txSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if ((data['type'] ?? '') != 'Expense') continue;
                          final Timestamp? ts =
                              data['timestamp'] as Timestamp?;
                          if (ts == null) continue;
                          final date = ts.toDate();
                          final amount = (data['amount'] ?? 0).toDouble();
                          if (!date.isBefore(today)) todaySpent += amount;
                          if (!date.isBefore(monthStart)) monthSpent += amount;
                        }
                      }

                      final double remaining = monthlyLimit > 0
                          ? (monthlyLimit - monthSpent)
                          : 0;
                      final bool overBudget =
                          monthlyLimit > 0 && monthSpent > monthlyLimit;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.bar_chart_rounded,
                                    color: kTealColor, size: 18),
                                SizedBox(width: 6),
                                Text("Quick Stats",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: kTealColor)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatChip(
                                    "Today",
                                    "$currencySymbol ${todaySpent.toStringAsFixed(0)}",
                                    Colors.redAccent),
                                _buildStatChip(
                                    "This Month",
                                    "$currencySymbol ${monthSpent.toStringAsFixed(0)}",
                                    kTealColor),
                                if (monthlyLimit > 0)
                                  _buildStatChip(
                                    "Remaining",
                                    "$currencySymbol ${remaining.abs().toStringAsFixed(0)}",
                                    overBudget ? Colors.red : Colors.green,
                                  ),
                              ],
                            ),
                            if (monthlyLimit > 0) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value:
                                      (monthSpent / monthlyLimit).clamp(0.0, 1.0),
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.2),
                                  color: overBudget
                                      ? Colors.red
                                      : monthSpent / monthlyLimit > 0.8
                                          ? Colors.orange
                                          : Colors.green,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                overBudget
                                    ? "Over budget!"
                                    : "${((monthSpent / monthlyLimit) * 100).toStringAsFixed(0)}% of monthly limit used",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: overBudget ? Colors.red : Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // ── 4. Monthly Budget Limit ──────────────────────
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kTealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month,
                          color: kTealColor, size: 22),
                    ),
                    title: const Text("Monthly Budget Limit",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      monthlyLimit > 0
                          ? "$currencySymbol ${monthlyLimit.toStringAsFixed(0)}"
                          : "Not set",
                      style: TextStyle(
                        fontSize: 12,
                        color: monthlyLimit > 0 ? kTealColor : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.edit, size: 16, color: Colors.grey),
                    onTap: () => _showBudgetLimitDialog(context, uid, monthlyLimit, currencySymbol),
                  ),
                  const Divider(height: 1),

                  // ── 5. Edit Profile ──────────────────────────────
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kTealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: kTealColor, size: 22),
                    ),
                    title: const Text("Edit Profile",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()));
                    },
                  ),
                ],
              );
            },
          ),

          const Spacer(),
          const Divider(height: 1),

          // ── Logout ───────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Logout",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showBudgetLimitDialog(
      BuildContext context, String? uid, double currentLimit, String currencySymbol) {
    final controller = TextEditingController(
        text: currentLimit > 0 ? currentLimit.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Monthly Budget Limit",
            style: TextStyle(
                color: kTealColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Amount ($currencySymbol)",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final double? val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'monthlyBudgetLimit': val});
              }
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text("Save",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color color = kTealColor}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(
              color: color == Colors.redAccent ? Colors.redAccent : null)),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      decoration: BoxDecoration(
        color: kTealColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: kTealColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.receipt_long_rounded, color: Colors.white60, size: 28), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTransactionsScreen()));
          }),
          IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.white60, size: 28), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()));
          }),
          GestureDetector(
            onTap: () => _pushAndPauseStreams(const AddCategoryScreen()),
            child: const CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.add, color: kTealColor, size: 30)),
          ),
          IconButton(icon: const Icon(Icons.emoji_events_rounded, color: Colors.white60, size: 28), onPressed: () {
            _pushAndPauseStreams(const FinancialGoalsScreen());
          }),
          IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white60, size: 28), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }
}