import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool localOnlyMode = true;
  bool pharmacySync = false;

  bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
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

            /// 🟡 FIXED: ValueListenableBuilder must return the widget inside it
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, themeMode, _) {
                return SwitchListTile(
                  title: const Text("Dark Mode"),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (bool value) {
                    themeNotifier.toggleTheme(value);
                  },
                );
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
