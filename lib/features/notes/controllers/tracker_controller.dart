import 'package:flutter/foundation.dart';
import 'package:nimahub_app/features/notes/data/notes_database.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:nimahub_app/features/notes/services/tracker_entry_image_service.dart';
import 'package:nimahub_app/features/notes/services/tracker_reminder_service.dart';

class TrackerController extends ChangeNotifier {
  TrackerController._();

  static final TrackerController instance = TrackerController._();

  final NotesDatabase _database = NotesDatabase.instance;

  final TrackerReminderService _reminderService =
      TrackerReminderService.instance;

  final TrackerEntryImageService _imageService =
      TrackerEntryImageService.instance;

  final Map<String, TrackerData> _trackersByPageId = {};
  final Map<String, List<TrackerEntry>> _entriesByPageId = {};
  final Map<String, List<TrackerPause>> _pausesByPageId = {};

  final Set<String> _loadedPageIds = {};
  final Set<String> _loadingPageIds = {};

  TrackerData? trackerByPageId(String pageId) {
    return _trackersByPageId[pageId];
  }

  List<TrackerEntry> entriesForPage(String pageId) {
    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

    return List<TrackerEntry>.unmodifiable(entries);
  }

  TrackerEntry? entryByExternalReference({
    required String pageId,
    required String sourceModule,
    required String externalId,
  }) {
    final normalizedSource = sourceModule.trim().toLowerCase();

    final normalizedExternalId = externalId.trim();

    if (normalizedSource.isEmpty || normalizedExternalId.isEmpty) {
      return null;
    }

    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

    for (final entry in entries) {
      if (entry.sourceModule == normalizedSource &&
          entry.externalId == normalizedExternalId) {
        return entry;
      }
    }

    return null;
  }

  List<TrackerPause> pausesForPage(String pageId) {
    final pauses = _pausesByPageId[pageId] ?? const <TrackerPause>[];

    return List<TrackerPause>.unmodifiable(pauses);
  }

  bool isLoading(String pageId) {
    return _loadingPageIds.contains(pageId);
  }

  DateTime periodStartFor(DateTime date, TrackerFrequency frequency) {
    return _periodStart(date, frequency);
  }

  DateTime previousPeriodStartFor(DateTime period, TrackerFrequency frequency) {
    return _previousPeriodStart(_periodStart(period, frequency), frequency);
  }

  DateTime nextPeriodStartFor(DateTime period, TrackerFrequency frequency) {
    return _nextPeriodStart(_periodStart(period, frequency), frequency);
  }

  List<TrackerEntry> entriesForPeriod(String pageId, DateTime referenceDate) {
    final tracker = _trackersByPageId[pageId];

    if (tracker == null) {
      return const <TrackerEntry>[];
    }

    final periodStart = _periodStart(referenceDate, tracker.frequency);

    final periodEnd = _nextPeriodStart(periodStart, tracker.frequency);

    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

    final filteredEntries =
        entries.where((entry) {
          return !entry.recordedAt.isBefore(periodStart) &&
              entry.recordedAt.isBefore(periodEnd);
        }).toList()..sort((first, second) {
          return second.recordedAt.compareTo(first.recordedAt);
        });

    return List<TrackerEntry>.unmodifiable(filteredEntries);
  }

  TrackerPeriodActivity activityForPeriod(
    String pageId,
    DateTime referenceDate, {
    DateTime? now,
  }) {
    final tracker = _trackersByPageId[pageId];

    if (tracker == null) {
      return TrackerPeriodActivity(
        periodStart: DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
        ),
        value: 0,
        targetValue: 1,
        progress: 0,
        state: TrackerActivityState.noActivity,
      );
    }

    final referenceNow = now ?? DateTime.now();

    final periodStart = _periodStart(referenceDate, tracker.frequency);

    final trackerStart = _periodStart(tracker.startDate, tracker.frequency);

    final currentPeriod = _periodStart(referenceNow, tracker.frequency);

    final targetValue = tracker.targetValue > 0 ? tracker.targetValue : 1.0;

