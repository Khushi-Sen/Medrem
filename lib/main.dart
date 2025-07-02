import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/theme_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_medication_screen.dart';
import 'screens/dose_history_screen.dart';
import 'screens/refill_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/EditMedicationScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Global instances
final ThemeNotifier themeNotifier = ThemeNotifier();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  tz.initializeTimeZones();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iOSInit = DarwinInitializationSettings();

  final InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iOSInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final String? medName = response.payload;

      if (medName != null &&
          (response.actionId == 'taken_action' || response.actionId == 'snooze_action')) {
        final status = response.actionId == 'taken_action' ? 'taken' : 'missed';

        final res = await http.post(
          Uri.parse('http://10.0.2.2:5000/api/medications/dose-history'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': 'abc123',
            'medication': medName,
            'status': status,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );

        print("📤 Dose history response: ${res.statusCode} - ${res.body}");
      }

      if (response.actionId == 'snooze_action') {
        print("⏰ Snoozing for 10 mins...");
        final now = DateTime.now().add(const Duration(minutes: 10));
        await flutterLocalNotificationsPlugin.zonedSchedule(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'Snoozed Reminder',
          'Take your medication now.',
          tz.TZDateTime.from(now, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'med_reminder_channel',
              'Medication Reminders',
              channelDescription: 'Channel for daily medication reminders',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: medName,
        );
      }
    },
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MedicationAdherenceApp(isLoggedIn: isLoggedIn));
}

class MedicationAdherenceApp extends StatelessWidget {
  final bool isLoggedIn;
  const MedicationAdherenceApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'TrackUrPills',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
            scaffoldBackgroundColor: const Color(0xFFF8F3EF),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFD7CCC8),
              iconTheme: IconThemeData(color: Colors.brown),
              titleTextStyle: TextStyle(
                color: Colors.brown,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: Colors.brown[300]!,
              secondary: Colors.brown,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black12,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          initialRoute: isLoggedIn ? '/dashboard' : '/login',
          routes: {
            '/': (context) => HomeScreen(),
            '/login': (context) => LoginScreen(),
            '/signup': (context) => SignUpScreen(),
            '/dashboard': (context) => DashboardScreen(),
            '/add': (context) => AddMedicationScreen(),
            '/history': (context) => DoseHistoryScreen(),
            '/refill': (context) => RefillScreen(),
            '/settings': (context) => SettingsScreen(),
            '/edit': (context) => EditMedicationScreen(),
          },
        );
      },
    );
  }
}
