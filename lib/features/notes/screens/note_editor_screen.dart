// NIMAHUB_NOTE_EDITOR_WORD_STYLE_LISTS_V8
import 'dart:async';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimahub_app/features/notes/controllers/notes_controller.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';

enum _ToolbarListMode { paragraph, bullet, numbered, lettered, checklist }

enum _GroupEdgeDropSlot { none, top, bottom }

class _NoteSearchResult {
  const _NoteSearchResult({
    required this.blockId,
    required this.blockNumber,
    required this.label,
    required this.text,
    required this.query,
    required this.matchStart,
  });

  final String blockId;
  final int blockNumber;
  final String label;
  final String text;
  final String query;
  final int matchStart;
}

class _NoteRenderEntry {
  const _NoteRenderEntry.block({required this.blockIndexes}) : groupId = null;

  const _NoteRenderEntry.group({
    required this.groupId,
    required this.blockIndexes,
  });

  final String? groupId;
  final List<int> blockIndexes;

  bool get isGroup => groupId != null;

  int get firstBlockIndex => blockIndexes.first;
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final NotesController _notesController = NotesController.instance;
  static const double _editorContentLeft = 4;
  static const double _editorContentRight = 12;
  static const double _blockDragHandleWidth = 40;
  static const Color _groupBorderColor = Color(0xFF8A6A24);
  static const Color _groupBackgroundColor = Color(0x332D2411);
  static const double _groupDragPlaceholderHeight = 86;
  static const double _groupHeaderHeight = 50;

  static const String _dragNoGroupPreviewId = '__nimahub_drag_no_group__';

  static const List<NoteBlockType> _insertableBlockTypes = [
    NoteBlockType.paragraph,
    NoteBlockType.bulletList,
    NoteBlockType.numberedList,
    NoteBlockType.checklist,
    NoteBlockType.image,
    NoteBlockType.divider,
  ];

  static const List<int> _blockColorValues = <int>[
    // Neutros
    0xFF141519,
    0xFF24252A,
    0xFF34363D,
    0xFF4A4D57,

    // Azules
    0xFF16324F,
    0xFF1E4666,
    0xFF285B7A,
    0xFF244B72,

    // Turquesas
    0xFF164C55,
    0xFF1E5D63,
    0xFF286A73,

    // Verdes
    0xFF1E4935,
    0xFF285A42,
    0xFF356B4D,
    0xFF4B6643,

    // Morados
    0xFF342B59,
    0xFF49346A,
    0xFF5A3D75,
    0xFF684B78,

    // Rosados
    0xFF5A3048,
    0xFF713851,
    0xFF80445C,

    // Rojos
    0xFF592B2F,
    0xFF70343A,
    0xFF814247,

    // Marrones y cálidos
    0xFF5C4027,
    0xFF704C2D,
    0xFF785637,
    0xFF625737,
  ];

  static const List<String> _fontFamilies = <String>[
    'Inter',
    'Roboto',
    'Poppins',
    'Montserrat',
    'Lora',
    'Merriweather',
  ];

  static const List<double> _fontSizes = <double>[
    12,
    14,
    16,
    18,
    20,
    24,
    28,
    32,
  ];

  static const List<int> _textColorValues = <int>[
    0xFFFFFFFF,
    0xFFE8E8E8,
    0xFFBFC7D5,
    0xFF7EA7FF,
    0xFF65C7F7,
    0xFF67D5B5,
    0xFFA8D672,
    0xFFFFD166,
    0xFFFFA65C,
    0xFFFF7B7B,
    0xFFF285B8,
    0xFFC59BFF,
  ];

  late final TextEditingController _titleController;

  final Map<String, TextEditingController> _blockControllers = {};

  final Map<String, FocusNode> _blockFocusNodes = {};

  final Map<String, TextEditingController> _groupTitleControllers = {};

  final Map<String, FocusNode> _groupTitleFocusNodes = {};

  String? _draggingBlockId;
  String? _draggingGroupId;
  String? _dragPreviewGroupId;
  Offset? _lastDragGlobalPosition;
  _GroupEdgeDropSlot _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
  String? _blockedEdgePreviewGroupId;
  _GroupEdgeDropSlot _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;

  Map<int, int> _reorderIndexByBlockIndex = <int, int>{};

  final Map<String, GlobalKey> _groupViewportKeys = <String, GlobalKey>{};

  final Map<String, List<TextEditingController>> _listLineControllers = {};

  static const String _emptyListItemMarker = '\u200B';

  String _visibleListItemText(String value) {
    return value.replaceAll(_emptyListItemMarker, '');
  }

  String _editableListItemText(String value) {
    return value.isEmpty ? _emptyListItemMarker : value;
  }

  final Map<String, List<FocusNode>> _listLineFocusNodes = {};

  final Map<String, GlobalKey> _blockViewportKeys = <String, GlobalKey>{};

  Timer? _saveDebounce;

  late List<NoteBlock> _blocks;

  int? _activeBlockIndex;
  bool _isSlashMenuOpen = false;

  @override
  void initState() {
    super.initState();

    final note = _notesController.noteById(widget.noteId);

    _titleController = TextEditingController(text: note?.title ?? '');

    _blocks = (note?.blocks ?? const <NoteBlock>[])
        .map(_normalizeLegacyBlock)
        .toList();

    if (_blocks.isEmpty) {
      _blocks.add(NoteBlock(id: _newBlockId(), type: NoteBlockType.paragraph));
    }

    for (final block in _blocks) {
      _blockControllers[block.id] = TextEditingController(text: block.text);

      _blockFocusNodes[block.id] = FocusNode();

      if (_isWordListBlock(block)) {
        _createListEditorsForBlock(block);
      }
    }

    final initialActiveIndex = _blocks.indexWhere(
      (block) => block.type != NoteBlockType.divider,
    );

    _activeBlockIndex = initialActiveIndex == -1 ? null : initialActiveIndex;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();

    unawaited(_persistNote());

    _titleController.dispose();

    for (final controller in _blockControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _blockFocusNodes.values) {
      focusNode.dispose();
    }

    for (final controller in _groupTitleControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _groupTitleFocusNodes.values) {
      focusNode.dispose();
    }

    for (final controllers in _listLineControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    for (final focusNodes in _listLineFocusNodes.values) {
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    }

    super.dispose();
  }

  String _newBlockId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  bool _isWordListBlock(NoteBlock block) {
    return block.type == NoteBlockType.bulletList ||
        block.type == NoteBlockType.numberedList ||
        block.type == NoteBlockType.checklist;
  }

  List<String> _listLinesForBlock(NoteBlock block) {
    final normalizedText = block.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    if (normalizedText.isEmpty) {
      return <String>[''];
    }

    return normalizedText.split('\n');
  }

  List<bool> _checklistStatesForBlock(NoteBlock block, int lineCount) {
    return List<bool>.generate(lineCount, (index) {
      if (index < block.checklistStates.length) {
        return block.checklistStates[index];
      }

      if (index == 0 && block.isChecked) {
        return true;
      }

      return false;
    });
  }

  void _createListEditorsForBlock(NoteBlock block) {
    final lines = _listLinesForBlock(block);

    _listLineControllers[block.id] = lines
        .map((line) => TextEditingController(text: _editableListItemText(line)))
        .toList();

    _listLineFocusNodes[block.id] = List<FocusNode>.generate(
      lines.length,
      (_) => FocusNode(),
    );
  }

  void _disposeListEditorsForBlock(String blockId) {
    final controllers = _listLineControllers.remove(blockId);

    if (controllers != null) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    final focusNodes = _listLineFocusNodes.remove(blockId);

    if (focusNodes != null) {
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    }
  }

  void _replaceListEditorsForBlock(NoteBlock block) {
    _disposeListEditorsForBlock(block.id);
    _createListEditorsForBlock(block);
  }

  void _ensureListEditorsForBlock(NoteBlock block) {
    final expectedLineCount = _listLinesForBlock(block).length;
    final controllers = _listLineControllers[block.id];
    final focusNodes = _listLineFocusNodes[block.id];

    if (controllers == null ||
        focusNodes == null ||
        controllers.length != expectedLineCount ||
        focusNodes.length != expectedLineCount) {
      _replaceListEditorsForBlock(block);
    }
  }

  void _syncHiddenBlockController(NoteBlock block) {
    final controller = _blockControllers[block.id];

    if (controller == null || controller.text == block.text) {
      return;
    }

    controller.value = TextEditingValue(
      text: block.text,
      selection: TextSelection.collapsed(offset: block.text.length),
    );
  }

  String _newGroupId() {
    return 'group_${_newBlockId()}';
  }

  String? _effectiveGroupIdForBlock(NoteBlock block) {
    return _validGroupId(block.groupId);
  }

  String? _effectiveGroupIdAtIndex(int index) {
    if (index < 0 || index >= _blocks.length) {
      return null;
    }

    return _effectiveGroupIdForBlock(_blocks[index]);
  }

  bool _isGroupedBlock(NoteBlock block) {
    return _effectiveGroupIdForBlock(block) != null;
  }

  String _groupTitleForGroupId(String groupId) {
    for (final block in _blocks) {
      if (block.groupId == groupId && block.groupTitle.trim().isNotEmpty) {
        return block.groupTitle;
      }
    }

    return 'Grupo';
  }

  ({int start, int end}) _groupRangeForIndex(int index) {
    if (index < 0 || index >= _blocks.length) {
      return (start: index, end: index);
    }

    final groupId = _blocks[index].groupId;

    if (groupId == null || groupId.isEmpty) {
      return (start: index, end: index);
    }

    var start = index;
    var end = index;

    while (start > 0 && _blocks[start - 1].groupId == groupId) {
      start -= 1;
    }

    while (end < _blocks.length - 1 && _blocks[end + 1].groupId == groupId) {
      end += 1;
    }

    return (start: start, end: end);
  }

  int _groupSizeExcludingBlock(String groupId, String? excludedBlockId) {
    return _blocks.where((block) {
      return block.id != excludedBlockId &&
          _validGroupId(block.groupId) == groupId;
    }).length;
  }

  ({int start, int end})? _groupRangeInBlocks(
    List<NoteBlock> blocks,
    String groupId,
  ) {
    var start = -1;
    var end = -1;

    for (var i = 0; i < blocks.length; i++) {
      if (_validGroupId(blocks[i].groupId) != groupId) {
        continue;
      }

      if (start == -1) {
        start = i;
      }

      end = i;
    }

    if (start == -1 || end == -1) {
      return null;
    }

    return (start: start, end: end);
  }

  bool _isFirstBlockInGroup(int index) {
    final groupId = _effectiveGroupIdAtIndex(index);

    if (groupId == null) {
      return false;
    }

    return index == 0 || _effectiveGroupIdAtIndex(index - 1) != groupId;
  }

  bool _isLastBlockInGroup(int index) {
    final groupId = _effectiveGroupIdAtIndex(index);

    if (groupId == null) {
      return false;
    }

    return index == _blocks.length - 1 ||
        _effectiveGroupIdAtIndex(index + 1) != groupId;
  }

  bool _groupCollapsedInBlocks(List<NoteBlock> blocks, String groupId) {
    for (final block in blocks) {
      if (_validGroupId(block.groupId) == groupId) {
        return block.groupCollapsed;
      }
    }

    return false;
  }

  bool _isGroupCollapsed(String groupId) {
    return _groupCollapsedInBlocks(_blocks, groupId);
  }

  List<_NoteRenderEntry> _buildRenderEntriesForBlocks(List<NoteBlock> blocks) {
    final entries = <_NoteRenderEntry>[];
    var index = 0;

    while (index < blocks.length) {
      final groupId = _validGroupId(blocks[index].groupId);

      if (groupId == null || !_groupCollapsedInBlocks(blocks, groupId)) {
        entries.add(_NoteRenderEntry.block(blockIndexes: <int>[index]));
        index += 1;
        continue;
      }

      final groupedIndexes = <int>[];

      while (index < blocks.length &&
          _validGroupId(blocks[index].groupId) == groupId) {
        groupedIndexes.add(index);
        index += 1;
      }

      entries.add(
        _NoteRenderEntry.group(groupId: groupId, blockIndexes: groupedIndexes),
      );
    }

    return entries;
  }

  List<_NoteRenderEntry> _buildRenderEntries() {
    return _buildRenderEntriesForBlocks(_blocks);
  }

  Map<int, int> _buildReorderIndexMap(List<_NoteRenderEntry> entries) {
    final map = <int, int>{};

    for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
      for (final blockIndex in entries[entryIndex].blockIndexes) {
        map[blockIndex] = entryIndex;
      }
    }

    return map;
  }

  TextEditingController _groupTitleControllerFor(String groupId) {
    return _groupTitleControllers.putIfAbsent(
      groupId,
      () => TextEditingController(text: _groupTitleForGroupId(groupId)),
    );
  }

  FocusNode _groupTitleFocusNodeFor(String groupId) {
    return _groupTitleFocusNodes.putIfAbsent(groupId, FocusNode.new);
  }

  void _handleGroupTitleChanged(String groupId, String value) {
    for (var i = 0; i < _blocks.length; i++) {
      if (_blocks[i].groupId == groupId) {
        _blocks[i] = _blocks[i].copyWith(groupTitle: value);
      }
    }

    _saveNote();
  }

  void _setGroupCollapsed(String groupId, bool collapsed) {
    setState(() {
      for (var i = 0; i < _blocks.length; i++) {
        if (_validGroupId(_blocks[i].groupId) == groupId) {
          _blocks[i] = _blocks[i].copyWith(groupCollapsed: collapsed);
        }
      }
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  void _cleanupUnusedGroupTitleEditors() {
    final activeGroupIds = _blocks
        .map((block) => block.groupId)
        .whereType<String>()
        .where((groupId) => groupId.isNotEmpty)
        .toSet();

    final removedControllerIds = _groupTitleControllers.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedControllerIds) {
      _groupTitleControllers.remove(groupId)?.dispose();
    }

    final removedFocusIds = _groupTitleFocusNodes.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedFocusIds) {
      _groupTitleFocusNodes.remove(groupId)?.dispose();
    }

    final removedViewportIds = _groupViewportKeys.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedViewportIds) {
      _groupViewportKeys.remove(groupId);
    }
  }

