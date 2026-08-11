import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';

class NotesMindMapView extends StatefulWidget {
  const NotesMindMapView({
    required this.notes,
    required this.allNotes,
    required this.currentFolderId,
    required this.folderPath,
    required this.positions,
    required this.titleForNote,
    required this.onOpenNote,
    required this.onOpenFolder,
    required this.onGoToParentFolder,
    required this.onPositionChanged,
    required this.onResetLayout,
    super.key,
  });

  /// Hijos directos de la carpeta actualmente enfocada.
  final List<NotePage> notes;

  /// Todas las páginas. Se usa para construir las ramas descendientes.
  final List<NotePage> allNotes;

  final String? currentFolderId;
  final List<NotePage> folderPath;

  final Map<String, NoteMindMapPosition> positions;

  final String Function(NotePage note) titleForNote;

  final ValueChanged<NotePage> onOpenNote;

  final ValueChanged<String?> onOpenFolder;

  final VoidCallback onGoToParentFolder;

  final void Function(NotePage note, Offset position) onPositionChanged;

  final VoidCallback onResetLayout;

  @override
  State<NotesMindMapView> createState() => _NotesMindMapViewState();
}

class _NotesMindMapViewState extends State<NotesMindMapView> {
  final TransformationController _transformationController =
      TransformationController();

  final Set<String> _collapsedFolderIds = <String>{};

  final Map<String, Offset> _customPositions = <String, Offset>{};

  String? _draggingNodeId;
  Offset? _dragStartGlobalPosition;
  Offset? _dragStartScenePosition;

  bool _didCenterInitially = false;

  Size? _lastViewportSize;
  _MindMapLayout? _lastLayout;

  @override
  void initState() {
    super.initState();
    _syncCustomPositions();
  }

