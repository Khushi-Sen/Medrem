import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditMedicationScreen extends StatefulWidget {
  const EditMedicationScreen({super.key});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  TimeOfDay? selectedTime;
  late String medicationId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final med = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (med != null) {
      nameController.text = med['name'] ?? '';
      doseController.text = med['dose'] ?? '';
      selectedTime = _parseTimeFlexible(med['time']);
      medicationId = med['_id'];
    }
  }

  TimeOfDay _parseTimeFlexible(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 8, minute: 0);
    try {
      return TimeOfDay.fromDateTime(DateFormat.jm().parse(timeStr));
    } catch (_) {
      try {
        return TimeOfDay.fromDateTime(DateFormat.Hm().parse(timeStr));
      } catch (_) {
        return const TimeOfDay(hour: 8, minute: 0);
      }
    }
  }

  Future<void> _updateMedication() async {
    if (!_formKey.currentState!.validate() || selectedTime == null) return;

    final updatedData = {
      "name": nameController.text.trim(),
      "dose": doseController.text.trim(),
      "time": selectedTime!.format(context),
    };

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:5000/api/medications/$medicationId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Success"),
              content: const Text("Medication updated successfully!"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close alert
                    Navigator.of(context).pop(true); // Return true to dashboard
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD7CCC8),
        title: const Text("Edit Medication", style: TextStyle(color: Colors.brown)),
        iconTheme: const IconThemeData(color: Colors.brown),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medication Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: doseController,
                decoration: const InputDecoration(labelText: 'Dose'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Time:'),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _showTimePicker,
                    child: Text(
                      selectedTime?.format(context) ?? 'Pick Time',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _updateMedication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
