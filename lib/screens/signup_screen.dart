import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'select_currency_screen.dart';

// Brand Colors
const Color kTealColor = Color(0xFF2B90B6);
const Color kLimeColor = Color(0xFFADCF35);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

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

  /// Checks if the chosen username is already taken in the Firestore database
  Future<bool> _isUsernameTaken(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();
    return result.docs.isNotEmpty;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      String username = _usernameController.text.trim().toLowerCase();

      // 1. Create Firebase Auth account first (needed to read other users' docs)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 2. Now authenticated — check if username is already taken
      bool taken = await _isUsernameTaken(username);
      if (taken) {
        // Roll back: delete the auth account since username is taken
        await userCredential.user!.delete();
        _showError("This username is already taken. Try another.");
        setState(() => _isLoading = false);
        return;
      }

      // 3. Save User Profile Data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'username': username,
        'email': _emailController.text.trim(),
        'profileImage': null,
        'createdAt': FieldValue.serverTimestamp(),
        'setupComplete': false,
        'totalBalance': 0.0,
      });

      // 4. Update Local Storage: Mark Onboarding as seen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      if (!mounted) return;

      // 5. Navigate to Currency Selection (The final setup step)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SelectCurrencyScreen()),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String msg = "Sign up failed.";
      if (e.code == 'email-already-in-use') msg = "Email already registered.";
      if (e.code == 'weak-password') msg = "Password is too weak.";
      _showError(msg);
    } catch (e) {
      debugPrint("❌ Signup error: $e");
      _showError("Error: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: kTealColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Fill in your details to get started",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  _buildField("Full Name", _nameController, Icons.person_outline),
                  const SizedBox(height: 15),
                  _buildField("Email Address", _emailController, Icons.email_outlined, isEmail: true),
                  const SizedBox(height: 15),
                  _buildField("Choose Username", _usernameController, Icons.alternate_email),
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
                    Icons.lock_reset_outlined,
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
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _isLoading ? null : _handleSignUp,
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Sign Up",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? ", style: TextStyle(color: Colors.black54)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Log In",
                          style: TextStyle(color: kTealColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController controller, IconData icon,
      {bool isPass = false, bool isEmail = false, bool isConfirmPass = false, bool showVisibilityToggle = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPass && _obscurePassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, color: kTealColor, size: 22),
        suffixIcon: showVisibilityToggle
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: kTealColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "This field is required";
        if (isEmail && !RegExp(r"^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$").hasMatch(value)) return "Invalid email format";
        if (isPass && value.length < 6) return "Password must be at least 6 characters";
        if (isConfirmPass && value != _passwordController.text) return "Passwords do not match";
        return null;
      },
    );
  }
}