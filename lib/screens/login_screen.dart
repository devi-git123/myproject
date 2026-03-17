import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'reset_password_screen.dart';
import 'select_currency_screen.dart';
import 'dashboard_screen.dart';

// Brand Colors
const Color kTealColor = Color(0xFF2B90B6);
const Color kLimeColor = Color(0xFFADCF35);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 1. Check if user has already completed setup
        final uid = FirebaseAuth.instance.currentUser?.uid;
        bool setupComplete = false;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          setupComplete = doc.data()?['setupComplete'] == true;
        }

        if (!mounted) return;

        // 2. Existing users go to dashboard; new/incomplete users pick currency
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => setupComplete
                ? const DashboardScreen()
                : const SelectCurrencyScreen(),
          ),
        );

      } on FirebaseAuthException catch (e) {
        String errorMessage = "Login failed. Please check your credentials.";

        if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          errorMessage = "No account found for this email.";
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          errorMessage = "Incorrect email or password.";
        } else if (e.code == 'network-request-failed') {
          errorMessage = "Check your internet connection.";
        }

        if (!mounted) return; // Safety check before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Image.asset(
                  'assets/images/login.png',
                  height: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTealColor),
                ),
                const Text("Log in to continue your budget tracking", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 50),

                _buildField(
                  controller: _emailController,
                  hint: "Email",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? "Enter a valid email" : null,
                ),
                const SizedBox(height: 20),

                _buildField(
                  controller: _passwordController,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) => (v == null || v.length < 6) ? "Password must be 6+ characters" : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                      );
                    },
                    child: const Text("Forgot password?", style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Log In", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                      child: const Text("Sign up", style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kTealColor),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggle,
        )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kTealColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }
}