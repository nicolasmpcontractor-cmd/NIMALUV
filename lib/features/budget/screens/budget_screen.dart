import 'package:flutter/material.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final List<Map<String, dynamic>> expenses = [
    {
      'title': 'Dinner',
      'amount': 45.0,
      'category': 'Date',
      'paidBy': 'You',
      'date': 'February 14, 2026',
    },
    {
      'title': 'Movie tickets',
      'amount': 25.0,
      'category': 'Entertainment',
      'paidBy': 'Partner',
      'date': 'February 14, 2026',
    },
  ];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  String selectedCategory = 'Date';
  String selectedPaidBy = 'You';
  DateTime? selectedDate;

  final List<String> categories = [
    'Date',
    'Food',
    'Travel',
    'Home',
    'Gift',
    'Entertainment',
    'Savings',
    'Other',
  ];

  final List<String> paidByOptions = ['You', 'Partner'];

  double get totalSpent {
    return expenses.fold(
      0,
      (sum, expense) => sum + (expense['amount'] as double),
    );
  }

  double get youPaid {
    return expenses
        .where((expense) => expense['paidBy'] == 'You')
        .fold(0, (sum, expense) => sum + (expense['amount'] as double));
  }

  double get partnerPaid {
    return expenses
        .where((expense) => expense['paidBy'] == 'Partner')
        .fold(0, (sum, expense) => sum + (expense['amount'] as double));
  }

  String get balanceMessage {
    final eachShare = totalSpent / 2;
    final youBalance = youPaid - eachShare;

    if (expenses.isEmpty || youBalance == 0) {
      return 'Both are even.';
    }

    if (youBalance > 0) {
      return 'Partner owes you \$${youBalance.toStringAsFixed(2)}';
    }

    return 'You owe partner \$${youBalance.abs().toStringAsFixed(2)}';
  }

  void openAddExpenseModal() {
    titleController.clear();
    amountController.clear();
    selectedCategory = 'Date';
    selectedPaidBy = 'You';
    selectedDate = null;

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
                      'Add Expense',
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
                        hintText: 'Example: Dinner',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Example: 45.50',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setModalState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPaidBy,
                      decoration: const InputDecoration(
                        labelText: 'Paid by',
                        border: OutlineInputBorder(),
                      ),
                      items: paidByOptions.map((person) {
                        return DropdownMenuItem(
                          value: person,
                          child: Text(person),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setModalState(() {
                          selectedPaidBy = value;
                        });
                      },
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
                          addExpense(modalContext);
                        },
                        child: const Text('Save Expense'),
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

  void addExpense(BuildContext modalContext) {
    final title = titleController.text.trim();
    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty ||
        amount == null ||
        amount <= 0 ||
        selectedDate == null) {
      return;
    }

    setState(() {
      expenses.add({
        'title': title,
        'amount': amount,
        'category': selectedCategory,
        'paidBy': selectedPaidBy,
        'date': formatDate(selectedDate!),
      });
    });

    Navigator.pop(modalContext);
  }

  void deleteExpense(int index) {
    setState(() {
      expenses.removeAt(index);
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
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Budget'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      'Couple Budget Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(
                      label: 'Total spent',
                      value: '\$${totalSpent.toStringAsFixed(2)}',
                    ),
                    _SummaryRow(
                      label: 'You paid',
                      value: '\$${youPaid.toStringAsFixed(2)}',
                    ),
                    _SummaryRow(
                      label: 'Partner paid',
                      value: '\$${partnerPaid.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 28),
                    Text(
                      balanceMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Text(
                      'No expenses yet.',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: expenses.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final expense = expenses[index];

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet),
                          title: Text(
                            expense['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${expense['category']} • Paid by ${expense['paidBy']}\n${expense['date']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${(expense['amount'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  deleteExpense(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
