import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Add imports for notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
// import 'package:medremm/main.dart'; // To access the global navigatorKey and plugin instance

// --- Constants (copied from add_medication_screen for consistency) ---
const List<String> _availableDoseTimes = ['Morning', 'Afternoon', 'Evening'];
const List<String> _mealRelations = ['Before Meal', 'After Meal', 'Anytime', 'With Food'];

// Define the time slots for notifications (copied from add_medication_screen)
final Map<String, TimeOfDay> _doseTimeSlots = {
  'Morning': const TimeOfDay(hour: 7, minute: 0),
  'Afternoon': const TimeOfDay(hour: 12, minute: 30),
  'Evening': const TimeOfDay(hour: 19, minute: 30),
};

class EditMedicationScreen extends StatefulWidget {
  // Add the FlutterLocalNotificationsPlugin to the constructor
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const EditMedicationScreen({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController _totalTabsController = TextEditingController(); // New: for totalTabs
  late String medicationId;

  // Modified to handle multiple dose times and meal relation
  List<String> _selectedDoseTimes = [];
  String _selectedMealRelation = _mealRelations.first; // Default or initialize from loaded data

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final med = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (med != null) {
      medicationId = med['_id'] as String;
      nameController.text = med['name'] ?? '';
      doseController.text = med['dose'] ?? '';

      // Initialize dose times
      if (med['doseTimes'] != null) {
        _selectedDoseTimes = List<String>.from(med['doseTimes']);
      } else {
        _selectedDoseTimes = []; // Default to empty if no dose times
      }

      // Initialize meal relation
      _selectedMealRelation = med['mealRelation'] ?? _mealRelations.first;

      // Initialize total tabs
      _totalTabsController.text = (med['totalTabs'] ?? 0).toString();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    _totalTabsController.dispose(); // Dispose new controller
    super.dispose();
  }

  // _parseTimeFlexible is no longer needed as we're using _doseTimeSlots and string names
  // TimeOfDay _parseTimeFlexible(String? timeStr) {
  //   if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 8, minute: 0);
  //   try {
  //     return TimeOfDay.fromDateTime(DateFormat.jm().parse(timeStr));
  //   } catch (_) {
  //     try {
  //       return TimeOfDay.fromDateTime(DateFormat.Hm().parse(timeStr));
  //     } catch (_) {
  //       return const TimeOfDay(hour: 8, minute: 0);
  //     }
  //   }
  // }

  /// Schedules all necessary notifications for a given medication.
  /// (Copied from add_medication_screen.dart)
  Future<void> _scheduleNotificationsForMedication(Map<String, dynamic> medData) async {
    final String medName = medData['name'];
    final String medId = medData['_id'];
    final String mealRelation = medData['mealRelation'];
    final String medDose = medData['dose'];
    final List<String> doseTimes = List<String>.from(medData['doseTimes']);

    print('Scheduling notifications for medId: $medId, medName: $medName, medDose: $medDose, doseTimes: $doseTimes');

    for (int i = 0; i < doseTimes.length; i++) {
      String doseTime = doseTimes[i];
      final TimeOfDay startTime = _doseTimeSlots[doseTime]!;

      final int baseNotificationId = '${medId}_${i}'.hashCode % 2147483647;
      print('Generated baseNotificationId for $medName ($doseTime): $baseNotificationId');

      await _scheduleRepeatingReminder(baseNotificationId, medId, medName, mealRelation, medDose, startTime);
      await _scheduleMissedDoseCheck(baseNotificationId + 100000, medId, medName, mealRelation, medDose, startTime);
    }
  }

  /// Schedules a reminder that repeats every minute for 2 hours.
  /// (Copied from add_medication_screen.dart)
  Future<void> _scheduleRepeatingReminder(int id, String medId, String medName, String mealRelation, String medDose, TimeOfDay startTime) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final payloadData = jsonEncode({
        'medId': medId,
        'originalNotificationId': id,
        'notificationType': 'repeating_reminder',
        'medName': medName,
        'mealRelation': mealRelation,
        'medDose': medDose,
    });
    print('Payload for repeating reminder (ID: $id): $payloadData');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'med_reminder_channel_repeating',
      'Medication Reminders',
      channelDescription: 'Repeating reminders to take medication',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('taken_action', 'Taken', showsUserInterface: false),
        AndroidNotificationAction('snooze_action', 'Snooze (15 min)', showsUserInterface: false),
      ],
    );

    await widget.flutterLocalNotificationsPlugin.periodicallyShow(
      id,
      'Time for your medication!',
      'Take $medName ($mealRelation)',
      RepeatInterval.everyMinute,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payloadData,
    );
    print('Scheduled repeating reminder (ID: $id) for $medName at $scheduledTime, repeating every minute.');

    final tz.TZDateTime cancelTime = scheduledTime.add(const Duration(hours: 2));
    final cancelPayloadData = jsonEncode({
        'notificationType': 'cancel_task',
        'medId': medId,
        'idToCancel': id,
        'medDose': medDose,
    });
    print('Payload for cancel task (ID: ${id+1}): $cancelPayloadData');