    if (periodStart.isBefore(trackerStart)) {
      return TrackerPeriodActivity(
        periodStart: periodStart,
        value: 0,
        targetValue: targetValue,
        progress: 0,
        state: TrackerActivityState.beforeStart,
      );
    }

    if (periodStart.isAfter(currentPeriod)) {
      return TrackerPeriodActivity(
        periodStart: periodStart,
        value: 0,
        targetValue: targetValue,
        progress: 0,
        state: TrackerActivityState.future,
      );
    }

    final periodEnd = _nextPeriodStart(periodStart, tracker.frequency);

    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

    var value = 0.0;

    for (final entry in entries) {
      final belongsToPeriod =
          !entry.recordedAt.isBefore(periodStart) &&
          entry.recordedAt.isBefore(periodEnd);

      if (belongsToPeriod) {
        value += entry.value;
      }
    }

    final progress = (value / targetValue).clamp(0.0, 1.0).toDouble();

    final pauses = _pausesByPageId[pageId] ?? const <TrackerPause>[];

    final isPaused = _isPausedPeriod(
      pauses: pauses,
      periodStart: periodStart,
      frequency: tracker.frequency,
      referenceDate: referenceNow,
    );

    late final TrackerActivityState state;

    if (isPaused) {
      state = TrackerActivityState.paused;
    } else if (value >= targetValue) {
      state = TrackerActivityState.completed;
    } else if (value > 0) {
      state = TrackerActivityState.incomplete;
    } else {
      state = TrackerActivityState.noActivity;
    }