  @override
  void didUpdateWidget(covariant NotesMindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final folderChanged = oldWidget.currentFolderId != widget.currentFolderId;

    final structureChanged =
        oldWidget.allNotes.length != widget.allNotes.length;

    final layoutWasReset =
        oldWidget.positions.isNotEmpty && widget.positions.isEmpty;

    if (folderChanged || structureChanged || layoutWasReset) {
      _didCenterInitially = false;
    }

    if (folderChanged) {
      _collapsedFolderIds.clear();
      _draggingNodeId = null;
      _dragStartGlobalPosition = null;
      _dragStartScenePosition = null;
    }

    if (_draggingNodeId == null) {
      _syncCustomPositions();
    }

    final validFolderIds = widget.allNotes
        .where((note) => note.kind == NotePageKind.folder)
        .map((note) => note.id)
        .toSet();

    _collapsedFolderIds.retainAll(validFolderIds);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _syncCustomPositions() {
    _customPositions
      ..clear()
      ..addEntries(
        widget.positions.values.map((position) {
          return MapEntry<String, Offset>(
            position.pageId,
            Offset(position.x, position.y),
          );
        }),
      );
  }

  void _startDragging(
    _MindMapNodePlacement placement,
    LongPressStartDetails details,
  ) {
    setState(() {
      _draggingNodeId = placement.note.id;

      _dragStartGlobalPosition = details.globalPosition;

      _dragStartScenePosition = placement.topLeft;
    });
  }

  void _updateDragging(
    _MindMapNodePlacement placement,
    LongPressMoveUpdateDetails details,
  ) {
    if (_draggingNodeId != placement.note.id) {
      return;
    }

    final startGlobalPosition = _dragStartGlobalPosition;

    final startScenePosition = _dragStartScenePosition;

    final layout = _lastLayout;

    if (startGlobalPosition == null ||
        startScenePosition == null ||
        layout == null) {
      return;
    }

    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    if (!currentScale.isFinite || currentScale <= 0) {
      return;
    }

    final screenDelta = details.globalPosition - startGlobalPosition;

    final sceneDelta = screenDelta / currentScale;

    final candidate = startScenePosition + sceneDelta;

    final maximumX = layout.sceneSize.width - placement.size.width - 24;

    final maximumY = layout.sceneSize.height - placement.size.height - 24;

    final clampedPosition = Offset(
      candidate.dx.clamp(24.0, maximumX).toDouble(),
      candidate.dy.clamp(24.0, maximumY).toDouble(),
    );

    setState(() {
      _customPositions[placement.note.id] = clampedPosition;
    });
  }

  void _endDragging(_MindMapNodePlacement placement) {
    if (_draggingNodeId != placement.note.id) {
      return;
    }

    final position = _customPositions[placement.note.id];

    setState(() {
      _draggingNodeId = null;
      _dragStartGlobalPosition = null;
      _dragStartScenePosition = null;
    });

    if (position == null) {
      return;
    }

    widget.onPositionChanged(placement.note, position);
  }

  void _toggleFolder(NotePage folder) {
    if (folder.kind != NotePageKind.folder) {
      return;
    }

    setState(() {
      if (!_collapsedFolderIds.add(folder.id)) {
        _collapsedFolderIds.remove(folder.id);
      }

      _didCenterInitially = false;
    });
  }

  void _scheduleInitialCenter({
    required Size viewportSize,
    required _MindMapLayout layout,
  }) {
    _lastViewportSize = viewportSize;
    _lastLayout = layout;

    if (_didCenterInitially) {
      return;
    }

    _didCenterInitially = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _centerMap();
    });
  }

  void _centerMap() {
    final viewportSize = _lastViewportSize;
    final layout = _lastLayout;

    if (viewportSize == null || layout == null) {
      return;
    }

    final scale = (viewportSize.width / 460).clamp(0.62, 1.0).toDouble();

    final matrix = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-layout.center.dx, -layout.center.dy, 0, 1);

    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final visibleNodes = _buildVisibleNodes(
      rootFolderId: widget.currentFolderId,
      allNotes: widget.allNotes,
      collapsedFolderIds: _collapsedFolderIds,
    );

    final layout = _createMindMapLayout(
      visibleNodes,
      customPositions: _customPositions,
    );

    final currentFolder = widget.folderPath.isEmpty
        ? null
        : widget.folderPath.last;

    final centerTitle = currentFolder == null
        ? 'Notas'
        : widget.titleForNote(currentFolder);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        _scheduleInitialCenter(viewportSize: viewportSize, layout: layout);

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  minScale: 0.24,
                  maxScale: 2.8,
                  boundaryMargin: const EdgeInsets.all(360),
                  panEnabled: _draggingNodeId == null,
                  scaleEnabled: _draggingNodeId == null,
                  child: SizedBox(
                    width: layout.sceneSize.width,
                    height: layout.sceneSize.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MindMapConnectionsPainter(
                              center: layout.center,
                              nodes: layout.placements,
                            ),
                          ),
                        ),
                        Positioned(
                          left: layout.center.dx - 76,
                          top: layout.center.dy - 45,
                          width: 152,
                          height: 90,
                          child: _MindMapCenterNode(
                            title: centerTitle,
                            isFolder: currentFolder != null,
                            itemCount: widget.notes.length,
                          ),
                        ),
                        for (final placement in layout.placements)
                          Positioned(
                            left: placement.topLeft.dx,
                            top: placement.topLeft.dy,
                            width: placement.size.width,
                            height: placement.size.height,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPressStart: (details) {
                                _startDragging(placement, details);
                              },
                              onLongPressMoveUpdate: (details) {
                                _updateDragging(placement, details);
                              },
                              onLongPressEnd: (_) {
                                _endDragging(placement);
                              },
                              child: _MindMapNoteNode(
                                note: placement.note,
                                title: widget.titleForNote(placement.note),
                                childCount: placement.childCount,
                                isCollapsed: placement.isCollapsed,
                                isDragging:
                                    _draggingNodeId == placement.note.id,
                                onTap:
                                    placement.note.kind == NotePageKind.folder
                                    ? () {
                                        _toggleFolder(placement.note);
                                      }
                                    : () {
                                        widget.onOpenNote(placement.note);
                                      },
                                onDoubleTap:
                                    placement.note.kind == NotePageKind.folder
                                    ? () {
                                        widget.onOpenFolder(placement.note.id);
                                      }
                                    : null,
                              ),
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
                  child: _MindMapEmptyMessage(
                    isInsideFolder: widget.currentFolderId != null,
                  ),
                ),
              ),
            Positioned(
              top: 16,
              left: 18,
              right: 76,
              child: _MindMapFolderNavigation(
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
              child: _MindMapRecenterButton(onTap: _centerMap),
            ),

            Positioned(
              top: 70,
              right: 18,
              child: _MindMapResetButton(
                isEnabled: widget.positions.isNotEmpty,
                onTap: widget.onResetLayout,
              ),
            ),
          ],
        );
      },
    );
  }
}

