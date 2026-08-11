import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:nimahub_app/features/notes/controllers/notes_controller.dart';
import 'package:nimahub_app/features/notes/controllers/tracker_controller.dart';
import 'package:nimahub_app/features/notes/controllers/tracker_template_controller.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:nimahub_app/features/notes/screens/list_editor_screen.dart';
import 'package:nimahub_app/features/notes/screens/note_editor_screen.dart';
import 'package:nimahub_app/features/notes/screens/tracker_editor_screen.dart';
import 'package:nimahub_app/features/notes/widgets/notes_board_view.dart';
import 'package:nimahub_app/features/notes/widgets/notes_mind_map_view.dart';

enum _NotesCreateOption { note, list, tracker, database, folder }

enum _TrackerCreationAction { blank }

enum _TrackerTemplateMenuAction { edit, delete }

enum _NotesViewMode { list, mindMap, board }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.showCreateButton = true});

  final bool showCreateButton;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NotesController _notesController = NotesController.instance;
  final TrackerController _trackerController = TrackerController.instance;
  final TrackerTemplateController _templateController =
      TrackerTemplateController.instance;

  final LayerLink _createMenuLink = LayerLink();
  final LayerLink _viewMenuLink = LayerLink();

  OverlayEntry? _createMenuOverlay;
  OverlayEntry? _viewMenuOverlay;

  bool _isCreateMenuOpen = false;
  bool _isViewMenuOpen = false;

  _NotesViewMode _viewMode = _NotesViewMode.list;
  String? _currentFolderId;

  final ScrollController _listScrollController = ScrollController();

  List<String>? _listReorderIds;
  String? _draggingListNoteId;
  String? _listReorderFolderId;
  String? _lastListReorderTargetId;
  bool _isFinishingListReorder = false;

  @override
  void initState() {
    super.initState();

    unawaited(_loadNotesAndTrackerSummaries());
  }

  Future<void> _loadNotesAndTrackerSummaries() async {
    await Future.wait<void>([
      _notesController.loadNotes(),
      _templateController.loadTemplates(),
    ]);

    final trackerPages = _notesController.notes.where((note) {
      return note.kind == NotePageKind.tracker;
    });

    await Future.wait(
      trackerPages.map((note) {
        return _trackerController.loadTracker(note.id);
      }),
    );
  }

  @override
  void didUpdateWidget(covariant NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.showCreateButton) {
      _closeCreateMenu(rebuild: false);
      _closeViewMenu(rebuild: false);
    }
  }

  @override
  void dispose() {
    final createOverlay = _createMenuOverlay;

    _createMenuOverlay = null;

    if (createOverlay != null) {
      createOverlay.remove();
      createOverlay.dispose();
    }

    final viewOverlay = _viewMenuOverlay;

    _viewMenuOverlay = null;

    if (viewOverlay != null) {
      viewOverlay.remove();
      viewOverlay.dispose();
    }

    _listScrollController.dispose();

    super.dispose();
  }

  Future<void> _openNote(NotePage note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          switch (note.kind) {
            case NotePageKind.list:
              return ListEditorScreen(noteId: note.id);

            case NotePageKind.note:
              return NoteEditorScreen(noteId: note.id);

            case NotePageKind.tracker:
              return TrackerEditorScreen(noteId: note.id);

            case NotePageKind.database:
            case NotePageKind.folder:
              return NoteEditorScreen(noteId: note.id);
          }
        },
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _openPage(NotePage note) {
    if (note.kind == NotePageKind.folder) {
      _openFolder(note);
      return;
    }

    unawaited(_openNote(note));
  }

  void _openFolder(NotePage folder) {
    if (folder.kind != NotePageKind.folder) {
      return;
    }

    _closeCreateMenu(rebuild: false);

    _closeViewMenu(rebuild: false);

    setState(() {
      _currentFolderId = folder.id;
    });
  }

  void _goToFolder(String? folderId) {
    if (folderId == null) {
      setState(() {
        _currentFolderId = null;
      });

      return;
    }

    final folder = _notesController.noteById(folderId);

    if (folder == null || folder.kind != NotePageKind.folder) {
      setState(() {
        _currentFolderId = null;
      });

      return;
    }

    setState(() {
      _currentFolderId = folder.id;
    });
  }

  void _goToParentFolder() {
    final currentFolder = _currentFolderId == null
        ? null
        : _notesController.noteById(_currentFolderId!);

    _goToFolder(currentFolder?.parentFolderId);
  }

  void _createNote() {
    final note = _notesController.createNote(
      parentFolderId: _currentFolderId,
      notifyChanges: false,
    );

    // Retira el menú sin mostrar la lista actualizada.
    _closeCreateMenu(rebuild: false);

    // Navigator.push se ejecuta inmediatamente.
    unawaited(_openNote(note));
  }

  void _createList() {
    final listPage = _notesController.createList(
      parentFolderId: _currentFolderId,
      notifyChanges: false,
    );

    // Retira el menú sin mostrar la lista actualizada.
    _closeCreateMenu(rebuild: false);

    unawaited(_openNote(listPage));
  }

  void _createTracker() {
    final trackerPage = _notesController.createTracker(
      parentFolderId: _currentFolderId,
      notifyChanges: false,
    );

    // Cierra el menú sin reconstruir antes de navegar.
    _closeCreateMenu(rebuild: false);

    unawaited(_openNote(trackerPage));
  }

  void _createTrackerFromTemplate(TrackerTemplate template) {
    final trackerPage = _notesController.createTrackerFromTemplate(
      template: template,
      parentFolderId: _currentFolderId,
      notifyChanges: false,
    );

    _closeCreateMenu(rebuild: false);

    unawaited(_openNote(trackerPage));
  }

  String _templateFrequencyLabel(TrackerFrequency frequency) {
    switch (frequency) {
      case TrackerFrequency.daily:
        return 'Diario';

      case TrackerFrequency.weekly:
        return 'Semanal';

      case TrackerFrequency.monthly:
        return 'Mensual';
    }
  }

  String _templateMetricLabel(TrackerMetricType metricType) {
    switch (metricType) {
      case TrackerMetricType.completion:
        return 'Cumplimiento';

      case TrackerMetricType.count:
        return 'Conteo';

      case TrackerMetricType.duration:
        return 'Duración';

      case TrackerMetricType.quantity:
        return 'Cantidad';
    }
  }

  String _templateConfigurationLabel(TrackerTemplate template) {
    final frequency = _templateFrequencyLabel(template.frequency);

    final metric = _templateMetricLabel(template.metricType);

    if (template.metricType == TrackerMetricType.completion) {
      return '$frequency · $metric';
    }

    final formattedTarget =
        template.targetValue == template.targetValue.roundToDouble()
        ? template.targetValue.toStringAsFixed(0)
        : template.targetValue.toStringAsFixed(1);

    final unit = template.unit.trim();

    return '$frequency · $metric · '
        '$formattedTarget'
        '${unit.isEmpty ? '' : ' $unit'}';
  }

  void _showTemplateMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF24252B),
        ),
      );
  }

  Future<void> _showEditTemplateDialog(TrackerTemplate template) async {
    final nameController = TextEditingController(text: template.name);

    final descriptionController = TextEditingController(
      text: template.description,
    );

    String? nameError;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF17181D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              title: const Text(
                'Editar plantilla',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) {
                        if (nameError == null) {
                          return;
                        }

                        setDialogState(() {
                          nameError = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        errorText: nameError,
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.44),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF111216),
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
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Descripción opcional',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.44),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF111216),
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
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      setDialogState(() {
                        nameError = 'Escribe un nombre.';
                      });

                      return;
                    }

                    Navigator.of(dialogContext).pop({
                      'name': name,
                      'description': descriptionController.text.trim(),
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) {
      return;
    }

    try {
      await _templateController.updateTemplate(
        template.copyWith(
          name: result['name'] ?? template.name,
          description: result['description'] ?? '',
        ),
      );

      _showTemplateMessage('Plantilla actualizada.');
    } catch (error, stackTrace) {
      debugPrint('No se pudo actualizar la plantilla: $error');

      debugPrintStack(stackTrace: stackTrace);

      _showTemplateMessage('No fue posible actualizar la plantilla.');
    }
  }

  Future<void> _confirmDeleteTemplate(TrackerTemplate template) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181D),
          title: const Text(
            'Eliminar plantilla',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'La plantilla “${template.name}” '
            'se eliminará permanentemente. '
            'Los Trackers creados con ella '
            'no se modificarán.',
            style: const TextStyle(color: Colors.white60),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _templateController.deleteTemplate(template.id);

      _showTemplateMessage('Plantilla eliminada.');
    } catch (error, stackTrace) {
      debugPrint('No se pudo eliminar la plantilla: $error');

      debugPrintStack(stackTrace: stackTrace);

      _showTemplateMessage('No fue posible eliminar la plantilla.');
    }
  }

  Future<void> _showTrackerCreationOptions() async {
    await _templateController.loadTemplates();

    if (!mounted) {
      return;
    }

    final selection = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111216),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Crear Tracker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(
                            sheetContext,
                          ).pop(_TrackerCreationAction.blank);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.black,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Crear desde cero',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Configura un Tracker nuevo',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mis plantillas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _templateController,
                          builder: (context, child) {
                            return Text(
                              '${_templateController.templates.length}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _templateController,
                      builder: (context, child) {
                        if (_templateController.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        final templates = _templateController.templates;

                        if (templates.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bookmarks_outlined,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Todavía no tienes plantillas.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Abre un Tracker y usa '
                                    '“Guardar como plantilla”.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.30,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                          itemCount: templates.length,
                          separatorBuilder: (context, index) {
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            final template = templates[index];

                            final description = template.description.trim();

                            final configuration = _templateConfigurationLabel(
                              template,
                            );

                            return Material(
                              color: const Color(0xFF191A1F),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(sheetContext).pop(template);
                                },
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    18,
                                    _currentFolderId == null ? 0 : 12,
                                    18,
                                    120,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.07,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.insights_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              template.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (description.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                description,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.42),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              configuration,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.27,
                                                ),
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<
                                        _TrackerTemplateMenuAction
                                      >(
                                        tooltip: 'Opciones de plantilla',
                                        color: const Color(0xFF24252B),
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                          color: Colors.white54,
                                        ),
                                        onSelected: (action) {
                                          switch (action) {
                                            case _TrackerTemplateMenuAction
                                                .edit:
                                              unawaited(
                                                _showEditTemplateDialog(
                                                  template,
                                                ),
                                              );
                                              return;

                                            case _TrackerTemplateMenuAction
                                                .delete:
                                              unawaited(
                                                _confirmDeleteTemplate(
                                                  template,
                                                ),
                                              );
                                              return;
                                          }
                                        },
                                        itemBuilder: (context) {
                                          return const [
                                            PopupMenuItem(
                                              value: _TrackerTemplateMenuAction
                                                  .edit,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    color: Colors.white70,
                                                    size: 19,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Editar',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: _TrackerTemplateMenuAction
                                                  .delete,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Colors.redAccent,
                                                    size: 19,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Eliminar',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ];
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
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

    if (!mounted) {
      return;
    }

    // Restaura visualmente el botón + si se cerró el selector.
    setState(() {});

    if (selection == _TrackerCreationAction.blank) {
      _createTracker();
      return;
    }

    if (selection is TrackerTemplate) {
      _createTrackerFromTemplate(selection);
    }
  }

  String _displayTitle(NotePage note) {
    final title = note.title.trim();

    if (title.isNotEmpty) {
      return title;
    }

    if (note.kind == NotePageKind.tracker) {
      return NotesController.untitledTrackerTitle;
    }

    return 'Sin título';
  }

  String _previewText(NotePage note) {
    if (note.kind == NotePageKind.folder) {
      final itemCount = _notesController.directChildCount(note.id);

      if (itemCount == 1) {
        return '1 elemento';
      }

      return '$itemCount elementos';
    }

    for (final block in note.blocks) {
      if (block.type == NoteBlockType.image) {
        final caption = block.text.trim();

        return caption.isEmpty ? 'Imagen' : caption;
      }

      final text = block.text.trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return 'Nota vacía';
  }

  IconData _viewModeIcon(_NotesViewMode mode) {
    switch (mode) {
      case _NotesViewMode.list:
        return Icons.view_agenda_outlined;

      case _NotesViewMode.mindMap:
        return Icons.account_tree_outlined;

      case _NotesViewMode.board:
        return Icons.dashboard_customize_outlined;
    }
  }

  void _toggleCreateMenu() {
    if (_isCreateMenuOpen) {
      _closeCreateMenu();
      return;
    }

    _openCreateMenu();
  }

  void _openCreateMenu() {
    if (_createMenuOverlay != null || !widget.showCreateButton) {
      return;
    }

    _closeViewMenu(rebuild: false);

    final overlay = Overlay.of(context, rootOverlay: true);

    final overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, animationValue, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeCreateMenu,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14 * animationValue,
                          sigmaY: 14 * animationValue,
                        ),
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: 0.34 * animationValue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Menú vertical nítido.
                CompositedTransformFollower(
                  link: _createMenuLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.topRight,
                  followerAnchor: Alignment.bottomRight,
                  offset: const Offset(0, -10),
                  child: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: animationValue,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - animationValue)),
                        child: Transform.scale(
                          alignment: Alignment.bottomRight,
                          scale: 0.82 + (0.18 * animationValue),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _NotesCreateCircleButton(
                                icon: Icons.folder_outlined,
                                label: 'Carpeta',
                                onTap: () {
                                  _selectCreateOption(
                                    _NotesCreateOption.folder,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              _NotesCreateCircleButton(
                                icon: Icons.description_outlined,
                                label: 'Nota',
                                onTap: () {
                                  _selectCreateOption(_NotesCreateOption.note);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Copia nítida del botón principal.
                CompositedTransformFollower(
                  link: _createMenuLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.center,
                  followerAnchor: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: _NotesMainCreateButton(
                      isOpen: true,
                      onTap: _closeCreateMenu,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _createMenuOverlay = overlayEntry;

    setState(() {
      _isCreateMenuOpen = true;
    });

    overlay.insert(overlayEntry);
  }

  void _closeCreateMenu({bool rebuild = true}) {
    final overlayEntry = _createMenuOverlay;

    _createMenuOverlay = null;

    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry.dispose();
    }

    final wasOpen = _isCreateMenuOpen;

    _isCreateMenuOpen = false;

    if (rebuild && mounted && wasOpen) {
      setState(() {});
    }
  }

  void _toggleViewMenu() {
    if (_isViewMenuOpen) {
      _closeViewMenu();
      return;
    }

    _openViewMenu();
  }

  void _openViewMenu() {
    if (_viewMenuOverlay != null || !widget.showCreateButton) {
      return;
    }

    _closeCreateMenu(rebuild: false);

    final overlay = Overlay.of(context, rootOverlay: true);

    final overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, animationValue, child) {
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeViewMenu,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14 * animationValue,
                          sigmaY: 14 * animationValue,
                        ),
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: 0.34 * animationValue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Menú vertical izquierdo.
                CompositedTransformFollower(
                  link: _viewMenuLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.topLeft,
                  followerAnchor: Alignment.bottomLeft,
                  offset: const Offset(0, -10),
                  child: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: animationValue,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - animationValue)),
                        child: Transform.scale(
                          alignment: Alignment.bottomLeft,
                          scale: 0.82 + (0.18 * animationValue),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _NotesViewCircleButton(
                                icon: _viewModeIcon(_NotesViewMode.board),
                                label: 'Pizarrón',
                                isSelected: _viewMode == _NotesViewMode.board,
                                onTap: () {
                                  _selectViewMode(_NotesViewMode.board);
                                },
                              ),
                              const SizedBox(height: 10),
                              _NotesViewCircleButton(
                                icon: _viewModeIcon(_NotesViewMode.mindMap),
                                label: 'Mapa mental',
                                isSelected: _viewMode == _NotesViewMode.mindMap,
                                onTap: () {
                                  _selectViewMode(_NotesViewMode.mindMap);
                                },
                              ),
                              const SizedBox(height: 10),
                              _NotesViewCircleButton(
                                icon: _viewModeIcon(_NotesViewMode.list),
                                label: 'Lista',
                                isSelected: _viewMode == _NotesViewMode.list,
                                onTap: () {
                                  _selectViewMode(_NotesViewMode.list);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Copia nítida del botón izquierdo.
                CompositedTransformFollower(
                  link: _viewMenuLink,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.center,
                  followerAnchor: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: _NotesMainViewButton(
                      icon: _viewModeIcon(_viewMode),
                      isOpen: true,
                      onTap: _closeViewMenu,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _viewMenuOverlay = overlayEntry;

    setState(() {
      _isViewMenuOpen = true;
    });

    overlay.insert(overlayEntry);
  }

  void _closeViewMenu({bool rebuild = true}) {
    final overlayEntry = _viewMenuOverlay;

    _viewMenuOverlay = null;

    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry.dispose();
    }

    final wasOpen = _isViewMenuOpen;

    _isViewMenuOpen = false;

    if (rebuild && mounted && wasOpen) {
      setState(() {});
    }
  }

  void _selectViewMode(_NotesViewMode mode) {
    _closeViewMenu(rebuild: false);

    if (!mounted) {
      return;
    }

    setState(() {
      _viewMode = mode;
    });
  }

  Future<void> _showCreateFolderDialog() async {
    // Retira el menú sin reconstruir
    // inmediatamente el Pizarrón.
    _closeCreateMenu(rebuild: false);

    // Espera a que el OverlayEntry anterior
    // termine de salir del árbol.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      return;
    }

    var typedName = '';
    String? nameError;

    final folderName = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitFolder() {
              final name = typedName.trim();

              if (name.isEmpty) {
                setDialogState(() {
                  nameError = 'Escribe un nombre.';
                });

                return;
              }

              Navigator.of(dialogContext, rootNavigator: true).pop(name);
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF17181D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              title: const Text(
                'Nueva carpeta',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: TextFormField(
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  typedName = value;

                  if (nameError == null) {
                    return;
                  }

                  setDialogState(() {
                    nameError = null;
                  });
                },
                onFieldSubmitted: (_) {
                  submitFolder();
                },
                decoration: InputDecoration(
                  labelText: 'Nombre de la carpeta',
                  errorText: nameError,
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF111216),
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
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: submitFolder,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Crear',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || folderName == null || folderName.trim().isEmpty) {
      return;
    }

    // Permite terminar el cierre del diálogo
    // antes de reconstruir el Pizarrón.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      return;
    }

    _notesController.createFolder(
      title: folderName.trim(),
      parentFolderId: _currentFolderId,
    );
  }

  void _showNotesMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF24252B),
        ),
      );
  }

  Future<void> _showMoveToFolderSheet(NotePage note) async {
    String? browsingFolderId = note.parentFolderId;

    final destination = await showModalBottomSheet<_FolderMoveDestination>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final storedCurrentFolder = browsingFolderId == null
                ? null
                : _notesController.noteById(browsingFolderId!);

            final currentFolder =
                storedCurrentFolder?.kind == NotePageKind.folder
                ? storedCurrentFolder
                : null;

            final currentFolderId = currentFolder?.id;

            final folderPath = _notesController.folderPath(currentFolderId);

            final availableFolders = _notesController
                .childrenOfFolder(currentFolderId)
                .where((folder) {
                  return folder.kind == NotePageKind.folder &&
                      folder.id != note.id &&
                      _notesController.canMoveToFolder(
                        noteId: note.id,
                        destinationFolderId: folder.id,
                      );
                })
                .toList();

            final currentDestinationName = currentFolder == null
                ? 'Notas'
                : _displayTitle(currentFolder);

            final destinationItemCount = currentFolderId == null
                ? _notesController.childrenOfFolder(null).length
                : _notesController.directChildCount(currentFolderId);

            final isCurrentLocation = note.parentFolderId == currentFolderId;

            return SafeArea(
              top: false,
              child: FractionallySizedBox(
                heightFactor: 0.78,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF111216),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Carpeta anterior',
                              onPressed: currentFolder == null
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        browsingFolderId =
                                            currentFolder.parentFolderId;
                                      });
                                    },
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: currentFolder == null
                                    ? Colors.white24
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mover a carpeta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _displayTitle(note),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 40,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _FolderBreadcrumbChip(
                              label: 'Notas',
                              isCurrent: currentFolderId == null,
                              onTap: () {
                                setSheetState(() {
                                  browsingFolderId = null;
                                });
                              },
                            ),
                            for (final folder in folderPath) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.28),
                                  size: 18,
                                ),
                              ),
                              _FolderBreadcrumbChip(
                                label: _displayTitle(folder),
                                isCurrent: folder.id == currentFolderId,
                                onTap: () {
                                  setSheetState(() {
                                    browsingFolderId = folder.id;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF191A1F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFFFFC85A,
                                  ).withValues(alpha: 0.14),
                                ),
                                child: Icon(
                                  currentFolder == null
                                      ? Icons.home_outlined
                                      : Icons.folder_open_outlined,
                                  color: const Color(0xFFFFC85A),
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentDestinationName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      destinationItemCount == 1
                                          ? '1 elemento'
                                          : '$destinationItemCount elementos',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.36,
                                        ),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrentLocation)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'Ubicación actual',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Subcarpetas',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Expanded(
                        child: availableFolders.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.folder_off_outlined,
                                        color: Colors.white.withValues(
                                          alpha: 0.20,
                                        ),
                                        size: 38,
                                      ),
                                      const SizedBox(height: 11),
                                      Text(
                                        'No hay subcarpetas disponibles.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.42,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  18,
                                ),
                                itemCount: availableFolders.length,
                                separatorBuilder: (context, index) {
                                  return const SizedBox(height: 8);
                                },
                                itemBuilder: (context, index) {
                                  final folder = availableFolders[index];

                                  final childCount = _notesController
                                      .directChildCount(folder.id);

                                  return Material(
                                    color: const Color(0xFF191A1F),
                                    borderRadius: BorderRadius.circular(15),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        setSheetState(() {
                                          browsingFolderId = folder.id;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(
                                                  0xFFFFC85A,
                                                ).withValues(alpha: 0.13),
                                              ),
                                              child: const Icon(
                                                Icons.folder_outlined,
                                                color: Color(0xFFFFC85A),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 11),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _displayTitle(folder),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    childCount == 1
                                                        ? '1 elemento'
                                                        : '$childCount elementos',
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.34,
                                                          ),
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.white38,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                        child: FilledButton.icon(
                          onPressed: isCurrentLocation
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop(
                                    _FolderMoveDestination(currentFolderId),
                                  );
                                },
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: Text(
                            isCurrentLocation ? 'Ya está aquí' : 'Mover aquí',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.10,
                            ),
                            disabledForegroundColor: Colors.white38,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
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
      },
    );

    if (destination == null || !mounted) {
      return;
    }

    try {
      await _notesController.moveToFolder(
        noteId: note.id,
        destinationFolderId: destination.folderId,
      );

      if (!mounted) {
        return;
      }

      final destinationFolder = destination.folderId == null
          ? null
          : _notesController.noteById(destination.folderId!);

      final destinationName = destinationFolder == null
          ? 'Notas'
          : _displayTitle(destinationFolder);

      _showNotesMessage('Movido a $destinationName.');
    } on StateError catch (error) {
      _showNotesMessage(error.message.toString());
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo mover la página '
        '${note.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      _showNotesMessage('No fue posible mover el elemento.');
    }
  }

  Future<_FolderDeleteAction?> _showFolderDeleteDialog(NotePage folder) async {
    final contentCount = _notesController.recursiveChildCount(folder.id);

    return showDialog<_FolderDeleteAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          title: const Text(
            'Eliminar carpeta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${_displayTitle(folder)}” '
                'contiene '
                '${contentCount == 1 ? '1 elemento' : '$contentCount elementos'} '
                'en total.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _FolderDeleteOptionCard(
                icon: Icons.unarchive_outlined,
                title: 'Conservar contenido',
                description:
                    'Mueve los elementos a la '
                    'carpeta superior y elimina '
                    'solo esta carpeta.',
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_FolderDeleteAction.keepContents);
                },
              ),
              const SizedBox(height: 10),
              _FolderDeleteOptionCard(
                icon: Icons.delete_forever_outlined,
                title: 'Eliminar todo',
                description:
                    'Elimina la carpeta, sus '
                    'subcarpetas y todo su '
                    'contenido. No se puede '
                    'deshacer.',
                isDestructive: true,
                onTap: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_FolderDeleteAction.deleteEverything);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePage(NotePage note) async {
    if (note.kind == NotePageKind.folder &&
        _notesController.directChildCount(note.id) > 0) {
      final folderTitle = _displayTitle(note);

      final parentFolder = note.parentFolderId == null
          ? null
          : _notesController.noteById(note.parentFolderId!);

      final parentName = parentFolder == null
          ? 'Notas'
          : _displayTitle(parentFolder);

      final action = await _showFolderDeleteDialog(note);

      if (action == null || !mounted) {
        return;
      }

      try {
        switch (action) {
          case _FolderDeleteAction.keepContents:
            await _notesController.deleteFolderKeepingContents(note.id);

            if (!mounted) {
              return;
            }

            _showNotesMessage(
              'Carpeta “$folderTitle” '
              'eliminada. El contenido se '
              'movió a $parentName.',
            );
            return;

          case _FolderDeleteAction.deleteEverything:
            await _notesController.deleteFolderAndContents(note.id);

            if (!mounted) {
              return;
            }

            _showNotesMessage(
              'Carpeta “$folderTitle” y su '
              'contenido eliminados.',
            );
            return;
        }
      } on StateError catch (error) {
        _showNotesMessage(error.message.toString());
        return;
      } catch (error, stackTrace) {
        debugPrint(
          'No se pudo eliminar la carpeta '
          '${note.id}: $error',
        );

        debugPrintStack(stackTrace: stackTrace);

        _showNotesMessage(
          'No fue posible eliminar '
          'la carpeta.',
        );
        return;
      }
    }

    try {
      await _notesController.deleteNote(note.id);
    } on StateError catch (error) {
      _showNotesMessage(error.message.toString());
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo eliminar la página '
        '${note.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      _showNotesMessage(
        'No fue posible eliminar '
        'el elemento.',
      );
    }
  }

  void _selectCreateOption(_NotesCreateOption option) {
    switch (option) {
      case _NotesCreateOption.note:
        _createNote();
        return;

      case _NotesCreateOption.list:
        _createList();
        return;

      case _NotesCreateOption.tracker:
        _closeCreateMenu(rebuild: false);

        unawaited(_showTrackerCreationOptions());

        return;

      case _NotesCreateOption.database:
        _closeCreateMenu();
        _showPendingToolMessage('Base de Datos');
        return;

      case _NotesCreateOption.folder:
        unawaited(_showCreateFolderDialog());
        return;
    }
  }

  void _showPendingToolMessage(String toolName) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'El editor de $toolName se agregará en la siguiente etapa.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF24252B),
        ),
      );
  }

  String _pageEmoji(NotePage note) {
    final customEmoji = note.emoji.trim();

    if (customEmoji.isNotEmpty) {
      return customEmoji;
    }

    if (note.isPinned) {
      return '📌';
    }

    switch (note.kind) {
      case NotePageKind.note:
        return '📝';

      case NotePageKind.list:
        return '✅';

      case NotePageKind.tracker:
        return '📊';

      case NotePageKind.database:
        return '🗂️';

      case NotePageKind.folder:
        return '📁';
    }
  }

  Future<void> _showEmojiPicker(NotePage note) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF18191F),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 340,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) async {
                Navigator.of(context).pop();

                await _notesController.updateNote(
                  note.copyWith(emoji: emoji.emoji, updatedAt: DateTime.now()),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _pageAccentColor(NotePageKind kind) {
    switch (kind) {
      case NotePageKind.note:
        return const Color(0xFF9B8CFF);

      case NotePageKind.list:
        return const Color(0xFF5CB8FF);

      case NotePageKind.tracker:
        return const Color(0xFFFF70AA);

      case NotePageKind.database:
        return const Color(0xFF62D8A6);

      case NotePageKind.folder:
        return const Color(0xFFFFC85A);
    }
  }

  Widget _buildFolderBreadcrumb() {
    final folderPath = _notesController.folderPath(_currentFolderId);

    if (folderPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF18191E),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _goToParentFolder,
                customBorder: const CircleBorder(),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _FolderBreadcrumbChip(
                    label: 'Notas',
                    isCurrent: false,
                    onTap: () {
                      _goToFolder(null);
                    },
                  ),
                  for (final folder in folderPath) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.28),
                        size: 18,
                      ),
                    ),
                    _FolderBreadcrumbChip(
                      label: _displayTitle(folder),
                      isCurrent: folder.id == _currentFolderId,
                      onTap: () {
                        _goToFolder(folder.id);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NotePage> _orderedNotesForList(List<NotePage> storedNotes) {
    final reorderIds = _listReorderIds;

    if (_draggingListNoteId == null ||
        _listReorderFolderId != _currentFolderId ||
        reorderIds == null ||
        reorderIds.isEmpty) {
      return storedNotes;
    }

    final notesById = <String, NotePage>{
      for (final note in storedNotes) note.id: note,
    };

    final orderedNotes = <NotePage>[];

    for (final noteId in reorderIds) {
      final note = notesById.remove(noteId);

      if (note != null) {
        orderedNotes.add(note);
      }
    }

    orderedNotes.addAll(notesById.values);

    return orderedNotes;
  }

  void _startListCardReorder(NotePage note, List<NotePage> notes) {
    setState(() {
      _draggingListNoteId = note.id;
      _listReorderFolderId = _currentFolderId;
      _listReorderIds = notes.map((item) => item.id).toList();
      _lastListReorderTargetId = null;
    });
  }

  bool _canReorderListCardOver(String draggedNoteId, NotePage targetNote) {
    if (draggedNoteId == targetNote.id) {
      return false;
    }

    final draggedNote = _notesController.noteById(draggedNoteId);

    if (draggedNote == null) {
      return false;
    }

    // Las páginas fijadas permanecen en su zona superior.
    return draggedNote.isPinned == targetNote.isPinned;
  }

  void _previewListCardReorder({
    required String draggedNoteId,
    required String targetNoteId,
  }) {
    final reorderIds = _listReorderIds;

    if (reorderIds == null ||
        _draggingListNoteId != draggedNoteId ||
        _listReorderFolderId != _currentFolderId ||
        _lastListReorderTargetId == targetNoteId) {
      return;
    }

    final draggedIndex = reorderIds.indexOf(draggedNoteId);

    final targetIndex = reorderIds.indexOf(targetNoteId);

    if (draggedIndex == -1 ||
        targetIndex == -1 ||
        draggedIndex == targetIndex) {
      return;
    }

    final updatedOrder = List<String>.from(reorderIds);

    // Intercambio directo:
    // solamente cambian de lugar la tarjeta
    // arrastrada y la tarjeta objetivo.
    updatedOrder[draggedIndex] = targetNoteId;

    updatedOrder[targetIndex] = draggedNoteId;

    if (_sameStringOrder(reorderIds, updatedOrder)) {
      return;
    }

    setState(() {
      _lastListReorderTargetId = targetNoteId;

      _listReorderIds = updatedOrder;
    });
  }

  void _leaveListCardReorderTarget(String targetNoteId) {
    if (_lastListReorderTargetId != targetNoteId) {
      return;
    }

    _lastListReorderTargetId = null;
  }

  bool _sameStringOrder(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  void _autoScrollListWhileDragging(Offset globalPosition) {
    if (!_listScrollController.hasClients) {
      return;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    const edgeExtent = 118.0;
    const scrollStep = 14.0;

    var delta = 0.0;

    if (globalPosition.dy < edgeExtent) {
      delta = -scrollStep;
    } else if (globalPosition.dy > screenHeight - edgeExtent) {
      delta = scrollStep;
    }

    if (delta == 0) {
      return;
    }

    final position = _listScrollController.position;
    final nextOffset = (_listScrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (nextOffset != _listScrollController.offset) {
      _listScrollController.jumpTo(nextOffset);
    }
  }

  Future<void> _finishListCardReorder() async {
    if (_isFinishingListReorder) {
      return;
    }

    final orderedNoteIds = _listReorderIds;
    final folderId = _listReorderFolderId;

    if (orderedNoteIds == null || _draggingListNoteId == null) {
      return;
    }

    _isFinishingListReorder = true;

    final persistFuture = _notesController.reorderNotesInFolder(
      folderId: folderId,
      orderedNoteIds: List<String>.from(orderedNoteIds),
    );

    if (mounted) {
      setState(() {
        _draggingListNoteId = null;
        _listReorderFolderId = null;
        _listReorderIds = null;
        _lastListReorderTargetId = null;
      });
    }

    try {
      await persistFuture;
    } on StateError catch (error) {
      _showNotesMessage(error.message.toString());
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar el nuevo orden de las notas: $error');

      debugPrintStack(stackTrace: stackTrace);

      _showNotesMessage('No fue posible guardar el nuevo orden.');
    } finally {
      _isFinishingListReorder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([_notesController, _trackerController]),
          builder: (context, child) {
            final storedNotes = _notesController.childrenOfFolder(
              _currentFolderId,
            );
            final notes = _orderedNotesForList(storedNotes);

            if (_viewMode == _NotesViewMode.mindMap) {
              return NotesMindMapView(
                notes: notes,
                allNotes: _notesController.notes,
                currentFolderId: _currentFolderId,
                folderPath: _notesController.folderPath(_currentFolderId),
                positions: _notesController.mindMapPositionsFor(
                  _currentFolderId,
                ),
                titleForNote: _displayTitle,
                onOpenNote: _openPage,
                onOpenFolder: _goToFolder,
                onGoToParentFolder: _goToParentFolder,
                onPositionChanged: (note, position) {
                  unawaited(
                    _notesController.updateMindMapPosition(
                      noteId: note.id,
                      folderId: _currentFolderId,
                      x: position.dx,
                      y: position.dy,
                    ),
                  );
                },
                onResetLayout: () {
                  unawaited(
                    _notesController.resetMindMapLayout(_currentFolderId),
                  );
                },
              );
            }

            if (_viewMode == _NotesViewMode.board) {
              return NotesBoardView(
                notes: notes,
                titleForNote: _displayTitle,
                onOpenNote: _openPage,
                currentFolderId: _currentFolderId,
                folderPath: _notesController.folderPath(_currentFolderId),
                onOpenFolder: _goToFolder,
                onGoToParentFolder: _goToParentFolder,
                onPositionChanged: (note, position) {
                  unawaited(
                    _notesController.updateBoardPosition(
                      noteId: note.id,
                      x: position.dx,
                      y: position.dy,
                    ),
                  );
                },
              );
            }

            return CustomScrollView(
              controller: _listScrollController,
              slivers: [
                if (_currentFolderId != null)
                  SliverToBoxAdapter(child: _buildFolderBreadcrumb()),

                if (notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentFolderId == null
                                  ? Icons.note_alt_outlined
                                  : Icons.folder_open_outlined,
                              color: Colors.white.withValues(alpha: 0.32),
                              size: 54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentFolderId == null
                                  ? 'Todavía no tienes notas'
                                  : 'Esta carpeta está vacía',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _currentFolderId == null
                                  ? 'Crea una página y comienza '
                                        'a organizar tus ideas.'
                                  : 'Agrega una nota o subcarpeta.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.46),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = notes[index];

                          final accentColor = _pageAccentColor(note.kind);

                          final tracker = note.kind == NotePageKind.tracker
                              ? _trackerController.trackerByPageId(note.id)
                              : null;

                          final trackerSummary = tracker == null
                              ? null
                              : _trackerController.progressSummaryForPage(
                                  note.id,
                                );

                          final card = InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              _openPage(note);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: note.isPinned
                                      ? Colors.white.withValues(alpha: 0.76)
                                      : accentColor.withValues(alpha: 0.48),
                                  width: note.isPinned ? 1.2 : 0.8,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor.withValues(alpha: 0.15),
                                    const Color(0xFF17181D),
                                    const Color(0xFF101115),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.16),
                                    blurRadius: 18,
                                  ),
                                  if (note.isPinned)
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.09,
                                      ),
                                      blurRadius: 12,
                                    ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: -5,
                                    left: 0,
                                    child: GestureDetector(
                                      onTap: () => _showEmojiPicker(note),
                                      child: Text(
                                        _pageEmoji(note),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),

                                  Positioned(
                                    top: -18,
                                    right: -10,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      color: const Color(0xFF24252A),
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'pin') {
                                          await _notesController.togglePinned(
                                            note.id,
                                          );
                                          return;
                                        }

                                        if (value == 'move') {
                                          await _showMoveToFolderSheet(note);
                                          return;
                                        }

                                        if (value == 'delete') {
                                          await _deletePage(note);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        return [
                                          PopupMenuItem(
                                            value: 'pin',
                                            child: Text(
                                              note.isPinned
                                                  ? 'Desfijar'
                                                  : 'Fijar',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'move',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.drive_file_move_outline,
                                                  color: Colors.white70,
                                                  size: 19,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Mover a carpeta',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Eliminar',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                        ];
                                      },
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.only(top: 23),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 2,
                                            right: 2,
                                          ),
                                          child: Text(
                                            _displayTitle(note),
                                            maxLines: 3,
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              height: 1.12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 0),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 2,
                                              right: 2,
                                            ),
                                            child:
                                                note.kind ==
                                                    NotePageKind.tracker
                                                ? _TrackerCardSummary(
                                                    tracker: tracker,
                                                    summary: trackerSummary,
                                                    isLoading:
                                                        _trackerController
                                                            .isLoading(note.id),
                                                  )
                                                : Text(
                                                    _previewText(note),
                                                    maxLines: 5,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.left,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.46,
                                                          ),
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Editada recientemente',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          return _AnimatedNoteGridPosition(
                            key: ValueKey<String>(note.id),
                            index: index,
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            child: _ReorderableNoteGridItem(
                              noteId: note.id,
                              isDragging: _draggingListNoteId == note.id,
                              canAccept: (draggedNoteId) {
                                return _canReorderListCardOver(
                                  draggedNoteId,
                                  note,
                                );
                              },
                              onDragStarted: () {
                                _startListCardReorder(note, notes);
                              },
                              onDragUpdate: _autoScrollListWhileDragging,
                              onMoveOver: (draggedNoteId) {
                                _previewListCardReorder(
                                  draggedNoteId: draggedNoteId,
                                  targetNoteId: note.id,
                                );
                              },
                              onMoveAway: () {
                                _leaveListCardReorderTarget(note.id);
                              },
                              onDragEnded: () {
                                unawaited(_finishListCardReorder());
                              },
                              child: card,
                            ),
                          );
                        },
                        childCount: notes.length,
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<String>) {
                            return null;
                          }

                          final index = notes.indexWhere(
                            (note) => note.id == key.value,
                          );

                          return index == -1 ? null : index;
                        },
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: IgnorePointer(
        ignoring: !widget.showCreateButton,
        child: AnimatedOpacity(
          opacity: widget.showCreateButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: widget.showCreateButton ? 1.0 : 0.82,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Transform.translate(
                    offset: const Offset(2, 12),
                    child: CompositedTransformTarget(
                      link: _viewMenuLink,
                      child: _NotesMainViewButton(
                        icon: _viewModeIcon(_viewMode),
                        isOpen: _isViewMenuOpen,
                        onTap: _toggleViewMenu,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-2, 12),
                    child: CompositedTransformTarget(
                      link: _createMenuLink,
                      child: _NotesMainCreateButton(
                        isOpen: _isCreateMenuOpen,
                        onTap: _toggleCreateMenu,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNoteGridPosition extends StatefulWidget {
  const _AnimatedNoteGridPosition({
    required this.index,
    required this.crossAxisCount,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.child,
    super.key,
  });

  final int index;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final Widget child;

  @override
  State<_AnimatedNoteGridPosition> createState() =>
      _AnimatedNoteGridPositionState();
}

class _AnimatedNoteGridPositionState extends State<_AnimatedNoteGridPosition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  double _rowDelta = 0;
  double _columnDelta = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedNoteGridPosition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.index == widget.index &&
        oldWidget.crossAxisCount == widget.crossAxisCount) {
      return;
    }

    final easedProgress = Curves.easeOutCubic.transform(
      _animationController.value,
    );

    final remainingProgress = 1 - easedProgress;

    final oldRow = oldWidget.index ~/ oldWidget.crossAxisCount;

    final oldColumn = oldWidget.index % oldWidget.crossAxisCount;

    final newRow = widget.index ~/ widget.crossAxisCount;

    final newColumn = widget.index % widget.crossAxisCount;

    // Conserva la posición visual actual
    // incluso si otro intercambio ocurre
    // antes de terminar la animación.
    final currentVisualRow = oldRow + (_rowDelta * remainingProgress);

    final currentVisualColumn = oldColumn + (_columnDelta * remainingProgress);

    _rowDelta = currentVisualRow - newRow;

    _columnDelta = currentVisualColumn - newColumn;

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _animationController,
          child: RepaintBoundary(child: widget.child),
          builder: (context, child) {
            final easedProgress = Curves.easeOutCubic.transform(
              _animationController.value,
            );

            final remainingProgress = 1 - easedProgress;

            final horizontalDistance =
                constraints.maxWidth + widget.crossAxisSpacing;

            final verticalDistance =
                constraints.maxHeight + widget.mainAxisSpacing;

            final offset = Offset(
              _columnDelta * horizontalDistance * remainingProgress,
              _rowDelta * verticalDistance * remainingProgress,
            );

            return Transform.translate(offset: offset, child: child);
          },
        );
      },
    );
  }
}

class _ReorderableNoteGridItem extends StatelessWidget {
  const _ReorderableNoteGridItem({
    required this.noteId,
    required this.isDragging,
    required this.canAccept,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onMoveOver,
    required this.onMoveAway,
    required this.onDragEnded,
    required this.child,
  });

  final String noteId;
  final bool isDragging;
  final bool Function(String draggedNoteId) canAccept;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<String> onMoveOver;
  final VoidCallback onMoveAway;
  final VoidCallback onDragEnded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final placeholder = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.drag_indicator_rounded,
              color: Colors.white.withValues(alpha: 0.20),
              size: 28,
            ),
          ),
        );

        return DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            return canAccept(details.data);
          },
          onMove: (details) {
            if (canAccept(details.data)) {
              onMoveOver(details.data);
            }
          },
          onLeave: (_) {
            onMoveAway();
          },
          onAcceptWithDetails: (_) {},
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<String>(
              data: noteId,
              delay: const Duration(milliseconds: 290),
              hapticFeedbackOnStart: true,
              maxSimultaneousDrags: 1,
              onDragStarted: onDragStarted,
              onDragUpdate: (details) {
                onDragUpdate(details.globalPosition);
              },
              onDragEnd: (_) {
                onDragEnded();
              },
              feedback: Material(
                color: Colors.transparent,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Transform.scale(
                      scale: 1.018,
                      child: Opacity(
                        opacity: 0.97,
                        child: IgnorePointer(child: child),
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: placeholder,
              child: isDragging ? placeholder : child,
            );
          },
        );
      },
    );
  }
}