    return TrackerPeriodActivity(
      periodStart: periodStart,
      value: value,
      targetValue: targetValue,
      progress: progress,
      state: state,
    );
  }

  TrackerAnalyticsData analyticsForPage(
    String pageId, {
    DateTime? now,
    int? chartPeriodCount,
  }) {
    final tracker = _trackersByPageId[pageId];

    if (tracker == null) {
      return const TrackerAnalyticsData.empty();
    }

    final referenceNow = now ?? DateTime.now();

    final trackerStart = _periodStart(tracker.startDate, tracker.frequency);

    final currentPeriod = _periodStart(referenceNow, tracker.frequency);

    if (currentPeriod.isBefore(trackerStart)) {
      return const TrackerAnalyticsData.empty();
    }

    final defaultChartPeriodCount = switch (tracker.frequency) {
      TrackerFrequency.daily => 14,
      TrackerFrequency.weekly => 12,
      TrackerFrequency.monthly => 12,
    };

    final resolvedChartPeriodCount =
        (chartPeriodCount ?? defaultChartPeriodCount).clamp(1, 60).toInt();

    var totalValue = 0.0;
    var bestPeriodValue = 0.0;
    DateTime? bestPeriodStart;

    var completedPeriods = 0;
    var missedPeriods = 0;
    var pausedPeriods = 0;
    var activePeriods = 0;
    var evaluatedPeriods = 0;

    var periodCursor = trackerStart;

    while (!periodCursor.isAfter(currentPeriod)) {
      final activity = activityForPeriod(
        pageId,
        periodCursor,
        now: referenceNow,
      );

      final isCurrentPeriod =
          periodCursor.millisecondsSinceEpoch ==
          currentPeriod.millisecondsSinceEpoch;

      if (activity.state == TrackerActivityState.paused) {
        pausedPeriods++;
      } else {
        activePeriods++;
        totalValue += activity.value;

        if (activity.value > bestPeriodValue) {
          bestPeriodValue = activity.value;
          bestPeriodStart = periodCursor;
        }

        if (activity.state == TrackerActivityState.completed) {
          completedPeriods++;
          evaluatedPeriods++;
        } else if (!isCurrentPeriod) {
          missedPeriods++;
          evaluatedPeriods++;
        }
      }

      periodCursor = _nextPeriodStart(periodCursor, tracker.frequency);
    }

    final averageValue = activePeriods == 0 ? 0.0 : totalValue / activePeriods;

    final completionRate = evaluatedPeriods == 0
        ? 0.0
        : completedPeriods / evaluatedPeriods;

    var firstChartPeriod = currentPeriod;

    for (var index = 1; index < resolvedChartPeriodCount; index++) {
      final previousPeriod = _previousPeriodStart(
        firstChartPeriod,
        tracker.frequency,
      );

      if (previousPeriod.isBefore(trackerStart)) {
        break;
      }

      firstChartPeriod = previousPeriod;
    }

    final chartPoints = <TrackerChartPoint>[];
    var chartCursor = firstChartPeriod;

    while (!chartCursor.isAfter(currentPeriod)) {
      final activity = activityForPeriod(
        pageId,
        chartCursor,
        now: referenceNow,
      );

      chartPoints.add(
        TrackerChartPoint(
          periodStart: activity.periodStart,
          value: activity.value,
          targetValue: activity.targetValue,
          progress: activity.progress,
          state: activity.state,
        ),
      );

      chartCursor = _nextPeriodStart(chartCursor, tracker.frequency);
    }

    return TrackerAnalyticsData(
      chartPoints: List<TrackerChartPoint>.unmodifiable(chartPoints),
      statistics: TrackerStatisticsSummary(
        totalValue: totalValue,
        averageValue: averageValue,
        completionRate: completionRate,
        bestPeriodValue: bestPeriodValue,
        bestPeriodStart: bestPeriodStart,
        completedPeriods: completedPeriods,
        missedPeriods: missedPeriods,
        pausedPeriods: pausedPeriods,
        activePeriods: activePeriods,
      ),
    );
  }

  TrackerProgressSummary progressSummaryForPage(
    String pageId, {
    DateTime? now,
  }) {
    final tracker = _trackersByPageId[pageId];

    if (tracker == null) {
      return const TrackerProgressSummary.empty();
    }

    final referenceDate = now ?? DateTime.now();
    final targetValue = tracker.targetValue > 0 ? tracker.targetValue : 1.0;

    final trackerStartPeriod = _periodStart(
      tracker.startDate,
      tracker.frequency,
    );

    final currentPeriod = _periodStart(referenceDate, tracker.frequency);

    if (currentPeriod.isBefore(trackerStartPeriod)) {
      return TrackerProgressSummary(
        currentValue: 0,
        targetValue: targetValue,
        progress: 0,
        currentStreak: 0,
        bestStreak: 0,
        completedPeriods: 0,
      );
    }

    final pauses = _pausesByPageId[pageId] ?? const <TrackerPause>[];
    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];
    final totalsByPeriod = <int, double>{};

    for (final entry in entries) {
      final period = _periodStart(entry.recordedAt, tracker.frequency);

      if (period.isBefore(trackerStartPeriod) ||
          period.isAfter(currentPeriod)) {
        continue;
      }

      final periodKey = period.millisecondsSinceEpoch;

      totalsByPeriod.update(
        periodKey,
        (currentValue) => currentValue + entry.value,
        ifAbsent: () => entry.value,
      );
    }

    final currentKey = currentPeriod.millisecondsSinceEpoch;
    final currentValue = totalsByPeriod[currentKey] ?? 0;

    final completedPeriodKeys = totalsByPeriod.entries
        .where((entry) {
          final period = DateTime.fromMillisecondsSinceEpoch(entry.key);

          return entry.value >= targetValue &&
              !_isPausedPeriod(
                pauses: pauses,
                periodStart: period,
                frequency: tracker.frequency,
                referenceDate: referenceDate,
              );
        })
        .map((entry) => entry.key)
        .toSet();

    var currentStreak = 0;
    var streakCursor = currentPeriod;
    var skippedIncompleteCurrentPeriod = false;

    while (!streakCursor.isBefore(trackerStartPeriod)) {
      final isPaused = _isPausedPeriod(
        pauses: pauses,
        periodStart: streakCursor,
        frequency: tracker.frequency,
        referenceDate: referenceDate,
      );

      if (isPaused) {
        streakCursor = _previousPeriodStart(streakCursor, tracker.frequency);

        continue;
      }

      final cursorKey = streakCursor.millisecondsSinceEpoch;

      if (completedPeriodKeys.contains(cursorKey)) {
        currentStreak++;
      } else if (!skippedIncompleteCurrentPeriod && cursorKey == currentKey) {
        skippedIncompleteCurrentPeriod = true;
      } else {
        break;
      }

      streakCursor = _previousPeriodStart(streakCursor, tracker.frequency);
    }

    var bestStreak = 0;
    var runningStreak = 0;
    var periodCursor = trackerStartPeriod;

    while (!periodCursor.isAfter(currentPeriod)) {
      final isPaused = _isPausedPeriod(
        pauses: pauses,
        periodStart: periodCursor,
        frequency: tracker.frequency,
        referenceDate: referenceDate,
      );

      if (!isPaused) {
        final cursorKey = periodCursor.millisecondsSinceEpoch;

        if (completedPeriodKeys.contains(cursorKey)) {
          runningStreak++;

          if (runningStreak > bestStreak) {
            bestStreak = runningStreak;
          }
        } else {
          runningStreak = 0;
        }
      }

      periodCursor = _nextPeriodStart(periodCursor, tracker.frequency);
    }

    final progress = (currentValue / targetValue).clamp(0.0, 1.0).toDouble();

    return TrackerProgressSummary(
      currentValue: currentValue,
      targetValue: targetValue,
      progress: progress,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      completedPeriods: completedPeriodKeys.length,
    );
  }

  bool _isPausedPeriod({
    required List<TrackerPause> pauses,
    required DateTime periodStart,
    required TrackerFrequency frequency,
    required DateTime referenceDate,
  }) {
    final periodEnd = _nextPeriodStart(periodStart, frequency);

    return pauses.any((pause) {
      final pauseEnd = pause.endedAt ?? referenceDate;

      return pause.startedAt.isBefore(periodEnd) &&
          pauseEnd.isAfter(periodStart);
    });
  }

  DateTime _periodStart(DateTime date, TrackerFrequency frequency) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    switch (frequency) {
      case TrackerFrequency.daily:
        return normalizedDate;

      case TrackerFrequency.weekly:
        return normalizedDate.subtract(
          Duration(days: normalizedDate.weekday - DateTime.monday),
        );

      case TrackerFrequency.monthly:
        return DateTime(normalizedDate.year, normalizedDate.month);
    }
  }

  DateTime _previousPeriodStart(DateTime period, TrackerFrequency frequency) {
    switch (frequency) {
      case TrackerFrequency.daily:
        return period.subtract(const Duration(days: 1));

      case TrackerFrequency.weekly:
        return period.subtract(const Duration(days: 7));

      case TrackerFrequency.monthly:
        return DateTime(period.year, period.month - 1);
    }
  }

  DateTime _nextPeriodStart(DateTime period, TrackerFrequency frequency) {
    switch (frequency) {
      case TrackerFrequency.daily:
        return period.add(const Duration(days: 1));

      case TrackerFrequency.weekly:
        return period.add(const Duration(days: 7));

      case TrackerFrequency.monthly:
        return DateTime(period.year, period.month + 1);
    }
  }

  void registerInitialTracker(
    TrackerData tracker, {
    bool notifyChanges = true,
  }) {
    _trackersByPageId[tracker.pageId] = tracker;
    _entriesByPageId.putIfAbsent(tracker.pageId, () => <TrackerEntry>[]);
    _pausesByPageId.putIfAbsent(tracker.pageId, () => <TrackerPause>[]);

    _loadedPageIds.add(tracker.pageId);

    if (notifyChanges) {
      notifyListeners();
    }
  }

  Future<void> loadTracker(String pageId, {bool forceReload = false}) async {
    if (_loadingPageIds.contains(pageId)) {
      return;
    }

    if (_loadedPageIds.contains(pageId) && !forceReload) {
      return;
    }

    _loadingPageIds.add(pageId);
    notifyListeners();

    try {
      final tracker = await _database.readTrackerData(pageId);
      final entries = await _database.readTrackerEntries(pageId);
      final pauses = await _database.readTrackerPauses(pageId);

      if (tracker == null) {
        _trackersByPageId.remove(pageId);
      } else {
        _trackersByPageId[pageId] = tracker;

        try {
          await _reminderService.syncReminder(tracker);
        } catch (error, stackTrace) {
          debugPrint(
            'No se pudo sincronizar el recordatorio '
            'del Tracker $pageId: $error',
          );

          debugPrintStack(stackTrace: stackTrace);
        }
      }

      _entriesByPageId[pageId] = entries;
      _pausesByPageId[pageId] = pauses;
      _loadedPageIds.add(pageId);
    } catch (error, stackTrace) {
      debugPrint('No se pudo cargar el Tracker $pageId: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _loadingPageIds.remove(pageId);
      notifyListeners();
    }
  }

  Future<void> updateTracker(TrackerData updatedTracker) async {
    final previousTracker = _trackersByPageId[updatedTracker.pageId];

    _trackersByPageId[updatedTracker.pageId] = updatedTracker;

    notifyListeners();

    try {
      await _database.upsertTrackerData(updatedTracker);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo actualizar el Tracker '
        '${updatedTracker.pageId}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      return;
    }

    if (!_reminderConfigurationChanged(previousTracker, updatedTracker)) {
      return;
    }

    try {
      await _reminderService.syncReminder(updatedTracker);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo actualizar el recordatorio '
        '${updatedTracker.pageId}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<TrackerData?> setStatus(
    String pageId,
    TrackerStatus nextStatus,
  ) async {
    final currentTracker = _trackersByPageId[pageId];

    if (currentTracker == null) {
      return null;
    }

    if (currentTracker.status == nextStatus) {
      return currentTracker;
    }

    final now = DateTime.now();
    final pauses = _pausesByPageId.putIfAbsent(pageId, () => <TrackerPause>[]);

    TrackerPause? createdPause;
    TrackerPause? closedPause;

    if (nextStatus == TrackerStatus.paused &&
        currentTracker.status != TrackerStatus.paused) {
      createdPause = TrackerPause(
        id: '${pageId}_${now.microsecondsSinceEpoch}',
        pageId: pageId,
        startedAt: now,
      );

      pauses.add(createdPause);
    }

    if (currentTracker.status == TrackerStatus.paused &&
        nextStatus != TrackerStatus.paused) {
      final openPauseIndex = pauses.lastIndexWhere((pause) => pause.isOpen);

      if (openPauseIndex != -1) {
        closedPause = pauses[openPauseIndex].copyWith(endedAt: now);

        pauses[openPauseIndex] = closedPause;
      }
    }

    final updatedTracker = currentTracker.copyWith(status: nextStatus);

    _trackersByPageId[pageId] = updatedTracker;
    notifyListeners();

    try {
      await _database.upsertTrackerData(updatedTracker);

      if (createdPause != null) {
        await _database.insertTrackerPause(createdPause);
      }

      if (closedPause != null && closedPause.endedAt != null) {
        await _database.closeTrackerPause(closedPause.id, closedPause.endedAt!);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo cambiar el estado '
        'del Tracker $pageId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _reminderService.syncReminder(updatedTracker);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo sincronizar el recordatorio '
        'del Tracker $pageId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }

    return updatedTracker;
  }

  String? validateStartDate(String pageId, DateTime startDate) {
    final today = DateTime.now();

    final normalizedStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final normalizedToday = DateTime(today.year, today.month, today.day);

    if (normalizedStartDate.isAfter(normalizedToday)) {
      return 'La fecha de inicio no puede estar en el futuro.';
    }

    final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

    final hasOlderEntries = entries.any((entry) {
      final entryDate = DateTime(
        entry.recordedAt.year,
        entry.recordedAt.month,
        entry.recordedAt.day,
      );

      return entryDate.isBefore(normalizedStartDate);
    });

    if (hasOlderEntries) {
      return 'Hay registros anteriores a esa fecha de inicio.';
    }

    return null;
  }

  String? validateEntry({
    required String pageId,
    required double value,
    required DateTime recordedAt,
    String? excludingEntryId,
  }) {
    final tracker = _trackersByPageId[pageId];

    if (tracker == null) {
      return 'No fue posible encontrar este Tracker.';
    }

    final isNewEntry = excludingEntryId == null;

    if (isNewEntry && tracker.status == TrackerStatus.paused) {
      return 'Reanuda el Tracker antes de registrar progreso.';
    }

    if (isNewEntry && tracker.status == TrackerStatus.completed) {
      return 'Este Tracker está finalizado.';
    }

    if (value <= 0) {
      return 'El valor debe ser mayor que cero.';
    }

    if (tracker.targetValue <= 0) {
      return 'La meta debe ser mayor que cero.';
    }

    if (tracker.metricType != TrackerMetricType.completion &&
        tracker.unit.trim().isEmpty) {
      return 'Debes escribir una unidad para este Tracker.';
    }

    final now = DateTime.now();

    if (recordedAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return 'No puedes crear registros en el futuro.';
    }

    final entryDate = DateTime(
      recordedAt.year,
      recordedAt.month,
      recordedAt.day,
    );

    final trackerStartDate = DateTime(
      tracker.startDate.year,
      tracker.startDate.month,
      tracker.startDate.day,
    );

    if (entryDate.isBefore(trackerStartDate)) {
      return 'El registro es anterior al inicio del Tracker.';
    }

    if (tracker.metricType == TrackerMetricType.completion) {
      final requestedPeriod = _periodStart(recordedAt, tracker.frequency);

      final entries = _entriesByPageId[pageId] ?? const <TrackerEntry>[];

      final duplicateExists = entries.any((entry) {
        if (entry.id == excludingEntryId) {
          return false;
        }

        final existingPeriod = _periodStart(
          entry.recordedAt,
          tracker.frequency,
        );

        return existingPeriod.millisecondsSinceEpoch ==
            requestedPeriod.millisecondsSinceEpoch;
      });

      if (duplicateExists) {
        return 'Ya existe un registro de cumplimiento para este período.';
      }
    }

    return null;
  }

  Future<TrackerEntry> addEntry({
    required String pageId,
    required double value,
    String note = '',
    DateTime? recordedAt,
    String? imagePath,
    String? sourceModule,
    String? externalId,
  }) async {
    final entryDate = recordedAt ?? DateTime.now();

    final normalizedSourceModule = sourceModule?.trim().toLowerCase();

    final normalizedExternalId = externalId?.trim();

    final hasSourceModule =
        normalizedSourceModule != null && normalizedSourceModule.isNotEmpty;

    final hasExternalId =
        normalizedExternalId != null && normalizedExternalId.isNotEmpty;

    if (hasSourceModule != hasExternalId) {
      throw ArgumentError('sourceModule y externalId deben enviarse juntos.');
    }

    if (hasSourceModule &&
        entryByExternalReference(
              pageId: pageId,
              sourceModule: normalizedSourceModule,
              externalId: normalizedExternalId!,
            ) !=
            null) {
      throw StateError('Este evento externo ya fue registrado.');
    }

    final validationMessage = validateEntry(
      pageId: pageId,
      value: value,
      recordedAt: entryDate,
    );

    if (validationMessage != null) {
      throw StateError(validationMessage);
    }

    final entry = TrackerEntry(
      id: '${pageId}_${DateTime.now().microsecondsSinceEpoch}',
      pageId: pageId,
      recordedAt: entryDate,
      value: value,
      note: note,
      imagePath: imagePath,
      sourceModule: hasSourceModule ? normalizedSourceModule : null,
      externalId: hasExternalId ? normalizedExternalId : null,
    );

    final entries = _entriesByPageId.putIfAbsent(
      pageId,
      () => <TrackerEntry>[],
    );

    entries
      ..add(entry)
      ..sort((first, second) {
        return second.recordedAt.compareTo(first.recordedAt);
      });

    notifyListeners();

    try {
      await _database.upsertTrackerEntry(entry);
    } catch (error, stackTrace) {
      entries.removeWhere((currentEntry) {
        return currentEntry.id == entry.id;
      });

      notifyListeners();

      await _imageService.deleteImage(imagePath);

      debugPrint(
        'No se pudo guardar el registro '
        '${entry.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    return entry;
  }

  Future<void> updateEntry(TrackerEntry updatedEntry) async {
    final validationMessage = validateEntry(
      pageId: updatedEntry.pageId,
      value: updatedEntry.value,
      recordedAt: updatedEntry.recordedAt,
      excludingEntryId: updatedEntry.id,
    );

    if (validationMessage != null) {
      throw StateError(validationMessage);
    }

    final entries = _entriesByPageId[updatedEntry.pageId];

    if (entries == null) {
      return;
    }

    final index = entries.indexWhere((entry) {
      return entry.id == updatedEntry.id;
    });

    if (index == -1) {
      return;
    }

    final previousEntry = entries[index];

    entries[index] = updatedEntry;

    entries.sort((first, second) {
      return second.recordedAt.compareTo(first.recordedAt);
    });

    notifyListeners();

    final imageWasChanged = previousEntry.imagePath != updatedEntry.imagePath;

    try {
      await _database.upsertTrackerEntry(updatedEntry);
    } catch (error, stackTrace) {
      final rollbackIndex = entries.indexWhere((entry) {
        return entry.id == previousEntry.id;
      });

      if (rollbackIndex == -1) {
        entries.add(previousEntry);
      } else {
        entries[rollbackIndex] = previousEntry;
      }

      entries.sort((first, second) {
        return second.recordedAt.compareTo(first.recordedAt);
      });

      notifyListeners();

      if (imageWasChanged) {
        await _imageService.deleteImage(updatedEntry.imagePath);
      }

      debugPrint(
        'No se pudo actualizar el registro '
        '${updatedEntry.id}: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    if (imageWasChanged) {
      await _imageService.deleteImage(previousEntry.imagePath);
    }
  }

  Future<void> deleteEntry({
    required String pageId,
    required String entryId,
  }) async {
    final entries = _entriesByPageId[pageId];

    if (entries == null) {
      return;
    }

    final entryIndex = entries.indexWhere((entry) {
      return entry.id == entryId;
    });

    if (entryIndex == -1) {
      return;
    }

    final removedEntry = entries.removeAt(entryIndex);

    notifyListeners();

    try {
      await _database.deleteTrackerEntry(entryId);
    } catch (error, stackTrace) {
      entries.add(removedEntry);

      entries.sort((first, second) {
        return second.recordedAt.compareTo(first.recordedAt);
      });

      notifyListeners();

      debugPrint(
        'No se pudo borrar el registro '
        '$entryId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }

    await _imageService.deleteImage(removedEntry.imagePath);
  }

  Future<void> deleteStoredImagesForPage(String pageId) async {
    await _imageService.deleteImagesForPage(pageId);
  }

  bool _reminderConfigurationChanged(
    TrackerData? previousTracker,
    TrackerData updatedTracker,
  ) {
    if (previousTracker == null) {
      return updatedTracker.reminderEnabled;
    }

    return previousTracker.reminderEnabled != updatedTracker.reminderEnabled ||
        previousTracker.reminderHour != updatedTracker.reminderHour ||
        previousTracker.reminderMinute != updatedTracker.reminderMinute ||
        previousTracker.frequency != updatedTracker.frequency ||
        previousTracker.status != updatedTracker.status ||
        previousTracker.startDate.year != updatedTracker.startDate.year ||
        previousTracker.startDate.month != updatedTracker.startDate.month ||
        previousTracker.startDate.day != updatedTracker.startDate.day;
  }

  void removeCachedTracker(String pageId, {bool notifyChanges = true}) {
    _trackersByPageId.remove(pageId);
    _entriesByPageId.remove(pageId);
    _pausesByPageId.remove(pageId);
    _loadedPageIds.remove(pageId);
    _loadingPageIds.remove(pageId);

    if (notifyChanges) {
      notifyListeners();
    }
  }
}
