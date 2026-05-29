import 'package:flutter/material.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final List<Map<String, String>> trips = [
    {
      'title': 'Beach weekend',
      'city': 'Cartagena',
      'country': 'Colombia',
      'startDate': 'March 15, 2026',
      'endDate': 'March 18, 2026',
      'status': 'Planned',
      'notes': 'Book hotel and check restaurants nearby.',
    },
    {
      'title': 'Mountain escape',
      'city': 'Medellín',
      'country': 'Colombia',
      'startDate': 'June 10, 2026',
      'endDate': 'June 13, 2026',
      'status': 'Completed',
      'notes': 'Add photos later to the trip album.',
    },
  ];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String selectedStatus = 'Planned';

  final List<String> statusOptions = ['Planned', 'Completed'];

  void openAddTripModal() {
    titleController.clear();
    cityController.clear();
    countryController.clear();
    notesController.clear();
    selectedStartDate = null;
    selectedEndDate = null;
    selectedStatus = 'Planned';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add Trip',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Trip title',
                        hintText: 'Example: Weekend in Cartagena',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'Example: Cartagena',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countryController,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        hintText: 'Example: Colombia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setModalState(() {
                              selectedStartDate = pickedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          selectedStartDate == null
                              ? 'Select Start Date'
                              : formatDate(selectedStartDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setModalState(() {
                              selectedEndDate = pickedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          selectedEndDate == null
                              ? 'Select End Date'
                              : formatDate(selectedEndDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Status',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: statusOptions.map((status) {
                        final isSelected = selectedStatus == status;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (_) {
                              setModalState(() {
                                selectedStatus = status;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Add reservations, ideas, pending tasks...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          addTrip(modalContext);
                        },
                        child: const Text('Save Trip'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void addTrip(BuildContext modalContext) {
    final title = titleController.text.trim();
    final city = cityController.text.trim();
    final country = countryController.text.trim();
    final notes = notesController.text.trim();

    if (title.isEmpty ||
        city.isEmpty ||
        country.isEmpty ||
        selectedStartDate == null ||
        selectedEndDate == null) {
      return;
    }

    setState(() {
      trips.add({
        'title': title,
        'city': city,
        'country': country,
        'startDate': formatDate(selectedStartDate!),
        'endDate': formatDate(selectedEndDate!),
        'status': selectedStatus,
        'notes': notes.isEmpty ? 'No notes added.' : notes,
      });
    });

    Navigator.pop(modalContext);
  }

  void deleteTrip(int index) {
    setState(() {
      trips.removeAt(index);
    });
  }

  IconData getStatusIcon(String status) {
    if (status == 'Completed') {
      return Icons.check_circle;
    }

    return Icons.flight_takeoff;
  }

  String formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void dispose() {
    titleController.dispose();
    cityController.dispose();
    countryController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trips'), centerTitle: true),
      body: trips.isEmpty
          ? const Center(
              child: Text('No trips yet.', style: TextStyle(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: trips.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trip = trips[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: Icon(getStatusIcon(trip['status'] ?? 'Planned')),
                      title: Text(
                        trip['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${trip['city']}, ${trip['country']}\n'
                          '${trip['startDate']} - ${trip['endDate']}\n'
                          'Status: ${trip['status']}\n'
                          '${trip['notes']}',
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          deleteTrip(index);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddTripModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