enum _FolderDeleteAction { keepContents, deleteEverything }

class _FolderDeleteOptionCard extends StatelessWidget {
  const _FolderDeleteOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final accentColor = isDestructive ? Colors.redAccent : Colors.white;

    return Material(
      color: isDestructive
          ? Colors.redAccent.withValues(alpha: 0.08)
          : const Color(0xFF111216),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDestructive
                  ? Colors.redAccent.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: accentColor.withValues(alpha: 0.54),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderMoveDestination {
  const _FolderMoveDestination(this.folderId);

  final String? folderId;
}

class _FolderBreadcrumbChip extends StatelessWidget {
  const _FolderBreadcrumbChip({
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent ? Colors.white : const Color(0xFF18191E),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: isCurrent
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerCardSummary extends StatelessWidget {
  const _TrackerCardSummary({
    required this.tracker,
    required this.summary,
    required this.isLoading,
  });

  final TrackerData? tracker;
  final TrackerProgressSummary? summary;
  final bool isLoading;

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _frequencyLabel(TrackerFrequency frequency) {
    switch (frequency) {
      case TrackerFrequency.daily:
        return 'Diario';

      case TrackerFrequency.weekly:
        return 'Semanal';

      case TrackerFrequency.monthly:
        return 'Mensual';
    }
  }

  String _statusLabel(TrackerStatus status) {
    switch (status) {
      case TrackerStatus.active:
        return 'Activo';

      case TrackerStatus.paused:
        return 'Pausado';

      case TrackerStatus.completed:
        return 'Finalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTracker = tracker;
    final currentSummary = summary;

    if (currentTracker == null || currentSummary == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          isLoading ? 'Cargando progreso…' : 'Tracker sin configuración',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      );
    }

    final percentage = (currentSummary.progress * 100).round();
    final unit = currentTracker.unit.trim();

    final progressText =
        currentTracker.metricType == TrackerMetricType.completion
        ? currentSummary.isCurrentPeriodCompleted
              ? 'Completado'
              : 'Pendiente'
        : '${_formatNumber(currentSummary.currentValue)} de '
              '${_formatNumber(currentSummary.targetValue)}'
              '${unit.isEmpty ? '' : ' $unit'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentTracker.description.trim().isNotEmpty) ...[
          Text(
            currentTracker.description.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 7),
        ],
        Row(
          children: [
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.local_fire_department_outlined,
              color: Colors.white54,
              size: 15,
            ),
            const SizedBox(width: 3),
            Text(
              '${currentSummary.currentStreak}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: currentSummary.progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          progressText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${_frequencyLabel(currentTracker.frequency)} · '
          '${_statusLabel(currentTracker.status)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _NotesMainViewButton extends StatelessWidget {
  const _NotesMainViewButton({
    required this.icon,
    required this.isOpen,
    required this.onTap,
  });

  final IconData icon;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isOpen ? 0.48 : 0.32),
            blurRadius: isOpen ? 17 : 12,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isOpen ? Icons.close_rounded : icon,
              key: ValueKey<Object>(isOpen ? 'close' : icon),
              color: Colors.black,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesViewCircleButton extends StatelessWidget {
  const _NotesViewCircleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: isSelected ? 0.45 : 0.27,
                  ),
                  blurRadius: isSelected ? 17 : 12,
                  spreadRadius: 0.4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.46),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Center(child: Icon(icon, color: Colors.black, size: 24)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFF18191E),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: isSelected ? 0.80 : 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesMainCreateButton extends StatelessWidget {
  const _NotesMainCreateButton({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isOpen ? 0.48 : 0.32),
            blurRadius: isOpen ? 17 : 12,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedRotation(
            turns: isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Colors.black, size: 27),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesCreateCircleButton extends StatelessWidget {
  const _NotesCreateCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF18191E),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.27),
                blurRadius: 12,
                spreadRadius: 0.4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.46),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(child: Icon(icon, color: Colors.black, size: 24)),
            ),
          ),
        ),
      ],
    );
  }
}
