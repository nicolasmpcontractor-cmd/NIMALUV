import 'package:flutter/material.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';

class NotesBoardView extends StatefulWidget {
  const NotesBoardView({
    required this.notes,
    required this.titleForNote,
    required this.onOpenNote,
    required this.onPositionChanged,
    required this.currentFolderId,
    required this.folderPath,
    required this.onOpenFolder,
    required this.onGoToParentFolder,
    super.key,
  });

  final List<NotePage> notes;
  final String Function(NotePage note) titleForNote;
  final ValueChanged<NotePage> onOpenNote;

  final void Function(NotePage note, Offset position) onPositionChanged;

  final String? currentFolderId;
  final List<NotePage> folderPath;
  final ValueChanged<String?> onOpenFolder;
  final VoidCallback onGoToParentFolder;

  @override
  State<NotesBoardView> createState() => _NotesBoardViewState();
}

class _NotesBoardViewState extends State<NotesBoardView> {
  static const Size _sceneSize = Size(2600, 2100);

  static const Size _cardSize = Size(184, 118);

  static const Offset _sceneCenter = Offset(1300, 1050);

  final TransformationController _transformationController =
      TransformationController();

  final Map<String, Offset> _positions = {};

  Size? _viewportSize;

  bool _didCenterInitially = false;

  String? _draggingNoteId;
  Offset? _dragStartGlobalPosition;
  Offset? _dragStartScenePosition;

  @override
  void initState() {
    super.initState();
    _syncPositions();
  }

