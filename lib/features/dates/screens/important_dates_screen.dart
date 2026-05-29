import 'package:flutter/material.dart';

class ImportantDatesScreen extends StatefulWidget {
  const ImportantDatesScreen({super.key});

  @override
  State<ImportantDatesScreen> createState() => _ImportantDatesScreenState();
}

class _ImportantDatesScreenState extends State<ImportantDatesScreen> {
  final List<Map<String, String>> importantDates = [
    {'title': 'Anniversary', 'date': 'January 15, 2026'},
    {'title': 'First Trip Together', 'date': 'March 22, 2026'},
  ];

  final TextEditingController titleController = TextEditingController();

  DateTime? selectedDate;

  void openAddDateModal() {
    titleController.clear();
    selectedDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                    'Add Important Date',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Example: Our anniversary',
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        addImportantDate(modalContext);
                      },
                      child: const Text('Save Date'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void addImportantDate(BuildContext modalContext) {
    final title = titleController.text.trim();

    if (title.isEmpty || selectedDate == null) {
      return;
    }

    setState(() {
      importantDates.add({'title': title, 'date': formatDate(selectedDate!)});
    });

    Navigator.pop(modalContext);
  }

  void deleteImportantDate(int index) {
    setState(() {
      importantDates.removeAt(index);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Important Dates'), centerTitle: true),
      body: importantDates.isEmpty
          ? const Center(
              child: Text(
                'No important dates yet.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: importantDates.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = importantDates[index];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(item['title'] ?? ''),
                    subtitle: Text(item['date'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        deleteImportantDate(index);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDateModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
