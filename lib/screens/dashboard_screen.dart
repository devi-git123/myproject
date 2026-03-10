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
import 'analytics_screen.dart';
import 'notifications_screen.dart';
import 'financial_goals_screen.dart';
import 'upload_receipt_screen.dart';
import 'add_expense_screen.dart';

const Color kTealColor = Color(0xFF2B90B6);
const Color kLightTeal = Color(0xFF76C8D5);
const Color kGreenColor = Color(0xFF2E7D32);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
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
        label: const Text("Scan Receipt"),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: kTealColor,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, scaffoldKey, isDark, uid),
                const SizedBox(height: 30),
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
                    return _buildBalanceCard("LKR ${balance.toStringAsFixed(2)}", isDark);
                  },
                ),
                const SizedBox(height: 30),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions').snapshots(),
                  builder: (context, snapshot) {
                    double totalIncome = 0;
                    double totalExpense = 0;
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        double amount = (data['amount'] ?? 0).toDouble();
                        if (data['type'] == 'Income') {
                          totalIncome += amount;
                        } else {
                          totalExpense += amount;
                        }
                      }
                    }
                    return Row(
                      children: [
                        _buildStatCard("Income", "LKR ${totalIncome.toStringAsFixed(0)}", Icons.arrow_downward, Colors.green, isDark),
                        const SizedBox(width: 15),
                        _buildStatCard("Expense", "LKR ${totalExpense.toStringAsFixed(0)}", Icons.arrow_upward, Colors.redAccent, isDark),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                _buildSectionHeader("Categories", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTransactionsScreen()));
                }),
                const SizedBox(height: 10),
                _buildCategoryList(isDark, uid),
                const SizedBox(height: 30),
                _buildSectionHeader("Recent Transactions", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTransactionsScreen()));
                }),
                const SizedBox(height: 15),
                _buildTransactionList(isDark, uid),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  // --- Helper Methods ---

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
                }
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
        boxShadow: [BoxShadow(color: kTealColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
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

  Widget _buildCategoryList(bool isDark, String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50);
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("No categories added");
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
                      decoration: BoxDecoration(
                        color: data['type'] == 'Income' ? Colors.green.withOpacity(0.1) : kTealColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconData(iconCode, fontFamily: 'MaterialIcons'),
                        color: data['type'] == 'Income' ? Colors.green : kTealColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(data['name'] ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTransactionList(bool isDark, String? uid) {
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
                subtitle: Text(isExpense ? "Expense" : "Income", style: const TextStyle(fontSize: 12)),
                trailing: Text("${isExpense ? '-' : '+'} LKR ${t['amount']}", style: TextStyle(fontWeight: FontWeight.bold, color: isExpense ? Colors.redAccent : Colors.green, fontSize: 16)),
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              String name = "Loading...";
              String email = FirebaseAuth.instance.currentUser?.email ?? "";
              String? profileImg;
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                name = data['name'] ?? "New User";
                profileImg = data['profileImage'];
              }
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: kTealColor),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: profileImg != null ? NetworkImage(profileImg) : null,
                  child: profileImg == null ? const Icon(Icons.person, color: kTealColor, size: 40) : null,
                ),
                accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(email),
              );
            },
          ),
          _buildDrawerItem(icon: Icons.person_outline, title: "Edit Profile", onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
          }),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: kTealColor),
            title: const Text("Dark Mode"),
            value: isDark,
            activeThumbColor: kTealColor,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              themeProvider.toggleTheme(val);
            },
          ),
          const Spacer(),
          const Divider(),
          _buildDrawerItem(icon: Icons.logout, title: "Logout", color: Colors.redAccent, onTap: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap, Color color = kTealColor}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color == Colors.redAccent ? Colors.redAccent : null)),
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
          IconButton(icon: const Icon(Icons.home_rounded, color: Colors.white, size: 28), onPressed: () {}),
          IconButton(icon: const Icon(Icons.bar_chart_rounded, color: Colors.white60, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()))),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCategoryScreen())), child: const CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.add, color: kTealColor, size: 30))),
          IconButton(icon: const Icon(Icons.emoji_events_rounded, color: Colors.white60, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialGoalsScreen()))),
          IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white60, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
        ],
      ),
    );
  }
}