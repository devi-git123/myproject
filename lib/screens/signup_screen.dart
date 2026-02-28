import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'select_currency_screen.dart';

const Color kTealColor = Color(0xFF2B90B6);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Handles the account creation and database entry
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate(); // Feedback for validation error
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 2. Save User Data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'setupComplete': false,
        'totalBalance': 0.0, // Initialize balance
      });

      // 3. Mark Onboarding as complete in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      if (!mounted) return;

      HapticFeedback.lightImpact(); // ✅ This provides a subtle success vibration

      // 4. Navigate to Currency Screen (Smooth Transition)
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secondaryAnim) => const SelectCurrencyScreen(),
          transitionsBuilder: (context, anim, secondaryAnim, child) {
            return FadeTransition(opacity: anim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "An authentication error occurred.");
    } catch (e) {
      _showError("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: const BackButton(color: kTealColor)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTealColor),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Fill in your details to get started",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  _buildField("Full Name", _nameController, Icons.person_outline),
                  const SizedBox(height: 15),
                  _buildField("Email", _emailController, Icons.email_outlined, isEmail: true),
                  const SizedBox(height: 15),
                  _buildField("Username", _usernameController, Icons.alternate_email),
                  const SizedBox(height: 15),
                  _buildField(
                    "Password",
                    _passwordController,
                    Icons.lock_outline,
                    isPass: true,
                    showVisibilityToggle: true,
                  ),
                  const SizedBox(height: 15),
                  _buildField(
                    "Confirm Password",
                    _confirmPasswordController,
                    Icons.lock_reset,
                    isPass: true,
                    isConfirmPass: true,
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTealColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleSignUp,
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Sign Up",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already have an account? Login", style: TextStyle(color: kTealColor)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      String hint,
      TextEditingController controller,
      IconData icon,
      {bool isPass = false, bool isEmail = false, bool isConfirmPass = false, bool showVisibilityToggle = false}
      ) {
    return TextFormField(
      controller: controller,
      obscureText: isPass && _obscurePassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textInputAction: isConfirmPass ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) => isConfirmPass ? _handleSignUp() : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: kTealColor),
        suffixIcon: showVisibilityToggle
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _obscurePassword = !_obscurePassword);
          },
        )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: kTealColor, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return "This field is required";
        if (isEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return "Enter a valid email";
        if (isPass && value.length < 6) return "Password must be at least 6 characters";
        if (isConfirmPass && value != _passwordController.text) return "Passwords do not match";
        return null;
      },
    );
  }
}