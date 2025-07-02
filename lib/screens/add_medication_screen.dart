// Line 1
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart'; // ✅ Line ~11
import 'package:medremm/main.dart'; // ✅ for notifications + navigatorKey

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final doseController = TextEditingController();
  final freqController = TextEditingController();
  TimeOfDay? selectedTime;
  String nextDose = '';

  void _showTimePicker(
    BuildContext context,
    Function(TimeOfDay, String) onTimeSelected,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      final nextDose =
          DateFormat.jm().format(selectedDateTime.add(const Duration(hours: 12)));
      onTimeSelected(picked, nextDose);
    }
  }

  Future<bool> _requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    const MethodChannel platform = MethodChannel('alarm_permission');

    try {
      final bool granted = await platform.invokeMethod('checkExactAlarmPermission');
      if (!granted) {
        await platform.invokeMethod('requestExactAlarmPermission');
        return false;
      }
      return true;
    } on PlatformException catch (e) {
      debugPrint("Permission error: $e");
      return false;
    }
  }

  Future<void> _scheduleNotification(String medName, TimeOfDay selectedTime) async {
    final now = DateTime.now();
    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledDate, tz.local)
            .isBefore(tz.TZDateTime.now(tz.local))
        ? tz.TZDateTime.from(scheduledDate, tz.local).add(const Duration(days: 1))
        : tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_reminder_channel',
      'Medication Reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'taken_action', 'Taken',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_action', 'Snooze',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
await flutterLocalNotificationsPlugin.zonedSchedule(
  DateTime.now().millisecondsSinceEpoch ~/ 1000,

  'Medication Reminder',
  'Take your medication: $medName 💊',
  tzTime,
  NotificationDetails(android: androidDetails),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
  payload: medName, 
);

  }

  void _saveMedication({
    required BuildContext context,
    required String name,
    required String dose,
    required String frequency,
    required TimeOfDay? selectedTime,
  }) async {
    if (name.isEmpty || dose.isEmpty || frequency.isEmpty || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final Map<String, dynamic> medData = {
      "userId": "abc123",
      "name": name.trim(),
      "dose": dose.trim(),
      "time": selectedTime.format(context),
      "startDate": DateTime.now().toIso8601String(),
      "endDate": DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      "takenHistory": [],
    };

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/medications/add'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(medData),
      );

      if (response.statusCode == 200) {
        bool permissionGranted = true;

        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          permissionGranted = await _requestExactAlarmPermission();
        }

        if (permissionGranted) {
          await _scheduleNotification(name, selectedTime);
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Medication saved & reminder scheduled!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving medication: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final freqController = TextEditingController();
    TimeOfDay? selectedTime;
    String nextDose = '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text('Add Medication', style: Theme.of(context).textTheme.titleLarge),
        iconTheme: Theme.of(context).appBarTheme.iconTheme ?? const IconThemeData(),

      ),
      body: StatefulBuilder(
        builder: (context, setLocalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Medication Name'),
                    validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                  ),
                  TextFormField(
                    controller: doseController,
                    decoration: const InputDecoration(labelText: 'Dose (e.g., 500mg)'),
                    validator: (value) => value!.isEmpty ? 'Please enter a dose' : null,
                  ),
                  TextFormField(
                    controller: freqController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Frequency (times/day)'),
                    validator: (value) => value!.isEmpty ? 'Please enter frequency' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Select Start Time: '),
                      TextButton(
                        onPressed: () {
                          _showTimePicker(context, (time, doseTime) {
                            setLocalState(() {
                              selectedTime = time;
                              nextDose = doseTime;
                            });
                          });
                        },
                        child: Text(
                          selectedTime != null
                              ? selectedTime!.format(context)
                              : 'Pick Time',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (nextDose.isNotEmpty)
                    Text(
                      'Next Dose: $nextDose',
                      style: Theme.of(context).textTheme.bodyMedium,

                    ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                   style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),

                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _saveMedication(
                          context: context,
                          name: nameController.text,
                          dose: doseController.text,
                          frequency: freqController.text,
                          selectedTime: selectedTime,
                        );
                      }
                    },
                    child: const Text('Save'),

                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
