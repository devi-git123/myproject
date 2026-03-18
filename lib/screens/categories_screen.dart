import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_transactions_screen.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Categories", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2B90B6),
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final String currencySymbol = userData?['currencySymbol'] ?? 
                    userData?['currencyCode'] ?? "LKR";

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('categories')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, categorySnapshot) {
                    if (!categorySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final categories = categorySnapshot.data!.docs;

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          "No Categories Yet",
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tap + to create your first category",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('transactions')
                      .snapshots(),
                  builder: (context, transactionSnapshot) {
                    // Calculate statistics
                    Map<String, int> categoryUsageCount = {};
                    if (transactionSnapshot.hasData) {
                      for (var doc in transactionSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        String category = data['category'] ?? '';
                        if (category.isNotEmpty) {
                          categoryUsageCount[category] = (categoryUsageCount[category] ?? 0) + 1;
                        }
                      }
                    }

                    String mostUsedCategory = '';
                    int maxCount = 0;
                    categoryUsageCount.forEach((key, value) {
                      if (value > maxCount) {
                        maxCount = value;
                        mostUsedCategory = key;
                      }
                    });

                    return Column(
                      children: [
                        // Statistics Card
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF2B90B6), const Color(0xFF1E6B8F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2B90B6).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                icon: Icons.category,
                                label: "Total",
                                value: "${categories.length}",
                              ),
                              Container(width: 1, height: 40, color: Colors.white30),
                              _buildStatItem(
                                icon: Icons.star,
                                label: "Most Used",
                                value: mostUsedCategory.isEmpty ? "None" : mostUsedCategory,
                                isSmallText: mostUsedCategory.length > 8,
                              ),
                            ],
                          ),
                        ),

                        // Category Grid
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final doc = categories[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final String name = data['name'] ?? 'Unnamed';
                              final int iconCode = data['iconCode'] ?? 58947;
                              final String type = data['type'] ?? 'Expense';
                              final double allocatedAmount = (data['allocatedAmount'] ?? 0).toDouble();
                              final int usageCount = categoryUsageCount[name] ?? 0;

                              return GestureDetector(
                                onTap: () => _navigateToTransactions(context, name),
                                onLongPress: () => _showCategoryOptions(context, doc.id, name, type, allocatedAmount, iconCode, currencySymbol),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: type == 'Income' 
                                          ? Colors.green.withOpacity(0.3) 
                                          : Colors.red.withOpacity(0.3),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Icon
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: type == 'Income' 
                                              ? Colors.green.withOpacity(0.1) 
                                              : Colors.red.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          IconData(iconCode, fontFamily: 'MaterialIcons'),
                                          color: type == 'Income' ? Colors.green : Colors.red,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Category Name
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Type Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: type == 'Income' 
                                              ? Colors.green.withOpacity(0.2) 
                                              : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: type == 'Income' ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Usage Count
                                      Text(
                                        "$usageCount transactions",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
          );
        },
        backgroundColor: const Color(0xFF2B90B6),
        icon: const Icon(Icons.add),
        label: const Text("Add Category"),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    bool isSmallText = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallText ? 12 : 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _navigateToTransactions(BuildContext context, String categoryName) {
    // Navigate to transactions screen filtered by this category
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyTransactionsScreen(filterCategory: categoryName),
      ),
    );
  }

  void _showCategoryOptions(
    BuildContext context,
    String docId,
    String name,
    String type,
    double allocatedAmount,
    int iconCode,
    String currencySymbol,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category Info Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: type == 'Income' 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconData(iconCode, fontFamily: 'MaterialIcons'),
                      color: type == 'Income' ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$type · Budget: $currencySymbol ${allocatedAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              // Action Buttons
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Edit Category"),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCategoryDialog(context, docId, name, allocatedAmount, iconCode, currencySymbol);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete Category"),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, docId, name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Color(0xFF2B90B6)),
                title: const Text("View Transactions"),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToTransactions(context, name);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    String docId,
    String currentName,
    double currentAmount,
    int currentIconCode,
    String currencySymbol,
  ) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController amountController = TextEditingController(text: currentAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Category"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Category Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: "Budget Amount",
                  border: OutlineInputBorder(),
                  prefixText: "$currencySymbol ",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newAmount = double.tryParse(amountController.text) ?? currentAmount;

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Name cannot be empty")),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('categories')
                      .doc(docId)
                      .update({
                    'name': newName,
                    'allocatedAmount': newAmount,
                  });

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Category updated!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString()}")),
                    );
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete Category?"),
          content: Text("Are you sure you want to delete '$name'?\n\nTransactions with this category will remain unchanged."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('categories')
                      .doc(docId)
                      .delete();

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Category deleted!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString()}")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}