List<_MindMapVisibleNode> _buildVisibleNodes({
  required String? rootFolderId,
  required List<NotePage> allNotes,
  required Set<String> collapsedFolderIds,
}) {
  final childrenByParent = <String?, List<NotePage>>{};

  for (final note in allNotes) {
    childrenByParent
        .putIfAbsent(note.parentFolderId, () => <NotePage>[])
        .add(note);
  }

  for (final children in childrenByParent.values) {
    children.sort(_compareMindMapNotes);
  }

  final visibleNodes = <_MindMapVisibleNode>[];
  final visitedFolderIds = <String>{};

  void addChildren({
    required String? parentFolderId,
    required String? parentNodeId,
    required int depth,
  }) {
    final children = childrenByParent[parentFolderId] ?? const <NotePage>[];

    for (final child in children) {
      final childCount = childrenByParent[child.id]?.length ?? 0;
      final isCollapsed = collapsedFolderIds.contains(child.id);

      visibleNodes.add(
        _MindMapVisibleNode(
          note: child,
          parentNodeId: parentNodeId,
          depth: depth,
          childCount: childCount,
          isCollapsed: isCollapsed,
        ),
      );

      if (child.kind != NotePageKind.folder ||
          childCount == 0 ||
          isCollapsed ||
          !visitedFolderIds.add(child.id)) {
        continue;
      }

      addChildren(
        parentFolderId: child.id,
        parentNodeId: child.id,
        depth: depth + 1,
      );
    }
  }

  if (rootFolderId != null) {
    visitedFolderIds.add(rootFolderId);
  }

  addChildren(parentFolderId: rootFolderId, parentNodeId: null, depth: 1);

  return visibleNodes;
}

int _compareMindMapNotes(NotePage first, NotePage second) {
  if (first.isPinned != second.isPinned) {
    return first.isPinned ? -1 : 1;
  }

  final orderComparison = first.folderOrder.compareTo(second.folderOrder);

  if (orderComparison != 0) {
    return orderComparison;
  }

  return second.updatedAt.compareTo(first.updatedAt);
}