  void _addGroupToBlock(int index) {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final groupId = _newGroupId();
    const groupTitle = 'Grupo';

    setState(() {
      _blocks[index] = _blocks[index].copyWith(
        groupId: groupId,
        groupTitle: groupTitle,
      );

      _activeBlockIndex = index;
    });

    _groupTitleControllers[groupId] = TextEditingController(text: groupTitle);
    _groupTitleFocusNodes[groupId] = FocusNode();

    _saveNote();
    HapticFeedback.selectionClick();
  }

  void _removeGroupFromBlock(int index) {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final groupId = _blocks[index].groupId;

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    setState(() {
      _blocks[index] = _blocks[index].copyWith(
        clearGroupId: true,
        groupTitle: '',
        groupCollapsed: false,
      );

      _activeBlockIndex = index;
    });

    _cleanupUnusedGroupTitleEditors();
    _saveNote();
    HapticFeedback.selectionClick();
  }

  void _insertParagraphBlockInGroup(int index, {required bool above}) {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final groupId = _blocks[index].groupId;

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final range = _groupRangeForIndex(index);
    final insertIndex = above ? range.start : range.end + 1;
    final groupTitle = _groupTitleForGroupId(groupId);

    final block = NoteBlock(
      id: _newBlockId(),
      type: NoteBlockType.paragraph,
      groupId: groupId,
      groupTitle: groupTitle,
      groupCollapsed: _isGroupCollapsed(groupId),
    );

    setState(() {
      _blocks.insert(insertIndex, block);
      _blockControllers[block.id] = TextEditingController();
      _blockFocusNodes[block.id] = FocusNode();
      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _blockFocusNodes[block.id]?.requestFocus();
    });
  }

