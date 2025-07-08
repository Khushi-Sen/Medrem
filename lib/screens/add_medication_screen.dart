import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:medremm/main.dart'; // Assuming your navigatorKey & notification handlers are there

const List<String> _availableDoseTimes = ['Morning', 'Afternoon', 'Evening'];
const List<String> _mealRelations = ['Before Meal', 'After Meal', 'Anytime', 'With Food'];

final Map<String, TimeOfDay> _doseTimeSlots = {
  'Morning': TimeOfDay(hour: 7, minute: 0),
  'Afternoon': TimeOfDay(hour: 12, minute: 10),
  'Evening': TimeOfDay(hour: 19, minute: 30),
};

class AddMedicationScreen extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const AddMedicationScreen({Key? key, required this.flutterLocalNotificationsPlugin}) : super(key: key);

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _totalTabsController = TextEditingController();
  final List<String> _selectedDoseTimes = [];
  String _selectedMealRelation = _mealRelations.first;

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); 
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _totalTabsController.dispose();
    super.dispose();
  }


// Future<void> _scheduleNotificationsForMedication1(Map<String, dynamic> medData) async {
//   final String medName = medData['name'];
//   final String medId = medData['_id'];
//   final String mealRelation = medData['mealRelation'];
//   final String medDose = medData['dose'];
//   final List<String> doseTimes = List<String>.from(medData['doseTimes']);

//   // --- IMPROVEMENT 1: Handle doseTimes safely and format for display ---
//   // Using the first dose time for startTime, or provide a default
//   final String doseTimeStr = doseTimes.isNotEmpty ? doseTimes[0] : "N/A";

//   // IMPORTANT: Ensure _doseTimeSlots is accessible and populated
//   // If this notification is for an immediate display (e.g., "Medication Added"),
//   // startTime might not be used for scheduling this 'show' notification.
//   // If you intend to schedule for a future time, you'd use flutterLocalNotificationsPlugin.zonedSchedule
//   // and resolve the TimeOfDay into a specific TZDateTime.
//   // final TimeOfDay? startTime = _doseTimeSlots[doseTimeStr]; // startTime can be null if key not found


//   // --- IMPROVEMENT 2: Better notification body formatting ---
//   final String notificationBody = "Dose: $medDose, Meal: $mealRelation. Times: ${doseTimes.join(', ')}";

//   final int baseId = '${medId}_1'.hashCode.abs() % 2147483647;

