import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimahub_app/features/notes/controllers/notes_controller.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';

class ListEditorScreen extends StatefulWidget {
  const ListEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<ListEditorScreen> createState() => _ListEditorScreenState();
}

class _ListEditorScreenState extends State<ListEditorScreen> {
  final NotesController _notesController = NotesController.instance;

  late final TextEditingController _titleController;

  final Map<String, TextEditingController> _itemControllers = {};

  final Map<String, FocusNode> _itemFocusNodes = {};

  late List<NoteBlock> _items;
  late NoteBlockType _listType;

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();

    final page = _notesController.noteById(widget.noteId);

    _titleController = TextEditingController(text: page?.title ?? '');

    _items = List<NoteBlock>.from(page?.blocks ?? const []);

    if (_items.isEmpty) {
      _items.add(NoteBlock(id: _newItemId(), type: NoteBlockType.checklist));
    }

    final firstType = _items.first.type;

    _listType = _isListType(firstType) ? firstType : NoteBlockType.checklist;

    _items = _items.map((item) {
      return item.copyWith(type: _listType);
    }).toList();

    for (final item in _items) {
      _itemControllers[item.id] = TextEditingController(text: item.text);

      _itemFocusNodes[item.id] = FocusNode();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_persistList());

    _titleController.dispose();

    for (final controller in _itemControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _itemFocusNodes.values) {
      focusNode.dispose();
    }

    super.dispose();
  }

  bool _isListType(NoteBlockType type) {
    return type == NoteBlockType.checklist ||
        type == NoteBlockType.bulletList ||
        type == NoteBlockType.numberedList;
  }

  String _newItemId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();

    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistList());
    });
  }

  Future<void> _persistList() async {
    final currentPage = _notesController.noteById(widget.noteId);

    if (currentPage == null) {
      return;
    }

    await _notesController.updateNote(
      currentPage.copyWith(
        title: _titleController.text,
        kind: NotePageKind.list,
        blocks: List<NoteBlock>.from(_items),
      ),
    );
  }

  void _changeListType(NoteBlockType type) {
    setState(() {
      _listType = type;

      _items = _items.map((item) {
        return item.copyWith(type: type);
      }).toList();
    });

    _scheduleSave();
    HapticFeedback.selectionClick();
  }

  void _addItem({int? afterIndex}) {
    final item = NoteBlock(id: _newItemId(), type: _listType);

    final int insertIndex;

    if (afterIndex == null) {
      insertIndex = _items.length;
    } else {
      final nextIndex = afterIndex + 1;

      insertIndex = nextIndex > _items.length ? _items.length : nextIndex;
    }

    setState(() {
      _items.insert(insertIndex, item);

      _itemControllers[item.id] = TextEditingController();

      _itemFocusNodes[item.id] = FocusNode();
    });

    _scheduleSave();
    HapticFeedback.selectionClick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _itemFocusNodes[item.id]?.requestFocus();
    });
  }

  void _updateItem(int index, String text) {
    _items[index] = _items[index].copyWith(text: text);

    _scheduleSave();
  }

  void _toggleItem(int index, bool value) {
    setState(() {
      _items[index] = _items[index].copyWith(isChecked: value);
    });

    _scheduleSave();
    HapticFeedback.selectionClick();
  }

  void _deleteItem(int index) {
    if (_items.length == 1) {
      final item = _items.first;

      _itemControllers[item.id]?.clear();

      setState(() {
        _items[0] = item.copyWith(text: '', isChecked: false);
      });

      _scheduleSave();
      return;
    }

    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    _itemControllers.remove(removedItem.id)?.dispose();

    _itemFocusNodes.remove(removedItem.id)?.dispose();

    _scheduleSave();
  }

  void _reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex < 0 ||
        newIndex >= _items.length) {
      return;
    }

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    _scheduleSave();
    HapticFeedback.selectionClick();
  }

  Widget _buildPrefix(int index) {
    final item = _items[index];

    switch (_listType) {
      case NoteBlockType.checklist:
        return Checkbox(
          value: item.isChecked,
          activeColor: Colors.white,
          checkColor: Colors.black,
          side: const BorderSide(color: Colors.white70),
          onChanged: (value) {
            _toggleItem(index, value ?? false);
          },
        );

      case NoteBlockType.bulletList:
        return const SizedBox(
          width: 42,
          child: Center(
            child: Text(
              '•',
              style: TextStyle(color: Colors.white, fontSize: 25, height: 1),
            ),
          ),
        );

      case NoteBlockType.numberedList:
        return SizedBox(
          width: 42,
          child: Center(
            child: Text(
              '${index + 1}.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );

      default:
        return const SizedBox(width: 42);
    }
  }

  Widget _buildItem(NoteBlock item, int index) {
    final completed = _listType == NoteBlockType.checklist && item.isChecked;

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: completed ? 0.035 : 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: completed ? 0.08 : 0.13),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white.withValues(alpha: 0.30),
                size: 20,
              ),
            ),
          ),
          _buildPrefix(index),
          Expanded(
            child: TextField(
              controller: _itemControllers[item.id],
              focusNode: _itemFocusNodes[item.id],
              maxLines: null,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: completed ? Colors.white38 : Colors.white,
                fontSize: 15,
                height: 1.35,
                decoration: completed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
              decoration: InputDecoration(
                hintText: 'Nuevo elemento',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                _updateItem(index, value);
              },
              onSubmitted: (_) {
                _addItem(afterIndex: index);
              },
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => _deleteItem(index),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.white38,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((item) => item.isChecked).length;

    final progress = _items.isEmpty ? 0.0 : completedCount / _items.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Editar lista',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: TextField(
              controller: _titleController,
              maxLines: null,
              onChanged: (_) {
                _scheduleSave();
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Sin título',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<NoteBlockType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: NoteBlockType.checklist,
                    icon: Icon(Icons.check_box_outlined),
                    label: Text('Checks'),
                  ),
                  ButtonSegment(
                    value: NoteBlockType.bulletList,
                    icon: Icon(Icons.format_list_bulleted_rounded),
                    label: Text('Puntos'),
                  ),
                  ButtonSegment(
                    value: NoteBlockType.numberedList,
                    icon: Icon(Icons.format_list_numbered_rounded),
                    label: Text('Números'),
                  ),
                ],
                selected: {_listType},
                onSelectionChanged: (selection) {
                  _changeListType(selection.first);
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.black
                        : Colors.white70;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected)
                        ? Colors.white
                        : const Color(0xFF18191E);
                  }),
                ),
              ),
            ),
          ),

          if (_listType == NoteBlockType.checklist)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '$completedCount de ${_items.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorderItem: _reorderItems,
              itemBuilder: (context, index) {
                return _buildItem(_items[index], index);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _addItem,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Agregar elemento',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