  NoteBlock _normalizeLegacyBlock(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.heading1:
        return block.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.heading1,
        );
      case NoteBlockType.heading2:
        return block.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.heading2,
        );
      case NoteBlockType.quote:
        return block.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.quote,
        );
      case NoteBlockType.callout:
        return block.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.callout,
        );
      case NoteBlockType.checklist:
        final lines = _listLinesForBlock(block);
        final states = _checklistStatesForBlock(block, lines.length);

        return block.copyWith(
          text: lines.join('\n'),
          isChecked: states.isNotEmpty && states.first,
          checklistStates: states,
        );
      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
        return block.copyWith(clearChecklistStates: true, isChecked: false);
      case NoteBlockType.paragraph:
      case NoteBlockType.image:
      case NoteBlockType.divider:
        return block;
    }
  }

  void _saveNote() {
    _saveDebounce?.cancel();

    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistNote());
    });
  }

  Future<void> _persistNote() async {
    final currentNote = _notesController.noteById(widget.noteId);

    if (currentNote == null) {
      return;
    }

    await _notesController.updateNote(
      currentNote.copyWith(
        title: _titleController.text,
        blocks: List<NoteBlock>.from(_blocks),
      ),
    );
  }

  Future<String?> _pickAndStoreImage() async {
    final XFile? selectedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (selectedImage == null) {
      return null;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final imagesDirectory = Directory(
      p.join(documentsDirectory.path, 'notes_images'),
    );

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    final originalExtension = p.extension(selectedImage.path);

    final extension = originalExtension.isEmpty ? '.jpg' : originalExtension;

    final destinationPath = p.join(
      imagesDirectory.path,
      'note_image_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    final savedImage = await File(selectedImage.path).copy(destinationPath);

    return savedImage.path;
  }

  Future<String?> _duplicateStoredImage(String? sourcePath) async {
    if (sourcePath == null) {
      return null;
    }

    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return null;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final imagesDirectory = Directory(
      p.join(documentsDirectory.path, 'notes_images'),
    );

    await imagesDirectory.create(recursive: true);

    final extension = p.extension(sourcePath);

    final destinationPath = p.join(
      imagesDirectory.path,
      'note_image_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    final duplicatedFile = await sourceFile.copy(destinationPath);

    return duplicatedFile.path;
  }

  Future<void> _deleteStoredImage(String? imagePath) async {
    if (imagePath == null) {
      return;
    }

    try {
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (_) {
      // La nota continúa funcionando aunque el archivo
      // ya no exista o no pueda eliminarse.
    }
  }

  Future<void> _insertImageBlock({int? afterIndex}) async {
    final imagePath = await _pickAndStoreImage();

    if (!mounted || imagePath == null) {
      return;
    }

    final block = NoteBlock(
      id: _newBlockId(),
      type: NoteBlockType.image,
      imagePath: imagePath,
    );

    final int insertIndex;

    if (afterIndex == null) {
      insertIndex = _blocks.length;
    } else {
      insertIndex = (afterIndex + 1).clamp(0, _blocks.length);
    }

    setState(() {
      _blocks.insert(insertIndex, block);

      _blockControllers[block.id] = TextEditingController();

      _blockFocusNodes[block.id] = FocusNode();

      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Future<void> _convertBlockToImage(int index) async {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final imagePath = await _pickAndStoreImage();

    if (!mounted || imagePath == null) {
      final blockId = _blocks[index].id;
      _blockFocusNodes[blockId]?.requestFocus();
      return;
    }

    final block = _blocks[index];
    final controller = _blockControllers[block.id];

    controller?.clear();
    _disposeListEditorsForBlock(block.id);

    setState(() {
      _blocks[index] = block.copyWith(
        type: NoteBlockType.image,
        text: '',
        imagePath: imagePath,
        isChecked: false,
        clearChecklistStates: true,
      );

      _activeBlockIndex = index;
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Future<void> _replaceImageBlock(int index) async {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final newImagePath = await _pickAndStoreImage();

    if (!mounted || newImagePath == null) {
      return;
    }

    final oldBlock = _blocks[index];
    final oldImagePath = oldBlock.imagePath;

    setState(() {
      _blocks[index] = oldBlock.copyWith(imagePath: newImagePath);
    });

    _saveNote();

    if (oldImagePath != null) {
      unawaited(_deleteStoredImage(oldImagePath));
    }

    HapticFeedback.selectionClick();
  }

  void _addBlock(
    NoteBlockType type, {
    int? afterIndex,
    NoteBlock? inheritFormattingFrom,
  }) {
    final block = NoteBlock(
      id: _newBlockId(),
      type: type,
      fontFamily: inheritFormattingFrom?.fontFamily ?? 'Inter',
      fontSize: inheritFormattingFrom?.fontSize,
      textColorValue: inheritFormattingFrom?.textColorValue,
      isBold: inheritFormattingFrom?.isBold ?? false,
      isItalic: inheritFormattingFrom?.isItalic ?? false,
      isUnderline: inheritFormattingFrom?.isUnderline ?? false,
      textAlignment:
          inheritFormattingFrom?.textAlignment ?? NoteTextAlignment.left,
      listMarkerStyle: type == NoteBlockType.numberedList
          ? inheritFormattingFrom?.listMarkerStyle ??
                NoteListMarkerStyle.numbered
          : NoteListMarkerStyle.automatic,
      checklistStates: type == NoteBlockType.checklist
          ? const <bool>[false]
          : const <bool>[],
    );

    final int insertIndex;

    if (afterIndex == null) {
      insertIndex = _blocks.length;
    } else {
      insertIndex = (afterIndex + 1).clamp(0, _blocks.length);
    }

    setState(() {
      _blocks.insert(insertIndex, block);

      _blockControllers[block.id] = TextEditingController();

      _blockFocusNodes[block.id] = FocusNode();

      if (_isWordListBlock(block)) {
        _createListEditorsForBlock(block);
      }

      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  NoteBlockType _nextBlockTypeAfter(NoteBlockType currentType) {
    switch (currentType) {
      case NoteBlockType.bulletList:
        return NoteBlockType.bulletList;
      case NoteBlockType.numberedList:
        return NoteBlockType.numberedList;
      case NoteBlockType.checklist:
        return NoteBlockType.checklist;
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.quote:
      case NoteBlockType.callout:
      case NoteBlockType.image:
        return NoteBlockType.paragraph;
      case NoteBlockType.divider:
        return NoteBlockType.paragraph;
    }
  }

  void _handleBlockSubmitted(int index) {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[index];
    final controller = _blockControllers[currentBlock.id];

    if (controller == null) {
      return;
    }

    final bool isEmpty = controller.text.trim().isEmpty;

    final bool isListBlock =
        currentBlock.type == NoteBlockType.bulletList ||
        currentBlock.type == NoteBlockType.numberedList ||
        currentBlock.type == NoteBlockType.checklist;

    final bool hasSpecialStyle = currentBlock.style != NoteBlockStyle.normal;

    // Enter en una lista vacía:
    // termina la lista y convierte el bloque en texto.
    if (isEmpty && isListBlock) {
      setState(() {
        _blocks[index] = currentBlock.copyWith(
          type: NoteBlockType.paragraph,
          text: '',
          isChecked: false,
          listMarkerStyle: NoteListMarkerStyle.automatic,
          clearChecklistStates: true,
        );

        _activeBlockIndex = index;
      });

      _saveNote();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _blockFocusNodes[currentBlock.id]?.requestFocus();
      });

      HapticFeedback.selectionClick();
      return;
    }

    // Enter en un bloque vacío con estilo especial:
    // conserva el contenido y vuelve al estilo normal.
    if (isEmpty && hasSpecialStyle) {
      setState(() {
        _blocks[index] = currentBlock.copyWith(
          style: NoteBlockStyle.normal,
          text: '',
        );

        _activeBlockIndex = index;
      });

      _saveNote();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _blockFocusNodes[currentBlock.id]?.requestFocus();
      });

      HapticFeedback.selectionClick();
      return;
    }

    // En cualquier otro caso crea un bloque debajo.
    final continuesList =
        currentBlock.type == NoteBlockType.bulletList ||
        currentBlock.type == NoteBlockType.numberedList ||
        currentBlock.type == NoteBlockType.checklist;

    _addBlock(
      _nextBlockTypeAfter(currentBlock.type),
      afterIndex: index,
      inheritFormattingFrom: continuesList ? currentBlock : null,
    );
  }

  void _handleBlockTextChanged(String blockId, String value) {
    final index = _blocks.indexWhere((block) => block.id == blockId);

    if (index == -1) {
      return;
    }

    _activeBlockIndex = index;

    _updateBlockText(index, value);

    if (value.trim() == '/' && !_isSlashMenuOpen) {
      _isSlashMenuOpen = true;

      Future<void>.microtask(() {
        final currentIndex = _blocks.indexWhere((block) => block.id == blockId);

        if (currentIndex == -1) {
          return;
        }

        _openSlashCommandMenu(currentIndex);
      });
    }
  }

  void _commitListBlock(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[blockIndex];
    final controllers = _listLineControllers[currentBlock.id];

    if (controllers == null || controllers.isEmpty) {
      return;
    }

    final text = controllers
        .map((controller) => _visibleListItemText(controller.text))
        .join('\n');
    final checklistStates = currentBlock.type == NoteBlockType.checklist
        ? _checklistStatesForBlock(currentBlock, controllers.length)
        : const <bool>[];

    final updatedBlock = currentBlock.copyWith(
      text: text,
      isChecked: checklistStates.isNotEmpty && checklistStates.first,
      checklistStates: checklistStates,
      clearChecklistStates: currentBlock.type != NoteBlockType.checklist,
    );

    _blocks[blockIndex] = updatedBlock;
    _syncHiddenBlockController(updatedBlock);
    _saveNote();
  }

  void _removeListItemAt(int blockIndex, int itemIndex) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[blockIndex];
    final controllers = _listLineControllers[currentBlock.id];
    final focusNodes = _listLineFocusNodes[currentBlock.id];

    if (controllers == null ||
        focusNodes == null ||
        controllers.length <= 1 ||
        itemIndex < 0 ||
        itemIndex >= controllers.length) {
      return;
    }

    final destinationIndex = itemIndex > 0 ? itemIndex - 1 : 1;
    final destinationController = controllers[destinationIndex];
    final destinationFocusNode = focusNodes[destinationIndex];
    final removedController = controllers[itemIndex];
    final removedFocusNode = focusNodes[itemIndex];
    final states = currentBlock.type == NoteBlockType.checklist
        ? _checklistStatesForBlock(currentBlock, controllers.length)
        : <bool>[];

    // Mueve el foco antes de retirar el renglón para que el teclado
    // virtual permanezca abierto.
    destinationController.selection = TextSelection.collapsed(
      offset: destinationController.text.length,
    );
    destinationFocusNode.requestFocus();

    setState(() {
      controllers.removeAt(itemIndex);
      focusNodes.removeAt(itemIndex);

      if (currentBlock.type == NoteBlockType.checklist &&
          itemIndex < states.length) {
        states.removeAt(itemIndex);
      }

      final text = controllers
          .map((controller) => _visibleListItemText(controller.text))
          .join('\n');

      final updatedBlock = currentBlock.copyWith(
        text: text,
        isChecked: states.isNotEmpty && states.first,
        checklistStates: states,
        clearChecklistStates: currentBlock.type != NoteBlockType.checklist,
      );

      _blocks[blockIndex] = updatedBlock;
      _syncHiddenBlockController(updatedBlock);
      _activeBlockIndex = blockIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removedController.dispose();
      removedFocusNode.dispose();
    });
  }

  void _handleListItemChanged(int blockIndex, int itemIndex, String value) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[blockIndex];
    final controllers = _listLineControllers[currentBlock.id];

    if (controllers == null ||
        itemIndex < 0 ||
        itemIndex >= controllers.length) {
      return;
    }

    _activeBlockIndex = blockIndex;

    // Al borrar el marcador invisible de un renglón vacío, elimina
    // únicamente ese renglón y conserva el foco en la lista.
    if (value.isEmpty && controllers.length > 1) {
      _removeListItemAt(blockIndex, itemIndex);
      return;
    }

    final cleanValue = _visibleListItemText(value);
    final newlineIndex = cleanValue.indexOf('\n');

    if (newlineIndex != -1) {
      _insertListItemAfter(
        blockIndex,
        itemIndex,
        forcedLeadingText: cleanValue.substring(0, newlineIndex),
        forcedTrailingText: cleanValue.substring(newlineIndex + 1),
      );
      return;
    }

    final controller = controllers[itemIndex];

    // Cuando el usuario escribe en un renglón vacío, retira el marcador
    // invisible sin alterar la posición visible del cursor.
    if (cleanValue != value) {
      final currentOffset = controller.selection.baseOffset
          .clamp(0, value.length)
          .toInt();
      final markerWasBeforeCursor =
          value.startsWith(_emptyListItemMarker) && currentOffset > 0;
      final adjustedOffset = (currentOffset - (markerWasBeforeCursor ? 1 : 0))
          .clamp(0, cleanValue.length)
          .toInt();

      controller.value = TextEditingValue(
        text: _editableListItemText(cleanValue),
        selection: TextSelection.collapsed(
          offset: cleanValue.isEmpty ? 1 : adjustedOffset,
        ),
      );
    }

    _commitListBlock(blockIndex);
  }

  void _insertListItemAfter(
    int blockIndex,
    int itemIndex, {
    String? forcedLeadingText,
    String? forcedTrailingText,
  }) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[blockIndex];
    final controllers = _listLineControllers[currentBlock.id];
    final focusNodes = _listLineFocusNodes[currentBlock.id];

    if (controllers == null ||
        focusNodes == null ||
        itemIndex < 0 ||
        itemIndex >= controllers.length) {
      return;
    }

    final currentController = controllers[itemIndex];
    final rawCurrentText = currentController.text;
    final currentText = _visibleListItemText(rawCurrentText);
    final hasLeadingMarker = rawCurrentText.startsWith(_emptyListItemMarker);
    final selectionOffset =
        (currentController.selection.baseOffset - (hasLeadingMarker ? 1 : 0))
            .clamp(0, currentText.length)
            .toInt();
    final leadingText =
        forcedLeadingText ?? currentText.substring(0, selectionOffset);
    final trailingText =
        forcedTrailingText ?? currentText.substring(selectionOffset);
    final newController = TextEditingController(
      text: _editableListItemText(trailingText),
    );
    final newFocusNode = FocusNode();
    final states = currentBlock.type == NoteBlockType.checklist
        ? _checklistStatesForBlock(currentBlock, controllers.length)
        : <bool>[];

    currentController.value = TextEditingValue(
      text: _editableListItemText(leadingText),
      selection: TextSelection.collapsed(
        offset: leadingText.isEmpty ? 1 : leadingText.length,
      ),
    );

    setState(() {
      controllers.insert(itemIndex + 1, newController);
      focusNodes.insert(itemIndex + 1, newFocusNode);

      if (currentBlock.type == NoteBlockType.checklist) {
        states.insert(itemIndex + 1, false);
      }

      final text = controllers
          .map((controller) => _visibleListItemText(controller.text))
          .join('\n');
      final updatedBlock = currentBlock.copyWith(
        text: text,
        isChecked: states.isNotEmpty && states.first,
        checklistStates: states,
        clearChecklistStates: currentBlock.type != NoteBlockType.checklist,
      );

      _blocks[blockIndex] = updatedBlock;
      _syncHiddenBlockController(updatedBlock);
      _activeBlockIndex = blockIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    // El marcador invisible ocupa un carácter; posicionar el cursor al
    // final permite que Backspace lo elimine y dispare la eliminación.
    newController.selection = TextSelection.collapsed(
      offset: newController.text.length,
    );
    newFocusNode.requestFocus();
  }

  void _toggleChecklistItem(int blockIndex, int itemIndex, bool isChecked) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final currentBlock = _blocks[blockIndex];
    final controllers = _listLineControllers[currentBlock.id];

    if (controllers == null ||
        itemIndex < 0 ||
        itemIndex >= controllers.length) {
      return;
    }

    final states = _checklistStatesForBlock(currentBlock, controllers.length);
    states[itemIndex] = isChecked;

    setState(() {
      _blocks[blockIndex] = currentBlock.copyWith(
        isChecked: states.isNotEmpty && states.first,
        checklistStates: states,
      );
      _activeBlockIndex = blockIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Future<void> _openSlashCommandMenu(int blockIndex) async {
    if (!mounted || blockIndex < 0 || blockIndex >= _blocks.length) {
      _isSlashMenuOpen = false;
      return;
    }

    final selectedType = await showModalBottomSheet<NoteBlockType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C21),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insertar bloque',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Convierte esta línea en otro tipo de contenido.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.43),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _insertableBlockTypes.length,
                  itemBuilder: (context, index) {
                    final type = _insertableBlockTypes[index];

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Icon(
                          _blockTypeIcon(type),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _blockTypeName(type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop(type);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    _isSlashMenuOpen = false;

    if (!mounted || blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final block = _blocks[blockIndex];
    final controller = _blockControllers[block.id];

    if (selectedType == null || controller == null) {
      _blockFocusNodes[block.id]?.requestFocus();
      return;
    }

    if (selectedType == NoteBlockType.image) {
      await _convertBlockToImage(blockIndex);
      return;
    }

    controller
      ..text = ''
      ..selection = const TextSelection.collapsed(offset: 0);

    final convertedBlock = block.copyWith(
      type: selectedType,
      text: '',
      isChecked: false,
      checklistStates: selectedType == NoteBlockType.checklist
          ? const <bool>[false]
          : const <bool>[],
      clearChecklistStates: selectedType != NoteBlockType.checklist,
      listMarkerStyle: selectedType == NoteBlockType.numberedList
          ? NoteListMarkerStyle.numbered
          : NoteListMarkerStyle.automatic,
    );

    _disposeListEditorsForBlock(block.id);

    setState(() {
      _blocks[blockIndex] = convertedBlock;

      if (_isWordListBlock(convertedBlock)) {
        _createListEditorsForBlock(convertedBlock);
      }

      _activeBlockIndex = blockIndex;
    });

    _saveNote();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_isWordListBlock(convertedBlock)) {
        final listFocusNodes = _listLineFocusNodes[block.id];

        if (listFocusNodes != null && listFocusNodes.isNotEmpty) {
          listFocusNodes.first.requestFocus();
        }

        return;
      }

      _blockFocusNodes[block.id]?.requestFocus();
    });

    HapticFeedback.selectionClick();
  }

  void _updateBlockText(int index, String value) {
    _blocks[index] = _blocks[index].copyWith(text: value);

    _saveNote();
  }

  void _toggleChecklist(int index, bool isChecked) {
    setState(() {
      _blocks[index] = _blocks[index].copyWith(isChecked: isChecked);
    });

    _saveNote();
  }

  Future<void> _duplicateBlock(int index) async {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final originalBlock = _blocks[index];

    String? duplicatedImagePath;

    if (originalBlock.type == NoteBlockType.image) {
      duplicatedImagePath = await _duplicateStoredImage(
        originalBlock.imagePath,
      );
    }

    if (!mounted) {
      return;
    }

    final duplicatedBlock = NoteBlock(
      id: _newBlockId(),
      type: originalBlock.type,
      text: originalBlock.text,
      isChecked: originalBlock.isChecked,
      imagePath: duplicatedImagePath,
      style: originalBlock.style,
      colorValue: originalBlock.colorValue,
      fontFamily: originalBlock.fontFamily,
      fontSize: originalBlock.fontSize,
      textColorValue: originalBlock.textColorValue,
      isBold: originalBlock.isBold,
      isItalic: originalBlock.isItalic,
      isUnderline: originalBlock.isUnderline,
      textAlignment: originalBlock.textAlignment,
      listMarkerStyle: originalBlock.listMarkerStyle,
      checklistStates: List<bool>.from(originalBlock.checklistStates),
      groupId: originalBlock.groupId,
      groupTitle: originalBlock.groupTitle,
      groupCollapsed: originalBlock.groupCollapsed,
    );

    final duplicatedController = TextEditingController(
      text: duplicatedBlock.text,
    );

    final duplicatedFocusNode = FocusNode();

    setState(() {
      _blocks.insert(index + 1, duplicatedBlock);

      _blockControllers[duplicatedBlock.id] = duplicatedController;

      _blockFocusNodes[duplicatedBlock.id] = duplicatedFocusNode;

      if (_isWordListBlock(duplicatedBlock)) {
        _createListEditorsForBlock(duplicatedBlock);
      }

      _activeBlockIndex = index + 1;
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  void _deleteBlock(int index) {
    if (_blocks.length == 1) {
      final block = _blocks.first;
      final oldImagePath = block.imagePath;

      _blockControllers[block.id]?.clear();
      _disposeListEditorsForBlock(block.id);

      setState(() {
        _blocks[0] = block.copyWith(
          type: NoteBlockType.paragraph,
          text: '',
          isChecked: false,
          clearImagePath: true,
          style: NoteBlockStyle.normal,
          clearColorValue: true,
          fontFamily: 'Inter',
          clearFontSize: true,
          clearTextColorValue: true,
          textAlignment: NoteTextAlignment.left,
          listMarkerStyle: NoteListMarkerStyle.automatic,
          clearChecklistStates: true,
        );
        _activeBlockIndex = 0;
      });

      _saveNote();

      if (oldImagePath != null) {
        unawaited(_deleteStoredImage(oldImagePath));
      }

      return;
    }

    final removedBlock = _blocks[index];

    setState(() {
      _blocks.removeAt(index);
    });

    _blockControllers.remove(removedBlock.id)?.dispose();

    _blockFocusNodes.remove(removedBlock.id)?.dispose();
    _disposeListEditorsForBlock(removedBlock.id);
    _blockViewportKeys.remove(removedBlock.id);
    _cleanupUnusedGroupTitleEditors();

    if (removedBlock.imagePath != null) {
      unawaited(_deleteStoredImage(removedBlock.imagePath));
    }

    if (_blocks.isEmpty) {
      _activeBlockIndex = null;
    } else {
      _activeBlockIndex = index.clamp(0, _blocks.length - 1).toInt();
    }

    _saveNote();
  }

  String? _validGroupId(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      return null;
    }

    return groupId;
  }

  String? _groupIdAtIndex(int index) {
    if (index < 0 || index >= _blocks.length) {
      return null;
    }

    return _validGroupId(_blocks[index].groupId);
  }

  Rect? _rectForViewportKey(GlobalKey key) {
    final keyContext = key.currentContext;

    if (keyContext == null) {
      return null;
    }

    final renderObject = keyContext.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final topLeft = renderObject.localToGlobal(Offset.zero);

    return topLeft & renderObject.size;
  }

  Rect? _rectForGroupId(String groupId) {
    final groupViewportKey = _groupViewportKeys[groupId];
    final groupViewportRect = groupViewportKey == null
        ? null
        : _rectForViewportKey(groupViewportKey);

    if (_isGroupCollapsed(groupId) && groupViewportRect != null) {
      return groupViewportRect;
    }
    final draggingBlockId = _draggingBlockId;
    Rect? groupRect;

    for (final block in _blocks) {
      if (block.id == draggingBlockId) {
        continue;
      }

      if (_validGroupId(block.groupId) != groupId) {
        continue;
      }

      final key = _blockViewportKeys[block.id];
      final rect = key == null ? null : _rectForViewportKey(key);

      if (rect == null) {
        continue;
      }

      groupRect = groupRect?.expandToInclude(rect) ?? rect;
    }

    return groupRect;
  }

  bool _positionIsInsideGroupBody(String groupId, Offset globalPosition) {
    final rect = _rectForGroupId(groupId);

    if (rect == null) {
      return false;
    }

    final isCollapsed = _isGroupCollapsed(groupId);

    if (isCollapsed) {
      final collapsedSafeRect = rect.deflate(6);
      return collapsedSafeRect.contains(globalPosition);
    }

    final bodyTop = rect.top + _groupHeaderHeight;
    final bodyBottom = rect.bottom - 10;

    if (bodyBottom <= bodyTop) {
      return false;
    }

    final bodyRect = Rect.fromLTRB(
      rect.left + 6,
      bodyTop,
      rect.right - 6,
      bodyBottom,
    );

    return bodyRect.contains(globalPosition);
  }

  bool _isDraggingBlockRelatedToGroup(String groupId) {
    final draggingBlockId = _draggingBlockId;

    if (draggingBlockId == null) {
      return false;
    }

    if (_dragPreviewGroupId == groupId) {
      return true;
    }

    for (final block in _blocks) {
      if (block.id == draggingBlockId) {
        return _validGroupId(block.groupId) == groupId;
      }
    }

    return false;
  }

  String? _groupIdAtGlobalPosition(Offset globalPosition) {
    final seenGroupIds = <String>{};

    for (final block in _blocks) {
      final groupId = _validGroupId(block.groupId);

      if (groupId == null || !seenGroupIds.add(groupId)) {
        continue;
      }

      if (_positionIsInsideGroupBody(groupId, globalPosition)) {
        return groupId;
      }
    }

    return null;
  }

  ({String groupId, _GroupEdgeDropSlot slot})? _groupEdgeDropTargetAtPosition(
    Offset globalPosition,
  ) {
    if (_draggingBlockId == null) {
      return null;
    }

    final groupId = _groupIdAtGlobalPosition(globalPosition);

    if (groupId == null) {
      return null;
    }

    final rect = _rectForGroupId(groupId);

    if (rect == null) {
      return null;
    }

    final middleY = rect.top + (rect.height / 2);

    return (
      groupId: groupId,
      slot: globalPosition.dy < middleY
          ? _GroupEdgeDropSlot.top
          : _GroupEdgeDropSlot.bottom,
    );
  }

  void _updateDragPreviewFromGlobalPosition(Offset globalPosition) {
    _lastDragGlobalPosition = globalPosition;
    if (_draggingBlockId == null) {
      return;
    }

    final edgeTarget = _groupEdgeDropTargetAtPosition(globalPosition);
    final nextPreviewId = edgeTarget?.groupId ?? _dragNoGroupPreviewId;
    final nextEdgeSlot = edgeTarget?.slot ?? _GroupEdgeDropSlot.none;

    if (_dragPreviewGroupId == nextPreviewId &&
        _dragEdgeDropSlot == nextEdgeSlot) {
      return;
    }

    setState(() {
      _dragPreviewGroupId = nextPreviewId;
      _dragEdgeDropSlot = nextEdgeSlot;
    });
  }

  bool _shouldShowGroupEdgeDropSpace(String groupId, _GroupEdgeDropSlot slot) {
    return false;
  }

  String? _targetGroupIdForMovedIndex(int movedIndex) {
    if (movedIndex < 0 || movedIndex >= _blocks.length) {
      return null;
    }

    final lastDragPosition = _lastDragGlobalPosition;

    if (lastDragPosition != null) {
      final groupAtPointer = _groupIdAtGlobalPosition(lastDragPosition);

      if (groupAtPointer != null) {
        return groupAtPointer;
      }
    }

    final previousGroupId = _groupIdAtIndex(movedIndex - 1);
    final nextGroupId = _groupIdAtIndex(movedIndex + 1);

    if (previousGroupId != null &&
        nextGroupId != null &&
        previousGroupId == nextGroupId) {
      return previousGroupId;
    }

    return null;
  }

  void _moveMovedBlockToGroupEdge({
    required String movedBlockId,
    required String targetGroupId,
    required _GroupEdgeDropSlot slot,
  }) {
    final currentIndex = _blocks.indexWhere(
      (block) => block.id == movedBlockId,
    );

    if (currentIndex == -1) {
      return;
    }

    final groupTitle = _groupTitleForGroupId(targetGroupId);
    final movedBlock = _blocks
        .removeAt(currentIndex)
        .copyWith(
          groupId: targetGroupId,
          groupTitle: groupTitle,
          groupCollapsed: _isGroupCollapsed(targetGroupId),
        );

    final groupIndexes = <int>[];

    for (var i = 0; i < _blocks.length; i++) {
      if (_validGroupId(_blocks[i].groupId) == targetGroupId) {
        groupIndexes.add(i);
      }
    }

    final insertIndex = switch (slot) {
      _GroupEdgeDropSlot.top =>
        groupIndexes.isEmpty
            ? currentIndex.clamp(0, _blocks.length).toInt()
            : groupIndexes.first.clamp(0, _blocks.length).toInt(),
      _GroupEdgeDropSlot.bottom =>
        groupIndexes.isEmpty
            ? currentIndex.clamp(0, _blocks.length).toInt()
            : (groupIndexes.last + 1).clamp(0, _blocks.length).toInt(),
      _GroupEdgeDropSlot.none => currentIndex.clamp(0, _blocks.length).toInt(),
    };

    _blocks.insert(insertIndex, movedBlock);

    final controller = _groupTitleControllerFor(targetGroupId);

    if (controller.text != groupTitle) {
      controller.text = groupTitle;
    }
  }

  void _applyGroupToMovedBlock({
    required int movedIndex,
    required String? targetGroupId,
  }) {
    if (movedIndex < 0 || movedIndex >= _blocks.length) {
      return;
    }

    final movedBlock = _blocks[movedIndex];
    final currentGroupId = _validGroupId(movedBlock.groupId);

    if (targetGroupId != null) {
      final groupTitle = _groupTitleForGroupId(targetGroupId);

      if (currentGroupId != targetGroupId ||
          movedBlock.groupTitle != groupTitle) {
        _blocks[movedIndex] = movedBlock.copyWith(
          groupId: targetGroupId,
          groupTitle: groupTitle,
          groupCollapsed: _isGroupCollapsed(targetGroupId),
        );
      }

      final controller = _groupTitleControllerFor(targetGroupId);

      if (controller.text != groupTitle) {
        controller.text = groupTitle;
      }

      return;
    }

    if (currentGroupId != null) {
      _blocks[movedIndex] = movedBlock.copyWith(
        clearGroupId: true,
        groupTitle: '',
        groupCollapsed: false,
      );
    }
  }

  void _refreshMovedBlockGroupMembership(String movedBlockId) {
    final movedIndex = _blocks.indexWhere((block) => block.id == movedBlockId);

    if (movedIndex == -1) {
      return;
    }

    final targetGroupId = _targetGroupIdForMovedIndex(movedIndex);

    _applyGroupToMovedBlock(
      movedIndex: movedIndex,
      targetGroupId: targetGroupId,
    );
  }

  void _finishDragGroupPreview() {
    final movedBlockId = _draggingBlockId;

    if (movedBlockId == null) {
      setState(() {
        _draggingGroupId = null;
        _dragPreviewGroupId = null;
        _lastDragGlobalPosition = null;
        _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
        _blockedEdgePreviewGroupId = null;
        _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
      });
      return;
    }

    final finalDropTarget = _lastDragGlobalPosition == null
        ? null
        : _groupEdgeDropTargetAtPosition(_lastDragGlobalPosition!);

    final previewGroupId = finalDropTarget?.groupId;
    final previewSlot = finalDropTarget?.slot ?? _GroupEdgeDropSlot.none;

    var shouldSave = false;

    setState(() {
      final beforeIndex = _blocks.indexWhere(
        (block) => block.id == movedBlockId,
      );

      final beforeGroupId = beforeIndex == -1
          ? null
          : _validGroupId(_blocks[beforeIndex].groupId);
      final beforeGroupTitle = beforeIndex == -1
          ? ''
          : _blocks[beforeIndex].groupTitle;

      if (beforeIndex != -1) {
        if (previewGroupId != null && previewSlot != _GroupEdgeDropSlot.none) {
          _moveMovedBlockToGroupEdge(
            movedBlockId: movedBlockId,
            targetGroupId: previewGroupId,
            slot: previewSlot,
          );
        } else {
          final movedIndex = _blocks.indexWhere(
            (block) => block.id == movedBlockId,
          );

          if (movedIndex != -1) {
            final targetGroupId = _targetGroupIdForMovedIndex(movedIndex);

            _applyGroupToMovedBlock(
              movedIndex: movedIndex,
              targetGroupId: targetGroupId,
            );
          }
        }
      }

      final afterIndex = _blocks.indexWhere(
        (block) => block.id == movedBlockId,
      );

      final afterGroupId = afterIndex == -1
          ? null
          : _validGroupId(_blocks[afterIndex].groupId);
      final afterGroupTitle = afterIndex == -1
          ? ''
          : _blocks[afterIndex].groupTitle;

      shouldSave =
          beforeIndex != afterIndex ||
          beforeGroupId != afterGroupId ||
          beforeGroupTitle != afterGroupTitle;

      _draggingBlockId = null;
      _draggingGroupId = null;
      _dragPreviewGroupId = null;
      _lastDragGlobalPosition = null;
      _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
      _blockedEdgePreviewGroupId = null;
      _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
    });

    _cleanupUnusedGroupTitleEditors();

    if (shouldSave) {
      _saveNote();
      HapticFeedback.selectionClick();
    }
  }

  void _syncAllVisibleEditorsIntoBlocks() {
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];

      if (_isWordListBlock(block)) {
        final controllers = _listLineControllers[block.id];

        if (controllers != null) {
          final text = controllers
              .map((controller) => _visibleListItemText(controller.text))
              .join('\n');

          if (text != block.text) {
            final checklistStates = block.type == NoteBlockType.checklist
                ? _checklistStatesForBlock(block, controllers.length)
                : const <bool>[];

            final updatedBlock = block.copyWith(
              text: text,
              isChecked: checklistStates.isNotEmpty && checklistStates.first,
              checklistStates: checklistStates,
              clearChecklistStates: block.type != NoteBlockType.checklist,
            );

            _blocks[i] = updatedBlock;
            _syncHiddenBlockController(updatedBlock);
          }
        }

        continue;
      }

      final controller = _blockControllers[block.id];

      if (controller != null && controller.text != block.text) {
        _blocks[i] = block.copyWith(text: controller.text);
      }
    }
  }

  void _reorderRenderEntries(int oldEntryIndex, int newEntryIndex) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_blocks.isEmpty) {
      return;
    }

    final entries = _buildRenderEntries();

    if (oldEntryIndex < 0 || oldEntryIndex >= entries.length) {
      return;
    }

    final movingEntry = entries[oldEntryIndex];
    final draggingGroupId = _draggingGroupId;

    final movedBlockId =
        draggingGroupId == null && movingEntry.blockIndexes.length == 1
        ? _blocks[movingEntry.firstBlockIndex].id
        : null;
    final activeBlockId =
        _activeBlockIndex != null &&
            _activeBlockIndex! >= 0 &&
            _activeBlockIndex! < _blocks.length
        ? _blocks[_activeBlockIndex!].id
        : null;

    final activeEdgeGroupId =
        _dragPreviewGroupId != null &&
            _dragPreviewGroupId != _dragNoGroupPreviewId
        ? _dragPreviewGroupId
        : null;
    final activeEdgeSlot = _dragEdgeDropSlot;

    setState(() {
      _syncAllVisibleEditorsIntoBlocks();

      final movingIds = draggingGroupId == null
          ? movingEntry.blockIndexes
                .map((blockIndex) => _blocks[blockIndex].id)
                .toSet()
          : _blocks
                .where(
                  (block) => _validGroupId(block.groupId) == draggingGroupId,
                )
                .map((block) => block.id)
                .toSet();

      final movingBlocks = _blocks
          .where((block) => movingIds.contains(block.id))
          .toList(growable: false);

      final remainingBlocks = _blocks
          .where((block) => !movingIds.contains(block.id))
          .toList();

      final remainingEntries = _buildRenderEntriesForBlocks(remainingBlocks);
      final safeNewEntryIndex = newEntryIndex
          .clamp(0, remainingEntries.length)
          .toInt();

      final insertBlockIndex = safeNewEntryIndex >= remainingEntries.length
          ? remainingBlocks.length
          : remainingEntries[safeNewEntryIndex].firstBlockIndex;

      if (movedBlockId != null &&
          activeEdgeGroupId != null &&
          activeEdgeSlot != _GroupEdgeDropSlot.none) {
        final range = _groupRangeInBlocks(remainingBlocks, activeEdgeGroupId);

        if (range != null) {
          final isStillOnTopEdge =
              activeEdgeSlot == _GroupEdgeDropSlot.top &&
              insertBlockIndex <= range.start;

          final isStillOnBottomEdge =
              activeEdgeSlot == _GroupEdgeDropSlot.bottom &&
              insertBlockIndex >= range.end + 1;

          if (isStillOnTopEdge || isStillOnBottomEdge) {
            if (activeBlockId != null) {
              final updatedIndex = _blocks.indexWhere(
                (currentBlock) => currentBlock.id == activeBlockId,
              );

              _activeBlockIndex = updatedIndex == -1 ? null : updatedIndex;
            }

            return;
          }

          _blockedEdgePreviewGroupId = activeEdgeGroupId;
          _blockedEdgePreviewSlot = activeEdgeSlot;
          _dragPreviewGroupId = _dragNoGroupPreviewId;
          _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
        }
      }

      remainingBlocks.insertAll(insertBlockIndex, movingBlocks);
      _blocks = remainingBlocks;

      if (movedBlockId != null) {
        final movedIndex = _blocks.indexWhere(
          (block) => block.id == movedBlockId,
        );

        if (movedIndex != -1) {
          final targetGroupId = _targetGroupIdForMovedIndex(movedIndex);

          _applyGroupToMovedBlock(
            movedIndex: movedIndex,
            targetGroupId: targetGroupId,
          );
        }
      }

      if (activeBlockId != null) {
        final updatedIndex = _blocks.indexWhere(
          (currentBlock) => currentBlock.id == activeBlockId,
        );

        _activeBlockIndex = updatedIndex == -1 ? null : updatedIndex;
      }
    });

    _cleanupUnusedGroupTitleEditors();
    _saveNote();
    HapticFeedback.selectionClick();
  }

  bool _supportsTextFormatting(NoteBlock block) {
    return block.type != NoteBlockType.divider;
  }

  bool _supportsListFormatting(NoteBlock block) {
    return block.type != NoteBlockType.image &&
        block.type != NoteBlockType.divider;
  }

  int? get _resolvedActiveBlockIndex {
    final activeIndex = _activeBlockIndex;

    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _blocks.length) {
      return null;
    }

    return activeIndex;
  }

  NoteBlock? get _activeFormattingBlock {
    final activeIndex = _resolvedActiveBlockIndex;

    if (activeIndex == null) {
      return null;
    }

    return _blocks[activeIndex];
  }

  void _setActiveBlock(int index) {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    if (_activeBlockIndex == index) {
      return;
    }

    setState(() {
      _activeBlockIndex = index;
    });
  }

  void _updateActiveFormattingBlock(
    NoteBlock Function(NoteBlock block) update,
  ) {
    final activeIndex = _resolvedActiveBlockIndex;

    if (activeIndex == null) {
      return;
    }

    final currentBlock = _blocks[activeIndex];

    if (!_supportsTextFormatting(currentBlock)) {
      return;
    }

    setState(() {
      _blocks[activeIndex] = update(currentBlock);
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  void _applyFontFamily(String fontFamily) {
    _updateActiveFormattingBlock(
      (block) => block.copyWith(fontFamily: fontFamily),
    );
  }

  void _applyFontSize(double? fontSize) {
    _updateActiveFormattingBlock(
      (block) => fontSize == null
          ? block.copyWith(clearFontSize: true)
          : block.copyWith(fontSize: fontSize),
    );
  }

  void _applyTextColor(int? colorValue) {
    _updateActiveFormattingBlock(
      (block) => colorValue == null
          ? block.copyWith(clearTextColorValue: true)
          : block.copyWith(textColorValue: colorValue),
    );
  }

  void _toggleBold() {
    _updateActiveFormattingBlock(
      (block) => block.copyWith(isBold: !block.isBold),
    );
  }

  void _toggleItalic() {
    _updateActiveFormattingBlock(
      (block) => block.copyWith(isItalic: !block.isItalic),
    );
  }

  void _toggleUnderline() {
    _updateActiveFormattingBlock(
      (block) => block.copyWith(isUnderline: !block.isUnderline),
    );
  }

  void _applyTextAlignment(NoteTextAlignment alignment) {
    _updateActiveFormattingBlock(
      (block) => block.copyWith(textAlignment: alignment),
    );
  }

  _ToolbarListMode _listModeForBlock(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.bulletList:
        return _ToolbarListMode.bullet;
      case NoteBlockType.numberedList:
        return block.listMarkerStyle == NoteListMarkerStyle.lettered
            ? _ToolbarListMode.lettered
            : _ToolbarListMode.numbered;
      case NoteBlockType.checklist:
        return _ToolbarListMode.checklist;
      case NoteBlockType.paragraph:
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.quote:
      case NoteBlockType.callout:
      case NoteBlockType.image:
      case NoteBlockType.divider:
        return _ToolbarListMode.paragraph;
    }
  }

  void _applyListMode(_ToolbarListMode selectedMode) {
    final activeIndex = _resolvedActiveBlockIndex;

    if (activeIndex == null) {
      return;
    }

    final currentBlock = _blocks[activeIndex];

    if (!_supportsListFormatting(currentBlock)) {
      return;
    }

    final currentMode = _listModeForBlock(currentBlock);
    final targetMode = currentMode == selectedMode
        ? _ToolbarListMode.paragraph
        : selectedMode;
    final currentText =
        _blockControllers[currentBlock.id]?.text ?? currentBlock.text;
    final normalizedText = currentText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalizedText.isEmpty
        ? <String>['']
        : normalizedText.split('\n');

    late final NoteBlock updatedBlock;

    switch (targetMode) {
      case _ToolbarListMode.paragraph:
        updatedBlock = currentBlock.copyWith(
          type: NoteBlockType.paragraph,
          text: lines.join('\n'),
          isChecked: false,
          style: NoteBlockStyle.normal,
          listMarkerStyle: NoteListMarkerStyle.automatic,
          clearChecklistStates: true,
        );
        break;
      case _ToolbarListMode.bullet:
        updatedBlock = currentBlock.copyWith(
          type: NoteBlockType.bulletList,
          text: lines.join('\n'),
          isChecked: false,
          style: NoteBlockStyle.normal,
          listMarkerStyle: NoteListMarkerStyle.automatic,
          clearChecklistStates: true,
        );
        break;
      case _ToolbarListMode.numbered:
        updatedBlock = currentBlock.copyWith(
          type: NoteBlockType.numberedList,
          text: lines.join('\n'),
          isChecked: false,
          style: NoteBlockStyle.normal,
          listMarkerStyle: NoteListMarkerStyle.numbered,
          clearChecklistStates: true,
        );
        break;
      case _ToolbarListMode.lettered:
        updatedBlock = currentBlock.copyWith(
          type: NoteBlockType.numberedList,
          text: lines.join('\n'),
          isChecked: false,
          style: NoteBlockStyle.normal,
          listMarkerStyle: NoteListMarkerStyle.lettered,
          clearChecklistStates: true,
        );
        break;
      case _ToolbarListMode.checklist:
        final states = currentBlock.type == NoteBlockType.checklist
            ? _checklistStatesForBlock(currentBlock, lines.length)
            : List<bool>.filled(lines.length, false);

        updatedBlock = currentBlock.copyWith(
          type: NoteBlockType.checklist,
          text: lines.join('\n'),
          isChecked: states.isNotEmpty && states.first,
          style: NoteBlockStyle.normal,
          listMarkerStyle: NoteListMarkerStyle.automatic,
          checklistStates: states,
        );
        break;
    }

    _disposeListEditorsForBlock(currentBlock.id);

    setState(() {
      _blocks[activeIndex] = updatedBlock;
      _syncHiddenBlockController(updatedBlock);

      if (_isWordListBlock(updatedBlock)) {
        _createListEditorsForBlock(updatedBlock);
      }

      _activeBlockIndex = activeIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_isWordListBlock(updatedBlock)) {
        final focusNodes = _listLineFocusNodes[updatedBlock.id];

        if (focusNodes != null && focusNodes.isNotEmpty) {
          focusNodes.first.requestFocus();
        }

        return;
      }

      _blockFocusNodes[updatedBlock.id]?.requestFocus();
    });
  }

  Future<void> _showFontFamilyPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final block = _activeFormattingBlock;

    if (block == null || !_supportsTextFormatting(block)) {
      return;
    }

    final selectedFont = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C21),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  'Fuente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final fontFamily in _fontFamilies)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    fontFamily,
                    style: GoogleFonts.getFont(
                      fontFamily,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  trailing: block.fontFamily == fontFamily
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(fontFamily);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedFont == null) {
      return;
    }

    _applyFontFamily(selectedFont);
  }

  Future<void> _showFontSizePicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final block = _activeFormattingBlock;

    if (block == null || !_supportsTextFormatting(block)) {
      return;
    }

    final selectedSize = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C21),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 8, 6, 14),
                child: Text(
                  'Tamaño de letra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final size in _fontSizes)
                    ChoiceChip(
                      label: Text(size.toInt().toString()),
                      selected: block.fontSize == size,
                      onSelected: (_) {
                        Navigator.of(sheetContext).pop(size);
                      },
                      labelStyle: const TextStyle(color: Colors.white),
                      selectedColor: const Color(0xFF415A85),
                      backgroundColor: const Color(0xFF292B31),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(-1.0);
                  },
                  child: const Text('Usar tamaño automático'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedSize == null) {
      return;
    }

    _applyFontSize(selectedSize < 0 ? null : selectedSize);
  }

  Future<void> _showTextColorPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final block = _activeFormattingBlock;

    if (block == null || !_supportsTextFormatting(block)) {
      return;
    }

    final selectedColor = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C21),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Color de letra',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final colorValue in _textColorValues)
                    InkWell(
                      onTap: () {
                        Navigator.of(sheetContext).pop(colorValue);
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: block.textColorValue == colorValue
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.22),
                            width: block.textColorValue == colorValue ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(0);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Usar color automático'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedColor == null) {
      return;
    }

    _applyTextColor(selectedColor == 0 ? null : selectedColor);
  }

  double _defaultFontSizeForBlock(NoteBlock block) {
    switch (block.style) {
      case NoteBlockStyle.heading1:
        return 28;
      case NoteBlockStyle.heading2:
        return 21;
      case NoteBlockStyle.quote:
        return 16;
      case NoteBlockStyle.callout:
        return 15;
      case NoteBlockStyle.normal:
        return 16;
    }
  }

  Color _textColorForBlock(NoteBlock block) {
    return block.textColorValue == null
        ? Colors.white.withValues(alpha: 0.92)
        : Color(block.textColorValue!);
  }

  TextAlign _textAlignForBlock(NoteBlock block) {
    switch (block.textAlignment) {
      case NoteTextAlignment.left:
        return TextAlign.left;
      case NoteTextAlignment.center:
        return TextAlign.center;
      case NoteTextAlignment.right:
        return TextAlign.right;
      case NoteTextAlignment.justify:
        return TextAlign.justify;
    }
  }

  TextStyle _textStyleForBlock(NoteBlock block) {
    final TextStyle baseStyle;

    switch (block.style) {
      case NoteBlockStyle.heading1:
        baseStyle = const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.15,
        );
        break;
      case NoteBlockStyle.heading2:
        baseStyle = const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.2,
        );
        break;
      case NoteBlockStyle.quote:
        baseStyle = const TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          height: 1.4,
        );
        break;
      case NoteBlockStyle.callout:
        baseStyle = const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        );
        break;
      case NoteBlockStyle.normal:
        baseStyle = const TextStyle(fontSize: 16, height: 1.45);
        break;
    }

    final resolvedStyle = baseStyle.copyWith(
      color: _textColorForBlock(block),
      fontSize: block.fontSize ?? baseStyle.fontSize,
      fontWeight: block.isBold ? FontWeight.w800 : baseStyle.fontWeight,
      fontStyle: block.isItalic ? FontStyle.italic : baseStyle.fontStyle,
      decoration: block.isUnderline
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationColor: _textColorForBlock(block),
      decorationThickness: 1.4,
    );

    try {
      return GoogleFonts.getFont(block.fontFamily, textStyle: resolvedStyle);
    } catch (_) {
      return resolvedStyle;
    }
  }

  TextStyle _imageCaptionStyleForBlock(NoteBlock block) {
    final style = _textStyleForBlock(block);

    if (block.style == NoteBlockStyle.normal && block.fontSize == null) {
      return style.copyWith(fontSize: 13, height: 1.35);
    }

    return style;
  }

  String _blockStyleName(NoteBlockStyle style) {
    switch (style) {
      case NoteBlockStyle.normal:
        return 'Normal';
      case NoteBlockStyle.heading1:
        return 'Título grande';
      case NoteBlockStyle.heading2:
        return 'Subtítulo';
      case NoteBlockStyle.quote:
        return 'Cita';
      case NoteBlockStyle.callout:
        return 'Bloque destacado';
    }
  }

  IconData _blockStyleIcon(NoteBlockStyle style) {
    switch (style) {
      case NoteBlockStyle.normal:
        return Icons.notes_rounded;
      case NoteBlockStyle.heading1:
        return Icons.title_rounded;
      case NoteBlockStyle.heading2:
        return Icons.text_fields_rounded;
      case NoteBlockStyle.quote:
        return Icons.format_quote_rounded;
      case NoteBlockStyle.callout:
        return Icons.border_outer_rounded;
    }
  }

  Color _blockBackgroundColor(NoteBlock block) {
    if (block.colorValue != null) {
      return Color(block.colorValue!);
    }

    if (block.style == NoteBlockStyle.callout) {
      return const Color(0xFF202228);
    }

    return const Color(0xFF202228);
  }

  BoxDecoration _blockDecoration(NoteBlock block, {double borderRadius = 14}) {
    final customColor = block.colorValue == null
        ? null
        : Color(block.colorValue!);

    final backgroundColor = _blockBackgroundColor(block);

    final normalBorderColor =
        customColor?.withValues(alpha: 0.78) ??
        Colors.white.withValues(alpha: 0.14);

    final isHighlighted = block.style == NoteBlockStyle.callout;

    Border border;

    if (isHighlighted) {
      border = Border.all(
        color: Colors.white.withValues(alpha: 0.95),
        width: 1.5,
      );
    } else if (block.style == NoteBlockStyle.quote) {
      border = Border(
        left: BorderSide(
          color:
              customColor?.withValues(alpha: 0.95) ??
              Colors.white.withValues(alpha: 0.70),
          width: 2,
        ),
        top: BorderSide(color: normalBorderColor, width: 0.8),
        right: BorderSide(color: normalBorderColor, width: 0.8),
        bottom: BorderSide(color: normalBorderColor, width: 0.8),
      );
    } else {
      border = Border.all(color: normalBorderColor, width: 0.8);
    }

    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border,
      boxShadow: isHighlighted
          ? [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.18),
                blurRadius: 13,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.07),
                blurRadius: 24,
                spreadRadius: -3,
              ),
            ]
          : customColor != null
          ? [
              BoxShadow(
                color: customColor.withValues(alpha: 0.10),
                blurRadius: 14,
              ),
            ]
          : null,
    );
  }

  String _blockTypeName(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
        return 'Texto';
      case NoteBlockType.heading1:
        return 'Título grande';
      case NoteBlockType.heading2:
        return 'Subtítulo';
      case NoteBlockType.bulletList:
        return 'Lista con puntos';
      case NoteBlockType.numberedList:
        return 'Lista numerada';
      case NoteBlockType.checklist:
        return 'Lista de tareas';
      case NoteBlockType.quote:
        return 'Cita';

      case NoteBlockType.callout:
        return 'Bloque destacado';

      case NoteBlockType.image:
        return 'Imagen';

      case NoteBlockType.divider:
        return 'Separador';
    }
  }

  IconData _blockTypeIcon(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
        return Icons.notes_rounded;
      case NoteBlockType.heading1:
        return Icons.title_rounded;
      case NoteBlockType.heading2:
        return Icons.text_fields_rounded;
      case NoteBlockType.bulletList:
        return Icons.format_list_bulleted_rounded;
      case NoteBlockType.numberedList:
        return Icons.format_list_numbered_rounded;
      case NoteBlockType.checklist:
        return Icons.check_box_outlined;
      case NoteBlockType.quote:
        return Icons.format_quote_rounded;

      case NoteBlockType.callout:
        return Icons.border_outer_rounded;

      case NoteBlockType.image:
        return Icons.image_outlined;

      case NoteBlockType.divider:
        return Icons.horizontal_rule_rounded;
    }
  }

  int _listSequencePosition(int index, NoteListMarkerStyle markerStyle) {
    int position = 1;

    for (int currentIndex = index - 1; currentIndex >= 0; currentIndex--) {
      final previousBlock = _blocks[currentIndex];

      if (previousBlock.type != NoteBlockType.numberedList) {
        break;
      }

      final previousMarker =
          previousBlock.listMarkerStyle == NoteListMarkerStyle.lettered
          ? NoteListMarkerStyle.lettered
          : NoteListMarkerStyle.numbered;

      if (previousMarker != markerStyle) {
        break;
      }

      position++;
    }

    return position;
  }

  String _alphabeticMarker(int position) {
    var value = position;
    final characters = <int>[];

    while (value > 0) {
      value--;
      characters.insert(0, 65 + (value % 26));
      value ~/= 26;
    }

    return String.fromCharCodes(characters);
  }

  String _numberedMarkerForBlock(NoteBlock block, int index) {
    final markerStyle = block.listMarkerStyle == NoteListMarkerStyle.lettered
        ? NoteListMarkerStyle.lettered
        : NoteListMarkerStyle.numbered;
    final position = _listSequencePosition(index, markerStyle);

    if (markerStyle == NoteListMarkerStyle.lettered) {
      return '${_alphabeticMarker(position)}.';
    }

    return '$position.';
  }

  Widget _buildBlockDragHandle({
    double width = _blockDragHandleWidth,
    double iconSize = 19,
    double iconAlpha = 0.30,
    EdgeInsetsGeometry iconPadding = EdgeInsets.zero,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.055),
            width: 0.7,
          ),
        ),
      ),
      child: Padding(
        padding: iconPadding,
        child: Icon(
          Icons.drag_indicator_rounded,
          size: iconSize,
          color: Colors.white.withValues(alpha: iconAlpha),
        ),
      ),
    );
  }

  Widget _buildReorderableBlockDragHandle({
    required int index,
    double width = _blockDragHandleWidth,
    double? height,
    double iconSize = 19,
    double iconAlpha = 0.30,
    EdgeInsetsGeometry iconPadding = EdgeInsets.zero,
    Alignment alignment = Alignment.center,
  }) {
    final reorderIndex = _reorderIndexByBlockIndex[index] ?? index;

    final handle = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
        _lastDragGlobalPosition = event.position;

        if (index >= 0 && index < _blocks.length) {
          final block = _blocks[index];

          setState(() {
            _draggingGroupId = null;
            _draggingBlockId = block.id;
            _dragPreviewGroupId = null;
            _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
            _blockedEdgePreviewGroupId = null;
            _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
          });
        }
      },

      onPointerMove: (event) {
        _updateDragPreviewFromGlobalPosition(event.position);
      },

      onPointerUp: (_) {
        if (_draggingBlockId != null) {
          _finishDragGroupPreview();
        }
      },
      onPointerCancel: (_) {
        setState(() {
          _lastDragGlobalPosition = null;
          _draggingBlockId = null;
          _draggingGroupId = null;
          _dragPreviewGroupId = null;
          _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
          _blockedEdgePreviewGroupId = null;
          _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
        });
      },
      child: _buildBlockDragHandle(
        width: width,
        iconSize: iconSize,
        iconAlpha: iconAlpha,
        iconPadding: iconPadding,
        alignment: alignment,
      ),
    );

    return ReorderableDragStartListener(
      index: reorderIndex,
      child: height == null
          ? handle
          : SizedBox(width: width, height: height, child: handle),
    );
  }

  Widget _buildReorderableGroupDragHandle({
    required String groupId,
    required int entryIndex,
    double width = _blockDragHandleWidth,
    double height = 42,
  }) {
    final handle = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();

        setState(() {
          _draggingGroupId = groupId;
          _draggingBlockId = null;

          _dragPreviewGroupId = null;
          _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
          _blockedEdgePreviewGroupId = null;
          _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
        });
      },
      onPointerCancel: (_) {
        setState(() {
          _draggingBlockId = null;
          _draggingGroupId = null;
          _dragPreviewGroupId = null;
          _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
          _blockedEdgePreviewGroupId = null;
          _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
        });
      },
      child: _buildBlockDragHandle(
        width: width,
        iconAlpha: 0.42,
        alignment: Alignment.center,
      ),
    );

    return ReorderableDragStartListener(
      index: entryIndex,
      child: SizedBox(width: width, height: height, child: handle),
    );
  }

  Future<void> _openImagePreview(String imagePath) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 46,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupDragPlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: 8,
      ),
      child: Container(
        height: _groupDragPlaceholderHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF24252A).withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _groupBorderColor.withValues(alpha: 0.42),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _blockDragHandleWidth,
              child: IgnorePointer(
                child: _buildBlockDragHandle(
                  width: _blockDragHandleWidth,
                  iconAlpha: 0.16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: _blockDragHandleWidth),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader({
    required String groupId,
    required int firstBlockIndex,
    required int entryIndex,
    required bool isCollapsed,
  }) {
    final groupTitleController = _groupTitleControllerFor(groupId);
    final groupTitleFocusNode = _groupTitleFocusNodeFor(groupId);
    final blockCount = _blocks.where((block) {
      return _validGroupId(block.groupId) == groupId;
    }).length;

    return Container(
      constraints: const BoxConstraints(minHeight: _groupHeaderHeight),
      padding: EdgeInsets.only(right: _editorContentRight + 8),
      child: Row(
        children: [
          _buildReorderableGroupDragHandle(
            groupId: groupId,
            entryIndex: entryIndex,
          ),
          SizedBox(
            width: 34,
            height: 42,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: isCollapsed ? 'Desplegar grupo' : 'Minimizar grupo',
              onPressed: () {
                _setGroupCollapsed(groupId, !isCollapsed);
              },
              icon: Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_right_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFFFFD166),
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey<String>('group-title-$groupId'),
              controller: groupTitleController,
              focusNode: groupTitleFocusNode,
              minLines: 1,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
              decoration: InputDecoration(
                hintText: 'Título del grupo',
                hintStyle: TextStyle(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.42),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              onTap: () {
                setState(() {
                  _activeBlockIndex = firstBlockIndex;
                });
              },
              onChanged: (value) {
                _handleGroupTitleChanged(groupId, value);
              },
            ),
          ),
          if (isCollapsed)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                '$blockCount',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedBlockFrame({
    required NoteBlock block,
    required int index,
    required Widget child,
  }) {
    if (!_isGroupedBlock(block)) {
      return child;
    }

    final groupId = _effectiveGroupIdForBlock(block)!;
    final isFirst = _isFirstBlockInGroup(index);
    final isLast = _isLastBlockInGroup(index);

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(18) : Radius.zero,
      bottom: isLast ? const Radius.circular(18) : Radius.zero,
    );

    final muteFrameDuringDrag = _isDraggingBlockRelatedToGroup(groupId);
    final frameAlpha = muteFrameDuringDrag ? 0.10 : 0.68;
    final shadowAlpha = muteFrameDuringDrag ? 0.0 : 0.10;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 8 : 0),
      child: CustomPaint(
        foregroundPainter: _GroupBlockFramePainter(
          color: _groupBorderColor.withValues(alpha: frameAlpha),
          isFirst: isFirst,
          isLast: isLast,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _groupBackgroundColor,
            borderRadius: borderRadius,
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: _groupBorderColor.withValues(alpha: shadowAlpha),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFirst) ...[
                _buildGroupHeader(
                  groupId: groupId,
                  firstBlockIndex: index,
                  entryIndex: _reorderIndexByBlockIndex[index] ?? index,
                  isCollapsed: false,
                ),
                if (_shouldShowGroupEdgeDropSpace(
                  groupId,
                  _GroupEdgeDropSlot.top,
                ))
                  _buildGroupDragPlaceholder(),
              ],
              child,
              if (isLast &&
                  _shouldShowGroupEdgeDropSpace(
                    groupId,
                    _GroupEdgeDropSlot.bottom,
                  ))
                _buildGroupDragPlaceholder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedEntry({
    required String groupId,
    required List<int> blockIndexes,
    required int entryIndex,
  }) {
    final isCollapsed = _isGroupCollapsed(groupId);
    final firstBlockIndex = blockIndexes.first;
    final muteFrameDuringDrag =
        _draggingGroupId == groupId || _isDraggingBlockRelatedToGroup(groupId);
    final frameAlpha = muteFrameDuringDrag ? 0.10 : 0.82;
    final shadowAlpha = muteFrameDuringDrag ? 0.0 : 0.10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _groupBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _groupBorderColor.withValues(alpha: frameAlpha),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _groupBorderColor.withValues(alpha: shadowAlpha),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGroupHeader(
            groupId: groupId,
            firstBlockIndex: firstBlockIndex,
            entryIndex: entryIndex,
            isCollapsed: isCollapsed,
          ),
          if (!isCollapsed) ...[
            if (_shouldShowGroupEdgeDropSpace(groupId, _GroupEdgeDropSlot.top))
              _buildGroupDragPlaceholder(),
            for (final blockIndex in blockIndexes)
              KeyedSubtree(
                key: _blockViewportKeys.putIfAbsent(
                  _blocks[blockIndex].id,
                  GlobalKey.new,
                ),
                child: _buildBlock(_blocks[blockIndex], blockIndex),
              ),
            if (_shouldShowGroupEdgeDropSpace(
              groupId,
              _GroupEdgeDropSlot.bottom,
            ))
              _buildGroupDragPlaceholder(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageBlock(NoteBlock block, int index) {
    final imagePath = block.imagePath;

    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: 8,
      ),
      child: _buildSwipeableBlock(
        block: block,
        index: index,
        borderRadius: 16,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          decoration: _blockDecoration(block, borderRadius: 16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: index,
                  iconAlpha: 0.34,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: imagePath == null
                            ? null
                            : () {
                                unawaited(_openImagePreview(imagePath));
                              },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: 90,
                              maxHeight: 240,
                            ),
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: imagePath == null
                                ? const SizedBox(
                                    height: 140,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white38,
                                        size: 38,
                                      ),
                                    ),
                                  )
                                : Image.file(
                                    File(imagePath),
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox(
                                        height: 140,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white38,
                                            size: 38,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        key: ValueKey<String>(
                          'image-caption-field-${block.id}',
                        ),
                        controller: _blockControllers[block.id],
                        focusNode: _blockFocusNodes[block.id],
                        minLines: 1,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        style: _imageCaptionStyleForBlock(block),
                        textAlign: _textAlignForBlock(block),
                        decoration: InputDecoration(
                          hintText: block.style == NoteBlockStyle.heading1
                              ? 'Título'
                              : block.style == NoteBlockStyle.heading2
                              ? 'Subtítulo'
                              : 'Agrega una descripción…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 5,
                          ),
                        ),
                        onTap: () {
                          _setActiveBlock(index);
                        },
                        onChanged: (value) {
                          _handleBlockTextChanged(block.id, value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddBlockMenu(int afterIndex) async {
    if (!mounted || afterIndex < 0 || afterIndex >= _blocks.length) {
      return;
    }

    final anchorBlockId = _blocks[afterIndex].id;

    const addBlockTypes = <NoteBlockType>[
      NoteBlockType.paragraph,
      NoteBlockType.image,
      NoteBlockType.divider,
    ];

    FocusScope.of(context).unfocus();

    final selectedType = await showModalBottomSheet<NoteBlockType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C21),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.68),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Agregar contenido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Elige qué quieres insertar debajo del último bloque.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addBlockTypes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.03,
                  ),
                  itemBuilder: (context, itemIndex) {
                    final type = addBlockTypes[itemIndex];

                    return Material(
                      color: const Color(0xFF24252A),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop(type);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.09),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Icon(
                                  _blockTypeIcon(type),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _blockTypeName(type),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedType == null) {
      return;
    }

    final resolvedAfterIndex = _blocks.indexWhere(
      (block) => block.id == anchorBlockId,
    );

    final insertionAnchor = resolvedAfterIndex == -1
        ? _blocks.length - 1
        : resolvedAfterIndex;

    if (selectedType == NoteBlockType.image) {
      await _insertImageBlock(afterIndex: insertionAnchor);
      return;
    }

    _addBlock(selectedType, afterIndex: insertionAnchor);
  }

  Widget _buildAddTextSectionBar(int index) {
    return SizedBox(
      width: double.infinity,
      height: 30,
      child: Material(
        color: const Color(0xFF24252A),
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(_showAddBlockMenu(index));
          },
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white70, size: 25),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeDeleteBackground({
    required Color cornerFill,
    double borderRadius = 14,
  }) {
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cornerFill),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF671720), Color(0xFF361016)],
              ),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.62),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.44),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Eliminar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeEditBackground({
    required Color cornerFill,
    double borderRadius = 14,
  }) {
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cornerFill),
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF18283E), Color(0xFF293E62)],
              ),
              border: Border.all(
                color: const Color(0xFF7EA7FF).withValues(alpha: 0.62),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7EA7FF).withValues(alpha: 0.16),
                    border: Border.all(
                      color: const Color(0xFF7EA7FF).withValues(alpha: 0.42),
                    ),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockColorPicker(int blockIndex) async {
    if (!mounted || blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final blockId = _blocks[blockIndex].id;

    final selectedColor = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C21),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Text(
                    'Color del bloque',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final colorValue in _blockColorValues)
                        InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop(colorValue);
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(colorValue),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(0);
                      },
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Quitar color'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedColor == null) {
      return;
    }

    final resolvedIndex = _blocks.indexWhere((block) => block.id == blockId);

    if (resolvedIndex == -1) {
      return;
    }

    setState(() {
      final currentBlock = _blocks[resolvedIndex];

      _blocks[resolvedIndex] = selectedColor == 0
          ? currentBlock.copyWith(clearColorValue: true)
          : currentBlock.copyWith(colorValue: selectedColor);
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Future<void> _showEditBlockMenu(int blockIndex) async {
    if (!mounted || blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final blockId = _blocks[blockIndex].id;
    final currentStyle = _blocks[blockIndex].style;
    final currentBlockType = _blocks[blockIndex].type;
    final currentGroupId = _blocks[blockIndex].groupId;
    final isGrouped = currentGroupId != null && currentGroupId.isNotEmpty;

    FocusScope.of(context).unfocus();

    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget styleOption(NoteBlockStyle style) {
          final isActive = currentStyle == style;

          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _blockStyleIcon(style),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              _blockStyleName(style),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: isActive
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : null,
            onTap: () {
              Navigator.of(sheetContext).pop(style.name);
            },
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1C21),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Editar bloque',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  styleOption(NoteBlockStyle.callout),
                  const Divider(color: Colors.white12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A6A24).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isGrouped
                            ? Icons.folder_off_outlined
                            : Icons.create_new_folder_outlined,
                        color: const Color(0xFFFFD166),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isGrouped ? 'Quitar de grupo' : 'Agregar grupo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      isGrouped
                          ? 'Sacar solo este bloque del grupo'
                          : 'Crear un contenedor amarillo para este bloque',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(
                        sheetContext,
                      ).pop(isGrouped ? 'removeGroup' : 'addGroup');
                    },
                  ),
                  if (isGrouped) ...[
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8A6A24,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.vertical_align_top_rounded,
                          color: Color(0xFFFFD166),
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Agregar bloque arriba al grupo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop('addGroupBlockAbove');
                      },
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8A6A24,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.vertical_align_bottom_rounded,
                          color: Color(0xFFFFD166),
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Agregar bloque abajo al grupo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop('addGroupBlockBelow');
                      },
                    ),
                  ],
                  const Divider(color: Colors.white12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Agregar color al bloque',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop('color');
                    },
                  ),
                  const Divider(color: Colors.white12),

                  if (currentBlockType == NoteBlockType.image)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Reemplazar imagen',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop('replaceImage');
                      },
                    ),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.copy_all_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Duplicar bloque',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Crear una copia debajo',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop('duplicate');
                    },
                  ),
                ],
              ), // Column
            ), // SingleChildScrollView
          ), // Container
        ); // ConstrainedBox
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    final resolvedIndex = _blocks.indexWhere((block) => block.id == blockId);

    if (resolvedIndex == -1) {
      return;
    }

    if (selectedAction == 'addGroup') {
      _addGroupToBlock(resolvedIndex);
      return;
    }

    if (selectedAction == 'removeGroup') {
      _removeGroupFromBlock(resolvedIndex);
      return;
    }

    if (selectedAction == 'addGroupBlockAbove') {
      _insertParagraphBlockInGroup(resolvedIndex, above: true);
      return;
    }

    if (selectedAction == 'addGroupBlockBelow') {
      _insertParagraphBlockInGroup(resolvedIndex, above: false);
      return;
    }

    if (selectedAction == 'duplicate') {
      await _duplicateBlock(resolvedIndex);
      return;
    }

    if (selectedAction == 'replaceImage') {
      await _replaceImageBlock(resolvedIndex);
      return;
    }

    if (selectedAction == 'color') {
      await _showBlockColorPicker(resolvedIndex);
      return;
    }

    final selectedStyle = NoteBlockStyle.values.firstWhere(
      (style) => style.name == selectedAction,
      orElse: () => NoteBlockStyle.normal,
    );

    setState(() {
      final currentBlock = _blocks[resolvedIndex];
      _blocks[resolvedIndex] = currentBlock.copyWith(
        style: currentBlock.style == selectedStyle
            ? NoteBlockStyle.normal
            : selectedStyle,
      );
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Widget _buildSwipeableBlock({
    required NoteBlock block,
    required int index,
    required Widget child,
    double borderRadius = 14,
    bool enableEdit = true,
    Color? cornerFillOverride,
  }) {
    final cornerFill = cornerFillOverride ?? _blockBackgroundColor(block);

    return _SwipeActionBlock(
      key: ValueKey<String>('swipe-${block.id}'),
      enableEdit: enableEdit,
      borderRadius: borderRadius,
      cornerFill: cornerFill,
      deleteBackground: _buildSwipeDeleteBackground(
        cornerFill: cornerFill,
        borderRadius: borderRadius,
      ),
      editBackground: _buildSwipeEditBackground(
        cornerFill: cornerFill,
        borderRadius: borderRadius,
      ),
      onDelete: () async {
        final currentIndex = _blocks.indexWhere((currentBlock) {
          return currentBlock.id == block.id;
        });

        if (currentIndex == -1) {
          return false;
        }

        final removesBlock = _blocks.length > 1;

        HapticFeedback.mediumImpact();
        _deleteBlock(currentIndex);

        return removesBlock;
      },
      onEdit: () async {
        final currentIndex = _blocks.indexWhere((currentBlock) {
          return currentBlock.id == block.id;
        });

        if (currentIndex == -1) {
          return;
        }

        HapticFeedback.selectionClick();
        await _showEditBlockMenu(currentIndex);
      },
      child: child,
    );
  }

  Widget _buildWordListBlock(NoteBlock block, int blockIndex) {
    _ensureListEditorsForBlock(block);

    final controllers = _listLineControllers[block.id]!;
    final focusNodes = _listLineFocusNodes[block.id]!;
    final checklistStates = _checklistStatesForBlock(block, controllers.length);

    Widget markerForItem(int itemIndex) {
      if (block.type == NoteBlockType.checklist) {
        return SizedBox(
          width: 34,
          height: 34,
          child: Checkbox(
            value: checklistStates[itemIndex],
            activeColor: _textColorForBlock(block),
            checkColor: Colors.black,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: _textColorForBlock(block)),
            onChanged: (value) {
              _toggleChecklistItem(blockIndex, itemIndex, value ?? false);
            },
          ),
        );
      }

      if (block.type == NoteBlockType.bulletList) {
        return SizedBox(
          width: 34,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '•',
              textAlign: TextAlign.center,
              style: _textStyleForBlock(
                block,
              ).copyWith(fontSize: 20, height: 1),
            ),
          ),
        );
      }

      final marker = block.listMarkerStyle == NoteListMarkerStyle.lettered
          ? '${_alphabeticMarker(itemIndex + 1)}.'
          : '${itemIndex + 1}.';

      return SizedBox(
        width: 38,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            marker,
            textAlign: TextAlign.right,
            style: _textStyleForBlock(
              block,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: 8,
      ),
      child: _buildSwipeableBlock(
        block: block,
        index: blockIndex,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
          decoration: _blockDecoration(block),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: blockIndex,
                  iconPadding: const EdgeInsets.only(top: 8),
                  alignment: Alignment.topCenter,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(controllers.length, (
                    itemIndex,
                  ) {
                    final isChecked =
                        block.type == NoteBlockType.checklist &&
                        checklistStates[itemIndex];

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: itemIndex == controllers.length - 1 ? 0 : 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          markerForItem(itemIndex),
                          const SizedBox(width: 5),
                          Expanded(
                            child: TextField(
                              key: ValueKey<String>(
                                'list-field-${block.id}-$itemIndex',
                              ),
                              controller: controllers[itemIndex],
                              focusNode: focusNodes[itemIndex],
                              minLines: 1,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              scrollPadding: EdgeInsets.zero,
                              style: _textStyleForBlock(block).copyWith(
                                decoration: isChecked
                                    ? TextDecoration.combine([
                                        if (block.isUnderline)
                                          TextDecoration.underline,
                                        TextDecoration.lineThrough,
                                      ])
                                    : block.isUnderline
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                color: isChecked
                                    ? _textColorForBlock(
                                        block,
                                      ).withValues(alpha: 0.55)
                                    : _textColorForBlock(block),
                              ),
                              textAlign: _textAlignForBlock(block),
                              decoration: InputDecoration(
                                hintText: itemIndex == 0
                                    ? 'Escribe el primer elemento…'
                                    : 'Nuevo elemento…',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 7,
                                ),
                              ),
                              onTap: () {
                                _setActiveBlock(blockIndex);
                              },
                              onChanged: (value) {
                                _handleListItemChanged(
                                  blockIndex,
                                  itemIndex,
                                  value,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(NoteBlock block, int index) {
    if (block.type == NoteBlockType.image) {
      return _buildImageBlock(block, index);
    }

    if (block.type == NoteBlockType.divider) {
      return Padding(
        key: ValueKey(block.id),
        padding: const EdgeInsets.only(
          left: _editorContentLeft,
          right: _editorContentRight,
          bottom: 8,
        ),
        child: _buildSwipeableBlock(
          block: block,
          index: index,
          enableEdit: false,
          cornerFillOverride: Colors.transparent,
          borderRadius: 10,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                _buildReorderableBlockDragHandle(
                  index: index,
                  width: 34,
                  height: 34,
                  iconSize: 18,
                  iconAlpha: 0.28,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isWordListBlock(block)) {
      return _buildWordListBlock(block, index);
    }

    Widget? prefix;

    if (block.type == NoteBlockType.bulletList) {
      prefix = Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '•',
          style: _textStyleForBlock(block).copyWith(fontSize: 20, height: 1),
        ),
      );
    }

    if (block.type == NoteBlockType.numberedList) {
      prefix = Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Text(
          _numberedMarkerForBlock(block, index),
          style: _textStyleForBlock(
            block,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );
    }

    if (block.type == NoteBlockType.checklist) {
      prefix = SizedBox(
        width: 34,
        height: 34,
        child: Checkbox(
          value: block.isChecked,
          activeColor: _textColorForBlock(block),
          checkColor: Colors.black,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: _textColorForBlock(block)),
          onChanged: (value) {
            _toggleChecklist(index, value ?? false);
          },
        ),
      );
    }

    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwipeableBlock(
            block: block,
            index: index,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              decoration: _blockDecoration(block),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _blockDragHandleWidth,
                    child: _buildReorderableBlockDragHandle(index: index),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prefix != null) ...[
                          prefix,
                          const SizedBox(width: 7),
                        ],
                        Expanded(
                          child: TextField(
                            key: ValueKey<String>('text-field-${block.id}'),
                            controller: _blockControllers[block.id],
                            focusNode: _blockFocusNodes[block.id],
                            minLines: 3,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            style: _textStyleForBlock(block),
                            textAlign: _textAlignForBlock(block),
                            decoration: InputDecoration(
                              hintText: block.style == NoteBlockStyle.heading1
                                  ? 'Título'
                                  : block.style == NoteBlockStyle.heading2
                                  ? 'Subtítulo'
                                  : 'Escribe algo…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onTap: () {
                              _setActiveBlock(index);
                            },
                            onChanged: (value) {
                              _handleBlockTextChanged(block.id, value);
                            },
                            onSubmitted: (_) {
                              _handleBlockSubmitted(index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSearchableBlock(NoteBlock block) {
    return block.type != NoteBlockType.image &&
        block.type != NoteBlockType.divider;
  }

  String _searchLabelForBlock(NoteBlock block) {
    if (block.style == NoteBlockStyle.heading1) {
      return 'Título interno';
    }

    if (block.style == NoteBlockStyle.heading2) {
      return 'Subtítulo';
    }

    if (block.style == NoteBlockStyle.quote) {
      return 'Cita';
    }

    if (block.style == NoteBlockStyle.callout) {
      return 'Bloque destacado';
    }

    switch (block.type) {
      case NoteBlockType.bulletList:
        return 'Lista con puntos';
      case NoteBlockType.numberedList:
        return block.listMarkerStyle == NoteListMarkerStyle.lettered
            ? 'Lista por letras'
            : 'Lista numerada';
      case NoteBlockType.checklist:
        return 'Lista de tareas';
      case NoteBlockType.paragraph:
        return 'Texto';
      case NoteBlockType.heading1:
        return 'Título interno';
      case NoteBlockType.heading2:
        return 'Subtítulo';
      case NoteBlockType.quote:
        return 'Cita';
      case NoteBlockType.callout:
        return 'Bloque destacado';
      case NoteBlockType.image:
        return 'Imagen';
      case NoteBlockType.divider:
        return 'Separador';
    }
  }

  List<_NoteSearchResult> _searchCurrentNote(String rawQuery) {
    final query = rawQuery.trim();

    if (query.isEmpty) {
      return const <_NoteSearchResult>[];
    }

    final normalizedQuery = query.toLowerCase();
    final results = <_NoteSearchResult>[];

    for (var index = 0; index < _blocks.length; index++) {
      final block = _blocks[index];

      if (!_isSearchableBlock(block)) {
        continue;
      }

      final text = _blockControllers[block.id]?.text ?? block.text;
      final matchStart = text.toLowerCase().indexOf(normalizedQuery);

      if (matchStart == -1) {
        continue;
      }

      results.add(
        _NoteSearchResult(
          blockId: block.id,
          blockNumber: index + 1,
          label: _searchLabelForBlock(block),
          text: text,
          query: query,
          matchStart: matchStart,
        ),
      );
    }

    return results;
  }

  String _searchResultSnippet(_NoteSearchResult result) {
    final compactText = result.text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (compactText.isEmpty) {
      return 'Bloque sin contenido';
    }

    final normalizedCompactText = compactText.toLowerCase();
    final normalizedQuery = result.query.toLowerCase();
    final compactMatchStart = normalizedCompactText.indexOf(normalizedQuery);
    final resolvedMatchStart = compactMatchStart == -1 ? 0 : compactMatchStart;
    final start = (resolvedMatchStart - 34)
        .clamp(0, compactText.length)
        .toInt();
    final end = (resolvedMatchStart + result.query.length + 54)
        .clamp(0, compactText.length)
        .toInt();
    final leadingEllipsis = start > 0 ? '…' : '';
    final trailingEllipsis = end < compactText.length ? '…' : '';

    return '$leadingEllipsis${compactText.substring(start, end)}$trailingEllipsis';
  }

  Future<void> _openSearchResult(_NoteSearchResult result) async {
    final blockIndex = _blocks.indexWhere(
      (block) => block.id == result.blockId,
    );

    if (!mounted || blockIndex == -1) {
      return;
    }

    final block = _blocks[blockIndex];

    setState(() {
      _activeBlockIndex = blockIndex;
    });

    if (_isWordListBlock(block)) {
      _ensureListEditorsForBlock(block);

      final controllers = _listLineControllers[result.blockId];
      final focusNodes = _listLineFocusNodes[result.blockId];

      if (controllers != null && focusNodes != null) {
        var accumulatedOffset = 0;

        for (var itemIndex = 0; itemIndex < controllers.length; itemIndex++) {
          final controller = controllers[itemIndex];
          final lineEnd = accumulatedOffset + controller.text.length;

          if (result.matchStart >= accumulatedOffset &&
              result.matchStart <= lineEnd) {
            final localStart = (result.matchStart - accumulatedOffset)
                .clamp(0, controller.text.length)
                .toInt();
            final localEnd = (localStart + result.query.length)
                .clamp(0, controller.text.length)
                .toInt();

            controller.selection = TextSelection(
              baseOffset: localStart,
              extentOffset: localEnd,
            );
            focusNodes[itemIndex].requestFocus();
            break;
          }

          accumulatedOffset = lineEnd + 1;
        }
      }
    } else {
      final controller = _blockControllers[result.blockId];
      final focusNode = _blockFocusNodes[result.blockId];

      if (controller != null) {
        final matchStart = controller.text.toLowerCase().indexOf(
          result.query.toLowerCase(),
        );

        if (matchStart != -1) {
          controller.selection = TextSelection(
            baseOffset: matchStart,
            extentOffset: matchStart + result.query.length,
          );
        }
      }

      focusNode?.requestFocus();
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (!mounted) {
      return;
    }

    final targetContext = _blockViewportKeys[result.blockId]?.currentContext;

    if (targetContext == null || !targetContext.mounted) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  Future<void> _showNoteSearch() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final searchController = TextEditingController();
    var query = '';

    final selectedResult = await showModalBottomSheet<_NoteSearchResult>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final results = _searchCurrentNote(query);
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: FractionallySizedBox(
                heightFactor: 0.72,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1C21),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar en esta nota',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.34),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      query = '';
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white54,
                                  ),
                                ),
                          filled: true,
                          fillColor: const Color(0xFF25272D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.34),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            query = value;
                          });
                        },
                        onSubmitted: (_) {
                          if (results.length == 1) {
                            Navigator.of(sheetContext).pop(results.first);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          query.trim().isEmpty
                              ? 'Busca en todos los bloques de texto de esta nota.'
                              : results.isEmpty
                              ? 'Sin coincidencias'
                              : '${results.length} ${results.length == 1 ? 'bloque encontrado' : 'bloques encontrados'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.52),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: query.trim().isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.manage_search_rounded,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              )
                            : results.isEmpty
                            ? Center(
                                child: Text(
                                  'No se encontró “${query.trim()}” en los bloques de esta nota.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: results.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final result = results[index];

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.07,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${result.blockNumber}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      result.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        _searchResultSnippet(result),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.52,
                                          ),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white38,
                                    ),
                                    onTap: () {
                                      Navigator.of(sheetContext).pop(result);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    if (!mounted || selectedResult == null) {
      return;
    }

    await _openSearchResult(selectedResult);
  }

  Widget _buildToolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: isActive
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                icon,
                size: 17,
                color: onPressed == null
                    ? Colors.white24
                    : isActive
                    ? Colors.white
                    : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    final activeBlock = _activeFormattingBlock;
    final textEnabled =
        activeBlock != null && _supportsTextFormatting(activeBlock);
    final listEnabled =
        activeBlock != null && _supportsListFormatting(activeBlock);
    final activeListMode = activeBlock == null
        ? _ToolbarListMode.paragraph
        : _listModeForBlock(activeBlock);
    final activeAlignment =
        activeBlock?.textAlignment ?? NoteTextAlignment.left;
    final activeTextColor = activeBlock?.textColorValue == null
        ? Colors.white
        : Color(activeBlock!.textColorValue!);
    final isBoldActive = activeBlock?.isBold ?? false;
    final isItalicActive = activeBlock?.isItalic ?? false;
    final isUnderlineActive = activeBlock?.isUnderline ?? false;
    final displayedSize = activeBlock == null
        ? 16
        : (activeBlock.fontSize ?? _defaultFontSizeForBlock(activeBlock))
              .round();

    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF202228),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 2, right: 4),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: textEnabled
                          ? () {
                              unawaited(_showFontFamilyPicker());
                            }
                          : null,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        width: 84,
                        height: 32,
                        padding: const EdgeInsets.only(left: 5, right: 2),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                activeBlock?.fontFamily ?? 'Fuente',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textEnabled
                                      ? Colors.white
                                      : Colors.white30,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 1),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: textEnabled
                                  ? Colors.white70
                                  : Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: textEnabled
                          ? () {
                              unawaited(_showFontSizePicker());
                            }
                          : null,
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 40,
                        height: 32,
                        child: Center(
                          child: Text(
                            '$displayedSize',
                            style: TextStyle(
                              color: textEnabled
                                  ? Colors.white
                                  : Colors.white30,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Color de letra',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: textEnabled
                            ? () {
                                unawaited(_showTextColorPicker());
                              }
                            : null,
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 34,
                          height: 32,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.format_color_text_rounded,
                                size: 17,
                                color: textEnabled
                                    ? Colors.white70
                                    : Colors.white24,
                              ),
                              Container(
                                width: 16,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: textEnabled
                                      ? activeTextColor
                                      : Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Negrita',
                    isActive: isBoldActive,
                    onPressed: textEnabled ? _toggleBold : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Cursiva',
                    isActive: isItalicActive,
                    onPressed: textEnabled ? _toggleItalic : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_underlined_rounded,
                    tooltip: 'Subrayado',
                    isActive: isUnderlineActive,
                    onPressed: textEnabled ? _toggleUnderline : null,
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_align_left_rounded,
                    tooltip: 'Alinear a la izquierda',
                    isActive: activeAlignment == NoteTextAlignment.left,
                    onPressed: textEnabled
                        ? () => _applyTextAlignment(NoteTextAlignment.left)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_align_center_rounded,
                    tooltip: 'Centrar',
                    isActive: activeAlignment == NoteTextAlignment.center,
                    onPressed: textEnabled
                        ? () => _applyTextAlignment(NoteTextAlignment.center)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_align_right_rounded,
                    tooltip: 'Alinear a la derecha',
                    isActive: activeAlignment == NoteTextAlignment.right,
                    onPressed: textEnabled
                        ? () => _applyTextAlignment(NoteTextAlignment.right)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_align_justify_rounded,
                    tooltip: 'Justificar',
                    isActive: activeAlignment == NoteTextAlignment.justify,
                    onPressed: textEnabled
                        ? () => _applyTextAlignment(NoteTextAlignment.justify)
                        : null,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.notes_rounded,
                    tooltip: 'Texto normal',
                    isActive: activeListMode == _ToolbarListMode.paragraph,
                    onPressed: listEnabled
                        ? () => _applyListMode(_ToolbarListMode.paragraph)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Lista con puntos',
                    isActive: activeListMode == _ToolbarListMode.bullet,
                    onPressed: listEnabled
                        ? () => _applyListMode(_ToolbarListMode.bullet)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.format_list_numbered_rounded,
                    tooltip: 'Lista numerada',
                    isActive: activeListMode == _ToolbarListMode.numbered,
                    onPressed: listEnabled
                        ? () => _applyListMode(_ToolbarListMode.numbered)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.sort_by_alpha_rounded,
                    tooltip: 'Lista por letras',
                    isActive: activeListMode == _ToolbarListMode.lettered,
                    onPressed: listEnabled
                        ? () => _applyListMode(_ToolbarListMode.lettered)
                        : null,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.check_box_outlined,
                    tooltip: 'Lista de tareas',
                    isActive: activeListMode == _ToolbarListMode.checklist,
                    onPressed: listEnabled
                        ? () => _applyListMode(_ToolbarListMode.checklist)
                        : null,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'Buscar en esta nota',
                    onPressed: () {
                      unawaited(_showNoteSearch());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF202228),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: _titleController,
          minLines: 1,
          maxLines: 2,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
          decoration: InputDecoration(
            hintText: 'Sin título',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.23)),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          onTap: () {
            setState(() {
              _activeBlockIndex = null;
            });
          },
          onChanged: (_) {
            _saveNote();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renderEntries = _buildRenderEntries();
    _reorderIndexByBlockIndex = _buildReorderIndexMap(renderEntries);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Editar nota',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Más opciones',
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStickyTitle(),
          _buildFormattingToolbar(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 37, 12, 36),
              buildDefaultDragHandles: false,
              itemCount: renderEntries.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  type: MaterialType.transparency,
                  color: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  child: child,
                );
              },
              footer: Padding(
                key: const ValueKey('add-block-footer-static'),
                padding: const EdgeInsets.only(
                  left: _editorContentLeft,
                  right: _editorContentRight,
                  bottom: 72,
                ),
                child: _buildAddTextSectionBar(_blocks.length - 1),
              ),
              onReorderStart: (index) {
                if (index < 0 || index >= renderEntries.length) {
                  return;
                }

                if (_draggingGroupId != null) {
                  return;
                }

                final entry = renderEntries[index];

                if (entry.isGroup) {
                  setState(() {
                    _draggingGroupId = entry.groupId;
                    _draggingBlockId = null;

                    _dragPreviewGroupId = null;
                    _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
                    _blockedEdgePreviewGroupId = null;
                    _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
                  });

                  return;
                }

                setState(() {
                  _draggingGroupId = null;
                  _draggingBlockId = _blocks[entry.firstBlockIndex].id;
                  _dragPreviewGroupId = null;
                  _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
                  _blockedEdgePreviewGroupId = null;
                  _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
                });
              },
              onReorderEnd: (index) {
                if (_draggingBlockId != null) {
                  _finishDragGroupPreview();
                  return;
                }

                if (_draggingGroupId != null || _dragPreviewGroupId != null) {
                  setState(() {
                    _draggingGroupId = null;
                    _dragPreviewGroupId = null;
                    _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
                  });
                }
              },
              onReorderItem: (oldIndex, newIndex) {
                if (oldIndex < 0 || oldIndex >= renderEntries.length) {
                  return;
                }

                final safeNewIndex = newIndex
                    .clamp(0, renderEntries.length)
                    .toInt();

                _reorderRenderEntries(oldIndex, safeNewIndex);
              },
              itemBuilder: (context, index) {
                final entry = renderEntries[index];

                if (entry.isGroup) {
                  final groupId = entry.groupId!;
                  final groupViewportKey = _groupViewportKeys.putIfAbsent(
                    groupId,
                    GlobalKey.new,
                  );

                  return KeyedSubtree(
                    key: groupViewportKey,
                    child: _buildGroupedEntry(
                      groupId: groupId,
                      blockIndexes: entry.blockIndexes,
                      entryIndex: index,
                    ),
                  );
                }

                final blockIndex = entry.firstBlockIndex;
                final block = _blocks[blockIndex];
                final viewportKey = _blockViewportKeys.putIfAbsent(
                  block.id,
                  GlobalKey.new,
                );

                final builtBlock = _buildBlock(block, blockIndex);

                return KeyedSubtree(
                  key: viewportKey,
                  child: _isGroupedBlock(block)
                      ? _buildGroupedBlockFrame(
                          block: block,
                          index: blockIndex,
                          child: builtBlock,
                        )
                      : builtBlock,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBlockFramePainter extends CustomPainter {
  const _GroupBlockFramePainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;
    const strokeWidth = 0.9;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    final halfStroke = strokeWidth / 2;

    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    if (isFirst && isLast) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
        paint,
      );
      return;
    }

    final path = Path();

    if (isFirst) {
      path
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + radius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + radius, rect.top)
        ..lineTo(rect.right - radius, rect.top)
        ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + radius)
        ..lineTo(rect.right, rect.bottom);
    } else if (isLast) {
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.left, rect.bottom - radius)
        ..quadraticBezierTo(
          rect.left,
          rect.bottom,
          rect.left + radius,
          rect.bottom,
        )
        ..lineTo(rect.right - radius, rect.bottom)
        ..quadraticBezierTo(
          rect.right,
          rect.bottom,
          rect.right,
          rect.bottom - radius,
        )
        ..lineTo(rect.right, rect.top);
    } else {
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.left, rect.bottom)
        ..moveTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GroupBlockFramePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast;
  }
}

class _SwipeActionBlock extends StatefulWidget {
  const _SwipeActionBlock({
    required this.child,
    required this.deleteBackground,
    required this.editBackground,
    required this.cornerFill,
    required this.onDelete,
    required this.onEdit,
    required this.borderRadius,
    required this.enableEdit,
    super.key,
  });

  final Widget child;
  final Widget deleteBackground;
  final Widget editBackground;
  final Color cornerFill;
  final Future<bool> Function() onDelete;
  final Future<void> Function() onEdit;
  final double borderRadius;
  final bool enableEdit;

  @override
  State<_SwipeActionBlock> createState() => _SwipeActionBlockState();
}

class _SwipeActionBlockState extends State<_SwipeActionBlock>
    with SingleTickerProviderStateMixin {
  static const double _deleteThreshold = 0.42;
  static const double _editThreshold = 0.34;
  static const double _velocityThreshold = 900;

  late final AnimationController _animationController;

  Animation<double>? _offsetAnimation;
  double _dragOffset = 0;
  double _availableWidth = 0;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 190),
        )..addListener(() {
          final animation = _offsetAnimation;

          if (animation == null || !mounted) {
            return;
          }

          setState(() {
            _dragOffset = animation.value;
          });
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 190),
  }) async {
    _animationController
      ..stop()
      ..duration = duration;

    _offsetAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    try {
      await _animationController.forward(from: 0).orCancel;
    } catch (_) {
      // La animación puede cancelarse si comienza otro gesto.
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isProcessingAction) {
      return;
    }

    _animationController.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isProcessingAction || _availableWidth <= 0) {
      return;
    }

    final maximumOffset = _availableWidth * 0.88;

    final minimumOffset = widget.enableEdit ? -maximumOffset : 0.0;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(minimumOffset, maximumOffset)
          .toDouble();
    });
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (_isProcessingAction || _availableWidth <= 0) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;

    final shouldDelete =
        _dragOffset >= _availableWidth * _deleteThreshold ||
        velocity >= _velocityThreshold;

    final shouldEdit =
        widget.enableEdit &&
        (_dragOffset <= -_availableWidth * _editThreshold ||
            velocity <= -_velocityThreshold);

    if (shouldDelete) {
      setState(() {
        _isProcessingAction = true;
      });

      await _animateTo(
        _availableWidth + 28,
        duration: const Duration(milliseconds: 170),
      );

      final removed = await widget.onDelete();

      if (!mounted) {
        return;
      }

      if (!removed) {
        await _animateTo(0);

        if (!mounted) {
          return;
        }

        setState(() {
          _isProcessingAction = false;
        });
      }

      return;
    }

    if (shouldEdit) {
      setState(() {
        _isProcessingAction = true;
      });

      await _animateTo(0);

      if (!mounted) {
        return;
      }

      await widget.onEdit();

      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingAction = false;
      });

      return;
    }

    await _animateTo(0);
  }

  void _handleDragCancel() {
    if (_isProcessingAction) {
      return;
    }

    unawaited(_animateTo(0));
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    return LayoutBuilder(
      builder: (context, constraints) {
        _availableWidth = constraints.maxWidth;

        final rawProgress = _availableWidth <= 0
            ? 0.0
            : (_dragOffset.abs() / (_availableWidth * 0.42))
                  .clamp(0.0, 1.0)
                  .toDouble();

        final showDeleteBackground = _dragOffset > 0.5;
        final showEditBackground = widget.enableEdit && _dragOffset < -0.5;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: _handleDragCancel,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (showDeleteBackground || showEditBackground)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.28 + (rawProgress * 0.72),
                      child: ClipRRect(
                        borderRadius: radius,
                        clipBehavior: Clip.antiAlias,
                        child: showDeleteBackground
                            ? widget.deleteBackground
                            : widget.editBackground,
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.cornerFill,
                      borderRadius: radius,
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
