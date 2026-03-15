import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Import your screens
import 'providers/theme_provider_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    debugPrint("✅ Firebase initialized successfully");
    // Initialize FCM: request permissions, set up background handler & listeners
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("❌ Firebase Initialization Error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const SmartBudgetApp(),
    ),
  );
}

class SmartBudgetApp extends StatelessWidget {
  const SmartBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kTealColor = Color(0xFF2B90B6);
    const Color kLimeColor = Color(0xFFADCF35);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Smart Student Budget Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: kTealColor, primary: kTealColor, secondary: kLimeColor),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: _buildInputTheme(kTealColor, Brightness.light),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: kTealColor, primary: kTealColor, secondary: kLimeColor, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        inputDecorationTheme: _buildInputTheme(kTealColor, Brightness.dark),
      ),

      // Define named routes for the logout/navigation logic
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },

      // The home is now the RootWrapper which decides the start screen
      home: const RootWrapper(),
    );
  }

  InputDecorationTheme _buildInputTheme(Color primaryColor, Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }
}

/// This class handles the logic: Onboarding -> Login -> Dashboard
class RootWrapper extends StatelessWidget {
  const RootWrapper({super.key});

  Future<bool> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    // Returns true if 'isFirstTime' is null (first launch)
    return prefs.getBool('isFirstTime') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstTime(),
      builder: (context, firstTimeSnapshot) {
        // While checking SharedPreferences, show a splash or loader
        if (firstTimeSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // 1. Check if it's the very first time opening the app
        if (firstTimeSnapshot.data == true) {
          return const OnboardingScreen();
        }

        // 2. If not first time, check if the user is already logged in
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (authSnapshot.hasData) {
              return const DashboardScreen(); // Logged in? Go to Dashboard
            } else {
              return const LoginScreen(); // Not logged in? Go to Login
            }
          },
        );
      },
    );
  }
}
