import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

// Screens in the same folder
import 'edit_profile_screen.dart';
import 'select_currency_screen.dart';
import 'help_center_screen.dart';
import 'reset_password_screen.dart';
import 'login_screen.dart';

// Going up one level to reach the providers folder
import '../providers/theme_provider_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
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

            _buildSettingItem(
              context,
              icon: Icons.nightlight_round,
              title: "Theme",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeProviderScreen()),
              ),
            ),

            _buildSettingItem(
              context,
              icon: Icons.lock_outline,
              title: "Password",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
              ),
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

            // BACKUP DATA
            _buildSettingItem(
              context,
              icon: Icons.save_outlined,
              title: "Backup & Export",
              onTap: () => _handleBackup(context),
            ),

            // DELETE & RESET
            _buildSettingItem(
              context,
              icon: Icons.delete_outline,
              title: "Delete & Reset",
              iconColor: Colors.red,
              onTap: () => _showDeleteConfirmation(context),
            ),

            _buildSettingItem(
              context,
              icon: Icons.help_outline,
              title: "Help & Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
              ),
            ),

            const SizedBox(height: 30),

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
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Data Management"),
        content: const Text("Would you like to reset your transaction history or permanently delete your account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")
          ),
          TextButton(
              onPressed: () {
                _handleReset(context);
                Navigator.pop(context);
              },
              child: const Text("Reset Data", style: TextStyle(color: Colors.orange))
          ),
          TextButton(
              onPressed: () {
                _handleDeleteAccount(context);
                Navigator.pop(context);
              },
              child: const Text("Delete Account", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        Color iconColor = Colors.green,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