_MindMapLayout _createMindMapLayout(
  List<_MindMapVisibleNode> visibleNodes, {
  required Map<String, Offset> customPositions,
}) {
  const baseRadius = 250.0;
  const ringGap = 225.0;
  const averageNodeWidth = 174.0;
  const nodeSpacing = 58.0;

  final nodesByDepth = <int, List<_MindMapVisibleNode>>{};

  for (final node in visibleNodes) {
    nodesByDepth
        .putIfAbsent(node.depth, () => <_MindMapVisibleNode>[])
        .add(node);
  }

  final depths = nodesByDepth.keys.toList()..sort();
  final localPlacements = <_MindMapNodePlacement>[];

  var previousRadius = 0.0;
  var farthestRadius = baseRadius;

  for (final depth in depths) {
    final nodesAtDepth = nodesByDepth[depth]!;
    final requiredRadius =
        (nodesAtDepth.length * (averageNodeWidth + nodeSpacing)) /
        (2 * math.pi);

    final defaultRadius = baseRadius + ((depth - 1) * ringGap);
    final minimumAfterPrevious = depth == 1
        ? baseRadius
        : previousRadius + ringGap;

    final radius = math.max(
      defaultRadius,
      math.max(requiredRadius, minimumAfterPrevious),
    );

    previousRadius = radius;
    farthestRadius = math.max(farthestRadius, radius);

    final angleOffset = depth.isOdd
        ? -math.pi / 2
        : -math.pi / 2 + (math.pi / nodesAtDepth.length);

    for (var index = 0; index < nodesAtDepth.length; index++) {
      final visibleNode = nodesAtDepth[index];
      final angle = angleOffset + ((2 * math.pi * index) / nodesAtDepth.length);

      final nodeSize = visibleNode.note.kind == NotePageKind.folder
          ? const Size(176, 102)
          : const Size(158, 92);

      final nodeCenter = Offset(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
      );

      localPlacements.add(
        _MindMapNodePlacement(
          note: visibleNode.note,
          parentNodeId: visibleNode.parentNodeId,
          depth: visibleNode.depth,
          childCount: visibleNode.childCount,
          isCollapsed: visibleNode.isCollapsed,
          topLeft: Offset(
            nodeCenter.dx - nodeSize.width / 2,
            nodeCenter.dy - nodeSize.height / 2,
          ),
          size: nodeSize,
        ),
      );
    }
  }

  final halfExtent = math.max(760.0, farthestRadius + 320);
  final sceneCenter = Offset(halfExtent, halfExtent);

  final placements = localPlacements.map((placement) {
    final automaticPosition = placement.topLeft + sceneCenter;

    final customPosition = customPositions[placement.note.id];

    if (customPosition == null) {
      return placement.copyWith(topLeft: automaticPosition);
    }

    final maximumX = (halfExtent * 2) - placement.size.width - 24;

    final maximumY = (halfExtent * 2) - placement.size.height - 24;

    return placement.copyWith(
      topLeft: Offset(
        customPosition.dx.clamp(24.0, maximumX).toDouble(),
        customPosition.dy.clamp(24.0, maximumY).toDouble(),
      ),
    );
  }).toList();

  return _MindMapLayout(
    sceneSize: Size(halfExtent * 2, halfExtent * 2),
    center: sceneCenter,
    placements: placements,
  );
}

class _MindMapVisibleNode {
  const _MindMapVisibleNode({
    required this.note,
    required this.parentNodeId,
    required this.depth,
    required this.childCount,
    required this.isCollapsed,
  });

  final NotePage note;
  final String? parentNodeId;
  final int depth;
  final int childCount;
  final bool isCollapsed;
}

class _MindMapLayout {
  const _MindMapLayout({
    required this.sceneSize,
    required this.center,
    required this.placements,
  });

  final Size sceneSize;
  final Offset center;
  final List<_MindMapNodePlacement> placements;
}

class _MindMapNodePlacement {
  const _MindMapNodePlacement({
    required this.note,
    required this.parentNodeId,
    required this.depth,
    required this.childCount,
    required this.isCollapsed,
    required this.topLeft,
    required this.size,
  });

  final NotePage note;
  final String? parentNodeId;
  final int depth;
  final int childCount;
  final bool isCollapsed;
  final Offset topLeft;
  final Size size;

  Offset get center {
    return Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
  }

  _MindMapNodePlacement copyWith({Offset? topLeft}) {
    return _MindMapNodePlacement(
      note: note,
      parentNodeId: parentNodeId,
      depth: depth,
      childCount: childCount,
      isCollapsed: isCollapsed,
      topLeft: topLeft ?? this.topLeft,
      size: size,
    );
  }
}

class _MindMapConnectionsPainter extends CustomPainter {
  const _MindMapConnectionsPainter({required this.center, required this.nodes});

  final Offset center;
  final List<_MindMapNodePlacement> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = <String, _MindMapNodePlacement>{
      for (final node in nodes) node.note.id: node,
    };

    for (final node in nodes) {
      final start = node.parentNodeId == null
          ? center
          : nodesById[node.parentNodeId]?.center;

      if (start == null) {
        continue;
      }

      final end = node.center;
      final difference = end - start;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + difference.dx * 0.34,
          start.dy,
          end.dx - difference.dx * 0.20,
          end.dy,
          end.dx,
          end.dy,
        );

      final color = _mindMapColorForKind(node.note.kind);

