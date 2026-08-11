enum TrackerFrequency { daily, weekly, monthly }

enum TrackerMetricType { completion, count, duration, quantity }

enum TrackerStatus { active, paused, completed }

enum TrackerActivityState {
  beforeStart,
  future,
  noActivity,
  incomplete,
  completed,
  paused,
}

class TrackerData {
  const TrackerData({
    required this.pageId,
    required this.description,
    required this.frequency,
    required this.metricType,
    required this.targetValue,
    required this.unit,
    required this.status,
    required this.startDate,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
  });

  factory TrackerData.initial({
    required String pageId,
    required DateTime startDate,
  }) {
    return TrackerData(
      pageId: pageId,
      description: '',
      frequency: TrackerFrequency.daily,
      metricType: TrackerMetricType.completion,
      targetValue: 1,
      unit: 'vez',
      status: TrackerStatus.active,
      startDate: startDate,
      reminderEnabled: false,
      reminderHour: 8,
      reminderMinute: 0,
    );
  }

  final String pageId;
  final String description;
  final TrackerFrequency frequency;
  final TrackerMetricType metricType;
  final double targetValue;
  final String unit;
  final TrackerStatus status;
  final DateTime startDate;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  TrackerData copyWith({
    String? description,
    TrackerFrequency? frequency,
    TrackerMetricType? metricType,
    double? targetValue,
    String? unit,
    TrackerStatus? status,
    DateTime? startDate,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return TrackerData(
      pageId: pageId,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      metricType: metricType ?? this.metricType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}

class TrackerEntry {
  const TrackerEntry({
    required this.id,
    required this.pageId,
    required this.recordedAt,
    required this.value,
    this.note = '',
    this.imagePath,
    this.sourceModule,
    this.externalId,
  });

  final String id;
  final String pageId;
  final DateTime recordedAt;
  final double value;
  final String note;
  final String? imagePath;

  // Referencia del módulo que originó el registro.
  // Los registros manuales mantienen ambos campos en null.
  final String? sourceModule;
  final String? externalId;

  bool get isExternal {
    return sourceModule != null &&
        sourceModule!.trim().isNotEmpty &&
        externalId != null &&
        externalId!.trim().isNotEmpty;
  }

  TrackerEntry copyWith({
    DateTime? recordedAt,
    double? value,
    String? note,
    String? imagePath,
    bool clearImagePath = false,
    String? sourceModule,
    String? externalId,
  }) {
    return TrackerEntry(
      id: id,
      pageId: pageId,
      recordedAt: recordedAt ?? this.recordedAt,
      value: value ?? this.value,
      note: note ?? this.note,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      sourceModule: sourceModule ?? this.sourceModule,
      externalId: externalId ?? this.externalId,
    );
  }
}

enum TrackerIntegrationOutcome { created, updated, unchanged }

class TrackerIntegrationResult {
  const TrackerIntegrationResult({required this.entry, required this.outcome});

  final TrackerEntry entry;
  final TrackerIntegrationOutcome outcome;

  bool get wasCreated {
    return outcome == TrackerIntegrationOutcome.created;
  }

  bool get wasUpdated {
    return outcome == TrackerIntegrationOutcome.updated;
  }
}

class TrackerProgressSummary {
  const TrackerProgressSummary({
    required this.currentValue,
    required this.targetValue,
    required this.progress,
    required this.currentStreak,
    required this.bestStreak,
    required this.completedPeriods,
  });

  const TrackerProgressSummary.empty()
    : currentValue = 0,
      targetValue = 1,
      progress = 0,
      currentStreak = 0,
      bestStreak = 0,
      completedPeriods = 0;

  final double currentValue;
  final double targetValue;
  final double progress;
  final int currentStreak;
  final int bestStreak;
  final int completedPeriods;

  bool get isCurrentPeriodCompleted {
    return currentValue >= targetValue;
  }
}

class TrackerPause {
  const TrackerPause({
    required this.id,
    required this.pageId,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String pageId;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isOpen => endedAt == null;

  TrackerPause copyWith({DateTime? endedAt}) {
    return TrackerPause(
      id: id,
      pageId: pageId,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

class TrackerPeriodActivity {
  const TrackerPeriodActivity({
    required this.periodStart,
    required this.value,
    required this.targetValue,
    required this.progress,
    required this.state,
  });

  final DateTime periodStart;
  final double value;
  final double targetValue;
  final double progress;
  final TrackerActivityState state;

  bool get isSelectable {
    return state != TrackerActivityState.beforeStart &&
        state != TrackerActivityState.future;
  }

  bool get isCompleted {
    return state == TrackerActivityState.completed;
  }
}

class TrackerChartPoint {
  const TrackerChartPoint({
    required this.periodStart,
    required this.value,
    required this.targetValue,
    required this.progress,
    required this.state,
  });

  final DateTime periodStart;
  final double value;
  final double targetValue;
  final double progress;
  final TrackerActivityState state;
}

class TrackerStatisticsSummary {
  const TrackerStatisticsSummary({
    required this.totalValue,
    required this.averageValue,
    required this.completionRate,
    required this.bestPeriodValue,
    required this.bestPeriodStart,
    required this.completedPeriods,
    required this.missedPeriods,
    required this.pausedPeriods,
    required this.activePeriods,
  });

  const TrackerStatisticsSummary.empty()
    : totalValue = 0,
      averageValue = 0,
      completionRate = 0,
      bestPeriodValue = 0,
      bestPeriodStart = null,
      completedPeriods = 0,
      missedPeriods = 0,
      pausedPeriods = 0,
      activePeriods = 0;

  final double totalValue;
  final double averageValue;
  final double completionRate;
  final double bestPeriodValue;
  final DateTime? bestPeriodStart;
  final int completedPeriods;
  final int missedPeriods;
  final int pausedPeriods;
  final int activePeriods;
}

class TrackerAnalyticsData {
  const TrackerAnalyticsData({
    required this.chartPoints,
    required this.statistics,
  });

  const TrackerAnalyticsData.empty()
    : chartPoints = const <TrackerChartPoint>[],
      statistics = const TrackerStatisticsSummary.empty();

  final List<TrackerChartPoint> chartPoints;
  final TrackerStatisticsSummary statistics;
}

class TrackerTemplate {
  const TrackerTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.trackerTitle,
    required this.trackerDescription,
    required this.frequency,
    required this.metricType,
    required this.targetValue,
    required this.unit,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  // Información propia de la plantilla.
  final String name;
  final String description;

  // Información que se copiará al nuevo Tracker.
  final String trackerTitle;
  final String trackerDescription;
  final TrackerFrequency frequency;
  final TrackerMetricType metricType;
  final double targetValue;
  final String unit;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  final DateTime createdAt;
  final DateTime updatedAt;

  TrackerTemplate copyWith({
    String? name,
    String? description,
    String? trackerTitle,
    String? trackerDescription,
    TrackerFrequency? frequency,
    TrackerMetricType? metricType,
    double? targetValue,
    String? unit,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    DateTime? updatedAt,
  }) {
    return TrackerTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      trackerTitle: trackerTitle ?? this.trackerTitle,
      trackerDescription: trackerDescription ?? this.trackerDescription,
      frequency: frequency ?? this.frequency,
      metricType: metricType ?? this.metricType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  TrackerData createTrackerData({
    required String pageId,
    required DateTime startDate,
  }) {
    return TrackerData(
      pageId: pageId,
      description: trackerDescription,
      frequency: frequency,
      metricType: metricType,
      targetValue: targetValue,
      unit: unit,
      status: TrackerStatus.active,
      startDate: startDate,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
  }
}
