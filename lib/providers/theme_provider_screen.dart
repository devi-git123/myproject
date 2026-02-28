import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. THE THEME LOGIC
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // This tells the app to refresh colors
  }
}

// 2. THE THEME UI SCREEN
class ThemeProviderScreen extends StatelessWidget {
  const ThemeProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Connect to the logic above
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Appearance", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Colors.green,
                ),
                title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  activeThumbColor: Colors.green,
                  onChanged: (value) {
                    themeProvider.toggleTheme(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}