  @override
  void didUpdateWidget(covariant NotesBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final folderChanged = oldWidget.currentFolderId != widget.currentFolderId;

    if (folderChanged || oldWidget.notes.length != widget.notes.length) {
      _didCenterInitially = false;
    }

    if (folderChanged) {
      _draggingNoteId = null;
      _dragStartGlobalPosition = null;
      _dragStartScenePosition = null;
    }

    _syncPositions();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _syncPositions() {
    final validNoteIds = widget.notes.map((note) => note.id).toSet();

    _positions.removeWhere((noteId, position) {
      return !validNoteIds.contains(noteId);
    });

    for (var index = 0; index < widget.notes.length; index++) {
      final note = widget.notes[index];

      if (note.hasBoardPosition) {
        _positions[note.id] = Offset(note.boardX!, note.boardY!);

        continue;
      }

      _positions.putIfAbsent(
        note.id,
        () => _automaticPosition(index: index, itemCount: widget.notes.length),
      );
    }
  }

  Offset _automaticPosition({required int index, required int itemCount}) {
    const columnCount = 4;
    const horizontalDistance = 226.0;
    const verticalDistance = 158.0;

    final rowCount = (itemCount / columnCount).ceil();

    final column = index % columnCount;
    final row = index ~/ columnCount;

    final visibleColumns = itemCount < columnCount ? itemCount : columnCount;

    final totalWidth =
        ((visibleColumns - 1) * horizontalDistance) + _cardSize.width;

    final totalHeight = ((rowCount - 1) * verticalDistance) + _cardSize.height;

    final startX = _sceneCenter.dx - totalWidth / 2;

    final startY = _sceneCenter.dy - totalHeight / 2;

    return Offset(
      startX + column * horizontalDistance,
      startY + row * verticalDistance,
    );
  }

  void _scheduleInitialCenter(Size viewportSize) {
    _viewportSize = viewportSize;

    if (_didCenterInitially) {
      return;
    }

    _didCenterInitially = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _centerBoard();
    });
  }

  void _centerBoard() {
    final viewportSize = _viewportSize;

    if (viewportSize == null) {
      return;
    }

    final scale = (viewportSize.width / 920).clamp(0.55, 0.92).toDouble();

    final matrix = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-_sceneCenter.dx, -_sceneCenter.dy, 0, 1);

    _transformationController.value = matrix;
  }

  void _startDragging(NotePage note, LongPressStartDetails details) {
    final currentPosition = _positions[note.id];

    if (currentPosition == null) {
      return;
    }

    setState(() {
      _draggingNoteId = note.id;
      _dragStartGlobalPosition = details.globalPosition;
      _dragStartScenePosition = currentPosition;
    });
  }

  void _updateDragging(NotePage note, LongPressMoveUpdateDetails details) {
    if (_draggingNoteId != note.id) {
      return;
    }

    final startGlobalPosition = _dragStartGlobalPosition;

    final startScenePosition = _dragStartScenePosition;

    if (startGlobalPosition == null || startScenePosition == null) {
      return;
    }

    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    if (!currentScale.isFinite || currentScale <= 0) {
      return;
    }

    final screenDelta = details.globalPosition - startGlobalPosition;

    final sceneDelta = screenDelta / currentScale;

    final candidate = startScenePosition + sceneDelta;

    final maximumX = _sceneSize.width - _cardSize.width - 24;

    final maximumY = _sceneSize.height - _cardSize.height - 24;

    final clampedPosition = Offset(
      candidate.dx.clamp(24.0, maximumX).toDouble(),
      candidate.dy.clamp(24.0, maximumY).toDouble(),
    );

    setState(() {
      _positions[note.id] = clampedPosition;
    });
  }

  void _endDragging(NotePage note) {
    if (_draggingNoteId != note.id) {
      return;
    }

    final position = _positions[note.id];

    setState(() {
      _draggingNoteId = null;
      _dragStartGlobalPosition = null;
      _dragStartScenePosition = null;
    });

    if (position == null) {
      return;
    }

    widget.onPositionChanged(note, position);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        _scheduleInitialCenter(viewportSize);

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: 0.30,
                  maxScale: 2.6,
                  boundaryMargin: const EdgeInsets.all(500),
                  panEnabled: _draggingNoteId == null,
                  scaleEnabled: _draggingNoteId == null,
                  child: SizedBox(
                    width: _sceneSize.width,
                    height: _sceneSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: _NotesBoardGridPainter()),
                        ),
                        for (final note in widget.notes)
                          Positioned(
                            left: _positions[note.id]?.dx ?? 0,
                            top: _positions[note.id]?.dy ?? 0,
                            width: _cardSize.width,
                            height: _cardSize.height,
                            child: _NotesBoardCard(
                              note: note,
                              title: widget.titleForNote(note),
                              isDragging: _draggingNoteId == note.id,
                              onTap: () {
                                widget.onOpenNote(note);
                              },
                              onLongPressStart: (details) {
                                _startDragging(note, details);
                              },
                              onLongPressMoveUpdate: (details) {
                                _updateDragging(note, details);
                              },
                              onLongPressEnd: (details) {
                                _endDragging(note);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.notes.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: _NotesBoardEmptyState(
                    isInsideFolder: widget.currentFolderId != null,
                  ),
                ),
              ),

            Positioned(
              top: 16,
              left: 18,
              right: 76,
              child: _NotesBoardFolderNavigation(
                currentFolderId: widget.currentFolderId,
                folderPath: widget.folderPath,
                titleForNote: widget.titleForNote,
                onOpenFolder: widget.onOpenFolder,
                onGoToParentFolder: widget.onGoToParentFolder,
              ),
            ),

            Positioned(
              top: 16,
              right: 18,
              child: _NotesBoardRecenterButton(onTap: _centerBoard),
            ),
          ],
        );
      },
    );
  }
}

class _NotesBoardGridPainter extends CustomPainter {
  const _NotesBoardGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const minorSpacing = 40.0;
    const majorEvery = 5;

    final minorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;

    final majorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..strokeWidth = 1;

    var verticalIndex = 0;

    for (var x = 0.0; x <= size.width; x += minorSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        verticalIndex % majorEvery == 0 ? majorPaint : minorPaint,
      );

      verticalIndex++;
    }

    var horizontalIndex = 0;

    for (var y = 0.0; y <= size.height; y += minorSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        horizontalIndex % majorEvery == 0 ? majorPaint : minorPaint,
      );

      horizontalIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant _NotesBoardGridPainter oldDelegate) {
    return false;
  }
}

class _NotesBoardCard extends StatelessWidget {
  const _NotesBoardCard({
    required this.note,
    required this.title,
    required this.isDragging,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
  });

  final NotePage note;
  final String title;
  final bool isDragging;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final color = _boardColorForKind(note.kind);

