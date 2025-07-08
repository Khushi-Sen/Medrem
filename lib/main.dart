import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'theme/theme_notifier.dart';
import 'package:medremm/theme/theme.dart';

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
    if (notificationResponse.payload != null) {
      try {
        final Map<String, dynamic> payload = jsonDecode(notificationResponse.payload!);
        final String actionType = notificationResponse.actionId!;
        final String? medId = payload['medId'];
        final int? originalNotificationId = payload['originalNotificationId'];
        final String? medName = payload['medName'];
        final String? medDose = payload['medDose'];

        if (medId != null) {
          if (actionType == 'taken_action' && medDose != null) {
            print("taken clicked");
            final res = await http.post(
              Uri.parse('http://10.0.2.2:5000/api/medications/$medId/logDose'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'status': 'taken',
                'timestamp': DateTime.now().toIso8601String(),
                'dose': medDose,
              }),
            );
            if (res.statusCode >= 200 && res.statusCode < 300 && originalNotificationId != null) {
              await flutterLocalNotificationsPlugin.cancel(originalNotificationId);
            }
          } else if (actionType == 'snooze_action') {
            if (originalNotificationId != null) {
              await flutterLocalNotificationsPlugin.cancel(originalNotificationId);
            }
            final tz.TZDateTime snoozedTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15));
            await flutterLocalNotificationsPlugin.zonedSchedule(
              (originalNotificationId ?? DateTime.now().millisecondsSinceEpoch) + 2000000,
              'Snoozed Reminder: ${medName ?? 'Medication'}',
              'Your dose of ${medName ?? 'medication'} is due. Take it now!',
              snoozedTime,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'med_reminder_channel_snooze',
                  'Medication Snooze',
                  channelDescription: 'Temporary snooze reminders for medications',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  //icon: "ic_notification"
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: jsonEncode({
                'medId': medId,
                'notificationType': 'snooze_temp',
                'medName': medName,
                'medDose': medDose,
              }),
            );
          }
        }
      } catch (_) {}
    }
  }
}

//  @pragma('vm:entry-point')
// void notificationTapaction(NotificationResponse notificationResponse) async {
//   tz.initializeTimeZones();
//   tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

//   print("Action clicked: ${notificationResponse.actionId}");
//   print("Payload: ${notificationResponse.payload}");

//   if (notificationResponse.actionId == "id_snooze") {
//     print("Snooze clicked: schedule after 5 min");

//     // Cancel current scheduled notifications (if any)
//     await flutterLocalNotificationsPlugin.cancelAll();

//     // Schedule snoozed notification after 5 min
//     await flutterLocalNotificationsPlugin.zonedSchedule(
//       1,
//       "Snoozed Notification",
//       "Reminder after snooze",
//       tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)),
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'snooze_channel_id',
//           'Snooze Notifications',
//           channelDescription: 'Notifications after snooze',
//           importance: Importance.max,
//           priority: Priority.high,
//           //icon: 'ic_notification',
//           actions: [
//             AndroidNotificationAction("id_snooze", "Snooze again"),
//           ],
//         ),
//       ),
//       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,    );
//     // After snooze, start the repeating reminder
//     await flutterLocalNotificationsPlugin.periodicallyShowWithDuration(
//       2,
//       "Auto Reminder",
//       "You haven’t acted on this!",
//       Duration(minutes: 15),
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'reminder_channel_id',
//           'Auto Reminder Notifications',
//           channelDescription: 'Reminds if no action taken',
//           importance: Importance.max,
//           priority: Priority.high,
//           //icon: 'ic_notification',
//           actions: [
//             AndroidNotificationAction("id_snooze", "Snooze again"),
//           ],
//         ),
//       ),
//     );

//   } else {
//     // Handle other actions or main tap
//     print("Notification was tapped or another action clicked");
//     // Cancel reminders since user acted
//     await flutterLocalNotificationsPlugin.cancelAll();
//   }
// }


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print("notification tapped");
      print("Action id:${response.actionId}");
      notificationTapBackground(response);
      
      if (response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
        if (response.payload != null) {
          try {
            final Map<String, dynamic> payload = jsonDecode(response.payload!);
            final String actionType = response.actionId!;
            final String? medId = payload['medId'];
            final int? originalNotificationId = payload['originalNotificationId'] ?? payload['id'];
            final String? medName = payload['medName'];
            final String? medDose = payload['medDose'];

            if (medId != null) {
              if (actionType == 'taken_action' && medDose != null) {
                final res = await http.post(
                  Uri.parse('http://10.0.2.2:5000/api/medications/$medId/logDose'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'status': 'taken',
                    'timestamp': DateTime.now().toIso8601String(),
                    'dose': medDose,
                  }),
                );
                if (res.statusCode >= 200 && res.statusCode < 300 && originalNotificationId != null) {
                  await flutterLocalNotificationsPlugin.cancel(originalNotificationId);
                }
              } else if (actionType == 'snooze_action') {
                if (originalNotificationId != null) {
                  await flutterLocalNotificationsPlugin.cancel(originalNotificationId);
                }
                final tz.TZDateTime snoozedTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15));
                await flutterLocalNotificationsPlugin.zonedSchedule(
                  (originalNotificationId ?? DateTime.now().millisecondsSinceEpoch) + 2000000,
                  'Snoozed Reminder: ${medName ?? 'Medication'}',
                  'Your dose of ${medName ?? 'medication'} is due. Take it now!',
                  snoozedTime,
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'med_reminder_channel_snooze',
                      'Medication Snooze',
                      channelDescription: 'Temporary snooze reminders for medications',
                      importance: Importance.max,
                      priority: Priority.high,
                      playSound: true,
                    ),
                  ),
                  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                  payload: jsonEncode({
                    'medId': medId,
                    'notificationType': 'snooze_temp',
                    'medName': medName,
                    'medDose': medDose,
                  }),
                );
              }
            }
          } catch (_) {}
        }
      }
    }
  );


  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  final themeNotifier = ThemeNotifier(appLightTheme);
  await themeNotifier.loadTheme();

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeNotifier,
      child: MedicationAdherenceApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MedicationAdherenceApp extends StatelessWidget {
  final bool isLoggedIn;
  const MedicationAdherenceApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TrackUrPills',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.currentTheme.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      initialRoute: isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/': (_) => HomeScreen(),
        '/login': (_) => LoginScreen(),
        '/signup': (_) => SignUpScreen(),
        '/dashboard': (_) => DashboardScreen(),
        '/add': (_) => AddMedicationScreen(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin),
        '/history': (_) => DoseHistoryScreen(),
        '/refill': (_) => RefillScreen(),
        '/settings': (_) => SettingsScreen(),
        '/edit': (_) => EditMedicationScreen(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin),
      },
    );
  }
}
