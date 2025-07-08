import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DoseHistoryScreen extends StatefulWidget {
  const DoseHistoryScreen({super.key});

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  String _filter = 'all';
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _doseHistory = [];

@override
void initState() {
  super.initState();
  _fetchDoseHistory();
}

Future<void> _fetchDoseHistory() async {

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

  final response = await http.get(Uri.parse(
      'http://10.0.2.2:5000/api/medications/dose-history?userId=$userId'));

  if (response.statusCode == 200) {
    setState(() {
      _doseHistory = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    });
  } else {
    debugPrint('Failed to load dose history: ${response.body}');
  }
}


  Future<void> _clearDoseHistory() async {
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
    final response = await http.delete(Uri.parse(
        'http://10.0.2.2:5000/api/medications/clear-dose-history?userId=$userId'));
    if (response.statusCode == 200) {
      setState(() {
        _doseHistory.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dose history cleared')));
    }
  }
  List<Map<String, dynamic>> get _filteredHistory {
  return _doseHistory.where((entry) {
    DateTime doseDate = DateTime.parse(entry["timestamp"]).toLocal();
    
    if (_filter == "taken") {
      return entry["status"] == "taken";
    } else if (_filter == "missed") {
      return entry["status"] == "missed";
    } else if (_filter == "date" && _selectedDate != null) {
      return doseDate.year == _selectedDate!.year &&
             doseDate.month == _selectedDate!.month &&
             doseDate.day == _selectedDate!.day;
    }
    return true; 
  }).toList();
}

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _filter = 'date';
      });
    }
  }

  Widget _buildFilterButtons() {
    return Wrap(
      spacing: 10,
      children: [
        ChoiceChip(
          label: Text("All", style: Theme.of(context).textTheme.bodyMedium),
          selected: _filter == 'all',
          onSelected: (_) => setState(() => _filter = 'all'),
        ),

        ChoiceChip(
          label: const Text("Taken"),
          selected: _filter == 'taken',
          onSelected: (_) => setState(() => _filter = 'taken'),
        ),
        ChoiceChip(
          label: const Text("Missed"),
          selected: _filter == 'missed',
          onSelected: (_) => setState(() => _filter = 'missed'),
        ),
        ActionChip(
          label: Text(_selectedDate != null
              ? DateFormat.yMMMd().format(_selectedDate!)
              : "Pick Date"),
          onPressed: _pickDate,
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_filteredHistory.isEmpty) {
   return Padding(
  padding: const EdgeInsets.only(top: 40),
  child: Center(
    child: Text(
      "No dose history found.",
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  ),
);

    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        final dose = _filteredHistory[index];
        final dt = DateTime.parse(dose["timestamp"]).toLocal();

return Card(
  margin: const EdgeInsets.symmetric(vertical: 8),
  child: ListTile(
    title: Text(
      dose["medication"],
      style: Theme.of(context).textTheme.titleMedium,
    ),
    subtitle: Text(
      "Status: ${dose["status"].toString().toUpperCase()} - ${DateFormat.yMMMd().add_jm().format(dt)}",
      style: Theme.of(context).textTheme.bodySmall,
    ),
    leading: Icon(
      dose["status"] == "taken" ? Icons.check_circle : Icons.cancel_outlined,
      color: dose["status"] == "taken"
          ? Colors.green
          : Theme.of(context).colorScheme.error,
    ),
  ),
);

      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dose History"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,

        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
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
              final response = await http.delete(
                Uri.parse('http://10.0.2.2:5000/api/medications/clear-dose-history?userId=$userId'),
              );
              if (response.statusCode == 200) {
                setState(() {
                  _doseHistory.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("History cleared")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to clear history")),
                );
              }
            },
          )
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFilterButtons(),
            const SizedBox(height: 20),
            Expanded(child: _buildHistoryList()),
          ],
        ),
      ),
    );
  }
}