    return AnimatedScale(
      scale: isDragging ? 1.055 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDragging ? null : onTap,
        onLongPressStart: onLongPressStart,
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: onLongPressEnd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDragging ? 0.34 : 0.16),
                blurRadius: isDragging ? 28 : 18,
                spreadRadius: isDragging ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.62),
                blurRadius: 18,
                offset: Offset(0, isDragging ? 12 : 8),
              ),
            ],
          ),
          child: Material(
            color: const Color(0xFF17181D),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 13, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDragging
                      ? Colors.white.withValues(alpha: 0.82)
                      : color.withValues(alpha: 0.48),
                  width: isDragging ? 1.5 : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    const Color(0xFF17181D),
                    const Color(0xFF101115),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          _boardIconForKind(note.kind),
                          color: color,
                          size: 17,
                        ),
                      ),
                      const Spacer(),
                      if (note.isPinned)
                        const Icon(
                          Icons.push_pin_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                      if (isDragging) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.open_with_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    note.kind == NotePageKind.folder
                        ? 'CARPETA · ABRIR'
                        : _boardKindLabel(note.kind),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
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

class _NotesBoardFolderNavigation extends StatelessWidget {
  const _NotesBoardFolderNavigation({
    required this.currentFolderId,
    required this.folderPath,
    required this.titleForNote,
    required this.onOpenFolder,
    required this.onGoToParentFolder,
  });

  final String? currentFolderId;
  final List<NotePage> folderPath;
  final String Function(NotePage note) titleForNote;
  final ValueChanged<String?> onOpenFolder;
  final VoidCallback onGoToParentFolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (currentFolderId != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.52),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: const Color(0xFF1B1C21),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onGoToParentFolder,
                customBorder: const CircleBorder(),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        Expanded(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _NotesBoardBreadcrumbChip(
                  label: 'Notas',
                  isCurrent: currentFolderId == null,
                  onTap: () {
                    onOpenFolder(null);
                  },
                ),

                for (final folder in folderPath) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.34),
                      size: 18,
                    ),
                  ),
                  _NotesBoardBreadcrumbChip(
                    label: titleForNote(folder),
                    isCurrent: folder.id == currentFolderId,
                    onTap: () {
                      onOpenFolder(folder.id);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesBoardBreadcrumbChip extends StatelessWidget {
  const _NotesBoardBreadcrumbChip({
    required this.label,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: isCurrent ? Colors.white : const Color(0xFF1B1C21),
        borderRadius: BorderRadius.circular(99),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesBoardRecenterButton extends StatelessWidget {
  const _NotesBoardRecenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.52),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF1B1C21),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _NotesBoardEmptyState extends StatelessWidget {
  const _NotesBoardEmptyState({required this.isInsideFolder});

  final bool isInsideFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 100, 36, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInsideFolder
                  ? Icons.folder_open_outlined
                  : Icons.dashboard_customize_outlined,
              color: Colors.white.withValues(alpha: 0.30),
              size: 46,
            ),
            const SizedBox(height: 15),
            Text(
              isInsideFolder
                  ? 'Esta carpeta está vacía'
                  : 'El Pizarrón está vacío',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isInsideFolder
                  ? 'Agrega una nota, lista, '
                        'Tracker o subcarpeta.'
                  : 'Agrega una nota, lista, '
                        'Tracker o carpeta para '
                        'colocar la primera tarjeta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _boardColorForKind(NotePageKind kind) {
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

IconData _boardIconForKind(NotePageKind kind) {
  switch (kind) {
    case NotePageKind.note:
      return Icons.description_outlined;

    case NotePageKind.list:
      return Icons.checklist_rounded;

    case NotePageKind.tracker:
      return Icons.insights_outlined;

    case NotePageKind.database:
      return Icons.table_chart_outlined;

    case NotePageKind.folder:
      return Icons.folder_outlined;
  }
}

String _boardKindLabel(NotePageKind kind) {
  switch (kind) {
    case NotePageKind.note:
      return 'NOTA';

    case NotePageKind.list:
      return 'LISTA';

    case NotePageKind.tracker:
      return 'TRACKER';

    case NotePageKind.database:
      return 'BASE DE DATOS';

    case NotePageKind.folder:
      return 'CARPETA';
  }
}
