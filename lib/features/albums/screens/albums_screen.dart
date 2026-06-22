import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AlbumData {
  AlbumData({
    required this.title,
    required this.description,
    required this.category,
    required this.entries,
  });

  final String title;
  final String description;
  final String category;
  final List<PhotoDiaryEntry> entries;
}

class PhotoDiaryEntry {
  PhotoDiaryEntry({
    required this.imagePath,
    required this.description,
    required this.createdAt,
    required this.uploadedBy,
  });

  final String imagePath;
  final String description;
  final DateTime createdAt;
  final String uploadedBy;
}

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final List<AlbumData> albums = [
    AlbumData(
      title: 'Our Photo Diary',
      description: 'Daily memories, photos, and small moments together.',
      category: 'Memories',
      entries: [],
    ),
    AlbumData(
      title: 'Trips Together',
      description: 'Photos and memories from our adventures.',
      category: 'Travel',
      entries: [],
    ),
  ];

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String selectedCategory = 'Memories';

  final List<String> categories = [
    'Memories',
    'Travel',
    'Dates',
    'Family',
    'Special Events',
    'Other',
  ];

  void openAddAlbumModal() {
    titleController.clear();
    descriptionController.clear();
    selectedCategory = 'Memories';

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
                      'Create Photo Diary',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Album title',
                        hintText: 'Example: Our daily memories',
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          addAlbum(modalContext);
                        },
                        child: const Text('Save Album'),
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

  void addAlbum(BuildContext modalContext) {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      return;
    }

    setState(() {
      albums.add(
        AlbumData(
          title: title,
          description: description.isEmpty
              ? 'No description added.'
              : description,
          category: selectedCategory,
          entries: [],
        ),
      );
    });

    Navigator.pop(modalContext);
  }

  void deleteAlbum(int index) {
    setState(() {
      albums.removeAt(index);
    });
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Travel':
        return Icons.flight_takeoff;
      case 'Dates':
        return Icons.favorite;
      case 'Family':
        return Icons.groups;
      case 'Special Events':
        return Icons.celebration;
      case 'Other':
        return Icons.folder;
      default:
        return Icons.photo_library;
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
        title: const Text('Albums'),
        centerTitle: true,
      ),
      body: albums.isEmpty
          ? const Center(
              child: Text('No albums yet.', style: TextStyle(fontSize: 16)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: albums.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final album = albums[index];

                return Card(
                  child: ListTile(
                    leading: Icon(getCategoryIcon(album.category)),
                    title: Text(
                      album.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${album.category} • ${album.entries.length} photo entries\n${album.description}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AlbumDetailScreen(album: album),
                        ),
                      ).then((_) {
                        setState(() {});
                      });
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        deleteAlbum(index);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final AlbumData album;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final ImagePicker imagePicker = ImagePicker();
  final TextEditingController descriptionController = TextEditingController();

  String? selectedImagePath;

  void openAddPhotoEntryModal() {
    descriptionController.clear();
    selectedImagePath = null;

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
                      'Add Today’s Photo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final pickedImage = await imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );

                        if (pickedImage == null) return;

                        setModalState(() {
                          selectedImagePath = pickedImage.path;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        height: 190,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: selectedImagePath == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 54,
                                  ),
                                  SizedBox(height: 12),
                                  Text('Tap to select a photo'),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(
                                  File(selectedImagePath!),
                                  width: double.infinity,
                                  height: 190,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Write what happened in this memory...',
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
                          addPhotoEntry(modalContext);
                        },
                        child: const Text('Save Photo Entry'),
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

  void addPhotoEntry(BuildContext modalContext) {
    final description = descriptionController.text.trim();

    if (selectedImagePath == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a photo and add a description.'),
        ),
      );
      return;
    }

    setState(() {
      widget.album.entries.insert(
        0,
        PhotoDiaryEntry(
          imagePath: selectedImagePath!,
          description: description,
          createdAt: DateTime.now(),
          uploadedBy: 'You',
        ),
      );
    });

    Navigator.pop(modalContext);
  }

  void deletePhotoEntry(int index) {
    setState(() {
      widget.album.entries.removeAt(index);
    });
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool hasEntryOnDate(DateTime date) {
    return widget.album.entries.any(
      (entry) => isSameDay(entry.createdAt, date),
    );
  }

  int calculateCurrentStreak() {
    if (widget.album.entries.isEmpty) return 0;

    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (!hasEntryOnDate(today) && !hasEntryOnDate(yesterday)) {
      return 0;
    }

    DateTime currentDate = hasEntryOnDate(today) ? today : yesterday;
    int streak = 0;

    while (hasEntryOnDate(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int calculateLongestStreak() {
    if (widget.album.entries.isEmpty) return 0;

    final uniqueDates =
        widget.album.entries
            .map((entry) => dateOnly(entry.createdAt))
            .toSet()
            .toList()
          ..sort();

    int longest = 1;
    int current = 1;

    for (int i = 1; i < uniqueDates.length; i++) {
      final previousDate = uniqueDates[i - 1];
      final currentDate = uniqueDates[i];

      if (currentDate.difference(previousDate).inDays == 1) {
        current++;
      } else {
        current = 1;
      }

      if (current > longest) {
        longest = current;
      }
    }

    return longest;
  }

  String getStreakStatus() {
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (widget.album.entries.isEmpty) {
      return 'Start your first daily photo streak.';
    }

    if (hasEntryOnDate(today)) {
      return 'Active today. You kept the streak alive.';
    }

    if (hasEntryOnDate(yesterday)) {
      return 'At risk. Add today’s photo to keep the streak.';
    }

    return 'Streak lost. Add a photo today to start again.';
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
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStreak = calculateCurrentStreak();
    final longestStreak = calculateLongestStreak();

    return Scaffold(
      appBar: AppBar(title: Text(widget.album.title), centerTitle: true),
      body: Column(
        children: [
          _StreakSummaryCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            statusMessage: getStreakStatus(),
          ),
          Expanded(
            child: widget.album.entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No photo entries yet.\nAdd today’s photo to start your diary streak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: widget.album.entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final entry = widget.album.entries[index];

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.file(
                              File(entry.imagePath),
                              width: double.infinity,
                              height: 230,
                              fit: BoxFit.cover,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.description,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${formatDate(entry.createdAt)} • Uploaded by ${entry.uploadedBy}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        deletePhotoEntry(index);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddPhotoEntryModal,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Photo'),
      ),
    );
  }
}

class _StreakSummaryCard extends StatelessWidget {
  const _StreakSummaryCard({
    required this.currentStreak,
    required this.longestStreak,
    required this.statusMessage,
  });

  final int currentStreak;
  final int longestStreak;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, size: 46),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Streak: $currentStreak days',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Longest Streak: $longestStreak days'),
                  const SizedBox(height: 6),
                  Text(statusMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
