import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens in the same folder (lib/screens/)
import 'edit_profile_screen.dart';
import 'select_currency_screen.dart';
import 'help_center_screen.dart';
import 'reset_password_screen.dart';
import 'login_screen.dart';

// Going up one level to reach the providers folder
import '../providers/theme_provider_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

            // THEME SETTING
            _buildSettingItem(
              context,
              icon: Icons.nightlight_round,
              title: "Theme",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeProviderScreen()),
              ),
            ),

            // PASSWORD SETTING
            _buildSettingItem(
              context,
              icon: Icons.lock_outline,
              title: "Password",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
              ),
            ),

            // CURRENCY SETTING
            _buildSettingItem(
              context,
              icon: Icons.currency_exchange,
              title: "Change Currency",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SelectCurrencyScreen()),
              ),
            ),

            // EXPORT DATA
            _buildSettingItem(
              context,
              icon: Icons.ios_share,
              title: "Export data",
              onTap: () {
                // Future: Implement CSV export
              },
            ),

            // BACKUP
            _buildSettingItem(
              context,
              icon: Icons.save_outlined,
              title: "Backup & Restore",
              onTap: () {
                // Future: Implement Firebase Cloud Backup
              },
            ),

            // DELETE DATA
            _buildSettingItem(
              context,
              icon: Icons.delete_outline,
              title: "Delete & Reset",
              iconColor: Colors.red,
              onTap: () => _showDeleteConfirmation(context),
            ),

            // HELP CENTER
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

            // LOGOUT BUTTON
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

  // Confirmation Dialog for the Delete Button
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Data?"),
        content: const Text(
            "This will permanently erase all your budget history. This action cannot be undone."
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")
          ),
          TextButton(
              onPressed: () {
                // Add actual deletion logic here
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red))
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