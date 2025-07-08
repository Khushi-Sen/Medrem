import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Assuming this path is correct
import 'custom_drawer.dart';

class RefillScreen extends StatefulWidget {
  const RefillScreen({super.key});

  @override
  State<RefillScreen> createState() => _RefillScreenState();
}

class _RefillScreenState extends State<RefillScreen> {
  List<Map<String, dynamic>> allMedications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllMedications();
  }

  Future<void> fetchAllMedications() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    // IMPORTANT: Add a check for userId
    if (userId == null) {
      print('RefillScreen: userId not found in SharedPreferences. Cannot fetch medications.');
      setState(() {
        isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        // Optionally, navigate to login screen if userId is null
        // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
      return;
    }

    print('RefillScreen: Fetching all meds for userId: $userId');

    final url = Uri.parse('http://10.0.2.2:5000/api/medications?userId=$userId');

    try {
      final response = await http.get(url);

      print('RefillScreen: API Response Status Code: ${response.statusCode}');
      print('RefillScreen: API Response Body: ${response.body}');

      if (context.mounted) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            allMedications = data.cast<Map<String, dynamic>>();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load medications: ${response.body}')),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('RefillScreen: Error fetching medications: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to server to get medications: $e')),
        );
      }
    }
  }

  Color _getStockColor(int currentTabs, int totalTabs) {
    if (totalTabs <= 0) return Colors.grey; // Handle cases where totalTabs is zero or not set
    // The previous percentage logic was not directly used for these thresholds.
    // Keeping current logic for consistency with previous code snippet.
    if (currentTabs <= 3) {
      return Colors.red.shade700;
    } else if (currentTabs <= 5) {
      return Colors.orange.shade700;
    } else if (currentTabs <= 10) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green.shade700;
    }
  }

  // --- MODIFIED: Function to delete medication ---
  // Renamed from _logDoseDone to _deleteMedication
  Future<void> _deleteMedication(String medId, String medName) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/medications/$medId'); // Target delete endpoint

    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        // DELETE requests typically don't have a body, or it's ignored by the server.
        // Removed the body that was sending 'status' and 'timestamp'.
      );

      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$medName has been removed from your list.')),
          );
          // Refresh the list after successful deletion
          await fetchAllMedications();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove $medName: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print('Error deleting medication: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to server to remove medication: $e')),
        );
      }
    }
  }

  // Existing refill medication logic (unchanged)
  Future<void> _refillMedication(String medId, int quantityToAdd) async {
    if (quantityToAdd <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity to add must be greater than 0')),
        );
      }
      return;
    }

    final url = Uri.parse('http://10.0.2.2:5000/api/medications/$medId/refill');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'quantityToAdd': quantityToAdd}),
      );

      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully refilled by $quantityToAdd tabs!')),
          );
          await fetchAllMedications(); // Refresh all meds list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to refill: ${response.body}')),
          );
        }
      }
    } catch (e) {
      print('Error refilling medication: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to server for refill: $e')),
        );
      }
    }
  }

  // Existing dialog to get refill quantity from user (unchanged)
  void _showRefillDialog(BuildContext context, String medId, String medName) {
    final TextEditingController quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Refill $medName'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity to Add',
              hintText: 'e.g., 30',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Refill'),
              onPressed: () {
                final int? quantity = int.tryParse(quantityController.text);
                if (quantity != null && quantity > 0) {
                  Navigator.of(dialogContext).pop();
                  _refillMedication(medId, quantity);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid positive number.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? colorScheme.surface,
        iconTheme: IconThemeData(color: colorScheme.primary),
        title: Text(
          'Medication Inventory',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: const CustomDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allMedications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No medications added yet!',
                        style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your medications to start tracking.',
                        style: textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: allMedications.length,
                    itemBuilder: (context, index) {
                      final med = allMedications[index];
                      final int currentTabs = med['currentTabs'] ?? 0;
                      final int totalTabs = med['totalTabs'] ?? 0;
                      final Color stockColor = _getStockColor(currentTabs, totalTabs);

                      // Determine if "Dose Done" (now "Delete") button should be shown
                      // Condition: currentTabs is 0 or less than 5 (i.e., currentTabs <= 4)
                      final bool showDeleteButton = currentTabs < 5;

                      return Card(
                        color: Theme.of(context).cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: stockColor, width: 2),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med['name'] ?? 'Medication Name',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Dosage: ${med['dose'] ?? 'N/A'}', style: textTheme.bodyMedium),
                              Text(
                                'Remaining: $currentTabs / $totalTabs',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: stockColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Refill Threshold: ${med['refillThreshold'] ?? 'N/A'}',
                                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Conditional rendering for the "Dose Done" (now "Delete") button
                                  if (showDeleteButton) // Show if currentTabs < 5
                                    TextButton.icon(
                                      onPressed: () {
                                        _deleteMedication(med['_id'], med['name']); // Call delete function
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 20), // Changed icon
                                      label: const Text('Delete Medication'), // Changed label
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700, // Changed color to red
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Refill Button (unchanged)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showRefillDialog(context, med['_id'], med['name']);
                                    },
                                    icon: const Icon(Icons.local_pharmacy, size: 20),
                                    label: const Text("Refill"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
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
    );
  }
}