//   await flutterLocalNotificationsPlugin.show(
//     baseId,
//     "$medName",
//     notificationBody, // Using the formatted body
//     const NotificationDetails(
//       android: AndroidNotificationDetails(
//         'channel_id',
//         'channel_name',
//         channelDescription: 'channel_description',
//         importance: Importance.max,
//         priority: Priority.high,
//         // --- CHANGE: REMOVED ICON PROPERTY ---
//         // icon: 'ic_notification', // <--- REMOVED THIS LINE
//         actions: [
//           AndroidNotificationAction("id_taken", "Taken", showsUserInterface: true),
//           AndroidNotificationAction("id_snooze", "snooze", showsUserInterface: true),
//         ],
//       ),
//     ),
//     payload: jsonEncode({
//       'medId': medId,
//       'notificationType': 'medication_reminder',
//       'doseTimes': doseTimes,
//       'mealRelation': mealRelation,
//       'medName': medName,
//       'medDose': medDose,
//     }),
//   );
// }






  Future<void> _scheduleNotificationsForMedication(Map<String, dynamic> medData) async {
    final String medName = medData['name'];
    final String medId = medData['_id'];
    final String mealRelation = medData['mealRelation'];
    final String medDose = medData['dose'];
    final List<String> doseTimes = List<String>.from(medData['doseTimes']);

    for (int i = 0; i < doseTimes.length; i++) {
      final String doseTime = doseTimes[i];
      final TimeOfDay startTime = _doseTimeSlots[doseTime]!;
      final int baseId = '${medId}_$i'.hashCode.abs() % 2147483647;

      await _scheduleRepeatingReminder(baseId, medId, medName, mealRelation, medDose, startTime);
      await _scheduleMissedDoseCheck(baseId + 100000, medId, medName, mealRelation, medDose, startTime);
    }
  }

  Future<void> _scheduleRepeatingReminder(
  int id,
  String medId,
  String medName,
  String mealRelation,
  String medDose,
  TimeOfDay startTime
) async {
  print("Called schedule repeat reminder");
  final now = tz.TZDateTime.now(tz.local);
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

  final payload = jsonEncode({
    'medId': medId,
    'originalNotificationId': id,
    'notificationType': 'repeating_reminder',
    'medName': medName,
    'mealRelation': mealRelation,
    'medDose': medDose,
  });

  await widget.flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Time for your medication!',
    'Take $medDose of $medName ($mealRelation)',
    scheduledTime,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'med_reminder_channel_repeating',
        'Medication Reminders',
        channelDescription: 'Daily medication reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ticker: 'ticker',
        //icon: "ic_notification",
        actions: [
          AndroidNotificationAction('taken_action', 'Taken', showsUserInterface: true),
          AndroidNotificationAction('snooze_action', 'Snooze (15 min)', showsUserInterface: true),
        ],
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    
    matchDateTimeComponents: DateTimeComponents.time,  // daily at the same time
    payload: payload,
  );
  
}

  Future<void> _scheduleMissedDoseCheck(int id, String medId, String medName, String mealRelation, String medDose, TimeOfDay startTime) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime checkTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, startTime.hour, startTime.minute)
        .add(const Duration(hours: 2));
    if (checkTime.isBefore(now)) {
      checkTime = checkTime.add(const Duration(days: 1));
    }

    await widget.flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Missed Dose Alert!',
      'It looks like you missed your dose of $medName ($mealRelation).',
      checkTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'missed_dose_channel',
          'Missed Dose Alerts',
          channelDescription: 'Alerts for when a medication dose is missed.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          //icon: "ic_notification"
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        'medId': medId,
        'notificationType': 'missed_check',
        'medName': medName,
        'medDose': medDose,
      }),
    );
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedDoseTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one dose time.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

      // Retrieve userId from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId'); // No default here, assume user is logged in

  if (userId == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('User not logged in. Please log in again.'),
        backgroundColor: Colors.redAccent,
      ));
      // Optionally, navigate back to login screen
      // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
    return;
  }

    final medData = {
      "userId": userId,
      "name": _nameController.text.trim(),
      "dose": _doseController.text,
      "doseTimes": _selectedDoseTimes,
      "mealRelation": _selectedMealRelation,
      "totalTabs": int.tryParse(_totalTabsController.text) ?? 0,
      "currentTabs": int.tryParse(_totalTabsController.text) ?? 0,
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final savedMedData = jsonDecode(response.body)['medication'];
        if (savedMedData['_id'] != null) {
          print("calling schedule notification");
          await _scheduleNotificationsForMedication(savedMedData);
        }

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Medication saved & reminders scheduled!'),
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
          SnackBar(content: Text('Failed to save: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Medication'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, 'Medicine Name', Icons.medical_services_outlined, 'Please enter the medicine name'),
              const SizedBox(height: 16),
              _buildTextField(_doseController, 'Dose (e.g., "10mg")', Icons.fitness_center, 'Please enter the dose'),
              const SizedBox(height: 16),
              _buildTextField(_totalTabsController, 'Number of Medicines Available', Icons.medication_liquid_outlined,
                  'Please enter the number of medicines',
                  isNumber: true),
              const SizedBox(height: 24),
              _buildDoseTimeChips(theme),
              const SizedBox(height: 24),
              _buildMealRelationRadios(theme),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save Medication', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, String errorMsg, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return errorMsg;
        if (isNumber && (int.tryParse(value) ?? 0) <= 0) return 'Please enter a number greater than 0';
        return null;
      },
    );
  }

  Widget _buildDoseTimeChips(ThemeData theme) {
    return Wrap(
      spacing: 8,
      children: _availableDoseTimes.map((time) {
        final selected = _selectedDoseTimes.contains(time);
        return FilterChip(
          label: Text(time),
          selected: selected,
          onSelected: (val) {
            setState(() {
              val ? _selectedDoseTimes.add(time) : _selectedDoseTimes.remove(time);
            });
          },
          selectedColor: theme.primaryColor.withOpacity(0.2),
        );
      }).toList(),
    );
  }

  Widget _buildMealRelationRadios(ThemeData theme) {
    return Column(
      children: _mealRelations.map((relation) {
        return RadioListTile<String>(
          title: Text(relation),
          value: relation,
          groupValue: _selectedMealRelation,
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedMealRelation = val);
            }
          },
        );
      }).toList(),
    );
  }
}
