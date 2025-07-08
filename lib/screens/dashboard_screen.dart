import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import for notifications
import 'package:medremm/main.dart'; // Import to access flutterLocalNotificationsPlugin
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_drawer.dart'; // Assuming this path is correct

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMedications();
  }

  // --- API Interaction Methods ---

  Future<void> fetchMedications() async {

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

    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/medications?userId=$userId'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List meds = jsonDecode(response.body);
        setState(() {
          _medications = meds.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        // Using ScaffoldMessenger.of(context) requires context to be mounted
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load medications')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching medications: $e')),
        );
      }
    }
  }

  Future<void> _updateMedicationStatus(String id, String statusType, String dose) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/medications/$id/logDose'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': statusType,
          'timestamp': DateTime.now().toIso8601String(),
          'dose': dose, // <<< --- Pass the dose value here!
        }),
      );

      if (context.mounted) { // Check if context is still valid
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dose marked as $statusType successfully!')),
          );
          await fetchMedications(); // Refresh the list after successful update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark dose as $statusType: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) { // Check if context is still valid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking dose: $e')),
        );
      }
    }
  }

  Future<void> deleteMedication(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:5000/api/medications/$id'),
      );

      if (context.mounted) { // Check if context is still valid
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication deleted')),
          );
          // Also cancel any scheduled notifications for this medication
          await _cancelAllNotificationsForMedication(id); // Call the helper function
          await fetchMedications(); // Refresh after deletion
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) { // Check if context is still valid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting medication: $e')),
        );
      }
    }
  }

  // --- Notification Cancellation Helper (Copied from previous example) ---
  Future<void> _cancelAllNotificationsForMedication(String medId) async {
    final List<PendingNotificationRequest> pendingNotifications =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests(); // No need for .then((value) => value.toList()) in newer versions

    for (var notification in pendingNotifications) {
      if (notification.payload != null) {
        try {
          final Map<String, dynamic> payload = jsonDecode(notification.payload!);
          if (payload['medId'] == medId) {
            await flutterLocalNotificationsPlugin.cancel(notification.id);
            print('Cancelled existing notification ID: ${notification.id} for medId: $medId');
          }
        } catch (e) {
          print('Error decoding payload for cancellation check: $e');
        }
      }
    }
    print('Attempted to cancel all existing notifications for medication ID: $medId');
  }

  // --- UI Related Methods ---

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              deleteMedication(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Medications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _medications.isEmpty
                      ? Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medication_outlined,
                                    size: 80, color: Colors.brown),
                                const SizedBox(height: 10),
                                Text(
                                  "No medications added yet!",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    // Await the result from AddMedicationScreen
                                    final result = await Navigator.pushNamed(context, '/add');
                                    if (result == true) {
                                      await fetchMedications(); // Refresh if true is returned
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text("Add Medication"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    textStyle: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            itemCount: _medications.length,
                            itemBuilder: (context, index) {
                              final med = _medications[index];
                              // Safely access fields, providing fallbacks
                              final String medicationName = med['name'] ?? 'N/A';
                              final String dose = med['dose']?.toString() ?? 'N/A';
                              final String doseTimes = (med['doseTimes'] is List)
                                  ? (med['doseTimes'] as List).join(', ')
                                  : (med['doseTimes'] ?? 'N/A');
                              final String mealRelation = med['mealRelation'] ?? 'N/A';
                              final int currentTabs = med['currentTabs'] ?? 0;
                              final int totalTabs = med['totalTabs'] ?? 0;

                              // Use refillThreshold from backend if available, otherwise default
                              final int refillThreshold = med['refillThreshold'] ?? 5;

                              Color stockColor = Colors.grey[700]!;
                              String stockMessage = 'Current Tabs: $currentTabs / $totalTabs';
                              if (currentTabs <= refillThreshold && currentTabs > 0) {
                                stockColor = Colors.orange;
                                stockMessage = 'Low Stock: $currentTabs / $totalTabs - Reorder Soon!';
                              } else if (currentTabs == 0) {
                                stockColor = Colors.red;
                                stockMessage = 'Out of Stock!';
                              }

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$medicationName ($dose)',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textTheme.titleLarge?.color,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                onPressed: () async {
                                                  // Pass the entire medication object
                                                  // EditMedicationScreen also needs the flutterLocalNotificationsPlugin
                                                  final updated = await Navigator.pushNamed(
                                                    context,
                                                    '/edit',
                                                    arguments: med, // Pass the medication map
                                                  );
                                                  if (updated == true) await fetchMedications();
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _confirmDelete(med['_id']),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Dose Times: $doseTimes', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                                      Text('Relation to Meal: $mealRelation', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                                      Text(
                                        stockMessage,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stockColor),
                                      ),
                                      const SizedBox(height: 16),
                                      // --- Mark as Taken/Missed Buttons ---
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: currentTabs > 0
                                                  ? () => _updateMedicationStatus(med['_id'], 'taken', dose) // <<< --- Pass dose here!
                                                  : null, // Disable if out of stock
                                              icon: const Icon(Icons.check_circle_outline),
                                              label: const Text('Taken'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _updateMedicationStatus(med['_id'], 'missed', dose), // <<< --- Pass dose here!
                                              icon: const Icon(Icons.cancel_outlined),
                                              label: const Text('Missed'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 20),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Await the result from AddMedicationScreen
                          final result = await Navigator.pushNamed(context, '/add');
                          if (result == true) {
                            await fetchMedications(); // Refresh if true is returned
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Add Medication"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[400],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                        icon: const Icon(Icons.history),
                        label: const Text("Dose History"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[300],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Await the result from AddMedicationScreen for the FAB
          final result = await Navigator.pushNamed(context, '/add');
          if (result == true) {
            await fetchMedications(); // Refresh if true is returned
          }
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}