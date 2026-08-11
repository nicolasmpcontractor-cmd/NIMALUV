import 'package:nimahub_app/features/notes/controllers/tracker_controller.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';

class TrackerIntegrationService {
  TrackerIntegrationService._();

  static final TrackerIntegrationService instance =
      TrackerIntegrationService._();

  final TrackerController _trackerController = TrackerController.instance;

  Future<TrackerIntegrationResult> recordProgress({
    required String trackerPageId,
    required String sourceModule,
    required String externalId,
    required double value,
    String? note,
    DateTime? recordedAt,
  }) async {
    final normalizedPageId = trackerPageId.trim();

    final normalizedSource = sourceModule.trim().toLowerCase();

    final normalizedExternalId = externalId.trim();

    if (normalizedPageId.isEmpty) {
      throw ArgumentError('Debes indicar el Tracker de destino.');
    }

    if (normalizedSource.isEmpty) {
      throw ArgumentError('Debes indicar el módulo de origen.');
    }

    if (normalizedExternalId.isEmpty) {
      throw ArgumentError('Debes indicar el identificador externo.');
    }

    if (value <= 0) {
      throw ArgumentError('El progreso debe ser mayor que cero.');
    }

    await _trackerController.loadTracker(normalizedPageId);

    final tracker = _trackerController.trackerByPageId(normalizedPageId);

    if (tracker == null) {
      throw StateError('No fue posible encontrar el Tracker de destino.');
    }

    final existingEntry = _trackerController.entryByExternalReference(
      pageId: normalizedPageId,
      sourceModule: normalizedSource,
      externalId: normalizedExternalId,
    );

    final normalizedNote = note == null
        ? existingEntry?.note ?? ''
        : note.trim();

    final effectiveDate =
        recordedAt ?? existingEntry?.recordedAt ?? DateTime.now();

    if (existingEntry == null) {
      final createdEntry = await _trackerController.addEntry(
        pageId: normalizedPageId,
        value: value,
        note: normalizedNote,
        recordedAt: effectiveDate,
        sourceModule: normalizedSource,
        externalId: normalizedExternalId,
      );

      return TrackerIntegrationResult(
        entry: createdEntry,
        outcome: TrackerIntegrationOutcome.created,
      );
    }

    final hasChanges =
        existingEntry.value != value ||
        existingEntry.note != normalizedNote ||
        existingEntry.recordedAt.millisecondsSinceEpoch !=
            effectiveDate.millisecondsSinceEpoch;

    if (!hasChanges) {
      return TrackerIntegrationResult(
        entry: existingEntry,
        outcome: TrackerIntegrationOutcome.unchanged,
      );
    }

    final updatedEntry = existingEntry.copyWith(
      value: value,
      note: normalizedNote,
      recordedAt: effectiveDate,
    );

    await _trackerController.updateEntry(updatedEntry);

    return TrackerIntegrationResult(
      entry: updatedEntry,
      outcome: TrackerIntegrationOutcome.updated,
    );
  }

  Future<bool> removeProgress({
    required String trackerPageId,
    required String sourceModule,
    required String externalId,
  }) async {
    final normalizedPageId = trackerPageId.trim();

    final normalizedSource = sourceModule.trim().toLowerCase();

    final normalizedExternalId = externalId.trim();

    if (normalizedPageId.isEmpty ||
        normalizedSource.isEmpty ||
        normalizedExternalId.isEmpty) {
      return false;
    }

    await _trackerController.loadTracker(normalizedPageId);

    final existingEntry = _trackerController.entryByExternalReference(
      pageId: normalizedPageId,
      sourceModule: normalizedSource,
      externalId: normalizedExternalId,
    );

    if (existingEntry == null) {
      return false;
    }

    await _trackerController.deleteEntry(
      pageId: normalizedPageId,
      entryId: existingEntry.id,
    );

    return true;
  }
}