    await widget.flutterLocalNotificationsPlugin.zonedSchedule(
      id + 1,
      'Stop Reminder for $medName',
      'Reminders for $medName have stopped for this slot.',
      cancelTime,
      const NotificationDetails(android: AndroidNotificationDetails(
        'cancel_channel',
        'Cancel Notifications',
        channelDescription: 'Channel for cancelling reminders.',
        importance: Importance.low,
      )),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: cancelPayloadData,
    );
    print('Scheduled cancellation (ID: ${id+1}) for repeating reminder (ID: $id) at $cancelTime');
  }

  /// Schedules a final check to see if the dose was missed.
  /// (Copied from add_medication_screen.dart)
  Future<void> _scheduleMissedDoseCheck(int id, String medId, String medName, String mealRelation, String medDose, TimeOfDay startTime) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime checkTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    ).add(const Duration(hours: 2));

    if (checkTime.isBefore(now)) {
      checkTime = checkTime.add(const Duration(days: 1));
    }

    final missedPayloadData = jsonEncode({
        'medId': medId,
        'notificationType': 'missed_check',
        'medName': medName,
        'medDose': medDose,
    });
    print('Payload for missed dose check (ID: $id): $missedPayloadData');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'missed_dose_channel',
      'Missed Dose Alerts',
      channelDescription: 'Alerts for when a medication dose is missed.',
      importance: Importance.defaultImportance,
    );

    await widget.flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Missed Dose Alert!',
      'It looks like you missed your dose of $medName ($mealRelation). Please update your record.',
      checkTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: missedPayloadData,
    );
    print('Scheduled missed dose check (ID: $id) for $medName at $checkTime');
  }


  Future<void> _cancelAllNotificationsForMedication(String medId) async {
    // Get all pending notifications
    final List<PendingNotificationRequest> pendingNotifications =
        await widget.flutterLocalNotificationsPlugin.pendingNotificationRequests();

    // Iterate and cancel those related to this medId
    for (var notification in pendingNotifications) {
      if (notification.payload != null) {
        try {
          final Map<String, dynamic> payload = jsonDecode(notification.payload!);
          if (payload['medId'] == medId) {
            await widget.flutterLocalNotificationsPlugin.cancel(notification.id);
            print('Cancelled existing notification ID: ${notification.id} for medId: $medId');
          }
        } catch (e) {
          print('Error decoding payload for cancellation check: $e');
        }
      }
    }
    print('Attempted to cancel all existing notifications for medication ID: $medId');
  }


  Future<void> _updateMedication() async {
    if (!_formKey.currentState!.validate() || _selectedDoseTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one dose time.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final updatedData = {
      "name": nameController.text.trim(),
      "dose": doseController.text.trim(),
      "doseTimes": _selectedDoseTimes, // Use the list of selected dose times
      "mealRelation": _selectedMealRelation, // Use the selected meal relation
      "totalTabs": int.tryParse(_totalTabsController.text) ?? 0, // Use the total tabs
      // Do NOT update _id directly
      // Do NOT update takenHistory directly here, use logDose for that
    };

    try {
      print('Attempting to update medication ID: $medicationId with data: ${jsonEncode(updatedData)}');
      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/api/medications/$medicationId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      if (context.mounted) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('Backend Response Body: ${response.body}');
          final Map<String, dynamic> responseBody = jsonDecode(response.body);
          final Map<String, dynamic> updatedMedData = responseBody;

          print('Medication updated successfully. Response: $responseBody');

          // --- Crucial Step: Cancel existing notifications and reschedule new ones ---
          await _cancelAllNotificationsForMedication(medicationId);
          await _scheduleNotificationsForMedication(updatedMedData); // Reschedule with updated data

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text("Success"),
              content: const Text("Medication updated and reminders re-scheduled!"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close alert
                    Navigator.of(context).pop(true); // Return true to dashboard to refresh
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else {
          print('Update failed: Status: ${response.statusCode}, Body: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Update failed: ${response.body}")),
          );
        }
      }
    } catch (e) {
      print('An error occurred during medication update: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // _showTimePicker is no longer directly applicable for selecting single time slots
  // void _showTimePicker() async {
  //   final picked = await showTimePicker(
  //     context: context,
  //     initialTime: selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
  //   );
  //   if (picked != null) setState(() => selectedTime = picked);
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD7CCC8),
        title: const Text("Edit Medication", style: TextStyle(color: Colors.brown)),
        iconTheme: const IconThemeData(color: Colors.brown),
      ),
      body: SingleChildScrollView( // Changed to SingleChildScrollView
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  border: OutlineInputBorder(), // Consistent styling
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
                validator: (value) => value!.isEmpty ? 'Medication name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: doseController,
                decoration: const InputDecoration(
                  labelText: 'Dose (e.g., "10mg", "5ml")',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                validator: (value) => value!.isEmpty ? 'Dose is required' : null,
              ),
              const SizedBox(height: 24),

              // --- Doses Per Day Selection (copied from AddMedicationScreen) ---
              Text(
                'Doses Per Day:',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _availableDoseTimes.map((time) {
                  final isSelected = _selectedDoseTimes.contains(time);
                  return FilterChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDoseTimes.add(time);
                        } else {
                          _selectedDoseTimes.remove(time);
                        }
                      });
                    },
                    selectedColor: theme.primaryColor.withOpacity(0.2),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- Meal Relation Selection (copied from AddMedicationScreen) ---
              Text(
                'When to Take:',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Column(
                children: _mealRelations.map((relation) {
                  return RadioListTile<String>(
                    title: Text(relation),
                    value: relation,
                    groupValue: _selectedMealRelation,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMealRelation = value;
                        });
                      }
                    },
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // --- Number of Tabs Input (copied from AddMedicationScreen) ---
              TextFormField(
                controller: _totalTabsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Medicines Available',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication_liquid_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the number of medicines';
                  }
                  if ((int.tryParse(value) ?? 0) <= 0) {
                    return 'Please enter a number greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox( // Added SizedBox for consistent button styling
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon( // Changed to ElevatedButton.icon for consistency
                  onPressed: _updateMedication,
                  icon: const Icon(Icons.save_alt_outlined, color: Colors.white),
                  label: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor, // Use theme primary color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Consistent border radius
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}