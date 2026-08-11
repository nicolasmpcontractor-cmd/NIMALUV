// NIMAHUB_NOTE_EDITOR_WORD_STYLE_LISTS_V8
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
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

class _AddContentMenuItem {
  const _AddContentMenuItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _LinkedBlockTextController extends TextEditingController {
  _LinkedBlockTextController({
    String text = '',
    List<NoteBlockLink> links = const <NoteBlockLink>[],
  }) : _links = links,
       super(text: text);

  List<NoteBlockLink> _links;

  bool _sameLinks(List<NoteBlockLink> first, List<NoteBlockLink> second) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      final firstLink = first[index];
      final secondLink = second[index];

      if (firstLink.id != secondLink.id ||
          firstLink.start != secondLink.start ||
          firstLink.end != secondLink.end ||
          firstLink.label != secondLink.label ||
          firstLink.target != secondLink.target) {
        return false;
      }
    }

    return true;
  }

  void updateLinks(List<NoteBlockLink> links) {
    if (_sameLinks(_links, links)) {
      return;
    }

    _links = links;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;
    final spans = <InlineSpan>[];

    final sortedLinks = _links.where((link) {
      return link.start >= 0 &&
          link.end <= currentText.length &&
          link.start < link.end;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    var currentIndex = 0;

    for (final link in sortedLinks) {
      if (link.start < currentIndex) {
        continue;
      }

      if (link.start > currentIndex) {
        spans.add(
          TextSpan(
            text: currentText.substring(currentIndex, link.start),
            style: baseStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: currentText.substring(link.start, link.end),
          style: baseStyle.copyWith(
            color: const Color(0xFF7EA7FF),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF7EA7FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      currentIndex = link.end;
    }

    if (currentIndex < currentText.length) {
      spans.add(
        TextSpan(text: currentText.substring(currentIndex), style: baseStyle),
      );
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  final NotesController _notesController = NotesController.instance;
  static const double _editorContentLeft = 4;
  static const double _editorContentRight = 12;
  static const double _blockDragHandleWidth = 34;
  static const double _textBlockDragHandleWidth = 31;
  static const Color _editorNeutralGray = Color(0xFF34363D);
  static const Color _editorBlockGray = Color(0xFF2F3137);
  static const Color _groupBorderColor = Color(0xFF6A6E78);
  static const Color _groupBackgroundColor = Color(0x3334363D);
  static const Color _groupDefaultTextColor = Color(0xFFE2E5EC);
  static const double _groupFrameRightInset = 8;
  static const double _groupFrameLeftInset = 0;
  static const double _groupDragPlaceholderHeight = 86;
  static const double _groupHeaderHeight = 50;
  static const double _groupAddHandleHeight = 22;
  static const double _groupAddPreviewBlockHeight = 86;
  static const double _groupAddDragThreshold = 38;
  static const int _groupAddMaxBlocksPerDrag = 5;
  static const double _groupDropPreviewHeight = 76;
  static const double _textBlockCollapsedHeight = 86;
  static const double _textBlockExpandedMaxHeight =
      _textBlockCollapsedHeight * 5;
  static const int _ribbonSlotCount = 5;
  static const double _ribbonCollapsedItemWidth = 118;
  static const double _ribbonItemGap = 8;

  static const String _dragNoGroupPreviewId = '__nimahub_drag_no_group__';

  static const List<NoteBlockType> _insertableBlockTypes = [
    NoteBlockType.paragraph,
    NoteBlockType.bulletList,
    NoteBlockType.numberedList,
    NoteBlockType.checklist,
    NoteBlockType.ribbon,
    NoteBlockType.image,
    NoteBlockType.file,
    NoteBlockType.divider,
  ];

  static const List<int> _blockColorValues = <int>[
    // Neutros
    0xFF141519,
    0xFF1D1F24,
    0xFF24252A,
    0xFF2D3037,
    0xFF34363D,
    0xFF4A4D57,

    // Azules
    0xFF13243D,
    0xFF16324F,
    0xFF1E4666,
    0xFF244B72,
    0xFF285B7A,
    0xFF2F6E94,

    // Turquesas
    0xFF123C43,
    0xFF164C55,
    0xFF1E5D63,
    0xFF286A73,
    0xFF1F6F6B,
    0xFF2F7F79,

    // Verdes
    0xFF183827,
    0xFF1E4935,
    0xFF285A42,
    0xFF356B4D,
    0xFF4B6643,
    0xFF556F39,

    // Dorados
    0xFF4B4424,
    0xFF5B5129,
    0xFF6B5D2F,
    0xFF70572A,
    0xFF7A6130,
    0xFF826A38,

    // Naranjas y marrones
    0xFF4B3322,
    0xFF5C4027,
    0xFF704C2D,
    0xFF785637,
    0xFF6B4636,
    0xFF7C4E3C,

    // Rosados y rojos
    0xFF4A2633,
    0xFF5A3048,
    0xFF713851,
    0xFF80445C,
    0xFF592B2F,
    0xFF814247,

    // Morados
    0xFF292848,
    0xFF342B59,
    0xFF49346A,
    0xFF5A3D75,
    0xFF684B78,
    0xFF5D4B8A,
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
  final FocusNode _titleFocusNode = FocusNode();

  final Map<String, TextEditingController> _blockControllers = {};

  final Map<String, FocusNode> _blockFocusNodes = {};
  final Map<String, ScrollController> _textBlockScrollControllers = {};
  final Map<String, List<TextEditingController>> _ribbonTextControllers = {};
  final Map<String, List<FocusNode>> _ribbonTextFocusNodes = {};
  final Map<String, PageController> _ribbonPageControllers = {};
  final Set<String> _expandedRibbonItemIds = <String>{};
  final Set<String> _expandedRibbonVerticalItemIds = <String>{};

  final Map<String, TextEditingController> _groupTitleControllers = {};

  final Map<String, FocusNode> _groupTitleFocusNodes = {};

  bool _keyboardBackDismissRequested = false;
  bool _textFocusBackDismissRequested = false;
  bool _isEditorBackExitInProgress = false;
  FocusNode? _lastEditorTextFocusNode;
  double _lastEditorKeyboardInset = 0;
  Timer? _editorBackSequenceResetTimer;
  bool _hasPendingNoteSave = false;

  String? _draggingBlockId;
  String? _draggingGroupId;
  String? _dragPreviewGroupId;
  String? _editingLinkedBlockId;
  Offset? _lastDragGlobalPosition;
  int _linkSerial = 0;

  _GroupEdgeDropSlot _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
  String? _blockedEdgePreviewGroupId;
  _GroupEdgeDropSlot _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;

  Map<int, int> _reorderIndexByBlockIndex = <int, int>{};

  final Map<String, GlobalKey> _groupViewportKeys = <String, GlobalKey>{};
  final Map<String, double> _groupAddDragOffsets = <String, double>{};
  final Map<String, double> _groupAddDragStartY = <String, double>{};
  final Map<String, double> _groupAddHandleStartTop = <String, double>{};
  OverlayEntry? _groupAddDragOverlayEntry;
  String? _activeGroupAddDragId;

  final Map<String, GlobalKey> _singleGroupSlotKeys = <String, GlobalKey>{};
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
  bool _hasPendingReorderSave = false;
  bool _isExternalBlockReorderActive = false;
  String? _externalDraggingBlockId;
  final Set<String> _expandedTextBlockIds = <String>{};
  final Map<String, double> _externalReorderGroupHeights = <String, double>{};
  final Map<String, double> _externalReorderBlockHeights = <String, double>{};

  bool get _isReorderInteractionActive {
    return _draggingBlockId != null || _draggingGroupId != null;
  }

  bool get _isInternalGroupBlockReorderActive {
    final draggingBlockId = _draggingBlockId;

    if (draggingBlockId == null) {
      return false;
    }

    return _groupIdForBlockId(draggingBlockId) != null;
  }

  bool get _freezeExpandedGroupsDuringExternalBlockReorder {
    return true;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _lastEditorKeyboardInset = _currentEditorKeyboardInset();

    final note = _notesController.noteById(widget.noteId);

    _titleController = TextEditingController(text: note?.title ?? '');

    _blocks = (note?.blocks ?? const <NoteBlock>[])
        .map(_normalizeLegacyBlock)
        .toList();

    if (_blocks.isEmpty) {
      _blocks.add(NoteBlock(id: _newBlockId(), type: NoteBlockType.paragraph));
    }

    _migrateLegacyGroupColorValues();

    for (final block in _blocks) {
      _blockControllers[block.id] = _createBlockTextController(block);

      _blockFocusNodes[block.id] = FocusNode();

      if (_isWordListBlock(block)) {
        _createListEditorsForBlock(block);
      }

      if (block.type == NoteBlockType.ribbon) {
        _createRibbonEditorsForBlock(block);
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
    _saveDebounce = null;
    _editorBackSequenceResetTimer?.cancel();

    if (_hasPendingNoteSave) {
      unawaited(_persistNote());
    }

    _titleController.dispose();
    _titleFocusNode.dispose();

    for (final controller in _blockControllers.values) {
      controller.dispose();
    }

    for (final focusNode in _blockFocusNodes.values) {
      focusNode.dispose();
    }

    for (final scrollController in _textBlockScrollControllers.values) {
      scrollController.dispose();
    }

    for (final controllers in _ribbonTextControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    for (final focusNodes in _ribbonTextFocusNodes.values) {
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    }

    for (final pageController in _ribbonPageControllers.values) {
      pageController.dispose();
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

    _groupAddDragOverlayEntry?.remove();
    _groupAddDragOverlayEntry = null;
    _activeGroupAddDragId = null;

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _newBlockId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _newLinkId() {
    _linkSerial += 1;
    return 'link_${DateTime.now().microsecondsSinceEpoch}_$_linkSerial';
  }

  TextEditingController _createBlockTextController(NoteBlock block) {
    return _LinkedBlockTextController(text: block.text, links: block.links);
  }

  void _syncBlockControllerLinks(NoteBlock block) {
    final controller = _blockControllers[block.id];

    if (controller is _LinkedBlockTextController) {
      controller.updateLinks(block.links);
    }
  }

  bool _isWordListBlock(NoteBlock block) {
    return block.type == NoteBlockType.bulletList ||
        block.type == NoteBlockType.numberedList ||
        block.type == NoteBlockType.checklist;
  }

  bool _isResizableTextBlock(NoteBlock block) {
    return block.type == NoteBlockType.paragraph;
  }

  String _ribbonItemKey(String blockId, int itemIndex) {
    return '$blockId::ribbon::$itemIndex';
  }

  List<String> _normalizedRibbonTexts(List<String> texts) {
    return List<String>.generate(_ribbonSlotCount, (index) {
      return index < texts.length ? texts[index] : '';
    });
  }

  List<String> _ribbonTextsForBlock(NoteBlock block) {
    final rawText = block.text.trim();

    if (rawText.isEmpty) {
      return _normalizedRibbonTexts(const <String>[]);
    }

    try {
      final decoded = jsonDecode(rawText);

      if (decoded is List) {
        return _normalizedRibbonTexts(
          decoded.map((value) => value?.toString() ?? '').toList(),
        );
      }
    } catch (_) {
      // Si una cinta antigua queda con texto plano, lo conservamos en el primer slot.
    }

    return _normalizedRibbonTexts(<String>[block.text]);
  }

  String _encodeRibbonTexts(List<String> texts) {
    return jsonEncode(_normalizedRibbonTexts(texts));
  }

  void _createRibbonEditorsForBlock(NoteBlock block) {
    final texts = _ribbonTextsForBlock(block);

    _ribbonTextControllers[block.id] = texts
        .map((text) => TextEditingController(text: text))
        .toList();

    _ribbonTextFocusNodes[block.id] = List<FocusNode>.generate(
      _ribbonSlotCount,
      (_) => FocusNode(),
    );
  }

  void _disposeRibbonEditorsForBlock(String blockId) {
    final controllers = _ribbonTextControllers.remove(blockId);

    if (controllers != null) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }

    final focusNodes = _ribbonTextFocusNodes.remove(blockId);

    if (focusNodes != null) {
      for (final focusNode in focusNodes) {
        focusNode.dispose();
      }
    }

    _ribbonPageControllers.remove(blockId)?.dispose();

    _expandedRibbonItemIds.removeWhere((key) {
      return key.startsWith('$blockId::ribbon::');
    });

    _expandedRibbonVerticalItemIds.removeWhere((key) {
      return key.startsWith('$blockId::ribbon::');
    });
  }

  void _ensureRibbonEditorsForBlock(NoteBlock block) {
    final controllers = _ribbonTextControllers[block.id];
    final focusNodes = _ribbonTextFocusNodes[block.id];

    if (controllers == null ||
        focusNodes == null ||
        controllers.length != _ribbonSlotCount ||
        focusNodes.length != _ribbonSlotCount) {
      _disposeRibbonEditorsForBlock(block.id);
      _createRibbonEditorsForBlock(block);
    }
  }

  PageController _ribbonPageControllerFor(String blockId) {
    return _ribbonPageControllers.putIfAbsent(
      blockId,
      () => PageController(viewportFraction: 0.5),
    );
  }

  void _centerRibbonItem(String blockId, int itemIndex) {
    final pageController = _ribbonPageControllers[blockId];

    if (pageController == null) {
      return;
    }

    final targetPage = itemIndex.clamp(0, _ribbonSlotCount - 1);

    void animateToItem() {
      if (!mounted || !pageController.hasClients) return;

      pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      animateToItem();
    });

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 210), animateToItem),
    );
  }

  void _handleRibbonTextChanged({
    required int blockIndex,
    required int itemIndex,
    required String value,
  }) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) {
      return;
    }

    final block = _blocks[blockIndex];
    final controllers = _ribbonTextControllers[block.id];

    if (block.type != NoteBlockType.ribbon ||
        controllers == null ||
        itemIndex < 0 ||
        itemIndex >= controllers.length) {
      return;
    }

    _activeBlockIndex = blockIndex;

    final texts = List<String>.generate(controllers.length, (index) {
      return index == itemIndex ? value : controllers[index].text;
    });

    final updatedBlock = block.copyWith(text: _encodeRibbonTexts(texts));

    _blocks[blockIndex] = updatedBlock;
    _syncHiddenBlockController(updatedBlock);
    _saveNote();
  }

  void _toggleRibbonItemExpanded(String blockId, int itemIndex) {
    final blockIndex = _blocks.indexWhere((block) => block.id == blockId);

    if (blockIndex == -1) {
      return;
    }

    final itemKey = _ribbonItemKey(blockId, itemIndex);
    final wasExpanded = _expandedRibbonItemIds.contains(itemKey);

    setState(() {
      _activeBlockIndex = blockIndex;

      _expandedRibbonItemIds.removeWhere((key) {
        return key.startsWith('$blockId::ribbon::');
      });

      _expandedRibbonVerticalItemIds.removeWhere((key) {
        return key.startsWith('$blockId::ribbon::') && key != itemKey;
      });

      if (wasExpanded) {
        _expandedRibbonVerticalItemIds.remove(itemKey);
      } else {
        _expandedRibbonItemIds.add(itemKey);
      }
    });

    if (!wasExpanded) {
      _centerRibbonItem(blockId, itemIndex);
    }

    if (wasExpanded) {
      final focusNodes = _ribbonTextFocusNodes[blockId];
      final focusNode = focusNodes != null && itemIndex < focusNodes.length
          ? focusNodes[itemIndex]
          : null;

      if (focusNode != null && focusNode.hasFocus) {
        _clearEditorTextFocus(focusNode);
      }
    }

    HapticFeedback.selectionClick();
  }

  void _toggleRibbonItemVerticalExpanded(String blockId, int itemIndex) {
    final blockIndex = _blocks.indexWhere((block) => block.id == blockId);

    if (blockIndex == -1) {
      return;
    }

    final itemKey = _ribbonItemKey(blockId, itemIndex);

    if (!_expandedRibbonItemIds.contains(itemKey)) {
      return;
    }

    final wasExpanded = _expandedRibbonVerticalItemIds.contains(itemKey);

    setState(() {
      _activeBlockIndex = blockIndex;

      if (wasExpanded) {
        _expandedRibbonVerticalItemIds.remove(itemKey);
      } else {
        _expandedRibbonVerticalItemIds.add(itemKey);
      }
    });

    if (wasExpanded) {
      final focusNodes = _ribbonTextFocusNodes[blockId];
      final focusNode = focusNodes != null && itemIndex < focusNodes.length
          ? focusNodes[itemIndex]
          : null;

      if (focusNode != null && focusNode.hasFocus) {
        _clearEditorTextFocus(focusNode);
      }
    }

    HapticFeedback.selectionClick();
  }

  ScrollController _textBlockScrollControllerFor(String blockId) {
    return _textBlockScrollControllers.putIfAbsent(
      blockId,
      () => ScrollController(),
    );
  }

  void _scrollTextBlockToTop(String blockId) {
    final scrollController = _textBlockScrollControllers[blockId];

    if (scrollController == null) {
      return;
    }

    void jumpToTop() {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpToTop();
    });

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 40), jumpToTop),
    );
  }

  void _toggleTextBlockExpanded(String blockId) {
    final blockIndex = _blocks.indexWhere((block) => block.id == blockId);

    if (blockIndex == -1) {
      return;
    }

    final block = _blocks[blockIndex];

    if (!_isResizableTextBlock(block)) {
      return;
    }

    final wasExpanded = _expandedTextBlockIds.contains(blockId);

    setState(() {
      _activeBlockIndex = blockIndex;

      if (wasExpanded) {
        _expandedTextBlockIds.remove(blockId);
      } else {
        _expandedTextBlockIds.add(blockId);
      }
    });

    if (wasExpanded) {
      final controller = _blockControllers[blockId];
      final focusNode = _blockFocusNodes[blockId];

      if (controller != null) {
        controller.selection = const TextSelection.collapsed(offset: 0);
      }

      if (focusNode != null && focusNode.hasFocus) {
        _clearEditorTextFocus(focusNode);
      }

      _scrollTextBlockToTop(blockId);
    }

    HapticFeedback.selectionClick();
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

    if (controller == null) {
      return;
    }

    if (controller is _LinkedBlockTextController) {
      controller.updateLinks(block.links);
    }

    if (controller.text == block.text) {
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

  int? _groupColorValueForGroupId(String groupId) {
    for (final block in _blocks) {
      if (_validGroupId(block.groupId) == groupId &&
          block.groupColorValue != null) {
        return block.groupColorValue;
      }
    }

    return null;
  }

  Color _groupBorderColorForGroupId(String groupId) {
    final colorValue = _groupColorValueForGroupId(groupId);

    if (colorValue == null) {
      return _groupBorderColor;
    }

    return Color(colorValue);
  }

  Color _groupBackgroundColorForGroupId(String groupId) {
    final colorValue = _groupColorValueForGroupId(groupId);

    if (colorValue == null) {
      return _groupBackgroundColor;
    }

    return Color(colorValue).withValues(alpha: 0.20);
  }

  Color _groupTitleColorForGroupId(String groupId) {
    final colorValue = _groupColorValueForGroupId(groupId);

    if (colorValue == null) {
      return _groupDefaultTextColor;
    }

    return Color(colorValue).withValues(alpha: 0.96);
  }

  NoteBlock _copyBlockIntoGroup({
    required NoteBlock block,
    required String groupId,
    required String groupTitle,
    required bool groupCollapsed,
  }) {
    final groupColorValue = _groupColorValueForGroupId(groupId);

    return block.copyWith(
      groupId: groupId,
      groupTitle: groupTitle,
      groupCollapsed: groupCollapsed,
      groupColorValue: groupColorValue,
      clearGroupColorValue: groupColorValue == null,
    );
  }

  void _migrateLegacyGroupColorValues() {
    final seenGroupIds = <String>{};

    for (final block in _blocks) {
      final groupId = _validGroupId(block.groupId);

      if (groupId == null || !seenGroupIds.add(groupId)) {
        continue;
      }

      final hasGroupColor = _blocks.any((currentBlock) {
        return _validGroupId(currentBlock.groupId) == groupId &&
            currentBlock.groupColorValue != null;
      });

      if (hasGroupColor) {
        continue;
      }

      int? legacyColor;

      for (final currentBlock in _blocks) {
        if (_validGroupId(currentBlock.groupId) != groupId) {
          continue;
        }

        if (currentBlock.colorValue != null) {
          legacyColor = currentBlock.colorValue;
          break;
        }
      }

      if (legacyColor == null) {
        continue;
      }

      for (var i = 0; i < _blocks.length; i++) {
        if (_validGroupId(_blocks[i].groupId) != groupId) {
          continue;
        }

        _blocks[i] = _blocks[i].copyWith(
          groupColorValue: legacyColor,
          clearColorValue: true,
          clearHighlightColorValue: true,
        );
      }
    }
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

  int _groupBlockCount(String groupId) {
    return _blocks.where((block) {
      return _validGroupId(block.groupId) == groupId;
    }).length;
  }

  bool _isSingleBlockGroup(String groupId) {
    return _groupBlockCount(groupId) == 1;
  }

  String? _singleBlockGroupAtDragPosition() {
    final dragPosition = _lastDragGlobalPosition;
    final draggingBlockId = _draggingBlockId;

    if (dragPosition == null || draggingBlockId == null) {
      return null;
    }

    final groupId = _groupIdAtGlobalPosition(dragPosition);

    if (groupId == null || !_isSingleBlockGroup(groupId)) {
      return null;
    }

    final draggingBlock = _blocks.cast<NoteBlock?>().firstWhere(
      (block) => block?.id == draggingBlockId,
      orElse: () => null,
    );

    if (draggingBlock == null) {
      return null;
    }

    // Si el bloque arrastrado ya pertenece a ese mismo grupo,
    // no lo tratamos como entrada externa.
    if (_validGroupId(draggingBlock.groupId) == groupId) {
      return null;
    }

    return groupId;
  }

  _GroupEdgeDropSlot _slotForGroupAtPosition(
    String groupId,
    Offset globalPosition,
  ) {
    final rect = _rectForGroupId(groupId);

    if (rect == null) {
      return _GroupEdgeDropSlot.bottom;
    }

    final isCollapsed = _isGroupCollapsed(groupId);
    final bodyTop = isCollapsed ? rect.top : rect.top + _groupHeaderHeight;
    final bodyHeight = rect.bottom - bodyTop;
    final middleY = bodyTop + (bodyHeight / 2);

    return globalPosition.dy < middleY
        ? _GroupEdgeDropSlot.top
        : _GroupEdgeDropSlot.bottom;
  }

  bool _isExternalBlockHoveringSingleBlockGroup() {
    final dragPosition = _lastDragGlobalPosition;
    final draggingBlockId = _draggingBlockId;

    if (dragPosition == null || draggingBlockId == null) {
      return false;
    }

    final draggingBlock = _blocks.cast<NoteBlock?>().firstWhere(
      (block) => block?.id == draggingBlockId,
      orElse: () => null,
    );

    if (draggingBlock == null) {
      return false;
    }

    final seenGroupIds = <String>{};

    for (final block in _blocks) {
      final groupId = _validGroupId(block.groupId);

      if (groupId == null || !seenGroupIds.add(groupId)) {
        continue;
      }

      if (!_isSingleBlockGroup(groupId) || _isGroupCollapsed(groupId)) {
        continue;
      }

      if (_validGroupId(draggingBlock.groupId) == groupId) {
        continue;
      }

      final groupRect = _rectForGroupId(groupId);

      if (groupRect == null) {
        continue;
      }

      if (groupRect.inflate(10).contains(dragPosition)) {
        return true;
      }
    }

    return false;
  }

  bool _lockSingleBlockGroupLandingPreview() {
    final dragPosition = _lastDragGlobalPosition;

    if (dragPosition == null || _draggingBlockId == null) {
      return false;
    }

    final slotTarget = _singleGroupFreeSlotTargetAtPosition(dragPosition);

    if (slotTarget != null) {
      if (_dragPreviewGroupId == slotTarget.groupId &&
          _dragEdgeDropSlot == slotTarget.slot) {
        return true;
      }

      setState(() {
        _dragPreviewGroupId = slotTarget.groupId;
        _dragEdgeDropSlot = slotTarget.slot;
      });

      return true;
    }

    if (_isExternalBlockHoveringSingleBlockGroup()) {
      if (_dragPreviewGroupId == _dragNoGroupPreviewId &&
          _dragEdgeDropSlot == _GroupEdgeDropSlot.none) {
        return true;
      }

      setState(() {
        _dragPreviewGroupId = _dragNoGroupPreviewId;
        _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
      });

      return true;
    }

    return false;
  }

  bool _hasActiveSingleGroupLandingZone(String groupId) {
    return _isSingleBlockGroup(groupId) &&
        _draggingBlockId != null &&
        _dragPreviewGroupId == groupId &&
        _dragEdgeDropSlot != _GroupEdgeDropSlot.none &&
        _lastDragGlobalPosition != null &&
        _groupIdAtGlobalPosition(_lastDragGlobalPosition!) == groupId;
  }

  bool _shouldShowSingleGroupFreeSlot(String groupId) {
    return _isSingleBlockGroup(groupId) && !_isGroupCollapsed(groupId);
  }

  bool _shouldUseInlineLandingZone(String groupId) {
    return false;
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

      if (groupId == null) {
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

    final removedSlotIds = _singleGroupSlotKeys.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedSlotIds) {
      _singleGroupSlotKeys.remove(groupId);
    }

    final removedAddDragIds = _groupAddDragOffsets.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedAddDragIds) {
      _groupAddDragOffsets.remove(groupId);
    }

    final removedAddStartIds = _groupAddDragStartY.keys
        .where((groupId) => !activeGroupIds.contains(groupId))
        .toList();

    for (final groupId in removedAddStartIds) {
      _groupAddDragStartY.remove(groupId);
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
    FocusManager.instance.primaryFocus?.unfocus();
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
        clearGroupColorValue: true,
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
      groupColorValue: _groupColorValueForGroupId(groupId),
    );

    setState(() {
      _blocks.insert(insertIndex, block);
      _blockControllers[block.id] = _createBlockTextController(block);
      _blockFocusNodes[block.id] = FocusNode();
      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  NoteBlock _normalizeMarkdownLinksInBlock(NoteBlock block) {
    if (block.links.isNotEmpty || !_markdownLinkPattern.hasMatch(block.text)) {
      return block;
    }

    final buffer = StringBuffer();
    final links = <NoteBlockLink>[];
    var currentIndex = 0;

    for (final match in _markdownLinkPattern.allMatches(block.text)) {
      if (match.start > currentIndex) {
        buffer.write(block.text.substring(currentIndex, match.start));
      }

      final rawLabel = match.group(1)?.trim() ?? '';
      final target = match.group(2)?.trim() ?? '';

      if (target.isEmpty) {
        buffer.write(block.text.substring(match.start, match.end));
        currentIndex = match.end;
        continue;
      }

      final label = rawLabel.isEmpty
          ? _labelForHyperlinkTarget(target)
          : rawLabel;

      final start = buffer.length;
      buffer.write(label);
      final end = buffer.length;

      links.add(
        NoteBlockLink(
          id: _newLinkId(),
          start: start,
          end: end,
          label: label,
          target: target,
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < block.text.length) {
      buffer.write(block.text.substring(currentIndex));
    }

    return block.copyWith(text: buffer.toString(), links: links);
  }

  NoteBlock _normalizeLegacyBlock(NoteBlock block) {
    if (block.type == NoteBlockType.ribbon) {
      return block.copyWith(
        text: _encodeRibbonTexts(_ribbonTextsForBlock(block)),
      );
    }

    final blockWithLinks = _normalizeMarkdownLinksInBlock(block);

    switch (blockWithLinks.type) {
      case NoteBlockType.heading1:
        return blockWithLinks.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.heading1,
        );

      case NoteBlockType.heading2:
        return blockWithLinks.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.heading2,
        );

      case NoteBlockType.quote:
        return blockWithLinks.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.quote,
        );

      case NoteBlockType.callout:
        return blockWithLinks.copyWith(
          type: NoteBlockType.paragraph,
          style: NoteBlockStyle.callout,
        );

      case NoteBlockType.checklist:
        final lines = _listLinesForBlock(blockWithLinks);
        final states = _checklistStatesForBlock(blockWithLinks, lines.length);

        return blockWithLinks.copyWith(
          text: lines.join('\n'),
          isChecked: states.isNotEmpty && states.first,
          checklistStates: states,
        );

      case NoteBlockType.bulletList:
      case NoteBlockType.numberedList:
        return blockWithLinks.copyWith(
          clearChecklistStates: true,
          isChecked: false,
        );

      case NoteBlockType.paragraph:
      case NoteBlockType.image:
      case NoteBlockType.file:
      case NoteBlockType.divider:
      case NoteBlockType.ribbon:
        return blockWithLinks;

      case NoteBlockType.tracker:
      case NoteBlockType.database:
        return blockWithLinks;
    }
  }

  void _saveNote() {
    _hasPendingNoteSave = true;
    _saveDebounce?.cancel();

    _saveDebounce = Timer(const Duration(milliseconds: 140), () {
      _saveDebounce = null;
      unawaited(_persistNote());
    });
  }

  Future<void> _persistNote() async {
    if (!_hasPendingNoteSave) {
      return;
    }

    final currentNote = _notesController.noteById(widget.noteId);

    if (currentNote == null) {
      _hasPendingNoteSave = false;
      return;
    }

    final title = _titleController.text;
    final blocks = List<NoteBlock>.from(_blocks);

    _hasPendingNoteSave = false;

    await _notesController.updateNote(
      currentNote.copyWith(title: title, blocks: blocks),
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

  String _safeStoredFileName(String fileName) {
    final baseName = p.basenameWithoutExtension(fileName).trim();
    final extension = p.extension(fileName).trim();
    final safeBaseName = baseName
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    final resolvedBaseName = safeBaseName.isEmpty ? 'archivo' : safeBaseName;

    return '$resolvedBaseName$extension';
  }

  Future<({String path, String name, int sizeBytes})?>
  _pickAndStoreFile() async {
    const typeGroup = XTypeGroup(
      label: 'Documentos',
      extensions: <String>[
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'zip',
      ],
    );

    final selectedFile = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );

    if (selectedFile == null) {
      return null;
    }

    final sourcePath = selectedFile.path;

    if (sourcePath.trim().isEmpty) {
      return null;
    }

    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      return null;
    }

    final originalName = selectedFile.name.trim().isEmpty
        ? p.basename(sourcePath)
        : selectedFile.name.trim();

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final filesDirectory = Directory(
      p.join(documentsDirectory.path, 'notes_files'),
    );

    if (!await filesDirectory.exists()) {
      await filesDirectory.create(recursive: true);
    }

    final safeFileName = _safeStoredFileName(originalName);

    final destinationPath = p.join(
      filesDirectory.path,
      'note_file_${DateTime.now().microsecondsSinceEpoch}_$safeFileName',
    );

    final savedFile = await sourceFile.copy(destinationPath);
    final sizeBytes = await savedFile.length();

    return (path: savedFile.path, name: originalName, sizeBytes: sizeBytes);
  }

  Future<void> _openStoredFile(String filePath) async {
    if (filePath.trim().isEmpty) {
      return;
    }

    final file = File(filePath);

    if (!await file.exists()) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo ya no está disponible.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await OpenFilex.open(filePath);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el archivo.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatStoredFileSize(String filePath) {
    try {
      final file = File(filePath);

      if (!file.existsSync()) {
        return 'Archivo';
      }

      final sizeBytes = file.lengthSync();

      if (sizeBytes < 1024) {
        return '$sizeBytes B';
      }

      final sizeKb = sizeBytes / 1024;

      if (sizeKb < 1024) {
        return '${sizeKb.toStringAsFixed(sizeKb < 10 ? 1 : 0)} KB';
      }

      final sizeMb = sizeKb / 1024;

      return '${sizeMb.toStringAsFixed(sizeMb < 10 ? 1 : 0)} MB';
    } catch (_) {
      return 'Archivo';
    }
  }

  IconData _iconForStoredFile(String fileNameOrPath) {
    final extension = p.extension(fileNameOrPath).toLowerCase();

    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
      case '.docx':
        return Icons.description_outlined;
      case '.xls':
      case '.xlsx':
      case '.csv':
        return Icons.table_chart_outlined;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow_outlined;
      case '.zip':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _insertFileBlock({int? afterIndex}) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final storedFile = await _pickAndStoreFile();

    if (!mounted || storedFile == null) {
      return;
    }

    final block = NoteBlock(
      id: _newBlockId(),
      type: NoteBlockType.file,
      text: storedFile.name,
      imagePath: storedFile.path,
    );

    final int insertIndex;

    if (afterIndex == null) {
      insertIndex = _blocks.length;
    } else {
      insertIndex = (afterIndex + 1).clamp(0, _blocks.length);
    }

    setState(() {
      _blocks.insert(insertIndex, block);
      _blockControllers[block.id] = _createBlockTextController(block);
      _blockFocusNodes[block.id] = FocusNode();
      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();

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

      _blockControllers[block.id] = _createBlockTextController(block);

      _blockFocusNodes[block.id] = FocusNode();

      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _convertBlockToImage(int index) async {
    if (index < 0 || index >= _blocks.length) {
      return;
    }

    final imagePath = await _pickAndStoreImage();

    if (!mounted || imagePath == null) {
      FocusManager.instance.primaryFocus?.unfocus();
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
    FocusManager.instance.primaryFocus?.unfocus();
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
      text: type == NoteBlockType.ribbon
          ? _encodeRibbonTexts(const <String>[])
          : '',
    );

    final int insertIndex;

    if (afterIndex == null) {
      insertIndex = _blocks.length;
    } else {
      insertIndex = (afterIndex + 1).clamp(0, _blocks.length);
    }

    setState(() {
      _blocks.insert(insertIndex, block);

      _blockControllers[block.id] = _createBlockTextController(block);

      _blockFocusNodes[block.id] = FocusNode();

      if (_isWordListBlock(block)) {
        _createListEditorsForBlock(block);
      }

      if (block.type == NoteBlockType.ribbon) {
        _createRibbonEditorsForBlock(block);
      }

      _activeBlockIndex = insertIndex;
    });

    _saveNote();
    HapticFeedback.selectionClick();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addParagraphBlocks({required int count, required int afterIndex}) {
    if (count <= 0) {
      return;
    }

    final inheritFormattingFrom = afterIndex >= 0 && afterIndex < _blocks.length
        ? _blocks[afterIndex]
        : null;

    final insertIndex = (afterIndex + 1).clamp(0, _blocks.length).toInt();

    final newBlocks = List<NoteBlock>.generate(count, (_) {
      return NoteBlock(
        id: _newBlockId(),
        type: NoteBlockType.paragraph,
        fontFamily: inheritFormattingFrom?.fontFamily ?? 'Inter',
        fontSize: inheritFormattingFrom?.fontSize,
        textColorValue: inheritFormattingFrom?.textColorValue,
        isBold: inheritFormattingFrom?.isBold ?? false,
        isItalic: inheritFormattingFrom?.isItalic ?? false,
        isUnderline: inheritFormattingFrom?.isUnderline ?? false,
        textAlignment:
            inheritFormattingFrom?.textAlignment ?? NoteTextAlignment.left,
        listMarkerStyle: NoteListMarkerStyle.automatic,
        checklistStates: const <bool>[],
      );
    });

    setState(() {
      _blocks.insertAll(insertIndex, newBlocks);

      for (final block in newBlocks) {
        _blockControllers[block.id] = _createBlockTextController(block);
        _blockFocusNodes[block.id] = FocusNode();
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
      case NoteBlockType.file:
      case NoteBlockType.ribbon:
        return NoteBlockType.paragraph;
      case NoteBlockType.divider:
        return NoteBlockType.paragraph;
      case NoteBlockType.tracker:
      case NoteBlockType.database:
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
            color: _editorNeutralGray,
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
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    if (selectedType == NoteBlockType.image) {
      await _convertBlockToImage(blockIndex);
      return;
    }

    if (selectedType == NoteBlockType.file) {
      await _insertFileBlock(afterIndex: blockIndex);
      return;
    }

    controller
      ..text = ''
      ..selection = const TextSelection.collapsed(offset: 0);

    final convertedBlock = block.copyWith(
      type: selectedType,
      text: selectedType == NoteBlockType.ribbon
          ? _encodeRibbonTexts(const <String>[])
          : '',
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
    _disposeRibbonEditorsForBlock(block.id);

    setState(() {
      _blocks[blockIndex] = convertedBlock;

      if (_isWordListBlock(convertedBlock)) {
        _createListEditorsForBlock(convertedBlock);
      }

      if (convertedBlock.type == NoteBlockType.ribbon) {
        _createRibbonEditorsForBlock(convertedBlock);
      }

      _activeBlockIndex = blockIndex;
    });

    _saveNote();

    FocusManager.instance.primaryFocus?.unfocus();

    HapticFeedback.selectionClick();
  }

  List<NoteBlockLink> _adjustLinksForTextChange({
    required String oldText,
    required String newText,
    required List<NoteBlockLink> oldLinks,
  }) {
    if (oldText == newText) {
      return oldLinks;
    }

    var prefixLength = 0;

    while (prefixLength < oldText.length &&
        prefixLength < newText.length &&
        oldText.codeUnitAt(prefixLength) == newText.codeUnitAt(prefixLength)) {
      prefixLength += 1;
    }

    var suffixLength = 0;

    while (suffixLength < oldText.length - prefixLength &&
        suffixLength < newText.length - prefixLength &&
        oldText.codeUnitAt(oldText.length - 1 - suffixLength) ==
            newText.codeUnitAt(newText.length - 1 - suffixLength)) {
      suffixLength += 1;
    }

    final oldChangeStart = prefixLength;
    final oldChangeEnd = oldText.length - suffixLength;
    final delta = newText.length - oldText.length;

    final adjustedLinks = <NoteBlockLink>[];

    for (final link in oldLinks) {
      if (link.end <= oldChangeStart) {
        adjustedLinks.add(link);
        continue;
      }

      if (link.start >= oldChangeEnd) {
        adjustedLinks.add(
          link.copyWith(start: link.start + delta, end: link.end + delta),
        );
        continue;
      }

      // Si el usuario edita dentro del texto vinculado,
      // se elimina ese link para evitar rangos rotos.
    }

    return adjustedLinks.where((link) {
      return link.start >= 0 &&
          link.end <= newText.length &&
          link.start < link.end;
    }).toList();
  }

  List<NoteBlockLink> _linksAfterTextReplacement({
    required List<NoteBlockLink> oldLinks,
    required int start,
    required int end,
    required int insertedLength,
  }) {
    final removedLength = end - start;
    final delta = insertedLength - removedLength;
    final adjustedLinks = <NoteBlockLink>[];

    for (final link in oldLinks) {
      if (link.end <= start) {
        adjustedLinks.add(link);
        continue;
      }

      if (link.start >= end) {
        adjustedLinks.add(
          link.copyWith(start: link.start + delta, end: link.end + delta),
        );
        continue;
      }

      // Si el reemplazo toca un link existente, se elimina.
    }

    return adjustedLinks;
  }

  void _updateBlockText(int index, String value) {
    final block = _blocks[index];

    final updatedLinks = _adjustLinksForTextChange(
      oldText: block.text,
      newText: value,
      oldLinks: block.links,
    );

    final updatedBlock = block.copyWith(text: value, links: updatedLinks);

    _blocks[index] = updatedBlock;
    _syncBlockControllerLinks(updatedBlock);

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

    if (originalBlock.type == NoteBlockType.image ||
        originalBlock.type == NoteBlockType.file) {
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
      highlightColorValue: originalBlock.highlightColorValue,
      fontFamily: originalBlock.fontFamily,
      fontSize: originalBlock.fontSize,
      textColorValue: originalBlock.textColorValue,
      isBold: originalBlock.isBold,
      isItalic: originalBlock.isItalic,
      isUnderline: originalBlock.isUnderline,
      textAlignment: originalBlock.textAlignment,
      listMarkerStyle: originalBlock.listMarkerStyle,
      checklistStates: List<bool>.from(originalBlock.checklistStates),
      links: originalBlock.links
          .map((link) => link.copyWith(id: _newLinkId()))
          .toList(),
      groupId: originalBlock.groupId,
      groupTitle: originalBlock.groupTitle,
      groupCollapsed: originalBlock.groupCollapsed,
      groupColorValue: originalBlock.groupColorValue,
    );

    final duplicatedController = _createBlockTextController(duplicatedBlock);

    final duplicatedFocusNode = FocusNode();

    setState(() {
      _blocks.insert(index + 1, duplicatedBlock);

      _blockControllers[duplicatedBlock.id] = duplicatedController;

      _blockFocusNodes[duplicatedBlock.id] = duplicatedFocusNode;

      if (_isWordListBlock(duplicatedBlock)) {
        _createListEditorsForBlock(duplicatedBlock);
      }

      if (duplicatedBlock.type == NoteBlockType.ribbon) {
        _createRibbonEditorsForBlock(duplicatedBlock);
      }

      _activeBlockIndex = index + 1;
    });

    _saveNote();
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _deleteBlock(int index) {
    if (_blocks.length == 1) {
      final block = _blocks.first;
      final oldImagePath = block.imagePath;

      _blockControllers[block.id]?.clear();
      _disposeListEditorsForBlock(block.id);
      _disposeRibbonEditorsForBlock(block.id);

      setState(() {
        _blocks[0] = block.copyWith(
          type: NoteBlockType.paragraph,
          text: '',
          isChecked: false,
          clearImagePath: true,
          style: NoteBlockStyle.normal,
          clearColorValue: true,
          clearHighlightColorValue: true,
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
      _expandedTextBlockIds.remove(removedBlock.id);
    });

    _blockControllers.remove(removedBlock.id)?.dispose();

    _blockFocusNodes.remove(removedBlock.id)?.dispose();
    _disposeListEditorsForBlock(removedBlock.id);
    _disposeRibbonEditorsForBlock(removedBlock.id);
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

  String? _groupIdForBlockId(String? blockId) {
    if (blockId == null) {
      return null;
    }

    for (final block in _blocks) {
      if (block.id == blockId) {
        return _validGroupId(block.groupId);
      }
    }

    return null;
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

  Rect? _rectForSingleGroupFreeSlot(String groupId) {
    final key = _singleGroupSlotKeys[groupId];

    if (key == null) {
      return null;
    }

    return _rectForViewportKey(key);
  }

  ({String groupId, _GroupEdgeDropSlot slot})?
  _singleGroupFreeSlotTargetAtPosition(Offset globalPosition) {
    final seenGroupIds = <String>{};

    for (final block in _blocks) {
      final groupId = _validGroupId(block.groupId);

      if (groupId == null || !seenGroupIds.add(groupId)) {
        continue;
      }

      if (!_isSingleBlockGroup(groupId) || _isGroupCollapsed(groupId)) {
        continue;
      }

      final slotRect = _rectForSingleGroupFreeSlot(groupId);

      if (slotRect == null) {
        continue;
      }

      if (slotRect.contains(globalPosition)) {
        return (groupId: groupId, slot: _GroupEdgeDropSlot.bottom);
      }
    }

    return null;
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

    final isCurrentPreview = _dragPreviewGroupId == groupId;

    final bodyTop = rect.top + _groupHeaderHeight;
    final bodyBottom = rect.bottom - 10;

    if (bodyBottom <= bodyTop) {
      return false;
    }

    final holdBottomPadding = isCurrentPreview ? 34.0 : 0.0;

    final bodyRect = Rect.fromLTRB(
      rect.left + 6,
      bodyTop,
      rect.right - 6,
      bodyBottom + holdBottomPadding,
    );

    return bodyRect.contains(globalPosition);
  }

  bool _isDraggingBlockRelatedToGroup(String groupId) {
    final draggingBlockId = _draggingBlockId;

    if (draggingBlockId == null) {
      return false;
    }

    final sourceGroupId = _groupIdForBlockId(draggingBlockId);

    if (sourceGroupId == groupId) {
      return false;
    }

    return _dragPreviewGroupId == groupId;
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

    final singleGroupSlotTarget = _singleGroupFreeSlotTargetAtPosition(
      globalPosition,
    );

    if (singleGroupSlotTarget != null) {
      return singleGroupSlotTarget;
    }

    final groupId = _groupIdAtGlobalPosition(globalPosition);

    if (groupId == null) {
      return null;
    }

    final draggingSourceGroupId = _groupIdForBlockId(_draggingBlockId);

    if (draggingSourceGroupId == groupId) {
      return null;
    }

    if (_isSingleBlockGroup(groupId)) {
      return null;
    }

    final rect = _rectForGroupId(groupId);

    if (rect == null) {
      return null;
    }

    return (
      groupId: groupId,
      slot: _slotForGroupAtPosition(groupId, globalPosition),
    );
  }

  void _updateDragPreviewFromGlobalPosition(Offset globalPosition) {
    _lastDragGlobalPosition = globalPosition;

    // El drag manual ya no mete bloques dentro de grupos.
    // Los grupos absorben/sueltan bloques únicamente con la franja.
    if (_dragPreviewGroupId != null ||
        _dragEdgeDropSlot != _GroupEdgeDropSlot.none) {
      setState(() {
        _dragPreviewGroupId = null;
        _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
        _blockedEdgePreviewGroupId = null;
        _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
      });
    }
  }

  bool _shouldShowGroupEdgeDropSpace(String groupId, _GroupEdgeDropSlot slot) {
    return false;
  }

  bool _shouldShowGroupDropLine(String groupId, _GroupEdgeDropSlot slot) {
    return _draggingBlockId != null &&
        _dragPreviewGroupId == groupId &&
        _dragEdgeDropSlot == slot &&
        _lastDragGlobalPosition != null &&
        _groupIdAtGlobalPosition(_lastDragGlobalPosition!) == groupId;
  }

  int _groupAddPreviewCount(String groupId) {
    return _blockIndexesCoveredByGroupAddDrag(groupId).length;
  }

  int _groupEjectPreviewCount(String groupId) {
    return _blockIndexesEjectedByGroupAddDrag(groupId).length;
  }

  bool _isGroupAddDragActive(String groupId) {
    return _activeGroupAddDragId == groupId ||
        (_groupAddDragOffsets[groupId] ?? 0) > 0;
  }

  bool _isGroupAddDragExtending(String groupId) {
    return (_groupAddDragOffsets[groupId] ?? 0) > 0;
  }

  bool _canAbsorbBlockIntoGroup(NoteBlock block) {
    if (_validGroupId(block.groupId) != null) {
      return false;
    }

    return true;
  }

  bool _canEjectBlockFromGroup(NoteBlock block) {
    return true;
  }

  List<int> _blockIndexesCoveredByGroupAddDrag(String groupId) {
    final dragOffset = _groupAddDragOffsets[groupId] ?? 0;

    if (dragOffset <= 0) {
      return const <int>[];
    }

    final lastGroupIndex = _blocks.lastIndexWhere((block) {
      return _validGroupId(block.groupId) == groupId;
    });

    if (lastGroupIndex == -1 || lastGroupIndex >= _blocks.length - 1) {
      return const <int>[];
    }

    final lastGroupBlock = _blocks[lastGroupIndex];
    final lastGroupBlockKey = _blockViewportKeys[lastGroupBlock.id];
    final lastGroupBlockRect = lastGroupBlockKey == null
        ? null
        : _rectForViewportKey(lastGroupBlockKey);

    final groupRect = _rectForGroupId(groupId);
    final startY = lastGroupBlockRect?.bottom ?? groupRect?.bottom;

    if (startY == null) {
      return const <int>[];
    }

    final endY = startY + dragOffset;
    final coveredIndexes = <int>[];

    for (var index = lastGroupIndex + 1; index < _blocks.length; index++) {
      final block = _blocks[index];

      if (!_canAbsorbBlockIntoGroup(block)) {
        break;
      }

      final blockKey = _blockViewportKeys[block.id];
      final blockRect = blockKey == null ? null : _rectForViewportKey(blockKey);

      if (blockRect == null) {
        break;
      }

      if (blockRect.center.dy <= endY) {
        coveredIndexes.add(index);
        continue;
      }

      break;
    }

    return coveredIndexes;
  }

  List<int> _blockIndexesEjectedByGroupAddDrag(String groupId) {
    final dragOffset = _groupAddDragOffsets[groupId] ?? 0;

    if (dragOffset >= 0) {
      return const <int>[];
    }

    final range = _groupRangeInBlocks(_blocks, groupId);

    if (range == null) {
      return const <int>[];
    }

    final groupLength = range.end - range.start + 1;

    if (groupLength <= 1) {
      return const <int>[];
    }

    final handleStartTop = _groupAddHandleStartTop[groupId];
    final groupRect = _rectForGroupId(groupId);

    final startY = handleStartTop ?? groupRect?.bottom;

    if (startY == null) {
      return const <int>[];
    }

    final currentY = startY + dragOffset;
    final ejectedIndexes = <int>[];

    for (var index = range.end; index >= range.start; index--) {
      if (ejectedIndexes.length >= _groupAddMaxBlocksPerDrag) {
        break;
      }

      final remainingInsideGroup = groupLength - ejectedIndexes.length;

      if (remainingInsideGroup <= 1) {
        break;
      }

      final block = _blocks[index];

      if (!_canEjectBlockFromGroup(block)) {
        break;
      }

      final blockKey = _blockViewportKeys[block.id];
      final blockRect = blockKey == null ? null : _rectForViewportKey(blockKey);

      if (blockRect == null) {
        break;
      }

      if (blockRect.center.dy >= currentY) {
        ejectedIndexes.add(index);
        continue;
      }

      break;
    }

    return ejectedIndexes.reversed.toList();
  }

  void _removeGroupAddDragOverlay() {
    final activeGroupId = _activeGroupAddDragId;

    _groupAddDragOverlayEntry?.remove();
    _groupAddDragOverlayEntry = null;

    if (activeGroupId != null) {
      _groupAddHandleStartTop.remove(activeGroupId);
    }

    _activeGroupAddDragId = null;
  }

  void _showOrUpdateGroupAddDragOverlay(String groupId) {
    if (!mounted) {
      return;
    }

    final overlayState = Overlay.of(context, rootOverlay: true);

    Widget buildOverlay() {
      final groupViewportKey = _groupViewportKeys[groupId];
      final groupRectGlobal =
          (groupViewportKey == null
              ? null
              : _rectForViewportKey(groupViewportKey)) ??
          _rectForGroupId(groupId);

      if (groupRectGlobal == null) {
        return const SizedBox.shrink();
      }

      final overlayBox = overlayState.context.findRenderObject();

      if (overlayBox is! RenderBox || !overlayBox.hasSize) {
        return const SizedBox.shrink();
      }

      final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
      final groupRect = groupRectGlobal.shift(-overlayOrigin);
      final groupColor = _groupBorderColorForGroupId(groupId);

      final dragOffset = _groupAddDragOffsets[groupId] ?? 0;
      final isRemovingBlocks = dragOffset < 0;

      final safeDownOffset = dragOffset > 0
          ? dragOffset.clamp(0, 900).toDouble()
          : 0.0;

      final coveredCount = _groupAddPreviewCount(groupId);
      final ejectedCount = _groupEjectPreviewCount(groupId);

      final initialHandleTopGlobal = _groupAddHandleStartTop[groupId];

      final fallbackHandleTop = groupRect.height - _groupAddHandleHeight - 8;

      final initialHandleTop = initialHandleTopGlobal == null
          ? fallbackHandleTop
          : initialHandleTopGlobal - overlayOrigin.dy - groupRect.top;

      final handleTop = initialHandleTop + dragOffset;

      final naturalOverlayHeight = groupRect.height + safeDownOffset;
      final minimumOverlayHeight = handleTop + _groupAddHandleHeight + 12;

      final overlayHeight = naturalOverlayHeight < minimumOverlayHeight
          ? minimumOverlayHeight
          : naturalOverlayHeight;

      const groupBottomMargin = 8.0;

      final groupPaintHeight = (groupRect.height - groupBottomMargin)
          .clamp(0.0, groupRect.height)
          .toDouble();

      final frameExtensionTop = (groupPaintHeight - _groupAddHandleHeight)
          .clamp(0.0, groupPaintHeight)
          .toDouble();

      final extensionFillColor = Colors.black.withValues(alpha: 0.22);

      return Positioned(
        left: groupRect.left,
        top: groupRect.top,
        width: groupRect.width,
        height: overlayHeight,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (!isRemovingBlocks)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GroupAddExtensionPainter(
                        color: groupColor.withValues(alpha: 0.82),
                        fillColor: extensionFillColor,
                        originalHeight: frameExtensionTop,
                        fillStartHeight: groupPaintHeight,
                        leftInset: _groupFrameLeftInset,
                        rightInset: _groupFrameRightInset,
                      ),
                    ),
                  ),
                Positioned(
                  left: _editorContentLeft,
                  right: _editorContentRight,
                  top: handleTop,
                  child: Container(
                    height: _groupAddHandleHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: groupColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: groupColor.withValues(alpha: 0.62),
                        width: 0.95,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: groupColor.withValues(alpha: 0.24),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      isRemovingBlocks
                          ? ejectedCount == 0
                                ? 'Arrastrar hacia arriba para sacar bloques'
                                : 'Soltar para sacar $ejectedCount ${ejectedCount == 1 ? 'bloque' : 'bloques'}'
                          : coveredCount == 0
                          ? 'Arrastrar sobre bloques'
                          : 'Soltar para añadir $coveredCount ${coveredCount == 1 ? 'bloque' : 'bloques'}',
                      style: TextStyle(
                        color: groupColor.withValues(alpha: 0.94),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_groupAddDragOverlayEntry == null || _activeGroupAddDragId != groupId) {
      _removeGroupAddDragOverlay();

      _activeGroupAddDragId = groupId;
      _groupAddDragOverlayEntry = OverlayEntry(builder: (_) => buildOverlay());

      overlayState.insert(_groupAddDragOverlayEntry!);
      return;
    }

    _groupAddDragOverlayEntry?.markNeedsBuild();
  }

  void _finishGroupAddDrag(String groupId) {
    final addIndexes = _blockIndexesCoveredByGroupAddDrag(groupId);
    final ejectIndexes = _blockIndexesEjectedByGroupAddDrag(groupId);
    final groupTitle = _groupTitleForGroupId(groupId);

    _removeGroupAddDragOverlay();

    setState(() {
      _groupAddDragOffsets.remove(groupId);
      _groupAddDragStartY.remove(groupId);
      _groupAddHandleStartTop.remove(groupId);
      _activeGroupAddDragId = null;

      for (final index in addIndexes) {
        final block = _blocks[index];

        _blocks[index] = _copyBlockIntoGroup(
          block: block,
          groupId: groupId,
          groupTitle: groupTitle,
          groupCollapsed: false,
        );
      }

      for (final index in ejectIndexes) {
        final block = _blocks[index];

        _blocks[index] = block.copyWith(
          clearGroupId: true,
          groupTitle: '',
          groupCollapsed: false,
          clearGroupColorValue: true,
        );
      }

      if (addIndexes.isNotEmpty) {
        _activeBlockIndex = addIndexes.first;
      } else if (ejectIndexes.isNotEmpty) {
        _activeBlockIndex = ejectIndexes.first;
      }
    });

    if (addIndexes.isNotEmpty || ejectIndexes.isNotEmpty) {
      _saveNote();
      HapticFeedback.selectionClick();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  bool get _isGroupAddDragInProgress {
    return _activeGroupAddDragId != null ||
        _groupAddDragOffsets.values.any((offset) => offset > 0);
  }

  Widget _buildGroupAddBlocksHandle(String groupId) {
    final isDragging =
        _activeGroupAddDragId == groupId ||
        (_groupAddDragOffsets[groupId] ?? 0) > 0;

    final groupColor = _groupBorderColorForGroupId(groupId);

    return Padding(
      padding: const EdgeInsets.only(right: _groupFrameRightInset),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          FocusManager.instance.primaryFocus?.unfocus();

          _groupAddDragStartY[groupId] = event.position.dy;
          _groupAddDragOffsets[groupId] = 0;
          _groupAddHandleStartTop[groupId] =
              event.position.dy - event.localPosition.dy;

          _activeGroupAddDragId = groupId;

          _showOrUpdateGroupAddDragOverlay(groupId);
          _groupAddDragOverlayEntry?.markNeedsBuild();

          setState(() {});

          HapticFeedback.selectionClick();
        },
        onPointerMove: (event) {
          final startY = _groupAddDragStartY[groupId];

          if (startY == null) {
            return;
          }

          final maxOffset =
              _groupAddPreviewBlockHeight * _groupAddMaxBlocksPerDrag;

          final nextOffset = (event.position.dy - startY)
              .clamp(-maxOffset, maxOffset)
              .toDouble();

          _groupAddDragOffsets[groupId] = nextOffset;
          _groupAddDragOverlayEntry?.markNeedsBuild();
        },
        onPointerUp: (_) {
          _finishGroupAddDrag(groupId);
        },
        onPointerCancel: (_) {
          _removeGroupAddDragOverlay();

          setState(() {
            _groupAddDragOffsets.remove(groupId);
            _groupAddDragStartY.remove(groupId);
            _groupAddHandleStartTop.remove(groupId);
            _activeGroupAddDragId = null;
          });
        },
        child: Opacity(
          opacity: isDragging ? 0.0 : 1.0,
          child: Container(
            height: _groupAddHandleHeight,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              border: Border(
                top: BorderSide(
                  color: groupColor.withValues(alpha: 0.22),
                  width: 0.9,
                ),
              ),
            ),
            child: Text(
              'Arrastrar para añadir bloques',
              style: TextStyle(
                color: groupColor.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupLandingOverlay({
    required bool hasHeader,
    required _GroupEdgeDropSlot slot,
  }) {
    final previewColor = _groupBorderColor;

    return Positioned(
      left: _editorContentLeft,
      right: _editorContentRight,
      top: slot == _GroupEdgeDropSlot.top
          ? (hasHeader ? _groupHeaderHeight + 6 : 6)
          : null,
      bottom: slot == _GroupEdgeDropSlot.bottom ? 6 : null,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: previewColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: previewColor.withValues(alpha: 0.66),
              width: 0.95,
            ),
            boxShadow: [
              BoxShadow(
                color: previewColor.withValues(alpha: 0.24),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: Center(
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: previewColor.withValues(alpha: 0.34),
                    size: 20,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: TextField(
                  readOnly: true,
                  enabled: false,
                  minLines: 3,
                  maxLines: null,
                  style: TextStyle(
                    color: previewColor.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: slot == _GroupEdgeDropSlot.top
                        ? 'Soltar arriba dentro del grupo'
                        : 'Soltar abajo dentro del grupo',
                    hintStyle: TextStyle(
                      color: previewColor.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _targetGroupIdForMovedIndex(
    int movedIndex, {
    String? preferredGroupId,
  }) {
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

    if (preferredGroupId != null &&
        (previousGroupId == preferredGroupId ||
            nextGroupId == preferredGroupId)) {
      return preferredGroupId;
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
    final movedRawBlock = _blocks.removeAt(currentIndex);

    final movedBlock = _copyBlockIntoGroup(
      block: movedRawBlock,
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
        _blocks[movedIndex] = _copyBlockIntoGroup(
          block: movedBlock,
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
        clearGroupColorValue: true,
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
    setState(() {
      _draggingBlockId = null;
      _draggingGroupId = null;
      _dragPreviewGroupId = null;
      _lastDragGlobalPosition = null;
      _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
      _blockedEdgePreviewGroupId = null;
      _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
    });
  }

  void _captureExternalReorderGroupHeights() {
    _externalReorderGroupHeights.clear();
    _externalReorderBlockHeights.clear();

    final seenGroupIds = <String>{};

    for (final block in _blocks) {
      final blockKey = _blockViewportKeys[block.id];
      final blockRect = blockKey == null ? null : _rectForViewportKey(blockKey);

      _externalReorderBlockHeights[block.id] = blockRect?.height ?? 86;

      final groupId = _validGroupId(block.groupId);

      if (groupId == null) {
        continue;
      }

      if (!seenGroupIds.add(groupId)) {
        continue;
      }

      final groupKey = _groupViewportKeys[groupId];
      final groupRect = groupKey == null ? null : _rectForViewportKey(groupKey);

      _externalReorderGroupHeights[groupId] = groupRect?.height ?? 180;
    }
  }

  void _finishReorderInteraction() {
    final shouldSave = _hasPendingReorderSave;

    setState(() {
      _draggingBlockId = null;
      _draggingGroupId = null;
      _dragPreviewGroupId = null;
      _lastDragGlobalPosition = null;

      _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
      _blockedEdgePreviewGroupId = null;
      _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
      _hasPendingReorderSave = false;
      _isExternalBlockReorderActive = false;
      _externalDraggingBlockId = null;
      _externalReorderGroupHeights.clear();
      _externalReorderBlockHeights.clear();
    });

    _cleanupUnusedGroupTitleEditors();

    if (shouldSave) {
      _saveNote();
      HapticFeedback.selectionClick();
    }
  }

  Widget _reorderProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    final externalDraggingBlockId = _externalDraggingBlockId;

    if (_isExternalBlockReorderActive && externalDraggingBlockId != null) {
      final blockIndex = _blocks.indexWhere((block) {
        return block.id == externalDraggingBlockId;
      });

      if (blockIndex != -1) {
        final block = _blocks[blockIndex];

        final frozenHeight =
            (_externalReorderBlockHeights[externalDraggingBlockId] ?? 86)
                .clamp(42.0, 10000.0)
                .toDouble();

        final proxyChild = _buildExternalReorderDragProxyBlockEntry(
          block: block,
          height: frozenHeight,
        );

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: curvedAnimation,
            child: proxyChild,
            builder: (context, animatedChild) {
              final lift = curvedAnimation.value;
              final scale = 1.0 + (lift * 0.012);

              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Material(
                  type: MaterialType.transparency,
                  color: Colors.transparent,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  child: animatedChild,
                ),
              );
            },
          ),
        );
      }
    }

    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        color: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: child,
      ),
    );
  }

  Widget _innerGroupReorderProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        color: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: child,
      ),
    );
  }

  bool _sameBlockOrder(List<NoteBlock> first, List<NoteBlock> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var i = 0; i < first.length; i++) {
      if (first[i].id != second[i].id) {
        return false;
      }
    }

    return true;
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

      if (block.type == NoteBlockType.ribbon) {
        final controllers = _ribbonTextControllers[block.id];

        if (controllers != null) {
          final text = _encodeRibbonTexts(
            controllers.map((controller) => controller.text).toList(),
          );

          if (text != block.text) {
            final updatedBlock = block.copyWith(text: text);

            _blocks[i] = updatedBlock;
            _syncHiddenBlockController(updatedBlock);
          }
        }

        continue;
      }

      final controller = _blockControllers[block.id];

      if (controller != null && controller.text != block.text) {
        final updatedLinks = _adjustLinksForTextChange(
          oldText: block.text,
          newText: controller.text,
          oldLinks: block.links,
        );

        final updatedBlock = block.copyWith(
          text: controller.text,
          links: updatedLinks,
        );

        _blocks[i] = updatedBlock;
        _syncBlockControllerLinks(updatedBlock);
      }
    }
  }

  void _reorderBlocksInsideGroup(
    String groupId,
    int oldLocalIndex,
    int newLocalIndex,
  ) {
    final range = _groupRangeInBlocks(_blocks, groupId);

    if (range == null) {
      return;
    }

    final groupLength = range.end - range.start + 1;

    if (groupLength <= 1) {
      return;
    }

    if (oldLocalIndex < 0 || oldLocalIndex >= groupLength) {
      return;
    }

    final groupBlocks = _blocks.sublist(range.start, range.end + 1).toList();

    if (groupBlocks.isEmpty) {
      return;
    }

    final movingBlockId = _draggingBlockId;

    var currentLocalIndex = movingBlockId == null
        ? -1
        : groupBlocks.indexWhere((block) => block.id == movingBlockId);

    if (currentLocalIndex == -1) {
      currentLocalIndex = oldLocalIndex;
    }

    if (currentLocalIndex < 0 || currentLocalIndex >= groupBlocks.length) {
      return;
    }

    final targetLocalIndex = newLocalIndex
        .clamp(0, groupBlocks.length - 1)
        .toInt();

    if (targetLocalIndex == currentLocalIndex) {
      return;
    }

    final groupTitle = _groupTitleForGroupId(groupId);

    final movedBlock = groupBlocks
        .removeAt(currentLocalIndex)
        .copyWith(
          groupId: groupId,
          groupTitle: groupTitle,
          groupCollapsed: false,
        );

    final safeInsertIndex = targetLocalIndex
        .clamp(0, groupBlocks.length)
        .toInt();

    groupBlocks.insert(safeInsertIndex, movedBlock);

    final normalizedGroupBlocks = groupBlocks.map((block) {
      return block.copyWith(
        groupId: groupId,
        groupTitle: groupTitle,
        groupCollapsed: false,
      );
    }).toList();

    final nextBlocks = List<NoteBlock>.from(_blocks)
      ..replaceRange(range.start, range.end + 1, normalizedGroupBlocks);

    if (_sameBlockOrder(_blocks, nextBlocks)) {
      return;
    }

    final updatedMovedIndex = nextBlocks.indexWhere(
      (block) => block.id == movedBlock.id,
    );

    setState(() {
      _blocks = nextBlocks;
      _activeBlockIndex = updatedMovedIndex == -1 ? null : updatedMovedIndex;
      _hasPendingReorderSave = true;
    });
  }

  int newIndexSafe(int newIndex, int maxLength) {
    return newIndex.clamp(0, maxLength).toInt();
  }

  void _reorderRenderEntries(int oldEntryIndex, int newEntryIndex) {
    if (_blocks.isEmpty) {
      return;
    }

    final entries = _buildRenderEntries();

    if (oldEntryIndex < 0 || oldEntryIndex >= entries.length) {
      return;
    }

    final movingEntry = entries[oldEntryIndex];

    final movingGroupId =
        _draggingGroupId ??
        (movingEntry.isGroup &&
                movingEntry.groupId != null &&
                _isGroupCollapsed(movingEntry.groupId!)
            ? movingEntry.groupId
            : null);

    final activeBlockId =
        _activeBlockIndex != null &&
            _activeBlockIndex! >= 0 &&
            _activeBlockIndex! < _blocks.length
        ? _blocks[_activeBlockIndex!].id
        : null;

    final movingIds = movingGroupId == null
        ? movingEntry.blockIndexes
              .map((blockIndex) => _blocks[blockIndex].id)
              .toSet()
        : _blocks
              .where((block) => _validGroupId(block.groupId) == movingGroupId)
              .map((block) => block.id)
              .toSet();

    final movingBlocks = _blocks
        .where((block) => movingIds.contains(block.id))
        .toList(growable: false);

    final remainingBlocks = _blocks
        .where((block) => !movingIds.contains(block.id))
        .toList();

    final remainingEntries = _buildRenderEntriesForBlocks(remainingBlocks);

    final safeNewEntryIndex = newIndexSafe(
      newEntryIndex,
      remainingEntries.length,
    );

    final insertBlockIndex = safeNewEntryIndex >= remainingEntries.length
        ? remainingBlocks.length
        : remainingEntries[safeNewEntryIndex].firstBlockIndex;

    final nextBlocks = List<NoteBlock>.from(remainingBlocks)
      ..insertAll(insertBlockIndex, movingBlocks);

    if (_sameBlockOrder(_blocks, nextBlocks)) {
      return;
    }

    setState(() {
      _blocks = nextBlocks;

      if (activeBlockId != null) {
        final updatedIndex = _blocks.indexWhere(
          (currentBlock) => currentBlock.id == activeBlockId,
        );

        _activeBlockIndex = updatedIndex == -1 ? null : updatedIndex;
      }

      _hasPendingReorderSave = true;
    });
  }

  bool _supportsTextFormatting(NoteBlock block) {
    return block.type != NoteBlockType.image &&
        block.type != NoteBlockType.file &&
        block.type != NoteBlockType.divider &&
        block.type != NoteBlockType.tracker &&
        block.type != NoteBlockType.database &&
        block.type != NoteBlockType.ribbon;
  }

  bool _supportsListFormatting(NoteBlock block) {
    return block.type != NoteBlockType.image &&
        block.type != NoteBlockType.file &&
        block.type != NoteBlockType.divider &&
        block.type != NoteBlockType.tracker &&
        block.type != NoteBlockType.database &&
        block.type != NoteBlockType.ribbon;
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

    final selectedBlockId = _blocks[index].id;

    if (_activeBlockIndex == index &&
        _editingLinkedBlockId == selectedBlockId) {
      return;
    }

    setState(() {
      _activeBlockIndex = index;

      if (_editingLinkedBlockId != selectedBlockId) {
        _editingLinkedBlockId = null;
      }
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
      case NoteBlockType.file:
      case NoteBlockType.divider:
      case NoteBlockType.ribbon:
        return _ToolbarListMode.paragraph;
      case NoteBlockType.tracker:
      case NoteBlockType.database:
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

    FocusManager.instance.primaryFocus?.unfocus();
  }

  static final RegExp _markdownLinkPattern = RegExp(
    r'\[([^\]]+)\]\(([^)\n]+)\)',
  );

  String _labelForHyperlinkTarget(
    String target, {
    String fallback = 'Abrir enlace',
  }) {
    final trimmedTarget = target.trim();

    if (trimmedTarget.startsWith('nimahub://note/') &&
        trimmedTarget.contains('/block/')) {
      return 'Bloque de nota';
    }

    if (trimmedTarget.startsWith('nimahub://note/')) {
      return 'Tarjeta de nota';
    }

    final uri = Uri.tryParse(trimmedTarget);

    if (uri != null && uri.host.trim().isNotEmpty) {
      return uri.host.replaceFirst(RegExp(r'^www\.'), '');
    }

    return fallback;
  }

  Future<void> _openHyperlinkTarget(String target) async {
    final trimmedTarget = target.trim();

    if (trimmedTarget.isEmpty) {
      return;
    }

    if (trimmedTarget.startsWith('nimahub://note/')) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enlace interno preparado. Falta conectar navegación.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(trimmedTarget);

    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildBlockTextEditorWithLinks({
    required NoteBlock block,
    required int index,
    required bool isExpanded,
  }) {
    final controller = _blockControllers[block.id];
    final focusNode = _blockFocusNodes[block.id];
    final scrollController = _textBlockScrollControllerFor(block.id);

    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    if (controller is _LinkedBlockTextController) {
      controller.updateLinks(block.links);
    }

    final baseStyle = _textStyleForBlock(block);
    final textAlign = _textAlignForBlock(block);
    const contentPadding = EdgeInsets.fromLTRB(8, 8, 22, 8);

    final placeholderStyle = baseStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.25),
      decoration: TextDecoration.none,
    );

    final placeholderText = block.style == NoteBlockStyle.heading1
        ? 'Título'
        : block.style == NoteBlockStyle.heading2
        ? 'Subtítulo'
        : 'Escribe algo…';

    final placeholderAlignment = switch (textAlign) {
      TextAlign.center => Alignment.topCenter,
      TextAlign.right => Alignment.topRight,
      TextAlign.end => Alignment.topRight,
      _ => Alignment.topLeft,
    };

    Widget buildPlaceholder() {
      return KeyedSubtree(
        key: ValueKey<String>('block-placeholder-${block.id}'),
        child: IgnorePointer(
          child: Padding(
            padding: contentPadding,
            child: Align(
              alignment: placeholderAlignment,
              child: Text(
                placeholderText,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textAlign: textAlign,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: true,
                  applyHeightToLastDescent: true,
                ),
                style: placeholderStyle,
              ),
            ),
          ),
        ),
      );
    }

    List<Widget> buildLinkTapOverlays({
      required BuildContext context,
      required BoxConstraints constraints,
    }) {
      final text = controller.text;

      if (text.isEmpty || block.links.isEmpty) {
        return const <Widget>[];
      }

      final maxTextWidth = (constraints.maxWidth - contentPadding.horizontal)
          .clamp(0.0, double.infinity)
          .toDouble();

      final textPainter = TextPainter(
        text: TextSpan(text: text, style: baseStyle),
        textAlign: textAlign,
        textDirection: Directionality.of(context),
        maxLines: null,
      )..layout(maxWidth: maxTextWidth);

      final overlays = <Widget>[];

      for (final link in block.links) {
        if (link.start < 0 ||
            link.end > text.length ||
            link.start >= link.end) {
          continue;
        }

        final boxes = textPainter.getBoxesForSelection(
          TextSelection(baseOffset: link.start, extentOffset: link.end),
        );

        for (final box in boxes) {
          final rect = box.toRect().inflate(5);

          overlays.add(
            Positioned(
              left: contentPadding.left + rect.left,
              top: contentPadding.top + rect.top,
              width: rect.width,
              height: rect.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  unawaited(_openHyperlinkTarget(link.target));
                },
                onLongPress: () {
                  FocusManager.instance.primaryFocus?.unfocus();

                  unawaited(
                    _showEditHyperlinkForBlock(
                      block: block,
                      blockIndex: index,
                      controller: controller,
                      matchStart: link.start,
                      matchEnd: link.end,
                      currentLabel: link.label,
                      currentTarget: link.target,
                    ),
                  );
                },
              ),
            ),
          );
        }
      }

      return overlays;
    }

    Widget buildEditor() {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: isExpanded ? Clip.none : Clip.hardEdge,
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) {
                      return const SizedBox.shrink();
                    }

                    return buildPlaceholder();
                  },
                ),
              ),

              TextField(
                key: ValueKey<String>('text-field-${block.id}'),
                controller: controller,
                focusNode: focusNode,
                scrollController: scrollController,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                scrollPhysics: isExpanded
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: baseStyle,
                textAlign: textAlign,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: contentPadding,
                ),
                onTap: () {
                  _rememberEditorTextFocus(focusNode);

                  setState(() {
                    _editingLinkedBlockId = block.id;
                    _activeBlockIndex = index;
                  });
                },
                onChanged: (value) {
                  _handleBlockTextChanged(block.id, value);
                },
                onSubmitted: (_) {
                  _handleBlockSubmitted(index);
                },
              ),

              ...buildLinkTapOverlays(
                context: context,
                constraints: constraints,
              ),
            ],
          );
        },
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: isExpanded
            ? _textBlockExpandedMaxHeight
            : _textBlockCollapsedHeight,
        child: buildEditor(),
      ),
    );
  }

  void _insertTextIntoActiveBlock(String insertText) {
    final activeIndex = _resolvedActiveBlockIndex;

    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _blocks.length) {
      return;
    }

    final block = _blocks[activeIndex];

    if (block.type == NoteBlockType.divider ||
        block.type == NoteBlockType.tracker ||
        block.type == NoteBlockType.database ||
        block.type == NoteBlockType.ribbon) {
      return;
    }

    if (_isWordListBlock(block)) {
      _ensureListEditorsForBlock(block);

      final controllers = _listLineControllers[block.id];
      final focusNodes = _listLineFocusNodes[block.id];

      if (controllers == null || controllers.isEmpty) {
        return;
      }

      var itemIndex = 0;

      if (focusNodes != null) {
        final focusedIndex = focusNodes.indexWhere((focusNode) {
          return focusNode.hasFocus;
        });

        if (focusedIndex != -1) {
          itemIndex = focusedIndex;
        }
      }

      final controller = controllers[itemIndex];
      final selection = controller.selection;
      final text = controller.text;

      final start = selection.isValid
          ? selection.start.clamp(0, text.length).toInt()
          : text.length;
      final end = selection.isValid
          ? selection.end.clamp(0, text.length).toInt()
          : text.length;

      final newText = text.replaceRange(start, end, insertText);
      final cursorOffset = start + insertText.length;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );

      _handleListItemChanged(activeIndex, itemIndex, newText);
      return;
    }

    final controller = _blockControllers[block.id];

    if (controller == null) {
      return;
    }

    final text = controller.text;
    final selection = controller.selection;

    final start = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, text.length).toInt()
        : text.length;

    final newText = text.replaceRange(start, end, insertText);
    final cursorOffset = start + insertText.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );

    setState(() {
      _blocks[activeIndex] = block.copyWith(text: newText);
    });

    _saveNote();
  }

  String _hyperlinkInsertionText({
    required String currentText,
    required TextSelection selection,
    required String markdownLink,
  }) {
    final safeStart = selection.isValid
        ? selection.start.clamp(0, currentText.length).toInt()
        : currentText.length;

    final safeEnd = selection.isValid
        ? selection.end.clamp(0, currentText.length).toInt()
        : currentText.length;

    final start = safeStart < safeEnd ? safeStart : safeEnd;
    final end = safeStart < safeEnd ? safeEnd : safeStart;

    final hasSelection = start != end;

    if (hasSelection) {
      return markdownLink;
    }

    final before = currentText.substring(0, start);
    final after = currentText.substring(start);

    final needsLeadingBreak =
        before.trim().isNotEmpty && !before.endsWith('\n');
    final needsTrailingBreak =
        after.trim().isNotEmpty && !after.startsWith('\n');

    return '${needsLeadingBreak ? '\n' : ''}'
        '$markdownLink'
        '${needsTrailingBreak ? '\n' : ''}';
  }

  void _insertHyperlinkIntoActiveBlock(String markdownLink) {
    final activeIndex = _resolvedActiveBlockIndex;

    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _blocks.length) {
      return;
    }

    final match = _markdownLinkPattern.firstMatch(markdownLink);

    if (match == null) {
      return;
    }

    final rawLabel = match.group(1)?.trim() ?? '';
    final target = match.group(2)?.trim() ?? '';

    if (target.isEmpty) {
      return;
    }

    final label = rawLabel.isEmpty
        ? _labelForHyperlinkTarget(target)
        : rawLabel;

    if (label.isEmpty) {
      return;
    }

    final block = _blocks[activeIndex];

    if (block.type == NoteBlockType.divider ||
        block.type == NoteBlockType.tracker ||
        block.type == NoteBlockType.database ||
        block.type == NoteBlockType.ribbon ||
        _isWordListBlock(block)) {
      return;
    }

    final controller = _blockControllers[block.id];

    if (controller == null) {
      return;
    }

    final text = controller.text;
    final selection = controller.selection;

    final insertText = _hyperlinkInsertionText(
      currentText: text,
      selection: selection,
      markdownLink: label,
    );

    final rawStart = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : text.length;

    final rawEnd = selection.isValid
        ? selection.end.clamp(0, text.length).toInt()
        : text.length;

    final start = rawStart < rawEnd ? rawStart : rawEnd;
    final end = rawStart < rawEnd ? rawEnd : rawStart;

    final labelOffsetInInsert = insertText.indexOf(label);
    final linkStart =
        start + (labelOffsetInInsert == -1 ? 0 : labelOffsetInInsert);
    final linkEnd = linkStart + label.length;

    final newText = text.replaceRange(start, end, insertText);
    final cursorOffset = start + insertText.length;

    final updatedLinks =
        _linksAfterTextReplacement(
          oldLinks: block.links,
          start: start,
          end: end,
          insertedLength: insertText.length,
        )..add(
          NoteBlockLink(
            id: _newLinkId(),
            start: linkStart,
            end: linkEnd,
            label: label,
            target: target,
          ),
        );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );

    final updatedBlock = block.copyWith(text: newText, links: updatedLinks);

    setState(() {
      _blocks[activeIndex] = updatedBlock;
      _editingLinkedBlockId = null;
    });

    _syncBlockControllerLinks(updatedBlock);
    _saveNote();
  }

  Future<void> _showHyperlinkPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted) {
      return;
    }

    final selectedType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);

        final safeBottom =
            mediaQuery.viewPadding.bottom > mediaQuery.padding.bottom
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;

        final bottomGap = safeBottom > 0 ? safeBottom + 12.0 : 28.0;

        Widget option({
          required String id,
          required IconData icon,
          required String title,
          required String subtitle,
        }) {
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
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext, id);
            },
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Agregar hipervínculo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                option(
                  id: 'web',
                  icon: Icons.language_rounded,
                  title: 'Página web / HTML',
                  subtitle: 'Insertar enlace externo',
                ),
                option(
                  id: 'note',
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Tarjeta de nota',
                  subtitle: 'Insertar enlace a otra tarjeta',
                ),
                option(
                  id: 'block',
                  icon: Icons.text_snippet_outlined,
                  title: 'Bloque de otra tarjeta',
                  subtitle: 'Insertar enlace a un bloque específico',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedType == null) {
      return;
    }

    if (selectedType == 'web') {
      FocusManager.instance.primaryFocus?.unfocus();

      await Future<void>.delayed(const Duration(milliseconds: 90));

      if (!mounted) {
        return;
      }

      await _showHyperlinkInputDialog(
        title: 'Página web / HTML',
        description: 'Inserta un enlace externo.',
        targetLabel: 'URL',
        targetHint: 'https://pagina.com',
        buildUrl: (primary, secondary) {
          final rawUrl = primary.trim();
          final lowerUrl = rawUrl.toLowerCase();

          if (lowerUrl.startsWith('http://') ||
              lowerUrl.startsWith('https://') ||
              lowerUrl.startsWith('file://')) {
            return rawUrl;
          }

          return 'https://$rawUrl';
        },
      );
      return;
    }

    if (selectedType == 'note') {
      FocusManager.instance.primaryFocus?.unfocus();

      await Future<void>.delayed(const Duration(milliseconds: 90));

      if (!mounted) {
        return;
      }

      await _showHyperlinkInputDialog(
        title: 'Tarjeta de nota',
        description: 'Inserta un enlace interno a otra tarjeta de nota.',
        targetLabel: 'ID de la tarjeta',
        targetHint: 'noteId',
        buildUrl: (primary, secondary) {
          return 'nimahub://note/${primary.trim()}';
        },
      );
      return;
    }

    if (selectedType == 'block') {
      FocusManager.instance.primaryFocus?.unfocus();

      await Future<void>.delayed(const Duration(milliseconds: 90));

      if (!mounted) {
        return;
      }

      await _showHyperlinkInputDialog(
        title: 'Bloque de otra tarjeta',
        description: 'Inserta un enlace interno a un bloque específico.',
        targetLabel: 'ID de la tarjeta',
        targetHint: 'noteId',
        secondTargetLabel: 'ID del bloque',
        secondTargetHint: 'blockId',
        buildUrl: (primary, secondary) {
          return 'nimahub://note/${primary.trim()}/block/${secondary!.trim()}';
        },
      );
    }
  }

  Future<void> _showHyperlinkInputDialog({
    required String title,
    required String description,
    required String targetLabel,
    required String targetHint,
    required String Function(String primary, String? secondary) buildUrl,
    String? secondTargetLabel,
    String? secondTargetHint,
    String? initialLabel,
    String? initialPrimary,
    String? initialSecondary,
    void Function(String markdownLink)? onMarkdownLinkReady,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted) {
      return;
    }

    final labelController = TextEditingController(text: initialLabel ?? '');
    final primaryController = TextEditingController(text: initialPrimary ?? '');
    final secondaryController = TextEditingController(
      text: initialSecondary ?? '',
    );

    final markdownLink = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final bottomInset = mediaQuery.viewInsets.bottom;

        final safeBottom =
            mediaQuery.viewPadding.bottom > mediaQuery.padding.bottom
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;

        final bottomGap = bottomInset > 0
            ? 12.0
            : safeBottom > 0
            ? safeBottom + 12.0
            : 28.0;

        InputDecoration inputDecoration(String label, String hint) {
          return InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
            filled: true,
            fillColor: const Color(0xFF2B2D34),
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
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + bottomGap),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.46),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: labelController,
                  autofocus: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: inputDecoration(
                    'Texto visible',
                    'Ej: Abrir enlace',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: primaryController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.url,
                  decoration: inputDecoration(targetLabel, targetHint),
                ),
                if (secondTargetLabel != null) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: secondaryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(
                      secondTargetLabel,
                      secondTargetHint ?? '',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      final primary = primaryController.text.trim();
                      final secondary = secondaryController.text.trim();

                      if (primary.isEmpty) {
                        return;
                      }

                      if (secondTargetLabel != null && secondary.isEmpty) {
                        return;
                      }

                      final url = buildUrl(
                        primary,
                        secondTargetLabel == null ? null : secondary,
                      );

                      final typedLabel = labelController.text.trim();

                      final label = typedLabel.isEmpty
                          ? _labelForHyperlinkTarget(
                              url,
                              fallback: 'Abrir enlace',
                            )
                          : typedLabel;

                      final markdownLink = '[$label]($url)';

                      Navigator.pop(sheetContext, markdownLink);
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Insertar hipervínculo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || markdownLink == null) {
      return;
    }

    if (onMarkdownLinkReady != null) {
      onMarkdownLinkReady(markdownLink);
    } else {
      _insertHyperlinkIntoActiveBlock(markdownLink);
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _editingLinkedBlockId = null;
    });

    HapticFeedback.selectionClick();
  }

  void _replaceHyperlinkInBlock({
    required NoteBlock block,
    required int blockIndex,
    required TextEditingController controller,
    required int matchStart,
    required int matchEnd,
    required String newMarkdownLink,
  }) {
    final match = _markdownLinkPattern.firstMatch(newMarkdownLink);

    if (match == null) {
      return;
    }

    final rawLabel = match.group(1)?.trim() ?? '';
    final target = match.group(2)?.trim() ?? '';

    if (target.isEmpty) {
      return;
    }

    final label = rawLabel.isEmpty
        ? _labelForHyperlinkTarget(target)
        : rawLabel;

    final oldText = controller.text;

    if (matchStart < 0 ||
        matchEnd > oldText.length ||
        matchStart >= matchEnd ||
        blockIndex < 0 ||
        blockIndex >= _blocks.length) {
      return;
    }

    final newText = oldText.replaceRange(matchStart, matchEnd, label);

    final updatedLinks =
        _linksAfterTextReplacement(
          oldLinks: block.links,
          start: matchStart,
          end: matchEnd,
          insertedLength: label.length,
        )..add(
          NoteBlockLink(
            id: _newLinkId(),
            start: matchStart,
            end: matchStart + label.length,
            label: label,
            target: target,
          ),
        );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: matchStart + label.length),
    );

    final updatedBlock = block.copyWith(text: newText, links: updatedLinks);

    setState(() {
      _blocks[blockIndex] = updatedBlock;
      _editingLinkedBlockId = null;
    });

    _syncBlockControllerLinks(updatedBlock);
    _saveNote();
  }

  Future<void> _showEditHyperlinkForBlock({
    required NoteBlock block,
    required int blockIndex,
    required TextEditingController controller,
    required int matchStart,
    required int matchEnd,
    required String currentLabel,
    required String currentTarget,
  }) async {
    if (matchStart < 0 ||
        matchEnd > controller.text.length ||
        matchStart >= matchEnd) {
      return;
    }

    final isInternalNoteLink = currentTarget.startsWith('nimahub://note/');
    final isInternalBlockLink =
        isInternalNoteLink && currentTarget.contains('/block/');

    if (isInternalBlockLink) {
      final withoutPrefix = currentTarget.replaceFirst('nimahub://note/', '');
      final parts = withoutPrefix.split('/block/');

      await _showHyperlinkInputDialog(
        title: 'Editar bloque vinculado',
        description: 'Modifica el enlace interno a un bloque específico.',
        targetLabel: 'ID de la tarjeta',
        targetHint: 'noteId',
        secondTargetLabel: 'ID del bloque',
        secondTargetHint: 'blockId',
        initialLabel: currentLabel,
        initialPrimary: parts.isNotEmpty ? parts.first : '',
        initialSecondary: parts.length > 1 ? parts[1] : '',
        buildUrl: (primary, secondary) {
          return 'nimahub://note/${primary.trim()}/block/${secondary!.trim()}';
        },
        onMarkdownLinkReady: (newMarkdownLink) {
          _replaceHyperlinkInBlock(
            block: block,
            blockIndex: blockIndex,
            controller: controller,
            matchStart: matchStart,
            matchEnd: matchEnd,
            newMarkdownLink: newMarkdownLink,
          );
        },
      );

      return;
    }

    if (isInternalNoteLink) {
      final noteId = currentTarget.replaceFirst('nimahub://note/', '');

      await _showHyperlinkInputDialog(
        title: 'Editar tarjeta vinculada',
        description: 'Modifica el enlace interno a una tarjeta de nota.',
        targetLabel: 'ID de la tarjeta',
        targetHint: 'noteId',
        initialLabel: currentLabel,
        initialPrimary: noteId,
        buildUrl: (primary, secondary) {
          return 'nimahub://note/${primary.trim()}';
        },
        onMarkdownLinkReady: (newMarkdownLink) {
          _replaceHyperlinkInBlock(
            block: block,
            blockIndex: blockIndex,
            controller: controller,
            matchStart: matchStart,
            matchEnd: matchEnd,
            newMarkdownLink: newMarkdownLink,
          );
        },
      );

      return;
    }

    await _showHyperlinkInputDialog(
      title: 'Editar hipervínculo',
      description: 'Modifica el enlace externo.',
      targetLabel: 'URL',
      targetHint: 'https://pagina.com',
      initialLabel: currentLabel,
      initialPrimary: currentTarget,
      buildUrl: (primary, secondary) {
        final rawUrl = primary.trim();
        final lowerUrl = rawUrl.toLowerCase();

        if (lowerUrl.startsWith('http://') ||
            lowerUrl.startsWith('https://') ||
            lowerUrl.startsWith('file://')) {
          return rawUrl;
        }

        return 'https://$rawUrl';
      },
      onMarkdownLinkReady: (newMarkdownLink) {
        _replaceHyperlinkInBlock(
          block: block,
          blockIndex: blockIndex,
          controller: controller,
          matchStart: matchStart,
          matchEnd: matchEnd,
          newMarkdownLink: newMarkdownLink,
        );
      },
    );
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
            color: _editorNeutralGray,
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
            color: _editorNeutralGray,
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
                      backgroundColor: _editorNeutralGray,
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
            color: _editorNeutralGray,
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
        return 16;
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
        baseStyle = const TextStyle(fontSize: 16, height: 1.45);
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
        return 'Agregar resaltado de bloque';
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

    return _editorBlockGray;
  }

  Color _brightHighlightColor(Color color) {
    final hsl = HSLColor.fromColor(color);

    return hsl
        .withSaturation((hsl.saturation + 0.45).clamp(0.72, 1.0))
        .withLightness(hsl.lightness < 0.62 ? 0.74 : hsl.lightness)
        .toColor();
  }

  BoxDecoration _blockDecoration(
    NoteBlock block, {
    double borderRadius = 14,
    double highlightedBorderWidth = 2.4,
  }) {
    final customColor = block.colorValue == null
        ? null
        : Color(block.colorValue!);

    final rawHighlightColor = block.highlightColorValue == null
        ? Colors.white
        : Color(block.highlightColorValue!);

    final highlightColor = _brightHighlightColor(rawHighlightColor);

    final backgroundColor = _blockBackgroundColor(block);

    final normalBorderColor =
        customColor?.withValues(alpha: 0.78) ??
        Colors.white.withValues(alpha: 0.14);

    final isHighlighted = block.highlightColorValue != null;

    Border border;

    if (isHighlighted) {
      border = Border.all(
        color: highlightColor.withValues(alpha: 1.0),
        width: highlightedBorderWidth,
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
      boxShadow: customColor != null
          ? [
              BoxShadow(
                color: customColor.withValues(alpha: 0.10),
                blurRadius: 14,
              ),
            ]
          : null,
    );
  }

  BoxDecoration _textBlockBodyDecoration(NoteBlock block) {
    return _blockDecoration(block, highlightedBorderWidth: 1.4).copyWith(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
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

      case NoteBlockType.file:
        return 'Archivo';

      case NoteBlockType.divider:
        return 'Separador';

      case NoteBlockType.tracker:
        return 'Tracker';
      case NoteBlockType.database:
        return 'Base de datos';
      case NoteBlockType.ribbon:
        return 'Cinta';
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

      case NoteBlockType.file:
        return Icons.attach_file_rounded;

      case NoteBlockType.divider:
        return Icons.horizontal_rule_rounded;

      case NoteBlockType.tracker:
        return Icons.track_changes_rounded;
      case NoteBlockType.database:
        return Icons.table_chart_outlined;
      case NoteBlockType.ribbon:
        return Icons.view_carousel_rounded;
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
    double backgroundAlpha = 0.0,
    Color? backgroundColor,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry iconPadding = EdgeInsets.zero,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      alignment: alignment,
      decoration: BoxDecoration(
        color:
            backgroundColor ?? Colors.white.withValues(alpha: backgroundAlpha),
        borderRadius: borderRadius,
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
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
    bool reorderEnabled = true,
    double width = _blockDragHandleWidth,
    double? height,
    double iconSize = 19,
    double iconAlpha = 0.30,
    double backgroundAlpha = 0.0,
    Color? backgroundColor,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry iconPadding = EdgeInsets.zero,
    Alignment alignment = Alignment.center,
  }) {
    final reorderIndex =
        reorderIndexOverride ?? _reorderIndexByBlockIndex[index] ?? index;

    final handle = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (isInternalGroupReorder) {
          _lastDragGlobalPosition = event.position;
          return;
        }

        FocusManager.instance.primaryFocus?.unfocus();
      },

      onPointerMove: (event) {
        if (isInternalGroupReorder) {
          _lastDragGlobalPosition = event.position;
        }
      },

      onPointerCancel: (_) {
        if (!mounted) {
          return;
        }

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
        backgroundAlpha: backgroundAlpha,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        iconPadding: iconPadding,
        alignment: alignment,
      ),
    );

    final sizedHandle = height == null
        ? handle
        : SizedBox(width: width, height: height, child: handle);

    if (!reorderEnabled) {
      return sizedHandle;
    }

    return ReorderableDragStartListener(
      index: reorderIndex,
      child: sizedHandle,
    );
  }

  Widget _buildReorderableGroupDragHandle({
    required String groupId,
    required int entryIndex,
    required bool isCollapsed,
    double width = _blockDragHandleWidth,
    double height = 42,
  }) {
    if (!isCollapsed) {
      return SizedBox(
        width: width,
        height: height,
        child: _buildBlockDragHandle(
          width: width,
          iconAlpha: 0.16,
          alignment: Alignment.center,
        ),
      );
    }
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
          color: _editorNeutralGray.withValues(alpha: 0.34),
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
              width: _textBlockDragHandleWidth,
              child: IgnorePointer(
                child: _buildBlockDragHandle(
                  width: _textBlockDragHandleWidth,
                  iconAlpha: 0.16,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: _textBlockDragHandleWidth),
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
    final groupColor = _groupTitleColorForGroupId(groupId);

    return Container(
      constraints: const BoxConstraints(minHeight: _groupHeaderHeight),
      padding: EdgeInsets.only(right: _editorContentRight + 8),
      child: Row(
        children: [
          _buildReorderableGroupDragHandle(
            groupId: groupId,
            entryIndex: entryIndex,
            isCollapsed: isCollapsed,
            width: _textBlockDragHandleWidth + _editorContentLeft,
          ),

          Expanded(
            child: TextField(
              key: ValueKey<String>('group-title-$groupId'),
              controller: groupTitleController,
              focusNode: groupTitleFocusNode,
              minLines: 1,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: groupColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
              decoration: InputDecoration(
                hintText: 'Título del grupo',
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                hintStyle: TextStyle(color: groupColor.withValues(alpha: 0.42)),
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
                _rememberEditorTextFocus(groupTitleFocusNode);

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
                color: groupColor,
                size: 26,
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
    final groupBorderColor = _groupBorderColorForGroupId(groupId);
    final groupBackgroundColor = _groupBackgroundColorForGroupId(groupId);

    final isFirst = _isFirstBlockInGroup(index);
    final isLast = _isLastBlockInGroup(index);

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(18) : Radius.zero,
      bottom: isLast ? const Radius.circular(18) : Radius.zero,
    );

    final muteFrameDuringDrag = _isDraggingBlockRelatedToGroup(groupId);
    final isAddingBlocks = _isGroupAddDragExtending(groupId);

    final frameAlpha = muteFrameDuringDrag ? 0.0 : 0.68;
    final shadowAlpha = muteFrameDuringDrag ? 0.0 : 0.10;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 8 : 0),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: groupBorderColor.withValues(alpha: shadowAlpha),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.none,
      child: CustomPaint(
        painter: _GroupBlockBackgroundPainter(
          color: groupBackgroundColor,
          isFirst: isFirst,
          isLast: isLast,
          leftInset: _groupFrameLeftInset,
          rightInset: _groupFrameRightInset,
        ),
        foregroundPainter: _GroupBlockFramePainter(
          color: groupBorderColor.withValues(alpha: frameAlpha),
          isFirst: isFirst,
          isLast: isLast,
          leftInset: _groupFrameLeftInset,
          rightInset: _groupFrameRightInset,
          hideBottomEdge: isLast && isAddingBlocks,
          bottomOpenInset: isLast && isAddingBlocks ? _groupAddHandleHeight : 0,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFirst) ...[
                  _buildGroupHeader(
                    groupId: groupId,
                    firstBlockIndex: index,
                    entryIndex: _reorderIndexByBlockIndex[index] ?? index,
                    isCollapsed: false,
                  ),
                ],

                child,

                if (isLast) _buildGroupAddBlocksHandle(groupId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedGroupInnerReorderList({
    required String groupId,
    required List<int> blockIndexes,
  }) {
    final children = <Widget>[];

    for (var localIndex = 0; localIndex < blockIndexes.length; localIndex++) {
      final blockIndex = blockIndexes[localIndex];

      if (blockIndex < 0 || blockIndex >= _blocks.length) {
        children.add(
          SizedBox.shrink(
            key: ValueKey<String>('invalid-inner-group-block-$localIndex'),
          ),
        );
        continue;
      }

      final block = _blocks[blockIndex];

      final viewportKey = _blockViewportKeys.putIfAbsent(
        block.id,
        GlobalKey.new,
      );

      children.add(
        KeyedSubtree(
          key: ValueKey<String>('inner-reorder-block-${block.id}'),
          child: KeyedSubtree(
            key: viewportKey,
            child: RepaintBoundary(
              child: _buildBlock(
                block,
                blockIndex,
                reorderIndexOverride: localIndex,
                isInternalGroupReorder: true,
                isLastInternalGroupBlock: localIndex == blockIndexes.length - 1,
              ),
            ),
          ),
        ),
      );
    }

    return ReorderableListView(
      key: ValueKey<String>('inner-group-reorder-$groupId'),
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      cacheExtent: 120,
      autoScrollerVelocityScalar: 6,
      proxyDecorator: _innerGroupReorderProxyDecorator,
      children: children,
      onReorderStart: (localIndex) {
        if (localIndex < 0 || localIndex >= blockIndexes.length) {
          return;
        }

        _syncAllVisibleEditorsIntoBlocks();
        HapticFeedback.selectionClick();
      },
      onReorderEnd: (_) {
        if (!mounted) {
          return;
        }

        _finishReorderInteraction();
      },
      onReorderItem: (oldLocalIndex, newLocalIndex) {
        _reorderBlocksInsideGroup(groupId, oldLocalIndex, newLocalIndex);
      },
    );
  }

  bool _deleteGroup(String groupId) {
    final groupBlockIds = _blocks
        .where((block) => _validGroupId(block.groupId) == groupId)
        .map((block) => block.id)
        .toSet();

    if (groupBlockIds.isEmpty) {
      return false;
    }

    final removedBlocks = _blocks
        .where((block) => groupBlockIds.contains(block.id))
        .toList();

    setState(() {
      _blocks.removeWhere((block) => groupBlockIds.contains(block.id));

      for (final removedBlock in removedBlocks) {
        _blockControllers.remove(removedBlock.id)?.dispose();
        _blockFocusNodes.remove(removedBlock.id)?.dispose();
        _disposeListEditorsForBlock(removedBlock.id);
        _blockViewportKeys.remove(removedBlock.id);

        if (removedBlock.imagePath != null) {
          unawaited(_deleteStoredImage(removedBlock.imagePath));
        }
      }

      if (_blocks.isEmpty) {
        final fallbackBlock = NoteBlock(
          id: _newBlockId(),
          type: NoteBlockType.paragraph,
        );

        _blocks.add(fallbackBlock);
        _blockControllers[fallbackBlock.id] = _createBlockTextController(
          fallbackBlock,
        );
        _blockFocusNodes[fallbackBlock.id] = FocusNode();
        _activeBlockIndex = 0;
      } else {
        _activeBlockIndex = _activeBlockIndex?.clamp(0, _blocks.length - 1);
      }
    });

    _cleanupUnusedGroupTitleEditors();
    _saveNote();

    return true;
  }

  Future<void> _showEditGroupMenu(String groupId) async {
    if (!mounted) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final isCollapsed = _isGroupCollapsed(groupId);

    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          decoration: BoxDecoration(
            color: _editorNeutralGray,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Editar grupo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                  'Cambiar color del grupo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop('color');
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
                  child: Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  isCollapsed ? 'Desplegar grupo' : 'Minimizar grupo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop('toggle');
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    if (selectedAction == 'color') {
      await _showGroupColorPicker(groupId);
      return;
    }

    if (selectedAction == 'toggle') {
      _setGroupCollapsed(groupId, !isCollapsed);
    }
  }

  Widget _buildSwipeableGroup({
    required String groupId,
    required Widget child,
    bool enableAddBelow = false,
    Future<void> Function()? onAddBelow,
    bool swipeEnabled = true,
  }) {
    final canSwipeGroup =
        swipeEnabled &&
        !_isGroupAddDragInProgress &&
        !_isReorderInteractionActive;

    if (!canSwipeGroup) {
      return child;
    }

    return _SwipeActionBlock(
      key: ValueKey<String>('swipe-group-$groupId'),
      gestureDeadZoneWidth: _textBlockDragHandleWidth + 10,
      enableEdit: true,
      swipeEnabled: canSwipeGroup,
      enableAddBelow: false,
      onAddBelow: null,
      addIndicatorRightInset: _groupFrameRightInset - 1,
      borderRadius: 18,
      cornerFill: Colors.transparent,
      deleteBackground: _buildSwipeDeleteBackground(
        cornerFill: Colors.transparent,
        borderRadius: 18,
      ),
      editBackground: _buildSwipeEditBackground(
        cornerFill: Colors.transparent,
        borderRadius: 18,
      ),
      onDelete: () async {
        HapticFeedback.mediumImpact();
        return _deleteGroup(groupId);
      },
      onEdit: () async {
        HapticFeedback.selectionClick();
        await _showEditGroupMenu(groupId);
      },
      child: child,
    );
  }

  Widget _buildExternalReorderFrozenBlockEntry({
    required NoteBlock block,
    required double height,
    double bottomGap = 8.0,
  }) {
    final controller = _blockControllers[block.id];

    final baseStyle = _textStyleForBlock(block);
    final textAlign = _textAlignForBlock(block);
    final isTextBlockExpanded = _expandedTextBlockIds.contains(block.id);
    const contentPadding = EdgeInsets.fromLTRB(8, 8, 22, 8);

    final placeholderText = block.style == NoteBlockStyle.heading1
        ? 'Título'
        : block.style == NoteBlockStyle.heading2
        ? 'Subtítulo'
        : 'Escribe algo…';

    final placeholderStyle = baseStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.25),
      decoration: TextDecoration.none,
    );

    final placeholderAlignment = switch (textAlign) {
      TextAlign.center => Alignment.topCenter,
      TextAlign.right => Alignment.topRight,
      TextAlign.end => Alignment.topRight,
      _ => Alignment.topLeft,
    };

    Widget buildFrozenPlaceholder() {
      return Positioned.fill(
        left: _textBlockDragHandleWidth,
        child: IgnorePointer(
          child: Padding(
            padding: contentPadding,
            child: Align(
              alignment: placeholderAlignment,
              child: Text(
                placeholderText,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textAlign: textAlign,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: true,
                  applyHeightToLastDescent: true,
                ),
                style: placeholderStyle,
              ),
            ),
          ),
        ),
      );
    }

    if (controller == null) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            left: _editorContentLeft,
            right: _editorContentRight,
            bottom: bottomGap,
          ),
          child: Container(
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  left: _textBlockDragHandleWidth,
                  child: Container(decoration: _textBlockBodyDecoration(block)),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _textBlockDragHandleWidth,
                  child: _buildBlockDragHandle(
                    width: _textBlockDragHandleWidth,
                    iconAlpha: 0.42,
                    backgroundColor: _editorBlockGray,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                    alignment: Alignment.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isEmpty = controller.text.isEmpty;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: _editorContentLeft,
          right: _editorContentRight,
          bottom: bottomGap,
        ),
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                left: _textBlockDragHandleWidth,
                child: Container(
                  decoration: _textBlockBodyDecoration(block),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _textBlockDragHandleWidth,
                child: _buildBlockDragHandle(
                  width: _textBlockDragHandleWidth,
                  iconAlpha: 0.42,
                  backgroundColor: _editorBlockGray,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  alignment: Alignment.center,
                ),
              ),

              if (isEmpty) buildFrozenPlaceholder(),

              Padding(
                padding: const EdgeInsets.only(left: _textBlockDragHandleWidth),
                child: IgnorePointer(
                  child: TextField(
                    controller: controller,
                    readOnly: true,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    style: baseStyle,
                    textAlign: textAlign,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: contentPadding,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 3,
                child: IgnorePointer(
                  child: Container(
                    width: 30,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.055),
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Icon(
                      isTextBlockExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.80),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _usesExternalTextReorderPreview(NoteBlock block) {
    return block.type != NoteBlockType.image &&
        block.type != NoteBlockType.file &&
        block.type != NoteBlockType.divider &&
        block.type != NoteBlockType.tracker &&
        block.type != NoteBlockType.database &&
        block.type != NoteBlockType.ribbon &&
        !_isWordListBlock(block);
  }

  Widget _buildExternalReorderDragProxyBlockEntry({
    required NoteBlock block,
    required double height,
  }) {
    final controller = _blockControllers[block.id];
    final rawText = controller?.text ?? block.text;
    final isEmpty = rawText.isEmpty;

    final baseStyle = _textStyleForBlock(block);
    final textAlign = _textAlignForBlock(block);
    final textColor = _textColorForBlock(block);
    final isTextBlockExpanded = _expandedTextBlockIds.contains(block.id);
    const contentPadding = EdgeInsets.fromLTRB(8, 8, 22, 8);

    final placeholderText = block.style == NoteBlockStyle.heading1
        ? 'Título'
        : block.style == NoteBlockStyle.heading2
        ? 'Subtítulo'
        : 'Escribe algo…';

    final displayText = isEmpty ? placeholderText : rawText;

    final displayStyle = isEmpty
        ? baseStyle.copyWith(
            color: textColor.withValues(alpha: 0.25),
            decoration: TextDecoration.none,
          )
        : baseStyle;

    final contentAlignment = switch (textAlign) {
      TextAlign.center => Alignment.topCenter,
      TextAlign.right => Alignment.topRight,
      TextAlign.end => Alignment.topRight,
      _ => Alignment.topLeft,
    };

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(
          left: _editorContentLeft,
          right: _editorContentRight,
          bottom: 8,
        ),
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                left: _textBlockDragHandleWidth,
                child: Container(decoration: _textBlockBodyDecoration(block)),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _textBlockDragHandleWidth,
                child: _buildBlockDragHandle(
                  width: _textBlockDragHandleWidth,
                  iconAlpha: 0.42,
                  backgroundColor: _editorBlockGray,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  alignment: Alignment.center,
                ),
              ),

              Positioned.fill(
                left: _textBlockDragHandleWidth,
                child: Padding(
                  padding: contentPadding,
                  child: Align(
                    alignment: contentAlignment,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        displayText,
                        maxLines: isEmpty ? 1 : null,
                        overflow: TextOverflow.clip,
                        softWrap: true,
                        textAlign: textAlign,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: true,
                          applyHeightToLastDescent: true,
                        ),
                        style: displayStyle,
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 0,
                bottom: 3,
                child: IgnorePointer(
                  child: Container(
                    width: 30,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.055),
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Icon(
                      isTextBlockExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.80),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalReorderFrozenGroupEntry({
    required String groupId,
    required int blockCount,
    required double height,
    required bool isCollapsed,
  }) {
    final groupColor = _groupTitleColorForGroupId(groupId);
    final title = _groupTitleForGroupId(groupId);

    final rawGroupColor = _groupColorValueForGroupId(groupId);

    final previewFillColor = rawGroupColor == null
        ? _editorNeutralGray.withValues(alpha: 0.16)
        : Color(rawGroupColor).withValues(alpha: 0.14);

    Widget buildHeader() {
      return Row(
        children: [
          SizedBox(
            width: _blockDragHandleWidth,
            child: Center(
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 19,
                color: groupColor.withValues(alpha: isCollapsed ? 0.42 : 0.28),
              ),
            ),
          ),

          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: groupColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
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

          SizedBox(
            width: 34,
            height: 42,
            child: Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: groupColor,
              size: 24,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(
            left: _editorContentLeft,
            right: _editorContentRight,
          ),
          decoration: BoxDecoration(
            color: previewFillColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: groupColor.withValues(alpha: 0.24),
              width: 0.9,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: isCollapsed
              ? buildHeader()
              : Column(
                  children: [
                    SizedBox(height: _groupHeaderHeight, child: buildHeader()),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _editorContentLeft,
                          2,
                          _editorContentRight,
                          10,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: double.infinity,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.035),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: groupColor.withValues(alpha: 0.10),
                                width: 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$blockCount ${blockCount == 1 ? 'bloque' : 'bloques'}',
                              style: TextStyle(
                                color: groupColor.withValues(alpha: 0.48),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildExternalReorderFrozenGroupBody({
    required String groupId,
    required List<int> blockIndexes,
  }) {
    final groupColor = _groupBorderColorForGroupId(groupId);

    final frozenBlocks = <Widget>[];

    for (final blockIndex in blockIndexes) {
      if (blockIndex < 0 || blockIndex >= _blocks.length) {
        continue;
      }

      final block = _blocks[blockIndex];
      final isLastGroupBlock = blockIndex == blockIndexes.last;

      final frozenHeight = (_externalReorderBlockHeights[block.id] ?? 86)
          .clamp(42.0, 10000.0)
          .toDouble();

      frozenBlocks.add(
        _buildExternalReorderFrozenBlockEntry(
          block: block,
          height: frozenHeight,
          bottomGap: isLastGroupBlock ? 0.0 : 8.0,
        ),
      );
    }

    return RepaintBoundary(
      child: TickerMode(
        enabled: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...frozenBlocks,

            Padding(
              padding: const EdgeInsets.only(
                left: _groupFrameLeftInset,
                right: _groupFrameRightInset,
              ),
              child: Container(
                height: _groupAddHandleHeight,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.07),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: groupColor.withValues(alpha: 0.22),
                      width: 0.9,
                    ),
                  ),
                ),
                child: Text(
                  'Arrastrar para añadir bloques',
                  style: TextStyle(
                    color: groupColor.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
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

    final useFrozenBody =
        _freezeExpandedGroupsDuringExternalBlockReorder &&
        _isExternalBlockReorderActive &&
        !isCollapsed;

    final muteFrameDuringDrag =
        _draggingGroupId == groupId || _isDraggingBlockRelatedToGroup(groupId);
    final isAddingBlocks = _isGroupAddDragExtending(groupId);

    final groupBorderColor = _groupBorderColorForGroupId(groupId);
    final groupBackgroundColor = _groupBackgroundColorForGroupId(groupId);

    final frameAlpha = muteFrameDuringDrag ? 0.0 : 0.82;
    final shadowAlpha = muteFrameDuringDrag ? 0.0 : 0.10;

    final groupContent = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: groupBorderColor.withValues(alpha: shadowAlpha),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        clipBehavior: Clip.none,
        child: CustomPaint(
          painter: _GroupBlockBackgroundPainter(
            color: groupBackgroundColor,
            isFirst: true,
            isLast: true,
            leftInset: _groupFrameLeftInset,
            rightInset: _groupFrameRightInset,
          ),
          foregroundPainter: _GroupBlockFramePainter(
            color: groupBorderColor.withValues(alpha: frameAlpha),
            isFirst: true,
            isLast: true,
            leftInset: _groupFrameLeftInset,
            rightInset: _groupFrameRightInset,
            hideBottomEdge: isAddingBlocks,
            bottomOpenInset: isAddingBlocks ? _groupAddHandleHeight : 0,
          ),
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
                if (useFrozenBody)
                  _buildExternalReorderFrozenGroupBody(
                    groupId: groupId,
                    blockIndexes: blockIndexes,
                  )
                else ...[
                  _buildExpandedGroupInnerReorderList(
                    groupId: groupId,
                    blockIndexes: blockIndexes,
                  ),

                  _buildGroupAddBlocksHandle(groupId),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    final canAddBelowFromGroup = _canUseAddBelowGestureForGroup(groupId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildSwipeableGroup(
        groupId: groupId,
        swipeEnabled: isCollapsed,
        enableAddBelow: canAddBelowFromGroup,
        onAddBelow: canAddBelowFromGroup
            ? () {
                return _openAddContentMenuFromBlock(blockIndexes.last);
              }
            : null,
        child: groupContent,
      ),
    );
  }

  Widget _buildToolBlock(
    NoteBlock block,
    int index, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
  }) {
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
        disableSwipe: isInternalGroupReorder,
        enableAddBelow: _canUseAddBelowGesture(index),
        onAddBelow: _canUseAddBelowGesture(index)
            ? () {
                return _openAddContentMenuFromBlock(index);
              }
            : null,
        borderRadius: 16,
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                left: _blockDragHandleWidth,
                child: Container(
                  decoration: _blockDecoration(block, borderRadius: 16),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: index,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
                  iconAlpha: 0.34,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.34),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.18),
                              blurRadius: 18,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: accentColor.withValues(alpha: 0.96),
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.34),
                        size: 22,
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

  Widget _buildRibbonTextItem({
    required NoteBlock block,
    required int blockIndex,
    required int itemIndex,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double expandedWidth,
    required double collapsedWidth,
  }) {
    final itemKey = _ribbonItemKey(block.id, itemIndex);
    final isHorizontalExpanded = _expandedRibbonItemIds.contains(itemKey);
    final isVerticalExpanded = _expandedRibbonVerticalItemIds.contains(itemKey);
    final itemWidth = isHorizontalExpanded ? expandedWidth : collapsedWidth;
    final itemHeight = isVerticalExpanded
        ? _textBlockExpandedMaxHeight
        : _textBlockCollapsedHeight;
    final baseStyle = _textStyleForBlock(block);
    final textAlign = _textAlignForBlock(block);
    final contentPadding = EdgeInsets.fromLTRB(
      8,
      8,
      isHorizontalExpanded ? 28 : 24,
      8,
    );
    final placeholderText = 'Texto ${itemIndex + 1}…';
    final placeholderStyle = baseStyle.copyWith(
      color: Colors.white.withValues(alpha: 0.25),
      decoration: TextDecoration.none,
    );

    final placeholderAlignment = switch (textAlign) {
      TextAlign.center => Alignment.topCenter,
      TextAlign.right => Alignment.topRight,
      TextAlign.end => Alignment.topRight,
      _ => Alignment.topLeft,
    };

    Widget buildPlaceholder() {
      return IgnorePointer(
        child: Padding(
          padding: contentPadding,
          child: Align(
            alignment: placeholderAlignment,
            child: Text(
              placeholderText,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              textAlign: textAlign,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: true,
                applyHeightToLastDescent: true,
              ),
              style: placeholderStyle,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: itemWidth,
        height: itemHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: isHorizontalExpanded ? 0.15 : 0.085,
            ),
            width: isHorizontalExpanded ? 0.9 : 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (value.text.isNotEmpty) {
                    return const SizedBox.shrink();
                  }

                  return buildPlaceholder();
                },
              ),
            ),
            Positioned.fill(
              child: TextField(
                key: ValueKey<String>('ribbon-text-field-$itemKey'),
                controller: controller,
                focusNode: focusNode,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                scrollPhysics: isVerticalExpanded
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: baseStyle,
                textAlign: textAlign,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: contentPadding,
                ),
                onTap: () {
                  _rememberEditorTextFocus(focusNode);

                  setState(() {
                    _editingLinkedBlockId = null;
                    _activeBlockIndex = blockIndex;
                  });
                },
                onChanged: (value) {
                  _handleRibbonTextChanged(
                    blockIndex: blockIndex,
                    itemIndex: itemIndex,
                    value: value,
                  );
                },
              ),
            ),
            Positioned(
              right: 0,
              top: 3,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _toggleRibbonItemExpanded(block.id, itemIndex);
                },
                child: Container(
                  width: 30,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Colors.white.withValues(alpha: 0.055),
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Icon(
                    isHorizontalExpanded
                        ? Icons.keyboard_arrow_left_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: Colors.white.withValues(alpha: 0.80),
                    size: 26,
                  ),
                ),
              ),
            ),
            if (isHorizontalExpanded)
              Positioned(
                right: 0,
                bottom: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _toggleRibbonItemVerticalExpanded(block.id, itemIndex);
                  },
                  child: Container(
                    width: 30,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.055),
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Icon(
                      isVerticalExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.80),
                      size: 26,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonBlock(
    NoteBlock block,
    int index, {
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
    bool isLastInternalGroupBlock = false,
  }) {
    _ensureRibbonEditorsForBlock(block);

    final controllers = _ribbonTextControllers[block.id];
    final focusNodes = _ribbonTextFocusNodes[block.id];

    if (controllers == null || focusNodes == null) {
      return const SizedBox.shrink();
    }

    final hasExpandedVerticalItem =
        List<int>.generate(_ribbonSlotCount, (itemIndex) => itemIndex).any((
          itemIndex,
        ) {
          return _expandedRibbonVerticalItemIds.contains(
            _ribbonItemKey(block.id, itemIndex),
          );
        });

    final expandedHorizontalItemIndex =
        List<int>.generate(_ribbonSlotCount, (itemIndex) => itemIndex).where((
          itemIndex,
        ) {
          return _expandedRibbonItemIds.contains(
            _ribbonItemKey(block.id, itemIndex),
          );
        }).firstOrNull;

    final hasExpandedHorizontalItem =
        List<int>.generate(_ribbonSlotCount, (itemIndex) => itemIndex).any((
          itemIndex,
        ) {
          return _expandedRibbonItemIds.contains(
            _ribbonItemKey(block.id, itemIndex),
          );
        });

    final ribbonHeight = hasExpandedVerticalItem
        ? _textBlockExpandedMaxHeight
        : _textBlockCollapsedHeight;

    final bottomGap = isInternalGroupReorder && isLastInternalGroupBlock
        ? 0.0
        : 8.0;

    return Padding(
      key: ValueKey(block.id),
      padding: EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: bottomGap,
      ),
      child: _buildSwipeableBlock(
        block: block,
        index: index,
        disableSwipe: isInternalGroupReorder,
        enableAddBelow: _canUseAddBelowGesture(index),
        onAddBelow: _canUseAddBelowGesture(index)
            ? () {
                return _openAddContentMenuFromBlock(index);
              }
            : null,
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                left: _textBlockDragHandleWidth,
                child: Container(
                  decoration: _blockDecoration(block),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _textBlockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: index,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
                  width: _textBlockDragHandleWidth,
                  iconAlpha: 0.30,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _textBlockDragHandleWidth),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: ribbonHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final collapsedWidth = constraints.maxWidth / 2;

                        final expandedWidth = constraints.maxWidth;

                        if (expandedHorizontalItemIndex != null) {
                          return _buildRibbonTextItem(
                            block: block,
                            blockIndex: index,
                            itemIndex: expandedHorizontalItemIndex,
                            controller:
                                controllers[expandedHorizontalItemIndex],
                            focusNode: focusNodes[expandedHorizontalItemIndex],
                            expandedWidth: expandedWidth,
                            collapsedWidth: collapsedWidth,
                          );
                        }

                        return PageView.builder(
                          controller: _ribbonPageControllerFor(block.id),
                          physics: hasExpandedHorizontalItem
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          pageSnapping: true,
                          padEnds: false,
                          clipBehavior: Clip.hardEdge,
                          itemCount: _ribbonSlotCount,
                          itemBuilder: (context, itemIndex) {
                            return OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: 0,
                              maxWidth: expandedWidth,
                              child: _buildRibbonTextItem(
                                block: block,
                                blockIndex: index,
                                itemIndex: itemIndex,
                                controller: controllers[itemIndex],
                                focusNode: focusNodes[itemIndex],
                                expandedWidth: expandedWidth,
                                collapsedWidth: collapsedWidth,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBlock(
    NoteBlock block,
    int index, {
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
  }) {
    final filePath = block.imagePath;

    final fileName = block.text.trim().isEmpty
        ? (filePath == null ? 'Archivo adjunto' : p.basename(filePath))
        : block.text.trim();

    final extension = p.extension(fileName).replaceFirst('.', '').toUpperCase();

    final sizeLabel = filePath == null
        ? 'Archivo'
        : _formatStoredFileSize(filePath);

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
        disableSwipe: isInternalGroupReorder,
        enableAddBelow: _canUseAddBelowGesture(index),
        onAddBelow: _canUseAddBelowGesture(index)
            ? () {
                return _openAddContentMenuFromBlock(index);
              }
            : null,
        borderRadius: 16,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                left: _blockDragHandleWidth,
                child: Container(
                  decoration: _blockDecoration(block, borderRadius: 16),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: index,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
                  iconAlpha: 0.34,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: filePath == null
                        ? null
                        : () {
                            unawaited(_openStoredFile(filePath));
                          },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Icon(
                              _iconForStoredFile(fileName),
                              color: Colors.white.withValues(alpha: 0.90),
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (extension.isNotEmpty) extension,
                                    sizeLabel,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.48),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white.withValues(alpha: 0.42),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageBlock(
    NoteBlock block,
    int index, {
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
  }) {
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
        disableSwipe: isInternalGroupReorder,
        enableAddBelow: _canUseAddBelowGesture(index),
        onAddBelow: _canUseAddBelowGesture(index)
            ? () {
                return _openAddContentMenuFromBlock(index);
              }
            : null,
        borderRadius: 16,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                left: _blockDragHandleWidth,
                child: Container(
                  decoration: _blockDecoration(block, borderRadius: 16),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: index,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
                  iconAlpha: 0.34,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _blockDragHandleWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                              minHeight: 64,
                              maxHeight: 150,
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
                      const SizedBox(height: 4),
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

  bool _canUseAddBelowGesture(int index) {
    if (index < 0 || index >= _blocks.length) {
      return false;
    }

    final groupId = _validGroupId(_blocks[index].groupId);

    if (groupId != null) {
      return false;
    }

    return index == _blocks.length - 1;
  }

  bool _canUseAddBelowGestureForGroup(String groupId) {
    final range = _groupRangeInBlocks(_blocks, groupId);

    if (range == null) {
      return false;
    }

    return range.end == _blocks.length - 1;
  }

  Future<void> _openAddContentMenuFromBlock(int index) async {
    if (!mounted || index < 0 || index >= _blocks.length) {
      return;
    }

    final groupId = _validGroupId(_blocks[index].groupId);

    final anchorIndex = groupId == null
        ? index
        : _groupRangeForIndex(index).end;

    await _showAddBlockMenu(anchorIndex);
  }

  Future<void> _showAddBlockMenu(int afterIndex) async {
    if (!mounted || afterIndex < 0 || afterIndex >= _blocks.length) {
      return;
    }

    final anchorBlockId = _blocks[afterIndex].id;

    const addContentItems = <_AddContentMenuItem>[
      _AddContentMenuItem(
        id: 'text1',
        icon: Icons.notes_rounded,
        title: 'Texto',
        subtitle: '1 bloque',
      ),
      _AddContentMenuItem(
        id: 'text2',
        icon: Icons.library_add_rounded,
        title: 'Texto x2',
        subtitle: '2 bloques',
      ),
      _AddContentMenuItem(
        id: 'text3',
        icon: Icons.playlist_add_rounded,
        title: 'Texto x3',
        subtitle: '3 bloques',
      ),
      _AddContentMenuItem(
        id: 'ribbon',
        icon: Icons.view_carousel_rounded,
        title: 'Cinta',
        subtitle: 'Hasta 5 textos',
      ),
      _AddContentMenuItem(
        id: 'tracker',
        icon: Icons.track_changes_rounded,
        title: 'Tracker',
        subtitle: 'Hábitos o progreso',
      ),
      _AddContentMenuItem(
        id: 'database',
        icon: Icons.table_chart_outlined,
        title: 'Base de datos',
        subtitle: 'Tabla de datos',
      ),
      _AddContentMenuItem(
        id: 'image',
        icon: Icons.image_outlined,
        title: 'Imagen',
        subtitle: 'Foto o imagen',
      ),
      _AddContentMenuItem(
        id: 'file',
        icon: Icons.attach_file_rounded,
        title: 'Archivo',
        subtitle: 'PDF, Word, Excel',
      ),
      _AddContentMenuItem(
        id: 'divider',
        icon: Icons.horizontal_rule_rounded,
        title: 'Separador',
        subtitle: 'Línea divisoria',
      ),
    ];

    FocusScope.of(context).unfocus();

    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);

        final safeBottom =
            mediaQuery.viewPadding.bottom > mediaQuery.padding.bottom
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;

        final bottomGap = safeBottom > 0 ? safeBottom + 12.0 : 28.0;
        final maxHeight = mediaQuery.size.height * 0.72;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                    itemCount: addContentItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.03,
                        ),
                    itemBuilder: (context, itemIndex) {
                      final item = addContentItems[itemIndex];

                      return Material(
                        color: const Color(0xFF2B2D34),
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(sheetContext).pop(item.id);
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
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.46),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
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
          ),
        );
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    final resolvedAfterIndex = _blocks.indexWhere(
      (block) => block.id == anchorBlockId,
    );

    final insertionAnchor = resolvedAfterIndex == -1
        ? _blocks.length - 1
        : resolvedAfterIndex;

    if (selectedAction == 'text1') {
      _addParagraphBlocks(count: 1, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'text2') {
      _addParagraphBlocks(count: 2, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'text3') {
      _addParagraphBlocks(count: 3, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'ribbon') {
      _addBlock(NoteBlockType.ribbon, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'tracker') {
      _addBlock(NoteBlockType.tracker, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'database') {
      _addBlock(NoteBlockType.database, afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'image') {
      await _insertImageBlock(afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'file') {
      await _insertFileBlock(afterIndex: insertionAnchor);
      return;
    }

    if (selectedAction == 'divider') {
      _addBlock(NoteBlockType.divider, afterIndex: insertionAnchor);
      return;
    }
  }

  Widget _buildAddTextSectionBar(int index) {
    return SizedBox(
      width: double.infinity,
      height: 30,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.76,
          child: Material(
            color: _editorNeutralGray,
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
              color: _editorNeutralGray,
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
                    'Color y resaltado del bloque',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildColorSwatchGrid(
                    sheetContext: sheetContext,
                    colorValues: _blockColorValues,
                    selectedColorValue: _blocks[blockIndex].colorValue,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(0);
                      },
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Quitar color y resaltado'),
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
          ? currentBlock.copyWith(
              clearColorValue: true,
              clearHighlightColorValue: true,
            )
          : currentBlock.copyWith(
              colorValue: selectedColor,
              highlightColorValue: selectedColor,
            );
    });

    _saveNote();
    HapticFeedback.selectionClick();
  }

  Widget _buildColorSwatchGrid({
    required BuildContext sheetContext,
    required List<int> colorValues,
    int? selectedColorValue,
  }) {
    const columns = 6;
    const gap = 10.0;

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final swatchSize =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final colorValue in colorValues)
                InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop(colorValue);
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: swatchSize,
                    height: swatchSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(colorValue),
                      border: Border.all(
                        color: selectedColorValue == colorValue
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.24),
                        width: selectedColorValue == colorValue ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showGroupColorPicker(String groupId) async {
    if (!mounted) {
      return;
    }

    final selectedColor = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.58,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: _editorNeutralGray,
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
                    'Color del grupo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 14),
                  _buildColorSwatchGrid(
                    sheetContext: sheetContext,
                    colorValues: _blockColorValues,
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(0);
                      },
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Volver a gris'),
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

    setState(() {
      for (var i = 0; i < _blocks.length; i++) {
        if (_validGroupId(_blocks[i].groupId) != groupId) {
          continue;
        }

        _blocks[i] = selectedColor == 0
            ? _blocks[i].copyWith(clearGroupColorValue: true)
            : _blocks[i].copyWith(groupColorValue: selectedColor);
      }
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
    final hasHighlight = _blocks[blockIndex].highlightColorValue != null;
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
        final mediaQuery = MediaQuery.of(sheetContext);

        final safeBottom =
            mediaQuery.viewPadding.bottom > mediaQuery.padding.bottom
            ? mediaQuery.viewPadding.bottom
            : mediaQuery.padding.bottom;

        final bottomGap = safeBottom > 0 ? safeBottom + 12.0 : 28.0;

        Widget styleOption(NoteBlockStyle style) {
          final isActive = style == NoteBlockStyle.callout
              ? hasHighlight || currentStyle == style
              : currentStyle == style;

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
              Navigator.of(sheetContext).pop(
                style == NoteBlockStyle.callout ? 'highlightColor' : style.name,
              );
            },
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomGap),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.82,
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              decoration: BoxDecoration(
                color: _editorNeutralGray,
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

                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _groupBorderColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isGrouped
                              ? Icons.folder_off_outlined
                              : Icons.create_new_folder_outlined,
                          color: _groupDefaultTextColor,
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
                            : 'Crear un contenedor gris para este bloque',
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
                            color: _groupBorderColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.vertical_align_top_rounded,
                            color: _groupDefaultTextColor,
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
                            color: _groupBorderColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.vertical_align_bottom_rounded,
                            color: _groupDefaultTextColor,
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
                        'Agregar color y resaltado',
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
          ), // ConstrainedBox
        ); // Padding
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
    bool enableAddBelow = false,
    Future<void> Function()? onAddBelow,
    Color? cornerFillOverride,
    bool disableSwipe = false,
  }) {
    final cornerFill = cornerFillOverride ?? _blockBackgroundColor(block);

    final groupId = _validGroupId(block.groupId);

    final keepSwipeForExpandedGroupedBlock =
        disableSwipe && groupId != null && !_isGroupCollapsed(groupId);

    if (disableSwipe && !keepSwipeForExpandedGroupedBlock) {
      return child;
    }

    return _SwipeActionBlock(
      key: ValueKey<String>('swipe-${block.id}'),
      gestureDeadZoneWidth: _blockDragHandleWidth + 10,
      enableEdit: enableEdit,
      enableAddBelow: false,
      onAddBelow: null,
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

  Widget _buildWordListBlock(
    NoteBlock block,
    int blockIndex, {
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
  }) {
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
        disableSwipe: isInternalGroupReorder,
        enableAddBelow: _canUseAddBelowGesture(blockIndex),
        onAddBelow: _canUseAddBelowGesture(blockIndex)
            ? () {
                return _openAddContentMenuFromBlock(blockIndex);
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
          child: Stack(
            children: [
              Positioned.fill(
                left: _blockDragHandleWidth,
                child: Container(
                  decoration: _blockDecoration(block),
                  clipBehavior: Clip.antiAlias,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _blockDragHandleWidth,
                child: _buildReorderableBlockDragHandle(
                  index: blockIndex,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
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
                                _rememberEditorTextFocus(focusNodes[itemIndex]);
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

  Widget _buildBlock(
    NoteBlock block,
    int index, {
    int? reorderIndexOverride,
    bool isInternalGroupReorder = false,
    bool isLastInternalGroupBlock = false,
  }) {
    if (block.type == NoteBlockType.image) {
      return _buildImageBlock(
        block,
        index,
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
      );
    }

    if (block.type == NoteBlockType.file) {
      return _buildFileBlock(
        block,
        index,
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
      );
    }

    if (block.type == NoteBlockType.ribbon) {
      return _buildRibbonBlock(
        block,
        index,
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
        isLastInternalGroupBlock: isLastInternalGroupBlock,
      );
    }

    if (block.type == NoteBlockType.tracker) {
      return _buildToolBlock(
        block,
        index,
        title: 'Tracker',
        subtitle: 'Bloque para hábitos, progreso, estados o métricas.',
        icon: Icons.track_changes_rounded,
        accentColor: const Color(0xFF67D5B5),
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
      );
    }

    if (block.type == NoteBlockType.database) {
      return _buildToolBlock(
        block,
        index,
        title: 'Base de datos',
        subtitle: 'Bloque para tablas, columnas, filas y datos estructurados.',
        icon: Icons.table_chart_outlined,
        accentColor: const Color(0xFF7EA7FF),
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
      );
    }

    if (block.type == NoteBlockType.divider) {
      final bottomGap = isInternalGroupReorder && isLastInternalGroupBlock
          ? 0.0
          : 8.0;
      return Padding(
        key: ValueKey(block.id),
        padding: EdgeInsets.only(
          left: _editorContentLeft,
          right: _editorContentRight,
          bottom: bottomGap,
        ),
        child: _buildSwipeableBlock(
          block: block,
          index: index,
          disableSwipe: isInternalGroupReorder,
          enableEdit: false,
          enableAddBelow: _canUseAddBelowGesture(index),
          onAddBelow: _canUseAddBelowGesture(index)
              ? () {
                  return _openAddContentMenuFromBlock(index);
                }
              : null,
          cornerFillOverride: Colors.transparent,
          borderRadius: 10,
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                _buildReorderableBlockDragHandle(
                  index: index,
                  reorderIndexOverride: reorderIndexOverride,
                  isInternalGroupReorder: isInternalGroupReorder,
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
      return _buildWordListBlock(
        block,
        index,
        reorderIndexOverride: reorderIndexOverride,
        isInternalGroupReorder: isInternalGroupReorder,
      );
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

    final isTextBlockExpanded = _expandedTextBlockIds.contains(block.id);

    final bottomGap = isInternalGroupReorder && isLastInternalGroupBlock
        ? 0.0
        : 8.0;

    return Padding(
      key: ValueKey(block.id),
      padding: EdgeInsets.only(
        left: _editorContentLeft,
        right: _editorContentRight,
        bottom: bottomGap,
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwipeableBlock(
            block: block,
            index: index,
            disableSwipe: isInternalGroupReorder,
            enableAddBelow: _canUseAddBelowGesture(index),
            onAddBelow: _canUseAddBelowGesture(index)
                ? () {
                    return _openAddContentMenuFromBlock(index);
                  }
                : null,
            cornerFillOverride: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Stack(
                children: [
                  Positioned.fill(
                    left: _textBlockDragHandleWidth,
                    child: Container(
                      decoration: _textBlockBodyDecoration(block),
                      clipBehavior: Clip.antiAlias,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _textBlockDragHandleWidth,
                    child: _buildReorderableBlockDragHandle(
                      index: index,
                      reorderIndexOverride: reorderIndexOverride,
                      isInternalGroupReorder: isInternalGroupReorder,
                      width: _textBlockDragHandleWidth,
                      reorderEnabled: !isTextBlockExpanded,
                      iconAlpha: isTextBlockExpanded ? 0.16 : 0.30,
                      backgroundColor: _editorBlockGray,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: _textBlockDragHandleWidth,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (prefix != null) ...[
                            prefix,
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: _buildBlockTextEditorWithLinks(
                              block: block,
                              index: index,
                              isExpanded: isTextBlockExpanded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    bottom: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _toggleTextBlockExpanded(block.id);
                      },
                      child: Container(
                        width: 30,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withValues(alpha: 0.055),
                              width: 0.7,
                            ),
                          ),
                        ),
                        child: Icon(
                          isTextBlockExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.80),
                          size: 26,
                        ),
                      ),
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
        block.type != NoteBlockType.divider &&
        block.type != NoteBlockType.tracker &&
        block.type != NoteBlockType.database &&
        block.type != NoteBlockType.ribbon;
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
      case NoteBlockType.file:
        return 'Archivo';
      case NoteBlockType.divider:
        return 'Separador';

      case NoteBlockType.tracker:
        return 'Tracker';
      case NoteBlockType.database:
        return 'Base de datos';
      case NoteBlockType.ribbon:
        return 'Cinta';
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
                    color: _editorNeutralGray,
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
                          fillColor: _editorNeutralGray,
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
        color: _editorNeutralGray,
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
                  _buildToolbarIconButton(
                    icon: Icons.link_rounded,
                    tooltip: 'Agregar hipervínculo',
                    onPressed: textEnabled
                        ? () {
                            unawaited(_showHyperlinkPicker());
                          }
                        : null,
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
          color: _editorNeutralGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
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
            _rememberEditorTextFocus(_titleFocusNode);

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

  double _currentEditorKeyboardInset() {
    final views = WidgetsBinding.instance.platformDispatcher.views;

    if (views.isEmpty) {
      return 0;
    }

    return views.first.viewInsets.bottom.toDouble();
  }

  void _syncEditorKeyboardBackStateFromInsets() {
    final currentInset = _currentEditorKeyboardInset();

    if (_lastEditorKeyboardInset > 0 &&
        currentInset < _lastEditorKeyboardInset) {
      _keyboardBackDismissRequested = true;
      _scheduleEditorBackSequenceReset();
    }

    _lastEditorKeyboardInset = currentInset;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncEditorKeyboardBackStateFromInsets();
  }

  bool _hasEditorTextFocus(FocusNode? primaryFocus) {
    if (primaryFocus == null) {
      return false;
    }

    if (primaryFocus == _titleFocusNode ||
        _blockFocusNodes.containsValue(primaryFocus) ||
        _groupTitleFocusNodes.containsValue(primaryFocus)) {
      return true;
    }

    if (_listLineFocusNodes.values.any(
      (focusNodes) => focusNodes.contains(primaryFocus),
    )) {
      return true;
    }

    return _ribbonTextFocusNodes.values.any(
      (focusNodes) => focusNodes.contains(primaryFocus),
    );
  }

  void _resetEditorBackSequence() {
    _editorBackSequenceResetTimer?.cancel();
    _editorBackSequenceResetTimer = null;
    _keyboardBackDismissRequested = false;
    _textFocusBackDismissRequested = false;
  }

  void _scheduleEditorBackSequenceReset() {
    _editorBackSequenceResetTimer?.cancel();
    _editorBackSequenceResetTimer = Timer(
      const Duration(milliseconds: 1600),
      () {
        if (!mounted) return;

        _keyboardBackDismissRequested = false;
      },
    );
  }

  void _rememberEditorTextFocus(FocusNode? focusNode) {
    _lastEditorTextFocusNode = focusNode;

    if (!_isEditorBackExitInProgress) {
      _resetEditorBackSequence();
    }
  }

  FocusNode? _focusNodeForEditorBack(FocusNode? primaryFocus) {
    if (_hasEditorTextFocus(primaryFocus)) {
      return primaryFocus;
    }

    final lastFocus = _lastEditorTextFocusNode;

    if (lastFocus != null && lastFocus.canRequestFocus) {
      return lastFocus;
    }

    return null;
  }

  void _clearEditorTextFocus(FocusNode? focusNode) {
    final focusToClear =
        focusNode ??
        _lastEditorTextFocusNode ??
        FocusManager.instance.primaryFocus;

    _lastEditorTextFocusNode = null;

    void clearFocus(FocusNode? node) {
      node?.consumeKeyboardToken();
      node?.unfocus(disposition: UnfocusDisposition.scope);
    }

    void clearLatestFocus() {
      if (!mounted || _isEditorBackExitInProgress) return;

      final latestFocus = FocusManager.instance.primaryFocus;

      if (latestFocus != null && _hasEditorTextFocus(latestFocus)) {
        clearFocus(latestFocus);
      }

      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    }

    clearFocus(focusToClear);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      clearLatestFocus();
    });

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 40), clearLatestFocus),
    );

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 90), clearLatestFocus),
    );
  }

  Future<bool> _handleEditorBackPressed() {
    if (_isEditorBackExitInProgress) {
      return SynchronousFuture<bool>(false);
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    _syncEditorKeyboardBackStateFromInsets();
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final focusToClear = _focusNodeForEditorBack(primaryFocus);

    if (isKeyboardVisible && !_keyboardBackDismissRequested) {
      _keyboardBackDismissRequested = true;
      _lastEditorTextFocusNode = focusToClear ?? _lastEditorTextFocusNode;
      focusToClear?.consumeKeyboardToken();
      _scheduleEditorBackSequenceReset();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
      return SynchronousFuture<bool>(false);
    }

    if (!_textFocusBackDismissRequested &&
        (_keyboardBackDismissRequested || focusToClear != null)) {
      _textFocusBackDismissRequested = true;
      _scheduleEditorBackSequenceReset();
      _clearEditorTextFocus(focusToClear);
      return SynchronousFuture<bool>(false);
    }

    _resetEditorBackSequence();
    _isEditorBackExitInProgress = true;
    return SynchronousFuture<bool>(true);
  }

  void _exitEditor() {
    if (!mounted || _isEditorBackExitInProgress) return;

    _resetEditorBackSequence();
    _isEditorBackExitInProgress = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final renderEntries = _buildRenderEntries();
    _reorderIndexByBlockIndex = _buildReorderIndexMap(renderEntries);

    return WillPopScope(
      onWillPop: _handleEditorBackPressed,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          toolbarHeight: 32,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leadingWidth: 36,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: () {
              _exitEditor();
            },
            constraints: const BoxConstraints.tightFor(width: 40, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),

          actions: [
            IconButton(
              tooltip: 'Más opciones',
              onPressed: () {},
              constraints: const BoxConstraints.tightFor(width: 36, height: 32),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz_rounded, size: 21),
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
                physics: _isGroupAddDragInProgress
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                buildDefaultDragHandles: false,
                dragStartBehavior: DragStartBehavior.down,
                cacheExtent: _isExternalBlockReorderActive ? 180 : 120,
                autoScrollerVelocityScalar: _isExternalBlockReorderActive
                    ? 7
                    : 6,
                itemCount: renderEntries.length,
                proxyDecorator: _reorderProxyDecorator,
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

                  _syncAllVisibleEditorsIntoBlocks();

                  if (_draggingGroupId != null) {
                    return;
                  }

                  final entry = renderEntries[index];

                  if (entry.isGroup) {
                    final groupId = entry.groupId!;

                    if (!_isGroupCollapsed(groupId)) {
                      return;
                    }

                    setState(() {
                      _draggingGroupId = groupId;
                      _draggingBlockId = null;

                      _dragPreviewGroupId = null;
                      _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
                      _blockedEdgePreviewGroupId = null;
                      _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
                    });

                    return;
                  }

                  final draggedBlockIndex = entry.firstBlockIndex;

                  if (draggedBlockIndex < 0 ||
                      draggedBlockIndex >= _blocks.length) {
                    return;
                  }

                  final draggedBlockId = _blocks[draggedBlockIndex].id;

                  _captureExternalReorderGroupHeights();

                  setState(() {
                    _isExternalBlockReorderActive = true;
                    _externalDraggingBlockId = draggedBlockId;
                    _draggingGroupId = null;
                    _draggingBlockId = null;
                    _dragPreviewGroupId = null;
                    _lastDragGlobalPosition = null;
                    _dragEdgeDropSlot = _GroupEdgeDropSlot.none;
                    _blockedEdgePreviewGroupId = null;
                    _blockedEdgePreviewSlot = _GroupEdgeDropSlot.none;
                  });

                  HapticFeedback.selectionClick();
                },
                onReorderEnd: (index) {
                  if (!mounted) {
                    return;
                  }

                  _finishReorderInteraction();
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
                      key: ValueKey<String>('reorder-group-$groupId'),
                      child: KeyedSubtree(
                        key: groupViewportKey,
                        child: _buildGroupedEntry(
                          groupId: groupId,
                          blockIndexes: entry.blockIndexes,
                          entryIndex: index,
                        ),
                      ),
                    );
                  }

                  final blockIndex = entry.firstBlockIndex;
                  final block = _blocks[blockIndex];
                  final viewportKey = _blockViewportKeys.putIfAbsent(
                    block.id,
                    GlobalKey.new,
                  );

                  if (_isExternalBlockReorderActive) {
                    final frozenHeight =
                        (_externalReorderBlockHeights[block.id] ?? 86)
                            .clamp(42.0, 10000.0)
                            .toDouble();

                    final reorderPreviewChild =
                        _usesExternalTextReorderPreview(block)
                        ? _buildExternalReorderFrozenBlockEntry(
                            block: block,
                            height: frozenHeight,
                          )
                        : SizedBox(
                            height: frozenHeight,
                            child: IgnorePointer(
                              child: TickerMode(
                                enabled: false,
                                child: _buildBlock(
                                  block,
                                  blockIndex,
                                  reorderIndexOverride: index,
                                ),
                              ),
                            ),
                          );

                    return KeyedSubtree(
                      key: ValueKey<String>('reorder-block-${block.id}'),
                      child: KeyedSubtree(
                        key: viewportKey,
                        child: reorderPreviewChild,
                      ),
                    );
                  }

                  final builtBlock = _buildBlock(
                    block,
                    blockIndex,
                    reorderIndexOverride: index,
                  );

                  return KeyedSubtree(
                    key: ValueKey<String>('reorder-block-${block.id}'),
                    child: KeyedSubtree(
                      key: viewportKey,
                      child: _isGroupedBlock(block)
                          ? _buildGroupedBlockFrame(
                              block: block,
                              index: blockIndex,
                              child: builtBlock,
                            )
                          : builtBlock,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBlockBackgroundPainter extends CustomPainter {
  const _GroupBlockBackgroundPainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.leftInset,
    required this.rightInset,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;
  final double leftInset;
  final double rightInset;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;

    final rect = Rect.fromLTWH(
      leftInset,
      0,
      size.width - leftInset - rightInset,
      size.height,
    );

    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final safeRadius = radius.clamp(0, rect.height / 2).toDouble();

    if (isFirst && isLast) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(safeRadius)),
        paint,
      );
      return;
    }

    final path = Path();

    if (isFirst) {
      path
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + safeRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + safeRadius,
          rect.top,
        )
        ..lineTo(rect.right - safeRadius, rect.top)
        ..quadraticBezierTo(
          rect.right,
          rect.top,
          rect.right,
          rect.top + safeRadius,
        )
        ..lineTo(rect.right, rect.bottom)
        ..close();
    } else if (isLast) {
      path
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.left, rect.bottom - safeRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.bottom,
          rect.left + safeRadius,
          rect.bottom,
        )
        ..lineTo(rect.right - safeRadius, rect.bottom)
        ..quadraticBezierTo(
          rect.right,
          rect.bottom,
          rect.right,
          rect.bottom - safeRadius,
        )
        ..lineTo(rect.right, rect.top)
        ..close();
    } else {
      path.addRect(rect);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GroupBlockBackgroundPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.leftInset != leftInset ||
        oldDelegate.rightInset != rightInset;
  }
}

class _GroupBlockFramePainter extends CustomPainter {
  const _GroupBlockFramePainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.leftInset,
    required this.rightInset,
    this.hideBottomEdge = false,
    this.bottomOpenInset = 0,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;
  final double leftInset;
  final double rightInset;
  final bool hideBottomEdge;
  final double bottomOpenInset;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;
    const strokeWidth = 0.9;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final halfStroke = strokeWidth / 2;

    final rect = Rect.fromLTWH(
      leftInset + halfStroke,
      halfStroke,
      size.width - leftInset - strokeWidth - rightInset,
      size.height - strokeWidth,
    );

    final openBottom = (rect.bottom - bottomOpenInset)
        .clamp(rect.top, rect.bottom)
        .toDouble();

    if (isFirst && isLast) {
      if (hideBottomEdge) {
        final path = Path()
          ..moveTo(rect.left, openBottom)
          ..lineTo(rect.left, rect.top + radius)
          ..quadraticBezierTo(rect.left, rect.top, rect.left + radius, rect.top)
          ..lineTo(rect.right - radius, rect.top)
          ..quadraticBezierTo(
            rect.right,
            rect.top,
            rect.right,
            rect.top + radius,
          )
          ..lineTo(rect.right, openBottom);

        canvas.drawPath(path, paint);
        return;
      }

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
      if (hideBottomEdge) {
        path
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.left, openBottom)
          ..moveTo(rect.right, rect.top)
          ..lineTo(rect.right, openBottom);
      } else {
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
      }
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
        oldDelegate.isLast != isLast ||
        oldDelegate.leftInset != leftInset ||
        oldDelegate.rightInset != rightInset ||
        oldDelegate.hideBottomEdge != hideBottomEdge ||
        oldDelegate.bottomOpenInset != bottomOpenInset;
  }
}

class _GroupAddExtensionPainter extends CustomPainter {
  const _GroupAddExtensionPainter({
    required this.color,
    required this.originalHeight,
    required this.leftInset,
    required this.rightInset,
    this.fillColor,
    this.fillStartHeight,
  });

  final Color color;
  final Color? fillColor;
  final double originalHeight;
  final double leftInset;
  final double rightInset;
  final double? fillStartHeight;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 18.0;
    const strokeWidth = 0.9;
    const seamOverlap = 2.4;

    final halfStroke = strokeWidth / 2;

    final fillLeft = leftInset;
    final fillRight = size.width - rightInset;

    final fillTop = (fillStartHeight ?? originalHeight)
        .clamp(0.0, size.height)
        .toDouble();

    final fillBottom = size.height;

    if (fillColor != null && fillBottom > fillTop + 4) {
      final fillRadius = radius
          .clamp(0.0, (fillBottom - fillTop) / 2)
          .toDouble();

      final fillPath = Path()
        ..moveTo(fillLeft, fillTop)
        ..lineTo(fillLeft, fillBottom - fillRadius)
        ..quadraticBezierTo(
          fillLeft,
          fillBottom,
          fillLeft + fillRadius,
          fillBottom,
        )
        ..lineTo(fillRight - fillRadius, fillBottom)
        ..quadraticBezierTo(
          fillRight,
          fillBottom,
          fillRight,
          fillBottom - fillRadius,
        )
        ..lineTo(fillRight, fillTop)
        ..close();

      final fillPaint = Paint()
        ..color = fillColor!
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    final strokeLeft = leftInset + halfStroke;
    final strokeRight = size.width - rightInset - halfStroke;
    final strokeTop = (originalHeight - seamOverlap - halfStroke)
        .clamp(0.0, size.height)
        .toDouble();
    final strokeBottom = size.height - halfStroke;

    if (strokeBottom <= strokeTop + 4) {
      return;
    }

    final strokeRadius = radius
        .clamp(0.0, (strokeBottom - strokeTop) / 2)
        .toDouble();

    final strokePath = Path()
      ..moveTo(strokeLeft, strokeTop)
      ..lineTo(strokeLeft, strokeBottom - strokeRadius)
      ..quadraticBezierTo(
        strokeLeft,
        strokeBottom,
        strokeLeft + strokeRadius,
        strokeBottom,
      )
      ..lineTo(strokeRight - strokeRadius, strokeBottom)
      ..quadraticBezierTo(
        strokeRight,
        strokeBottom,
        strokeRight,
        strokeBottom - strokeRadius,
      )
      ..lineTo(strokeRight, strokeTop);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GroupAddExtensionPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.originalHeight != originalHeight ||
        oldDelegate.fillStartHeight != fillStartHeight ||
        oldDelegate.leftInset != leftInset ||
        oldDelegate.rightInset != rightInset;
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
    this.swipeEnabled = true,
    this.enableAddBelow = false,
    this.onAddBelow,
    this.addIndicatorRightInset = 0,
    this.gestureDeadZoneWidth = 0,
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
  final bool swipeEnabled;
  final bool enableAddBelow;
  final Future<void> Function()? onAddBelow;
  final double addIndicatorRightInset;
  final double gestureDeadZoneWidth;

  @override
  State<_SwipeActionBlock> createState() => _SwipeActionBlockState();
}

class _SwipeActionBlockState extends State<_SwipeActionBlock>
    with SingleTickerProviderStateMixin {
  static const double _deleteThreshold = 0.42;
  static const double _editThreshold = 0.34;
  static const double _velocityThreshold = 900;
  static const double _addBelowThreshold = 20;
  static const double _addBelowMaximumOffset = 42;
  static const double _addBelowVelocityThreshold = 420;

  late final AnimationController _animationController;

  Animation<double>? _offsetAnimation;
  Animation<double>? _verticalOffsetAnimation;
  double _dragOffset = 0;
  double _verticalDragOffset = 0;
  double _availableWidth = 0;
  bool _isProcessingAction = false;
  bool _ignoreCurrentSwipeGesture = false;

  bool _isInsideGestureDeadZone(Offset localPosition) {
    return widget.gestureDeadZoneWidth > 0 &&
        localPosition.dx <= widget.gestureDeadZoneWidth;
  }

  bool get _canAddBelow {
    return widget.swipeEnabled &&
        widget.enableAddBelow &&
        widget.onAddBelow != null;
  }

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          final horizontalAnimation = _offsetAnimation;
          final verticalAnimation = _verticalOffsetAnimation;

          if (!mounted ||
              (horizontalAnimation == null && verticalAnimation == null)) {
            return;
          }

          setState(() {
            if (horizontalAnimation != null) {
              _dragOffset = horizontalAnimation.value;
            }

            if (verticalAnimation != null) {
              _verticalDragOffset = verticalAnimation.value;
            }
          });
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SwipeActionBlock oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.swipeEnabled && !widget.swipeEnabled && _dragOffset != 0) {
      unawaited(_animateTo(0));
    }

    if ((!widget.swipeEnabled || !widget.enableAddBelow) &&
        _verticalDragOffset != 0) {
      unawaited(_animateVerticalTo(0));
    }
  }

  Future<void> _animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 190),
  }) async {
    _animationController
      ..stop()
      ..duration = duration;

    _verticalOffsetAnimation = null;

    _offsetAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    try {
      await _animationController.forward(from: 0).orCancel;
    } catch (_) {
      // La animación puede cancelarse si comienza otro gesto.
    }
  }

  Future<void> _animateVerticalTo(
    double target, {
    Duration duration = const Duration(milliseconds: 90),
  }) async {
    _animationController
      ..stop()
      ..duration = duration;

    _offsetAnimation = null;

    _verticalOffsetAnimation =
        Tween<double>(begin: _verticalDragOffset, end: target).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    try {
      await _animationController.forward(from: 0).orCancel;
    } catch (_) {
      // La animación puede cancelarse si comienza otro gesto.
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _ignoreCurrentSwipeGesture = _isInsideGestureDeadZone(
      details.localPosition,
    );

    if (_ignoreCurrentSwipeGesture) {
      _animationController.stop();
      _offsetAnimation = null;
      _verticalOffsetAnimation = null;
      return;
    }
    if (_isProcessingAction ||
        !widget.swipeEnabled ||
        _verticalDragOffset != 0) {
      return;
    }

    _animationController.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_ignoreCurrentSwipeGesture) {
      return;
    }
    if (_isProcessingAction ||
        _availableWidth <= 0 ||
        !widget.swipeEnabled ||
        _verticalDragOffset != 0) {
      if (_dragOffset != 0) {
        unawaited(_animateTo(0));
      }

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
    if (_ignoreCurrentSwipeGesture) {
      _ignoreCurrentSwipeGesture = false;
      return;
    }
    if (_isProcessingAction || _availableWidth <= 0 || !widget.swipeEnabled) {
      await _animateTo(0);
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
    if (_ignoreCurrentSwipeGesture) {
      _ignoreCurrentSwipeGesture = false;
      return;
    }
    if (_isProcessingAction) {
      return;
    }

    unawaited(_animateTo(0));
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _ignoreCurrentSwipeGesture = _isInsideGestureDeadZone(
      details.localPosition,
    );

    if (_ignoreCurrentSwipeGesture) {
      _animationController.stop();
      _offsetAnimation = null;
      _verticalOffsetAnimation = null;
      return;
    }
    if (_isProcessingAction || !_canAddBelow) {
      return;
    }

    _animationController.stop();

    if (_dragOffset != 0) {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_ignoreCurrentSwipeGesture) {
      return;
    }
    if (_isProcessingAction || !_canAddBelow) {
      return;
    }

    final currentProgress = (_verticalDragOffset / _addBelowThreshold)
        .clamp(0.0, 1.0)
        .toDouble();

    final isPastThreshold = _verticalDragOffset >= _addBelowThreshold;

    final magnetMultiplier = 1.05 + (currentProgress * 0.42);

    final resistanceMultiplier = isPastThreshold && details.delta.dy > 0
        ? 0.42
        : 1.0;

    final adjustedDelta =
        details.delta.dy * magnetMultiplier * resistanceMultiplier;

    final nextOffset = (_verticalDragOffset + adjustedDelta)
        .clamp(0.0, _addBelowMaximumOffset)
        .toDouble();

    if (nextOffset == _verticalDragOffset) {
      return;
    }

    setState(() {
      _verticalDragOffset = nextOffset;
    });
  }

  Future<void> _handleVerticalDragEnd(DragEndDetails details) async {
    if (_ignoreCurrentSwipeGesture) {
      _ignoreCurrentSwipeGesture = false;
      return;
    }
    if (_isProcessingAction || !_canAddBelow) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;

    final shouldOpenMenu =
        _verticalDragOffset >= _addBelowThreshold ||
        velocity >= _addBelowVelocityThreshold;

    if (!shouldOpenMenu) {
      await _animateVerticalTo(0, duration: const Duration(milliseconds: 58));
      return;
    }

    setState(() {
      _isProcessingAction = true;
    });

    HapticFeedback.selectionClick();

    await _animateVerticalTo(0, duration: const Duration(milliseconds: 54));

    if (!mounted) {
      return;
    }

    await widget.onAddBelow!();

    if (!mounted) {
      return;
    }

    setState(() {
      _verticalDragOffset = 0;
      _isProcessingAction = false;
    });
  }

  void _handleVerticalDragCancel() {
    if (_ignoreCurrentSwipeGesture) {
      _ignoreCurrentSwipeGesture = false;
      return;
    }
    if (_isProcessingAction) {
      return;
    }

    if (_verticalDragOffset == 0) {
      return;
    }

    unawaited(_animateVerticalTo(0));
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

        final addProgress = (_verticalDragOffset / _addBelowThreshold)
            .clamp(0.0, 1.0)
            .toDouble();

        final showAddBackground = _canAddBelow && _verticalDragOffset > 0.5;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,

          // Swipe horizontal: rojo / azul
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onHorizontalDragCancel: _handleDragCancel,

          // Swipe vertical hacia abajo: agregar contenido
          onVerticalDragStart: _canAddBelow ? _handleVerticalDragStart : null,
          onVerticalDragUpdate: _canAddBelow ? _handleVerticalDragUpdate : null,
          onVerticalDragEnd: _canAddBelow ? _handleVerticalDragEnd : null,
          onVerticalDragCancel: _canAddBelow ? _handleVerticalDragCancel : null,

          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (showAddBackground)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.18 + (addProgress * 0.44),
                      child: ClipRRect(
                        borderRadius: radius,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC2C2C2),
                            borderRadius: radius,
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.32),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Añadir bloque',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.1,
                              shadows: [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (!showAddBackground &&
                  (showDeleteBackground || showEditBackground))
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
                offset: Offset(_dragOffset, _verticalDragOffset),
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
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

                      if (_canAddBelow)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _AddBelowGestureIndicatorPainter(
                                borderRadius: widget.borderRadius,
                                rightInset: widget.addIndicatorRightInset,
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _AddBelowGestureIndicatorPainter extends CustomPainter {
  const _AddBelowGestureIndicatorPainter({
    required this.borderRadius,
    this.rightInset = 0,
  });

  final double borderRadius;
  final double rightInset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final radius = borderRadius.clamp(6.0, size.shortestSide / 2).toDouble();

    const inset = 1.6;

    final safeRightInset = rightInset.clamp(0.0, size.width * 0.20).toDouble();

    final left = inset;
    final right = size.width - inset - safeRightInset;
    final bottom = size.height - inset;

    if (right <= left + 12) {
      return;
    }

    final path = Path()
      ..moveTo(left, bottom - radius)
      ..quadraticBezierTo(left, bottom, left + radius, bottom)
      ..lineTo(right - radius, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - radius);

    final fadeShader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0x00FFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0x00FFFFFF),
      ],
      stops: [0.00, 0.16, 0.84, 1.00],
    ).createShader(Rect.fromLTWH(left, 0, right - left, size.height));

    final outerGlowPaint = Paint()
      ..shader = fadeShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);

    final middleGlowPaint = Paint()
      ..shader = fadeShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.3);

    final corePaint = Paint()
      ..shader = fadeShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, outerGlowPaint);
    canvas.drawPath(path, middleGlowPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _AddBelowGestureIndicatorPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.rightInset != rightInset;
  }
}
