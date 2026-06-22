import 'package:flutter/material.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<Map<String, String>> goals = [
    {
      'title': 'Save for our first trip',
      'description': 'Create a small travel fund together.',
      'status': 'In Progress',
    },
    {
      'title': 'Try 10 new restaurants',
      'description': 'Explore new places and keep memories.',
      'status': 'Pending',
    },
  ];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedStatus = 'Pending';

  final List<String> statusOptions = ['Pending', 'In Progress', 'Completed'];

  void openAddGoalModal() {
    titleController.clear();
    descriptionController.clear();
    selectedStatus = 'Pending';

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
                    'Add Couple Goal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Goal title',
                      hintText: 'Example: Travel to Paris',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Write a short description...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setModalState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        addGoal(modalContext);
                      },
                      child: const Text('Save Goal'),
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

  void addGoal(BuildContext modalContext) {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      return;
    }

    setState(() {
      goals.add({
        'title': title,
        'description': description,
        'status': selectedStatus,
      });
    });

    Navigator.pop(modalContext);
  }

  void deleteGoal(int index) {
    setState(() {
      goals.removeAt(index);
    });
  }

  void updateGoalStatus(int index, String newStatus) {
    setState(() {
      goals[index]['status'] = newStatus;
    });
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'In Progress':
        return Icons.timelapse;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Goals'),
      ),
      body: goals.isEmpty
          ? const Center(
              child: Text('No goals yet.', style: TextStyle(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: goals.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final goal = goals[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            getStatusIcon(goal['status'] ?? 'Pending'),
                          ),
                          title: Text(
                            goal['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(goal['description'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              deleteGoal(index);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: goal['status'],
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            updateGoalStatus(index, value);
                          },
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
