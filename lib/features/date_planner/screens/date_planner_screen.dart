import 'package:flutter/material.dart';

class DatePlannerScreen extends StatefulWidget {
  const DatePlannerScreen({super.key});

  @override
  State<DatePlannerScreen> createState() => _DatePlannerScreenState();
}

class _DatePlannerScreenState extends State<DatePlannerScreen> {
  final List<Map<String, String>> datePlans = [
    {
      'title': 'Dinner night',
      'place': 'Italian restaurant',
      'date': 'February 14, 2026',
      'time': '7:00 PM',
      'notes': 'Make a reservation one week before.',
    },
    {
      'title': 'Movie date',
      'place': 'Cinema',
      'date': 'March 5, 2026',
      'time': '8:30 PM',
      'notes': 'Check movie options.',
    },
  ];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController placeController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  void openAddDatePlanModal() {
    titleController.clear();
    placeController.clear();
    notesController.clear();
    selectedDate = null;
    selectedTime = null;

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
                      'Plan a Date',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Example: Dinner date',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(
                        labelText: 'Place',
                        hintText: 'Example: Favorite restaurant',
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
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          selectedDate == null
                              ? 'Select Date'
                              : formatDate(selectedDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );

                          if (pickedTime != null) {
                            setModalState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          selectedTime == null
                              ? 'Select Time'
                              : selectedTime!.format(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Add details, reservation notes, ideas...',
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
                          addDatePlan(modalContext);
                        },
                        child: const Text('Save Plan'),
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

  void addDatePlan(BuildContext modalContext) {
    final title = titleController.text.trim();
    final place = placeController.text.trim();
    final notes = notesController.text.trim();

    if (title.isEmpty || selectedDate == null || selectedTime == null) {
      return;
    }

    setState(() {
      datePlans.add({
        'title': title,
        'place': place.isEmpty ? 'No place added' : place,
        'date': formatDate(selectedDate!),
        'time': selectedTime!.format(context),
        'notes': notes.isEmpty ? 'No notes added' : notes,
      });
    });

    Navigator.pop(modalContext);
  }

  void deleteDatePlan(int index) {
    setState(() {
      datePlans.removeAt(index);
    });
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
    placeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Date Planner'), centerTitle: true),
      body: datePlans.isEmpty
          ? const Center(
              child: Text('No date plans yet.', style: TextStyle(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: datePlans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final datePlan = datePlans[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: const Icon(Icons.favorite),
                      title: Text(
                        datePlan['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${datePlan['place']}\n${datePlan['date']} at ${datePlan['time']}\n${datePlan['notes']}',
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          deleteDatePlan(index);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDatePlanModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
