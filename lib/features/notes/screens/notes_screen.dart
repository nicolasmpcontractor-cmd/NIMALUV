import 'package:flutter/material.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final List<String> notes = [
    'Plan our next trip',
    'Restaurants we want to try',
    'Gift ideas',
  ];

  final TextEditingController noteController = TextEditingController();

  void addNote() {
    final noteText = noteController.text.trim();

    if (noteText.isEmpty) {
      return;
    }

    setState(() {
      notes.add(noteText);
    });

    noteController.clear();
    Navigator.pop(context);
  }

  void deleteNote(int index) {
    setState(() {
      notes.removeAt(index);
    });
  }

  void openAddNoteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
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
                'Add New Note',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Write something you both want to remember...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: addNote,
                  child: const Text('Save Note'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes'), centerTitle: true),
      body: notes.isEmpty
          ? const Center(
              child: Text('No notes yet.', style: TextStyle(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.note_alt),
                    title: Text(notes[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        deleteNote(index);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddNoteModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