      final linePaint = Paint()
        ..color = color.withValues(alpha: node.depth == 1 ? 0.42 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = node.depth == 1 ? 1.9 : 1.35
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);

      final endpointPaint = Paint()
        ..color = color.withValues(alpha: 0.74)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(end, 3.2, endpointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapConnectionsPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.nodes != nodes;
  }
}

class _MindMapCenterNode extends StatelessWidget {
  const _MindMapCenterNode({
    required this.title,
    required this.isFolder,
    required this.itemCount,
  });

  final String title;
  final bool isFolder;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.56),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFolder ? Icons.folder_open_rounded : Icons.hub_outlined,
            color: Colors.black,
            size: 23,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            itemCount == 1 ? '1 elemento' : '$itemCount elementos',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.48),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MindMapNoteNode extends StatelessWidget {
  const _MindMapNoteNode({
    required this.note,
    required this.title,
    required this.childCount,
    required this.isCollapsed,
    required this.isDragging,
    required this.onTap,
    required this.onDoubleTap,
  });

  final NotePage note;
  final String title;
  final int childCount;
  final bool isCollapsed;
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final color = _mindMapColorForKind(note.kind);
    final isFolder = note.kind == NotePageKind.folder;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: isDragging
                  ? 0.38
                  : isFolder
                  ? 0.24
                  : 0.17,
            ),
            blurRadius: isDragging
                ? 30
                : isFolder
                ? 22
                : 18,
            spreadRadius: isDragging ? 2 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.54),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF17181D),
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: isDragging
                    ? Colors.white.withValues(alpha: 0.88)
                    : note.isPinned
                    ? Colors.white.withValues(alpha: 0.76)
                    : color.withValues(alpha: isFolder ? 0.68 : 0.52),
                width: isDragging
                    ? 1.6
                    : note.isPinned || isFolder
                    ? 1.35
                    : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: isFolder ? 0.20 : 0.12),
                  const Color(0xFF17181D),
                  const Color(0xFF111216),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _mindMapIconForKind(note.kind),
                        color: color,
                        size: 15,
                      ),
                    ),
                    const Spacer(),
                    if (note.isPinned)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.push_pin_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ),
                    if (isFolder && childCount > 0)
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          isCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.expand_more_rounded,
                          color: color,
                          size: 17,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFolder
                      ? childCount == 1
                            ? 'CARPETA · 1 ELEMENTO'
                            : 'CARPETA · $childCount ELEMENTOS'
                      : _mindMapKindLabel(note.kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFolder
                        ? color.withValues(alpha: 0.78)
                        : Colors.white.withValues(alpha: 0.34),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MindMapFolderNavigation extends StatelessWidget {
  const _MindMapFolderNavigation({
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
                _MindMapBreadcrumbChip(
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
                  _MindMapBreadcrumbChip(
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

class _MindMapBreadcrumbChip extends StatelessWidget {
  const _MindMapBreadcrumbChip({
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

class _MindMapRecenterButton extends StatelessWidget {
  const _MindMapRecenterButton({required this.onTap});

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

class _MindMapResetButton extends StatelessWidget {
  const _MindMapResetButton({required this.isEnabled, required this.onTap});

  final bool isEnabled;
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
          onTap: isEnabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.restart_alt_rounded,
            color: isEnabled ? Colors.white : Colors.white24,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _MindMapEmptyMessage extends StatelessWidget {
  const _MindMapEmptyMessage({required this.isInsideFolder});

  final bool isInsideFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 150, 36, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInsideFolder
                  ? Icons.folder_open_outlined
                  : Icons.account_tree_outlined,
              color: Colors.white.withValues(alpha: 0.26),
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              isInsideFolder
                  ? 'Esta carpeta está vacía'
                  : 'El mapa todavía está vacío',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isInsideFolder
                  ? 'Agrega una nota, lista, Tracker o subcarpeta para crear una rama.'
                  : 'Agrega una nota, lista, Tracker o carpeta para crear el primer nodo.',
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

Color _mindMapColorForKind(NotePageKind kind) {
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

IconData _mindMapIconForKind(NotePageKind kind) {
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

String _mindMapKindLabel(NotePageKind kind) {
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
