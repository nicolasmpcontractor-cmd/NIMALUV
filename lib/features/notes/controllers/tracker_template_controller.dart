import 'package:flutter/foundation.dart';
import 'package:nimahub_app/features/notes/data/notes_database.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';

class TrackerTemplateController extends ChangeNotifier {
  TrackerTemplateController._();

  static final TrackerTemplateController instance =
      TrackerTemplateController._();

  final NotesDatabase _database = NotesDatabase.instance;

  final List<TrackerTemplate> _templates = [];

  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;

  List<TrackerTemplate> get templates {
    return List<TrackerTemplate>.unmodifiable(_templates);
  }

  TrackerTemplate? templateById(String templateId) {
    for (final template in _templates) {
      if (template.id == templateId) {
        return template;
      }
    }

    return null;
  }

  Future<void> loadTemplates({bool forceReload = false}) async {
    if (_isLoading) {
      return;
    }

    if (_isInitialized && !forceReload) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final storedTemplates = await _database.readTrackerTemplates();

      _templates
        ..clear()
        ..addAll(storedTemplates);

      _isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('No se pudieron cargar las plantillas: $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TrackerTemplate> createFromTracker({
    required String name,
    required String description,
    required String trackerTitle,
    required TrackerData tracker,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('La plantilla debe tener un nombre.');
    }

    final now = DateTime.now();

    final template = TrackerTemplate(
      id: now.microsecondsSinceEpoch.toString(),
      name: normalizedName,
      description: description.trim(),
      trackerTitle: trackerTitle.trimRight(),
      trackerDescription: tracker.description,
      frequency: tracker.frequency,
      metricType: tracker.metricType,
      targetValue: tracker.targetValue,
      unit: tracker.unit,
      reminderEnabled: tracker.reminderEnabled,
      reminderHour: tracker.reminderHour,
      reminderMinute: tracker.reminderMinute,
      createdAt: now,
      updatedAt: now,
    );

    _templates.insert(0, template);
    notifyListeners();

    try {
      await _database.upsertTrackerTemplate(template);
    } catch (error) {
      _templates.removeWhere((currentTemplate) {
        return currentTemplate.id == template.id;
      });

      notifyListeners();
      rethrow;
    }

    return template;
  }

  Future<void> updateTemplate(TrackerTemplate updatedTemplate) async {
    final normalizedName = updatedTemplate.name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('La plantilla debe tener un nombre.');
    }

    final index = _templates.indexWhere((template) {
      return template.id == updatedTemplate.id;
    });

    if (index == -1) {
      return;
    }

    final previousTemplate = _templates[index];

    final templateToSave = updatedTemplate.copyWith(
      name: normalizedName,
      description: updatedTemplate.description.trim(),
      updatedAt: DateTime.now(),
    );

    _templates[index] = templateToSave;
    notifyListeners();

    try {
      await _database.upsertTrackerTemplate(templateToSave);
    } catch (error) {
      _templates[index] = previousTemplate;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    final index = _templates.indexWhere((template) {
      return template.id == templateId;
    });

    if (index == -1) {
      return;
    }

    final removedTemplate = _templates.removeAt(index);

    notifyListeners();

    try {
      await _database.deleteTrackerTemplate(templateId);
    } catch (error) {
      _templates.insert(index, removedTemplate);
      notifyListeners();
      rethrow;
    }
  }
}
