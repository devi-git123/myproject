import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Screens in the same folder
import 'edit_profile_screen.dart';
import 'select_currency_screen.dart';
import 'help_center_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileImageUrl;
  bool _isLoadingImage = true;
  bool _notificationsEnabled = true;
  String _lastSyncTime = "Checking...";

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadNotificationSetting();
    _updateLastSyncTime();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
          });
        }
      }
    } catch (e) {
      // Default to enabled
    }
  }

  Future<void> _updateLastSyncTime() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          final timestamp = doc.data()?['lastSyncTime'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final now = DateTime.now();
            final diff = now.difference(date);
            
            String syncText;
            if (diff.inMinutes < 1) {
              syncText = "Just now";
            } else if (diff.inHours < 1) {
              syncText = "${diff.inMinutes}m ago";
            } else if (diff.inDays < 1) {
              syncText = "${diff.inHours}h ago";
            } else {
              syncText = "${diff.inDays}d ago";
            }
            
            setState(() => _lastSyncTime = syncText);
          } else {
            setState(() => _lastSyncTime = "Never");
          }
        }
      }
    } catch (e) {
      setState(() => _lastSyncTime = "Unknown");
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'notificationsEnabled': value});
        
        setState(() => _notificationsEnabled = value);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? "Notifications enabled" : "Notifications disabled"),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _syncData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update last sync timestamp
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastSyncTime': FieldValue.serverTimestamp()});
        
        // Optimistically update UI to "Just now"
        setState(() => _lastSyncTime = "Just now");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data synced successfully!")),
          );
        }
        
        // Reload the actual time after a brief delay
        await Future.delayed(const Duration(milliseconds: 500));
        _updateLastSyncTime();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            _profileImageUrl = doc.data()?['profileImage']; // base64 string
            _isLoadingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  // --- LOGIC FUNCTIONS ---
  // Finalized Settings Logic

  // 1. Backup Data Logic
  Future<void> _handleBackup(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetches all documents from your user's transactions collection
      final snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .get();

      final data = snapshots.docs.map((doc) => {
        "id": doc.id,
        ...doc.data(),
      }).toList();
      final jsonString = jsonEncode(data);

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/budget_backup.json');
      await file.writeAsString(jsonString);

      // Opens the phone's share sheet to save/send the file
      await Share.shareXFiles([XFile(file.path)], text: 'My Budget Backup');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backup Failed: $e")),
      );
    }
  }

  // 2. Restore Data Logic
  Future<void> _handleRestore(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Pick the JSON backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List<dynamic> backupData = jsonDecode(content);

        // 2. Use a Firestore WriteBatch for efficiency
        final batch = FirebaseFirestore.instance.batch();
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions');

        // 3. Loop through backup and set data back to Firestore
        for (var item in backupData) {
          // Use the original ID if it exists, otherwise generate a new one
          String docId = item['id'] ?? collection.doc().id;
          Map<String, dynamic> data = Map<String, dynamic>.from(item);

          // Remove the 'id' field from the map so it's not stored twice
          data.remove('id');

          batch.set(collection.doc(docId), data);
        }

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data restored successfully!")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restore Failed: $e")),
      );
    }
  }

  // 3. Reset Data Logic (Deletes sub-collection documents)
  Future<void> _handleReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions');

      final snapshots = await collection.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All data cleared successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reset Failed: $e")),
      );
    }
  }

  // 4. Delete Account Logic
  Future<void> _handleDeleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {

        final transactions = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .get();

        for (var doc in transactions.docs) {
          await doc.reference.delete();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();

        await user.delete();

        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please re-login before deleting account")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(color: Color(0xFF1E3A34), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
                _loadProfileImage();
              },
              child: _isLoadingImage
                  ? const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.grey,
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? MemoryImage(base64Decode(_profileImageUrl!))
                          : null,
                      child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // ═══════════════════════════════════════════════════
            // SECTION 1: APP PREFERENCES
            // ═══════════════════════════════════════════════════
            _buildSectionHeader("App Preferences"),
            
            _buildSwitchItem(
              icon: Icons.notifications_active,
              title: "Notifications",
              subtitle: "Budget alerts & reminders",
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),

            _buildSettingItem(
              context,
              icon: Icons.currency_exchange,
              title: "Change Currency",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectCurrencyScreen()),
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════
            // SECTION 2: DATA MANAGEMENT
            // ═══════════════════════════════════════════════════
            _buildSectionHeader("Data Management"),

            _buildSettingItem(
              context,
              icon: Icons.cloud_done,
              title: "Data Sync Status",
              subtitle: "Last synced: $_lastSyncTime",
              onTap: _syncData,
              iconColor: const Color(0xFF2B90B6),
            ),

            _buildSettingItem(
              context,
              icon: Icons.picture_as_pdf,
              title: "Export as PDF",
              subtitle: "Professional report with analytics",
              onTap: () => _showExportPDFOptions(context),
              iconColor: Colors.red,
            ),

            _buildSettingItem(
              context,
              icon: Icons.delete_outline,
              title: "Delete & Reset",
              subtitle: "Clear data or delete account",
              iconColor: Colors.red,
              onTap: () => _showDeleteConfirmation(context),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════
            // SECTION 3: SUPPORT & INFORMATION
            // ═══════════════════════════════════════════════════
            _buildSectionHeader("Support & Information"),

            _buildSettingItem(
              context,
              icon: Icons.help_outline,
              title: "Help & Support",
              subtitle: "FAQs and guides",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
              ),
            ),

            _buildSettingItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: "Data Privacy",
              subtitle: "How we handle your data",
              onTap: () => _showPrivacyScreen(context),
            ),

            _buildSettingItem(
              context,
              icon: Icons.info_outline,
              title: "App Version & About",
              subtitle: "v1.0.0",
              onTap: () => _showAboutScreen(context),
            ),

            const SizedBox(height: 30),

            // ═══════════════════════════════════════════════════
            // LOGOUT BUTTON
            // ═══════════════════════════════════════════════════
            Center(
              child: TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                },
                child: const Text(
                  "Logout",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG & CONFIRMATION HANDLERS
  // ══════════════════════════════════════════════════════
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Data Management"),
        content: const Text("Would you like to reset your transaction history or permanently delete your account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel")
          ),
          TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _handleReset(context);
              },
              child: const Text("Reset Data", style: TextStyle(color: Colors.orange))
          ),
          TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _handleDeleteAccount(context);
              },
              child: const Text("Delete Account", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _showExportPDFOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Export PDF Report"),
        content: const Text("Choose the date range for your financial report:"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generatePDF(context, "This Month");
            },
            child: const Text("This Month"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generatePDF(context, "Last Month");
            },
            child: const Text("Last Month"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && context.mounted) {
                _generatePDF(context, "Custom", customRange: picked);
              }
            },
            child: const Text("Custom Range"),
          ),
        ],
      ),
    );
  }

  void _showAboutScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("About Smart Budget"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Version: 1.0.0",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text("Build: 1.0.19"),
              SizedBox(height: 16),
              Text(
                "Developer Team",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("Smart Budget Development Team"),
              SizedBox(height: 16),
              Text(
                "License",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("NSBM License © 2026"),
              SizedBox(height: 16),
              Text(
                "Terms & Conditions",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "By using this app, you agree to our terms of service and privacy policy.",
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showPrivacyScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Data Privacy"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "What Data We Collect",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text("• Transactions (income and expenses)\n• Categories and budgets\n• Financial goals\n• Profile information"),
              SizedBox(height: 16),
              Text(
                "How We Use Your Data",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text("Your data is used solely for:\n• Personal financial analytics\n• Budget tracking and alerts\n• Goal progress visualization"),
              SizedBox(height: 16),
              Text(
                "Data Security",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text("• All data is encrypted using Firebase security\n• No third-party sharing\n• Stored securely in the cloud"),
              SizedBox(height: 16),
              Text(
                "Your Rights",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text("• Export your data anytime\n• Delete your account and all data\n• Control notification preferences"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF(BuildContext context, String period, {DateTimeRange? customRange}) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Generating PDF...")),
        );
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Calculate date range
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (customRange != null) {
        startDate = customRange.start;
        endDate = customRange.end;
      } else if (period == "This Month") {
        startDate = DateTime(endDate.year, endDate.month, 1);
      } else if (period == "Last Month") {
        final lastMonth = DateTime(endDate.year, endDate.month - 1, 1);
        startDate = DateTime(lastMonth.year, lastMonth.month, 1);
        endDate = DateTime(endDate.year, endDate.month, 0, 23, 59, 59);
      } else {
        startDate = DateTime(endDate.year, 1, 1);
      }

      // Fetch user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'User';
      final userEmail = user.email ?? userData['email'] ?? 'No email';
      final currency = userData['currencySymbol'] ?? userData['currencyCode'] ?? 'LKR';

      // Fetch transactions
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .get();

      // Filter transactions by date range
      final transactions = transactionsSnapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;
        final date = timestamp.toDate();
        return (date.isAfter(startDate) || date.isAtSameMomentAs(startDate)) &&
               (date.isBefore(endDate) || date.isAtSameMomentAs(endDate));
      }).toList();

      // Calculate totals
      double totalIncome = 0;
      double totalExpenses = 0;
      Map<String, double> categoryTotals = {};

      for (var doc in transactions) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final type = data['type'] ?? '';
        final category = data['category'] ?? 'Uncategorized';

        if (type == 'Income') {
          totalIncome += amount;
        } else {
          totalExpenses += amount;
          categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
        }
      }

      final balance = totalIncome - totalExpenses;

      // Fetch goals
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .get();

      // Generate PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header/Cover
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Financial Report',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      userName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      userEmail,
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Period: $period',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.Text(
                      '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Summary Section
              pw.Text(
                'Financial Summary',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Income', totalIncome, currency, PdfColors.green),
                    _buildSummaryItem('Total Expenses', totalExpenses, currency, PdfColors.red),
                    _buildSummaryItem('Balance', balance, currency, balance >= 0 ? PdfColors.green : PdfColors.red),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Category Breakdown
              if (categoryTotals.isNotEmpty)
                pw.Text(
                  'Expenses by Category',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
              if (categoryTotals.isNotEmpty)
                pw.SizedBox(height: 15),
              if (categoryTotals.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Table
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildTableCell('Category', isHeader: true),
                            _buildTableCell('Amount', isHeader: true),
                            _buildTableCell('% of Total', isHeader: true),
                          ],
                        ),
                        // Data rows
                        ...categoryTotals.entries.map((entry) {
                          final percentage = (entry.value / totalExpenses * 100).toStringAsFixed(1);
                          return pw.TableRow(
                            children: [
                              _buildTableCell(entry.key),
                              _buildTableCell('$currency${entry.value.toStringAsFixed(2)}'),
                              _buildTableCell('$percentage%'),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    // Visual Chart
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Visual Breakdown (Top 5 Categories)',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal700,
                            ),
                          ),
                          pw.SizedBox(height: 12),
                          ...categoryTotals.entries.take(5).map((entry) {
                            final percentage = (entry.value / totalExpenses * 100);
                            return pw.Container(
                              margin: const pw.EdgeInsets.only(bottom: 10),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        entry.key.length > 20 ? '${entry.key.substring(0, 20)}...' : entry.key,
                                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                                      ),
                                      pw.Text(
                                        '$currency ${entry.value.toStringAsFixed(0)}',
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.grey800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.SizedBox(height: 5),
                                  pw.Stack(
                                    children: [
                                      pw.Container(
                                        height: 18,
                                        width: double.infinity,
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.grey300,
                                          borderRadius: pw.BorderRadius.circular(4),
                                        ),
                                      ),
                                      pw.Container(
                                        height: 18,
                                        width: (percentage / 100) * 450,
                                        decoration: pw.BoxDecoration(
                                          color: _getCategoryColor(categoryTotals.keys.toList().indexOf(entry.key)),
                                          borderRadius: pw.BorderRadius.circular(4),
                                        ),
                                        child: pw.Center(
                                          child: pw.Text(
                                            '${percentage.toStringAsFixed(1)}%',
                                            style: const pw.TextStyle(
                                              fontSize: 9,
                                              color: PdfColors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              if (categoryTotals.isNotEmpty)
                pw.SizedBox(height: 25),

              // Goals Section
              if (goalsSnapshot.docs.isNotEmpty)
                pw.Text(
                  'Financial Goals',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
              if (goalsSnapshot.docs.isNotEmpty)
                pw.SizedBox(height: 15),
              ...goalsSnapshot.docs.map((doc) {
                  final data = doc.data();
                  final goalTitle = data['title'] ?? 'Unknown Goal';
                  final targetAmount = (data['targetAmount'] ?? 0).toDouble();
                  final savedAmount = (data['savedAmount'] ?? 0).toDouble();
                  final progress = targetAmount > 0 ? (savedAmount / targetAmount * 100).clamp(0, 100) : 0;

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              goalTitle,
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: progress >= 100 ? PdfColors.green : PdfColors.teal50,
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                progress >= 100 ? 'Completed' : '${progress.toStringAsFixed(0)}%',
                                style: pw.TextStyle(
                                  color: progress >= 100 ? PdfColors.white : PdfColors.teal,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (progress < 100) ...[
                          pw.SizedBox(height: 5),
                          pw.Text(
                            '$currency ${savedAmount.toStringAsFixed(2)} / $currency ${targetAmount.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Stack(
                            children: [
                              pw.Container(
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey300,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                              pw.Container(
                                height: 8,
                                width: (progress / 100) * 400, // Approximate max width for A4
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.teal,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              if (goalsSnapshot.docs.isNotEmpty)
                pw.SizedBox(height: 25),

              // Transactions Table
              pw.Text(
                'Recent Transactions',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
              pw.SizedBox(height: 15),
              if (transactions.isEmpty)
                pw.Text('No transactions found for this period.')
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('Category', isHeader: true),
                        _buildTableCell('Type', isHeader: true),
                        _buildTableCell('Amount', isHeader: true),
                      ],
                    ),
                    // Data rows (limit to 50 most recent)
                    ...transactions.take(50).map((doc) {
                      final data = doc.data();
                      final timestamp = data['timestamp'] as Timestamp?;
                      final date = timestamp != null ? _formatDate(timestamp.toDate()) : 'N/A';
                      final category = data['category'] ?? 'N/A';
                      final type = data['type'] ?? 'N/A';
                      final amount = (data['amount'] ?? 0).toDouble();

                      return pw.TableRow(
                        children: [
                          _buildTableCell(date),
                          _buildTableCell(category),
                          _buildTableCell(type),
                          _buildTableCell(
                            '$currency ${amount.toStringAsFixed(2)}',
                            color: type == 'Income' ? PdfColors.green : PdfColors.red,
                          ),
                        ],
                      );
                    }),
                  ],
                ),

              pw.SizedBox(height: 30),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Smart Budget App',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.teal,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      final fileName = 'Financial_Report_${period.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Save directly to Downloads folder
      try {
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Download/$fileName'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () async {
                  await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
                },
              ),
            ),
          );
        }
      } catch (e) {
        // Fallback to share if direct save fails
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: fileName,
        );
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generated! Choose where to save it.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  // Helper methods for PDF generation
  pw.Widget _buildSummaryItem(String label, double amount, String currency, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          '$currency ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper method to get different colors for categories in chart
  PdfColor _getCategoryColor(int index) {
    final colors = [
      PdfColors.teal,
      PdfColors.blue,
      PdfColors.purple,
      PdfColors.orange,
      PdfColors.pink,
      PdfColors.indigo,
      PdfColors.cyan,
      PdfColors.amber,
    ];
    return colors[index % colors.length];
  }

  // ══════════════════════════════════════════════════════
  // UI BUILDER METHODS
  // ══════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF1E3A34)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: const Color(0xFF1E3A34)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            )
          : null,
      value: value,
      activeColor: const Color(0xFF1E3A34),
      onChanged: onChanged,
    );
  }
}