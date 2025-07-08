// settings_screen.dart
import 'package:shared_preferences/shared_preferences.dart'; // <-- ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../theme/theme_notifier.dart'; // Ensure correct path to your ThemeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool localOnlyMode = true;
  bool pharmacySync = false;

  // No need for 'themeNotifier.value' here, we'll use Provider.of
  // bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    // Get the ThemeNotifier instance using Provider.of
    // listen: true is the default, so the widget rebuilds when theme changes
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.currentTheme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text("🔔 Notification Preferences",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Enable Reminders"),
              value: notificationsEnabled,
              onChanged: (value) {
                setState(() => notificationsEnabled = value);
              },
            ),
            const SizedBox(height: 20),
            const Text("🔒 Privacy Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Local-only Mode"),
              value: localOnlyMode,
              onChanged: (value) {
                setState(() => localOnlyMode = value);
              },
            ),
            const SizedBox(height: 20),
            const Text("🏥 Pharmacy Sync",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text("Sync with Pharmacy"),
              value: pharmacySync,
              onChanged: (value) {
                setState(() => pharmacySync = value);
              },
            ),
            const SizedBox(height: 20),
            const Text("🌓 Theme",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            // Modified Theme Toggle SwitchListTile
            SwitchListTile(
              title: const Text("Dark Mode"),
              value: isDarkMode, // Use the isDarkMode boolean from themeNotifier
              onChanged: (bool value) {
                // Call the toggleTheme method on the themeNotifier instance.
                // The toggleTheme method in ThemeNotifier flips the theme internally
                // so it doesn't need the 'value' argument.
                themeNotifier.toggleTheme();
              },
            ),

            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isLoggedIn');

                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              },
            )
          ],
        ),
      ),
    );
  }
}