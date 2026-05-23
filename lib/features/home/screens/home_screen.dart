import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = [
      {'title': 'Albums', 'icon': Icons.photo_library},
      {'title': 'Notes', 'icon': Icons.note_alt},
      {'title': 'Budget', 'icon': Icons.account_balance_wallet},
      {'title': 'Important Dates', 'icon': Icons.event},
      {'title': 'Trips', 'icon': Icons.flight_takeoff},
      {'title': 'Goals', 'icon': Icons.flag},
      {'title': 'Date Planner', 'icon': Icons.favorite},
      {'title': 'Settings', 'icon': Icons.settings},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nimaluv',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final module = modules[index];

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${module['title']} coming soon')),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(module['icon'] as IconData, size: 42),
                    const SizedBox(height: 14),
                    Text(
                      module['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
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
