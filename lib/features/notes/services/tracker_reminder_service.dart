import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class TrackerReminderService {
  TrackerReminderService._();

  static final TrackerReminderService instance = TrackerReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();

      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    } catch (error, stackTrace) {
      debugPrint('No se pudo configurar la zona horaria local: $error');

      debugPrintStack(stackTrace: stackTrace);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings: initializationSettings);

    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidImplementation
        ?.requestNotificationsPermission();

    // En versiones anteriores a Android 13 el método puede
    // devolver null porque el permiso no se solicita en runtime.
    return granted ?? true;
  }

  Future<void> syncReminder(TrackerData tracker) async {
    await initialize();

    await cancelReminder(tracker.pageId);

    if (!tracker.reminderEnabled || tracker.status != TrackerStatus.active) {
      return;
    }

    final scheduledDate = _nextScheduledDate(tracker);

    await _notifications.zonedSchedule(
      id: notificationIdForPage(tracker.pageId),
      title: 'NIMAHUB',
      body: 'Es hora de registrar tu progreso.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'nimahub_tracker_reminders',
          'Recordatorios de Tracker',
          channelDescription:
              'Recordatorios programados para '
              'los Trackers de NIMAHUB.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: _dateTimeComponentsFor(tracker.frequency),
      payload: 'tracker:${tracker.pageId}',
    );
  }

  Future<void> cancelReminder(String pageId) async {
    await initialize();

    await _notifications.cancel(id: notificationIdForPage(pageId));
  }

  int notificationIdForPage(String pageId) {
    var hash = 17;

    for (final codeUnit in pageId.codeUnits) {
      hash = ((hash * 37) + codeUnit) & 0x7FFFFFFF;
    }

    return hash;
  }

  DateTimeComponents _dateTimeComponentsFor(TrackerFrequency frequency) {
    switch (frequency) {
      case TrackerFrequency.daily:
        return DateTimeComponents.time;

      case TrackerFrequency.weekly:
        return DateTimeComponents.dayOfWeekAndTime;

      case TrackerFrequency.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }

  timezone.TZDateTime _nextScheduledDate(TrackerData tracker) {
    final now = timezone.TZDateTime.now(timezone.local);

    switch (tracker.frequency) {
      case TrackerFrequency.daily:
        return _nextDailyDate(
          now: now,
          hour: tracker.reminderHour,
          minute: tracker.reminderMinute,
        );

      case TrackerFrequency.weekly:
        return _nextWeeklyDate(
          now: now,
          weekday: tracker.startDate.weekday,
          hour: tracker.reminderHour,
          minute: tracker.reminderMinute,
        );

      case TrackerFrequency.monthly:
        return _nextMonthlyDate(
          now: now,
          day: tracker.startDate.day,
          hour: tracker.reminderHour,
          minute: tracker.reminderMinute,
        );
    }
  }

  timezone.TZDateTime _nextDailyDate({
    required timezone.TZDateTime now,
    required int hour,
    required int minute,
  }) {
    var scheduledDate = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      final tomorrow = now.add(const Duration(days: 1));

      scheduledDate = timezone.TZDateTime(
        timezone.local,
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        hour,
        minute,
      );
    }

    return scheduledDate;
  }

  timezone.TZDateTime _nextWeeklyDate({
    required timezone.TZDateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final daysUntilWeekday = (weekday - now.weekday) % 7;

    var targetDate = now.add(Duration(days: daysUntilWeekday));

    var scheduledDate = timezone.TZDateTime(
      timezone.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      targetDate = targetDate.add(const Duration(days: 7));

      scheduledDate = timezone.TZDateTime(
        timezone.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        hour,
        minute,
      );
    }

    return scheduledDate;
  }

  timezone.TZDateTime _nextMonthlyDate({
    required timezone.TZDateTime now,
    required int day,
    required int hour,
    required int minute,
  }) {
    var year = now.year;
    var month = now.month;

    while (true) {
      final daysInMonth = DateTime(year, month + 1, 0).day;

      if (day <= daysInMonth) {
        final scheduledDate = timezone.TZDateTime(
          timezone.local,
          year,
          month,
          day,
          hour,
          minute,
        );

        if (scheduledDate.isAfter(now)) {
          return scheduledDate;
        }
      }

      month++;

      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }
}
