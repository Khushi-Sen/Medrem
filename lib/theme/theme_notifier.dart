import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart'; // Import your custom theme definitions
import 'package:medremm/theme/theme.dart'; // <-- ADD THIS IMPORT

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  static const String _themeKey = 'isDarkMode'; // Key for SharedPreferences

  // Constructor now takes an initial ThemeData
  ThemeNotifier(this._currentTheme);

  ThemeData get currentTheme => _currentTheme;

  // Load the saved theme preference from SharedPreferences
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_themeKey) ?? false; // Default to light if not found
    _currentTheme = isDarkMode ? appDarkTheme : appLightTheme; // Use YOUR custom app themes
    notifyListeners();
  }

  // Toggle theme and save preference
  void toggleTheme() async { // This method takes NO arguments
    final prefs = await SharedPreferences.getInstance();
    if (_currentTheme.brightness == Brightness.light) {
      _currentTheme = appDarkTheme; // Switch to your custom darkTheme
      prefs.setBool(_themeKey, true); // Save true for dark mode
    } else {
      _currentTheme = appLightTheme; // Switch to your custom lightTheme
      prefs.setBool(_themeKey, false); // Save false for light mode
    }
    notifyListeners(); // Notify listeners to rebuild UI
  }
}