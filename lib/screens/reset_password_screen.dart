import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Brand Colors used in your previous screens
  static const Color kTealColor = Color(0xFF2B90B6);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Firebase standard: Sends a secure password reset link to the email
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      // Show professional success confirmation
      _showSuccessDialog();

    } on FirebaseAuthException catch (e) {
      String message = "An error occurred. Please try again.";
      if (e.code == 'user-not-found') {
        message = "No account exists with this email address.";
      } else if (e.code == 'invalid-email') {
        message = "Please enter a valid email address.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Colors.green, size: 60),
            SizedBox(height: 15),
            Text("Email Sent!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "A password reset link has been sent to your email. Please follow the instructions to set a new password.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go back to Login Screen
              },
              child: const Text("Back to Login", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: kTealColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Reset Password",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A535C)
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Enter your registered email address to receive a password reset link.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 50),

                const Text("Email Address", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "example@gmail.com",
                    prefixIcon: const Icon(Icons.email_outlined, color: kTealColor),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kTealColor, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Email is required";
                    if (!v.contains('@')) return "Enter a valid email";
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                        : const Text(
                        "Send Reset Link",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}