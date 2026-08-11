import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nimahub_app/features/notes/controllers/tracker_controller.dart';
import 'package:nimahub_app/features/notes/data/notes_database.dart';
import 'package:nimahub_app/features/notes/models/note_models.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:nimahub_app/features/notes/services/tracker_reminder_service.dart';

class NotesController extends ChangeNotifier {
  NotesController._();

  static final NotesController instance = NotesController._();
  static const String untitledTrackerTitle = 'Tracker sin título';
  static const String rootMindMapScopeId = '__root__';

  final NotesDatabase _database = NotesDatabase.instance;

  final List<NotePage> _notes = [];
  final Map<String, Map<String, NoteMindMapPosition>> _mindMapPositionsByScope =
      {};

  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;

  List<NotePage> get notes {
    final sortedNotes = List<NotePage>.from(_notes);

    sortedNotes.sort((first, second) {
      if (first.isPinned != second.isPinned) {
        return first.isPinned ? -1 : 1;
      }

      return second.updatedAt.compareTo(first.updatedAt);
    });

    return sortedNotes;
  }

  Future<void> loadNotes({bool forceReload = false}) async {
    if (_isLoading) {
      return;
    }

    if (_isInitialized && !forceReload) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final storedNotes = await _database.readNotes();

      final storedMindMapPositions = await _database.readMindMapPositions();

      _notes
        ..clear()
        ..addAll(storedNotes);

      _mindMapPositionsByScope.clear();

      for (final position in storedMindMapPositions) {
        _mindMapPositionsByScope.putIfAbsent(
          position.scopeId,
          () => <String, NoteMindMapPosition>{},
        )[position.pageId] = position;
      }

      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  NotePage? noteById(String noteId) {
    for (final note in _notes) {
      if (note.id == noteId) {
        return note;
      }
    }

    return null;
  }

  String mindMapScopeId(String? folderId) {
    return _normalizeFolderId(folderId) ?? rootMindMapScopeId;
  }

  Map<String, NoteMindMapPosition> mindMapPositionsFor(String? folderId) {
    final scopeId = mindMapScopeId(folderId);

    final positions = _mindMapPositionsByScope[scopeId];

    if (positions == null || positions.isEmpty) {
      return const <String, NoteMindMapPosition>{};
    }

    return Map<String, NoteMindMapPosition>.unmodifiable(positions);
  }

  String? _normalizeFolderId(String? folderId) {
    final normalizedFolderId = folderId?.trim();

    if (normalizedFolderId == null || normalizedFolderId.isEmpty) {
      return null;
    }

    return normalizedFolderId;
  }

  String? _validateParentFolderId(String? folderId) {
    final normalizedFolderId = _normalizeFolderId(folderId);

    if (normalizedFolderId == null) {
      return null;
    }

    final folder = noteById(normalizedFolderId);

    if (folder == null || folder.kind != NotePageKind.folder) {
      throw ArgumentError('La carpeta de destino no existe.');
    }

    return normalizedFolderId;
  }

  int _nextFolderOrder(String? folderId, {String? excludingNoteId}) {
    final normalizedFolderId = _normalizeFolderId(folderId);

    var greatestOrder = -1;

    for (final note in _notes) {
      if (note.id == excludingNoteId ||
          note.parentFolderId != normalizedFolderId) {
        continue;
      }

      if (note.folderOrder > greatestOrder) {
        greatestOrder = note.folderOrder;
      }
    }

    return greatestOrder + 1;
  }

  List<NotePage> childrenOfFolder(String? folderId) {
    final normalizedFolderId = _normalizeFolderId(folderId);

    final children = _notes.where((note) {
      return note.parentFolderId == normalizedFolderId;
    }).toList();

    children.sort((first, second) {
      if (first.isPinned != second.isPinned) {
        return first.isPinned ? -1 : 1;
      }

      final orderComparison = first.folderOrder.compareTo(second.folderOrder);

      if (orderComparison != 0) {
        return orderComparison;
      }

      return second.updatedAt.compareTo(first.updatedAt);
    });

    return children;
  }

  int directChildCount(String folderId) {
    return _notes.where((note) {
      return note.parentFolderId == folderId;
    }).length;
  }

  List<NotePage> folderPath(String? folderId) {
    final path = <NotePage>[];
    final visitedFolderIds = <String>{};

    var currentFolderId = _normalizeFolderId(folderId);

    while (currentFolderId != null) {
      if (!visitedFolderIds.add(currentFolderId)) {
        break;
      }

      final folder = noteById(currentFolderId);

      if (folder == null || folder.kind != NotePageKind.folder) {
        break;
      }

      path.add(folder);

      currentFolderId = folder.parentFolderId;
    }

    return path.reversed.toList();
  }

  bool canMoveToFolder({
    required String noteId,
    required String? destinationFolderId,
  }) {
    final note = noteById(noteId);

    if (note == null) {
      return false;
    }

    final normalizedDestinationId = _normalizeFolderId(destinationFolderId);

    if (normalizedDestinationId == null) {
      return true;
    }

    if (normalizedDestinationId == noteId) {
      return false;
    }

    final destinationFolder = noteById(normalizedDestinationId);

    if (destinationFolder == null ||
        destinationFolder.kind != NotePageKind.folder) {
      return false;
    }

    if (note.kind != NotePageKind.folder) {
      return true;
    }

    final visitedFolderIds = <String>{};

    NotePage? currentFolder = destinationFolder;

    while (currentFolder != null) {
      if (!visitedFolderIds.add(currentFolder.id)) {
        return false;
      }

      if (currentFolder.id == noteId) {
        return false;
      }

      final parentFolderId = currentFolder.parentFolderId;

      if (parentFolderId == null) {
        break;
      }

      currentFolder = noteById(parentFolderId);
    }

    return true;
  }

  Future<void> _persistCreatedPage(NotePage page) async {
    try {
      await _database.insertNote(page);
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar la página recién creada: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persistCreatedTracker(
    NotePage page,
    TrackerData tracker,
  ) async {
    try {
      await _database.insertTrackerPage(page, tracker);
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar el Tracker recién creado: $error');

      debugPrintStack(stackTrace: stackTrace);

      return;
    }

    try {
      await TrackerReminderService.instance.syncReminder(tracker);
    } catch (error, stackTrace) {
      debugPrint(
        'El Tracker se guardó, pero no se pudo '
        'sincronizar su recordatorio: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  NotePage createNote({String? parentFolderId, bool notifyChanges = true}) {
    final now = DateTime.now();
    final noteId = now.microsecondsSinceEpoch.toString();
    final validatedParentFolderId = _validateParentFolderId(parentFolderId);

    final folderOrder = _nextFolderOrder(validatedParentFolderId);

    final note = NotePage(
      id: noteId,
      title: '',
      createdAt: now,
      updatedAt: now,
      kind: NotePageKind.note,
      parentFolderId: validatedParentFolderId,
      folderOrder: folderOrder,
      blocks: [
        NoteBlock(id: '${noteId}_block_1', type: NoteBlockType.paragraph),
      ],
    );

    _notes.insert(0, note);

    if (notifyChanges) {
      notifyListeners();
    }

    unawaited(_persistCreatedPage(note));

    return note;
  }

  NotePage createList({String? parentFolderId, bool notifyChanges = true}) {
    final now = DateTime.now();
    final pageId = now.microsecondsSinceEpoch.toString();
    final validatedParentFolderId = _validateParentFolderId(parentFolderId);

    final folderOrder = _nextFolderOrder(validatedParentFolderId);

    final page = NotePage(
      id: pageId,
      title: '',
      createdAt: now,
      updatedAt: now,
      kind: NotePageKind.list,
      parentFolderId: validatedParentFolderId,
      folderOrder: folderOrder,
      blocks: [
        NoteBlock(id: '${pageId}_item_1', type: NoteBlockType.checklist),
      ],
    );

    _notes.insert(0, page);

    if (notifyChanges) {
      notifyListeners();
    }

    unawaited(_persistCreatedPage(page));

    return page;
  }

  NotePage createFolder({
    String title = '',
    String? parentFolderId,
    bool notifyChanges = true,
  }) {
    final now = DateTime.now();
    final folderId = now.microsecondsSinceEpoch.toString();

    final validatedParentFolderId = _validateParentFolderId(parentFolderId);

    final folderOrder = _nextFolderOrder(validatedParentFolderId);

    final normalizedTitle = title.trim();

    final folder = NotePage(
      id: folderId,
      title: normalizedTitle.isEmpty ? 'Carpeta sin título' : normalizedTitle,
      createdAt: now,
      updatedAt: now,
      kind: NotePageKind.folder,
      parentFolderId: validatedParentFolderId,
      folderOrder: folderOrder,
      blocks: const [],
    );

    _notes.add(folder);

    if (notifyChanges) {
      notifyListeners();
    }

    unawaited(_persistCreatedPage(folder));

    return folder;
  }

  NotePage createTracker({String? parentFolderId, bool notifyChanges = true}) {
    final now = DateTime.now();
    final pageId = now.microsecondsSinceEpoch.toString();
    final validatedParentFolderId = _validateParentFolderId(parentFolderId);

    final folderOrder = _nextFolderOrder(validatedParentFolderId);

    final page = NotePage(
      id: pageId,
      title: '',
      createdAt: now,
      updatedAt: now,
      kind: NotePageKind.tracker,
      parentFolderId: validatedParentFolderId,
      folderOrder: folderOrder,
      blocks: const [],
    );

    final tracker = TrackerData.initial(pageId: pageId, startDate: now);

    _notes.insert(0, page);

    TrackerController.instance.registerInitialTracker(
      tracker,
      notifyChanges: false,
    );

    if (notifyChanges) {
      notifyListeners();
    }

    unawaited(_persistCreatedTracker(page, tracker));

    return page;
  }

  NotePage createTrackerFromTemplate({
    required TrackerTemplate template,
    String? parentFolderId,
    bool notifyChanges = true,
  }) {
    final now = DateTime.now();
    final pageId = now.microsecondsSinceEpoch.toString();
    final validatedParentFolderId = _validateParentFolderId(parentFolderId);

    final folderOrder = _nextFolderOrder(validatedParentFolderId);

    final storedTitle = template.trackerTitle.trimRight();

    final page = NotePage(
      id: pageId,
      title: storedTitle.trim().isEmpty ? template.name : storedTitle,
      createdAt: now,
      updatedAt: now,
      kind: NotePageKind.tracker,
      parentFolderId: validatedParentFolderId,
      folderOrder: folderOrder,
      blocks: const [],
    );

    final tracker = template.createTrackerData(pageId: pageId, startDate: now);

    _notes.insert(0, page);

    TrackerController.instance.registerInitialTracker(
      tracker,
      notifyChanges: false,
    );

    if (notifyChanges) {
      notifyListeners();
    }

    unawaited(_persistCreatedTracker(page, tracker));

    return page;
  }

  Future<void> updateNote(NotePage updatedNote) async {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);

    if (index == -1) {
      return;
    }

    final savedNote = updatedNote.copyWith(updatedAt: DateTime.now());

    _notes[index] = savedNote;
    notifyListeners();

    await _database.updateNote(savedNote);
  }

  Future<void> reorderNotesInFolder({
    required String? folderId,
    required List<String> orderedNoteIds,
  }) async {
    final normalizedFolderId = _normalizeFolderId(folderId);

    final currentChildren = _notes.where((note) {
      return note.parentFolderId == normalizedFolderId;
    }).toList();

    if (currentChildren.length != orderedNoteIds.length) {
      throw StateError(
        'La lista cambió mientras se '
        'estaba reorganizando.',
      );
    }

    final currentIds = currentChildren.map((note) => note.id).toSet();

    final requestedIds = orderedNoteIds.toSet();

    if (currentIds.length != requestedIds.length ||
        !currentIds.containsAll(requestedIds)) {
      throw StateError(
        'El nuevo orden contiene '
        'elementos inválidos.',
      );
    }

    var foundUnpinned = false;

    for (final noteId in orderedNoteIds) {
      final note = noteById(noteId);

      if (note == null) {
        throw StateError(
          'Uno de los elementos ya '
          'no existe.',
        );
      }

      if (!note.isPinned) {
        foundUnpinned = true;
        continue;
      }

      if (foundUnpinned) {
        throw StateError(
          'Las notas fijadas deben '
          'permanecer en la parte superior.',
        );
      }
    }

    final previousNotes = <int, NotePage>{};

    for (var order = 0; order < orderedNoteIds.length; order++) {
      final noteId = orderedNoteIds[order];

      final noteIndex = _notes.indexWhere((note) => note.id == noteId);

      if (noteIndex == -1) {
        continue;
      }

      previousNotes[noteIndex] = _notes[noteIndex];

      _notes[noteIndex] = _notes[noteIndex].copyWith(folderOrder: order);
    }

    notifyListeners();

    try {
      await _database.updateNoteOrders(orderedNoteIds);
    } catch (error, stackTrace) {
      for (final entry in previousNotes.entries) {
        _notes[entry.key] = entry.value;
      }

      notifyListeners();

      debugPrint(
        'No se pudo guardar el nuevo '
        'orden de la carpeta '
        '${normalizedFolderId ?? 'Notas'}: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<void> moveToFolder({
    required String noteId,
    required String? destinationFolderId,
  }) async {
    final index = _notes.indexWhere((note) {
      return note.id == noteId;
    });

    if (index == -1) {
      throw StateError('El elemento que intentas mover no existe.');
    }

    final normalizedDestinationId = _normalizeFolderId(destinationFolderId);

    if (!canMoveToFolder(
      noteId: noteId,
      destinationFolderId: normalizedDestinationId,
    )) {
      throw StateError(
        'No es posible mover el elemento '
        'a esa carpeta.',
      );
    }

    final previousNote = _notes[index];

    if (previousNote.parentFolderId == normalizedDestinationId) {
      return;
    }

    final destinationOrder = _nextFolderOrder(
      normalizedDestinationId,
      excludingNoteId: noteId,
    );

    final updatedNote = normalizedDestinationId == null
        ? previousNote.copyWith(
            clearParentFolderId: true,
            folderOrder: destinationOrder,
            clearBoardPosition: true,
          )
        : previousNote.copyWith(
            parentFolderId: normalizedDestinationId,
            folderOrder: destinationOrder,
            clearBoardPosition: true,
          );

    _notes[index] = updatedNote;
    notifyListeners();

    try {
      await _database.updateNoteFolder(
        noteId: noteId,
        parentFolderId: normalizedDestinationId,
        folderOrder: destinationOrder,
      );
    } catch (error, stackTrace) {
      _notes[index] = previousNote;
      notifyListeners();

      debugPrint(
        'No se pudo mover la página '
        '$noteId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<void> updateMindMapPosition({
    required String noteId,
    required String? folderId,
    required double x,
    required double y,
  }) async {
    if (noteById(noteId) == null) {
      return;
    }

    final scopeId = mindMapScopeId(folderId);

    final scopePositions = _mindMapPositionsByScope.putIfAbsent(
      scopeId,
      () => <String, NoteMindMapPosition>{},
    );

    final previousPosition = scopePositions[noteId];

    final updatedPosition = NoteMindMapPosition(
      pageId: noteId,
      scopeId: scopeId,
      x: x,
      y: y,
    );

    scopePositions[noteId] = updatedPosition;

    notifyListeners();

    try {
      await _database.upsertMindMapPosition(
        pageId: noteId,
        scopeId: scopeId,
        x: x,
        y: y,
      );
    } catch (error, stackTrace) {
      if (previousPosition == null) {
        scopePositions.remove(noteId);

        if (scopePositions.isEmpty) {
          _mindMapPositionsByScope.remove(scopeId);
        }
      } else {
        scopePositions[noteId] = previousPosition;
      }

      notifyListeners();

      debugPrint(
        'No se pudo guardar la posición '
        'del nodo $noteId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<void> resetMindMapLayout(String? folderId) async {
    final scopeId = mindMapScopeId(folderId);

    final previousPositions = _mindMapPositionsByScope.remove(scopeId);

    if (previousPositions == null || previousPositions.isEmpty) {
      return;
    }

    notifyListeners();

    try {
      await _database.deleteMindMapPositionsForScope(scopeId);
    } catch (error, stackTrace) {
      _mindMapPositionsByScope[scopeId] = previousPositions;

      notifyListeners();

      debugPrint(
        'No se pudo restaurar la '
        'distribución automática del '
        'mapa $scopeId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<void> updateBoardPosition({
    required String noteId,
    required double x,
    required double y,
  }) async {
    final index = _notes.indexWhere((note) {
      return note.id == noteId;
    });

    if (index == -1) {
      return;
    }

    final previousNote = _notes[index];

    final updatedNote = previousNote.copyWith(boardX: x, boardY: y);

    _notes[index] = updatedNote;
    notifyListeners();

    try {
      await _database.updateNoteBoardPosition(noteId: noteId, x: x, y: y);
    } catch (error, stackTrace) {
      _notes[index] = previousNote;
      notifyListeners();

      debugPrint(
        'No se pudo guardar la posición '
        'de la página $noteId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  void _removeMindMapPositionsForDeletedIds(Set<String> deletedIds) {
    for (final deletedId in deletedIds) {
      _mindMapPositionsByScope.remove(deletedId);
    }

    final emptyScopeIds = <String>[];

    for (final entry in _mindMapPositionsByScope.entries) {
      entry.value.removeWhere((pageId, _) {
        return deletedIds.contains(pageId);
      });

      if (entry.value.isEmpty) {
        emptyScopeIds.add(entry.key);
      }
    }

    for (final scopeId in emptyScopeIds) {
      _mindMapPositionsByScope.remove(scopeId);
    }
  }

  List<NotePage> _folderSubtree(String folderId) {
    final subtree = <NotePage>[];
    final visitedIds = <String>{};
    final pendingIds = <String>[folderId];

    while (pendingIds.isNotEmpty) {
      final currentId = pendingIds.removeLast();

      if (!visitedIds.add(currentId)) {
        continue;
      }

      final currentPage = noteById(currentId);

      if (currentPage == null) {
        continue;
      }

      subtree.add(currentPage);

      for (final child in _notes) {
        if (child.parentFolderId == currentId) {
          pendingIds.add(child.id);
        }
      }
    }

    return subtree;
  }

  int recursiveChildCount(String folderId) {
    final subtree = _folderSubtree(folderId);

    if (subtree.isEmpty) {
      return 0;
    }

    return subtree.length - 1;
  }

  Future<void> _cleanupDeletedTracker(NotePage note) async {
    if (note.kind != NotePageKind.tracker) {
      return;
    }

    try {
      await TrackerReminderService.instance.cancelReminder(note.id);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo cancelar el recordatorio '
        'del Tracker ${note.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await TrackerController.instance.deleteStoredImagesForPage(note.id);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudieron eliminar las imágenes '
        'del Tracker ${note.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }

    TrackerController.instance.removeCachedTracker(
      note.id,
      notifyChanges: false,
    );
  }

  Future<void> deleteFolderAndContents(String folderId) async {
    final folder = noteById(folderId);

    if (folder == null || folder.kind != NotePageKind.folder) {
      throw StateError(
        'La carpeta que intentas eliminar '
        'no existe.',
      );
    }

    final removedPages = _folderSubtree(folderId);

    final removedIds = removedPages.map((page) => page.id).toSet();

    final previousNotes = List<NotePage>.from(_notes);

    _notes.removeWhere((note) {
      return removedIds.contains(note.id);
    });

    notifyListeners();

    try {
      await _database.deleteNotes(removedIds.toList());
    } catch (error, stackTrace) {
      _notes
        ..clear()
        ..addAll(previousNotes);

      notifyListeners();

      debugPrint(
        'No se pudo eliminar la carpeta '
        '$folderId y su contenido: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    _removeMindMapPositionsForDeletedIds(removedIds);

    notifyListeners();

    for (final removedPage in removedPages) {
      await _cleanupDeletedTracker(removedPage);
    }
  }

  Future<void> deleteFolderKeepingContents(String folderId) async {
    final folder = noteById(folderId);

    if (folder == null || folder.kind != NotePageKind.folder) {
      throw StateError(
        'La carpeta que intentas eliminar '
        'no existe.',
      );
    }

    final destinationFolderId = folder.parentFolderId;

    final directChildren =
        _notes.where((note) {
          return note.parentFolderId == folderId;
        }).toList()..sort((first, second) {
          return first.folderOrder.compareTo(second.folderOrder);
        });

    final previousNotes = List<NotePage>.from(_notes);

    final firstDestinationOrder = _nextFolderOrder(
      destinationFolderId,
      excludingNoteId: folderId,
    );

    final movedChildren = <NotePage>[];

    for (var index = 0; index < directChildren.length; index++) {
      final child = directChildren[index];

      final childIndex = _notes.indexWhere((note) => note.id == child.id);

      if (childIndex == -1) {
        continue;
      }

      final movedChild = destinationFolderId == null
          ? child.copyWith(
              clearParentFolderId: true,
              folderOrder: firstDestinationOrder + index,
              clearBoardPosition: true,
            )
          : child.copyWith(
              parentFolderId: destinationFolderId,
              folderOrder: firstDestinationOrder + index,
              clearBoardPosition: true,
            );

      _notes[childIndex] = movedChild;

      movedChildren.add(movedChild);
    }

    _notes.removeWhere((note) => note.id == folderId);

    notifyListeners();

    try {
      await _database.moveFolderChildrenAndDeleteFolder(
        folderId: folderId,
        movedChildren: movedChildren,
      );
    } catch (error, stackTrace) {
      _notes
        ..clear()
        ..addAll(previousNotes);

      notifyListeners();

      debugPrint(
        'No se pudo eliminar la carpeta '
        '$folderId conservando su contenido: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    _removeMindMapPositionsForDeletedIds(<String>{folderId});

    notifyListeners();
  }

  Future<void> togglePinned(String noteId) async {
    final note = noteById(noteId);

    if (note == null) {
      return;
    }

    await updateNote(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> deleteNote(String noteId) async {
    final note = noteById(noteId);

    if (note == null) {
      return;
    }

    if (note.kind == NotePageKind.folder && directChildCount(note.id) > 0) {
      throw StateError(
        'La carpeta contiene elementos. '
        'Elige cómo quieres eliminarlos.',
      );
    }

    final removedIndex = _notes.indexWhere((currentNote) {
      return currentNote.id == noteId;
    });

    if (removedIndex == -1) {
      return;
    }

    _notes.removeAt(removedIndex);
    notifyListeners();

    try {
      await _database.deleteNote(noteId);
    } catch (error, stackTrace) {
      final safeIndex = removedIndex.clamp(0, _notes.length);

      _notes.insert(safeIndex, note);

      notifyListeners();

      debugPrint(
        'No se pudo eliminar la página '
        '$noteId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    _removeMindMapPositionsForDeletedIds(<String>{noteId});

    notifyListeners();

    await _cleanupDeletedTracker(note);
  }
}
