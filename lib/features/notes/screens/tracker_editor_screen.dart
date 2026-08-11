import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nimahub_app/features/notes/controllers/notes_controller.dart';
import 'package:nimahub_app/features/notes/controllers/tracker_controller.dart';
import 'package:nimahub_app/features/notes/controllers/tracker_template_controller.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';
import 'package:nimahub_app/features/notes/services/tracker_entry_image_service.dart';
import 'package:nimahub_app/features/notes/services/tracker_reminder_service.dart';
import 'package:nimahub_app/features/notes/widgets/tracker_activity_calendar.dart';
import 'package:nimahub_app/features/notes/widgets/tracker_progress_chart.dart';
import 'package:nimahub_app/features/notes/widgets/tracker_statistics_panel.dart';

class TrackerEditorScreen extends StatefulWidget {
  const TrackerEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<TrackerEditorScreen> createState() => _TrackerEditorScreenState();
}

class _TrackerEditorScreenState extends State<TrackerEditorScreen>
    with WidgetsBindingObserver {
  final NotesController _notesController = NotesController.instance;
  final TrackerController _trackerController = TrackerController.instance;
  final TrackerTemplateController _templateController =
      TrackerTemplateController.instance;
  final TrackerEntryImageService _entryImageService =
      TrackerEntryImageService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  Timer? _titleSaveDebounce;
  Timer? _trackerSaveDebounce;

  Future<void> _titleSaveChain = Future<void>.value();
  Future<void> _trackerSaveChain = Future<void>.value();

  String? _lastQueuedTitle;
  TrackerData? _lastQueuedTracker;

  TrackerData? _draftTracker;
  bool _didSeedFields = false;

  bool _isClosing = false;
  bool _allowPop = false;

  bool _isRestoringRecoveredImage = false;
  bool _didCheckRecoveredImage = false;

  DateTime _selectedPeriodReference = DateTime.now();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final page = _notesController.noteById(widget.noteId);

    final storedTitle = page?.title ?? '';

    final hasAutomaticTitle =
        storedTitle.trim() == NotesController.untitledTrackerTitle;

    _titleController.text = hasAutomaticTitle ? '' : storedTitle;

    _lastQueuedTitle = storedTitle;

    _trackerController.addListener(_handleTrackerChanged);
    _seedTrackerFields(rebuild: false);

    unawaited(_loadTrackerAndRestoreRecoveredImage());
  }

  Future<void> _loadTrackerAndRestoreRecoveredImage() async {
    await _trackerController.loadTracker(widget.noteId);

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_restoreRecoveredEntryImage());
    });
  }

  Future<void> _restoreRecoveredEntryImage() async {
    if (_isRestoringRecoveredImage || _didCheckRecoveredImage) {
      return;
    }

    _isRestoringRecoveredImage = true;
    _didCheckRecoveredImage = true;

    try {
      final recoveredImage = await _entryImageService.takeRecoveredImage(
        widget.noteId,
      );

      if (recoveredImage == null || !mounted) {
        return;
      }

      final tracker =
          _draftTracker ?? _trackerController.trackerByPageId(widget.noteId);

      if (tracker == null) {
        _didCheckRecoveredImage = false;
        return;
      }

      TrackerEntry? entryToEdit;

      final recoveredEntryId = recoveredImage.entryId?.trim();

      if (recoveredEntryId != null && recoveredEntryId.isNotEmpty) {
        for (final entry in _trackerController.entriesForPage(widget.noteId)) {
          if (entry.id == recoveredEntryId) {
            entryToEdit = entry;
            break;
          }
        }

        if (entryToEdit == null) {
          await _entryImageService.discardRecoveredImage(
            recoveredImage.imagePath,
          );

          if (mounted) {
            _showTrackerMessage(
              'El registro que estabas editando '
              'ya no está disponible.',
            );
          }

          return;
        }
      }

      if (!mounted) {
        return;
      }

      await _showEntrySheet(
        tracker,
        entry: entryToEdit,
        initialDate: recoveredImage.selectedDate,
        recoveredImage: recoveredImage,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo restaurar la imagen '
        'del registro: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isRestoringRecoveredImage = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _titleSaveDebounce?.cancel();
    _trackerSaveDebounce?.cancel();

    _trackerController.removeListener(_handleTrackerChanged);

    unawaited(_flushPendingChanges());

    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }

    unawaited(_flushPendingChanges());
  }

  Future<void> _flushPendingChanges() async {
    _titleSaveDebounce?.cancel();
    _trackerSaveDebounce?.cancel();

    await Future.wait<void>([
      _saveTitle(useFallbackWhenEmpty: true),
      _saveTracker(),
    ]);
  }

  Future<void> _closeEditor() async {
    if (_isClosing) {
      return;
    }

    setState(() {
      _isClosing = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();

    await _flushPendingChanges();

    if (!mounted) {
      return;
    }

    setState(() {
      _allowPop = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    });
  }

  void _handleTrackerChanged() {
    _seedTrackerFields(rebuild: true);
  }

  void _seedTrackerFields({required bool rebuild}) {
    final storedTracker = _trackerController.trackerByPageId(widget.noteId);

    _draftTracker ??= storedTracker;
    _lastQueuedTracker ??= _draftTracker;

    final tracker = _draftTracker;

    if (tracker != null && !_didSeedFields) {
      _descriptionController.text = tracker.description;
      _targetController.text = _formatNumber(tracker.targetValue);
      _unitController.text = tracker.unit;

      _didSeedFields = true;
    }

    if (rebuild && mounted) {
      setState(() {});
    }
  }

  void _scheduleTitleSave() {
    _titleSaveDebounce?.cancel();

    _titleSaveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_saveTitle());
    });
  }

  Future<void> _saveTitle({bool useFallbackWhenEmpty = false}) {
    final page = _notesController.noteById(widget.noteId);

    if (page == null) {
      return _titleSaveChain;
    }

    var title = _titleController.text.trimRight();

    if (useFallbackWhenEmpty && title.trim().isEmpty) {
      title = NotesController.untitledTrackerTitle;
    }

    if (_lastQueuedTitle == title) {
      return _titleSaveChain;
    }

    _lastQueuedTitle = title;

    final pageToSave = page.copyWith(title: title);

    _titleSaveChain = _titleSaveChain
        .then((_) {
          return _notesController.updateNote(pageToSave);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'No se pudo guardar el título '
            'del Tracker: $error',
          );

          debugPrintStack(stackTrace: stackTrace);
        });

    return _titleSaveChain;
  }

  String _resolvedTrackerTitle() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      return NotesController.untitledTrackerTitle;
    }

    return title;
  }

  void _updateTracker(TrackerData Function(TrackerData tracker) change) {
    final current =
        _draftTracker ?? _trackerController.trackerByPageId(widget.noteId);

    if (current == null) {
      return;
    }

    setState(() {
      _draftTracker = change(current);
    });

    _trackerSaveDebounce?.cancel();

    _trackerSaveDebounce = Timer(const Duration(milliseconds: 420), () {
      unawaited(_saveTracker());
    });
  }

  Future<void> _saveTracker() {
    final tracker = _draftTracker;

    if (tracker == null) {
      return _trackerSaveChain;
    }

    if (identical(_lastQueuedTracker, tracker)) {
      return _trackerSaveChain;
    }

    _lastQueuedTracker = tracker;

    _trackerSaveChain = _trackerSaveChain
        .then((_) {
          return _trackerController.updateTracker(tracker);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'No se pudo guardar la configuración '
            'del Tracker: $error',
          );

          debugPrintStack(stackTrace: stackTrace);
        });

    return _trackerSaveChain;
  }

  void _changeMetricType(TrackerMetricType metricType) {
    final current =
        _draftTracker ?? _trackerController.trackerByPageId(widget.noteId);

    if (current == null) {
      return;
    }

    var updated = current.copyWith(metricType: metricType);

    if (metricType == TrackerMetricType.completion) {
      updated = updated.copyWith(targetValue: 1, unit: 'vez');

      _targetController.text = '1';
      _unitController.text = 'vez';
    }

    _updateTracker((_) => updated);
  }

  double? _parseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
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

  String _metricLabel(TrackerMetricType metricType) {
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

  String _reminderTimeLabel(TrackerData tracker) {
    return TimeOfDay(
      hour: tracker.reminderHour,
      minute: tracker.reminderMinute,
    ).format(context);
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'lunes';

      case DateTime.tuesday:
        return 'martes';

      case DateTime.wednesday:
        return 'miércoles';

      case DateTime.thursday:
        return 'jueves';

      case DateTime.friday:
        return 'viernes';

      case DateTime.saturday:
        return 'sábado';

      case DateTime.sunday:
        return 'domingo';

      default:
        return '';
    }
  }

  String _reminderDescription(TrackerData tracker) {
    final time = _reminderTimeLabel(tracker);

    switch (tracker.frequency) {
      case TrackerFrequency.daily:
        return 'Todos los días a las $time';

      case TrackerFrequency.weekly:
        return 'Cada ${_weekdayLabel(tracker.startDate.weekday)} a las $time';

      case TrackerFrequency.monthly:
        return 'El día ${tracker.startDate.day} '
            'de cada mes a las $time';
    }
  }

  Future<void> _setReminderEnabled(TrackerData tracker, bool enabled) async {
    if (enabled && tracker.status != TrackerStatus.active) {
      _showTrackerMessage(
        'Activa el Tracker antes de habilitar '
        'el recordatorio.',
      );

      return;
    }

    if (enabled) {
      final permissionGranted = await TrackerReminderService.instance
          .requestPermission();

      if (!mounted) {
        return;
      }

      if (!permissionGranted) {
        _showTrackerMessage(
          'Debes permitir las notificaciones '
          'para activar el recordatorio.',
        );

        return;
      }
    }

    final updatedTracker = tracker.copyWith(reminderEnabled: enabled);

    _trackerSaveDebounce?.cancel();

    setState(() {
      _draftTracker = updatedTracker;
      _lastQueuedTracker = updatedTracker;
    });

    await _trackerController.updateTracker(updatedTracker);

    if (!mounted) {
      return;
    }

    _showTrackerMessage(
      enabled ? 'Recordatorio activado.' : 'Recordatorio desactivado.',
    );
  }

  Future<void> _selectReminderTime(TrackerData tracker) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: tracker.reminderHour,
        minute: tracker.reminderMinute,
      ),
      helpText: 'Hora del recordatorio',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );

    if (selectedTime == null) {
      return;
    }

    final updatedTracker = tracker.copyWith(
      reminderHour: selectedTime.hour,
      reminderMinute: selectedTime.minute,
    );

    _trackerSaveDebounce?.cancel();

    setState(() {
      _draftTracker = updatedTracker;
      _lastQueuedTracker = updatedTracker;
    });

    await _trackerController.updateTracker(updatedTracker);

    if (!mounted) {
      return;
    }

    _showTrackerMessage(
      tracker.reminderEnabled
          ? 'Hora actualizada y recordatorio reprogramado.'
          : 'Hora del recordatorio actualizada.',
    );
  }

  String _periodTitle(TrackerFrequency frequency, DateTime referenceDate) {
    final selectedStart = _trackerController.periodStartFor(
      referenceDate,
      frequency,
    );

    final currentStart = _trackerController.periodStartFor(
      DateTime.now(),
      frequency,
    );

    if (selectedStart == currentStart) {
      switch (frequency) {
        case TrackerFrequency.daily:
          return 'Hoy';

        case TrackerFrequency.weekly:
          return 'Esta semana';

        case TrackerFrequency.monthly:
          return 'Este mes';
      }
    }

    final previousStart = _trackerController.previousPeriodStartFor(
      currentStart,
      frequency,
    );

    if (selectedStart == previousStart) {
      switch (frequency) {
        case TrackerFrequency.daily:
          return 'Ayer';

        case TrackerFrequency.weekly:
          return 'Semana anterior';

        case TrackerFrequency.monthly:
          return 'Mes anterior';
      }
    }

    switch (frequency) {
      case TrackerFrequency.daily:
        return _dateOnlyLabel(selectedStart);

      case TrackerFrequency.weekly:
        final periodEnd = _trackerController
            .nextPeriodStartFor(selectedStart, frequency)
            .subtract(const Duration(days: 1));

        return '${_dateOnlyLabel(selectedStart)} – '
            '${_dateOnlyLabel(periodEnd)}';

      case TrackerFrequency.monthly:
        const months = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre',
        ];

        return '${months[selectedStart.month - 1]} '
            '${selectedStart.year}';
    }
  }

  DateTime _summaryReferenceForSelectedPeriod(TrackerFrequency frequency) {
    final selectedStart = _trackerController.periodStartFor(
      _selectedPeriodReference,
      frequency,
    );

    final currentStart = _trackerController.periodStartFor(
      DateTime.now(),
      frequency,
    );

    if (selectedStart == currentStart) {
      return DateTime.now();
    }

    return _trackerController
        .nextPeriodStartFor(selectedStart, frequency)
        .subtract(const Duration(microseconds: 1));
  }

  bool _canMoveToPreviousPeriod(TrackerData tracker) {
    final selectedStart = _trackerController.periodStartFor(
      _selectedPeriodReference,
      tracker.frequency,
    );

    final trackerStart = _trackerController.periodStartFor(
      tracker.startDate,
      tracker.frequency,
    );

    return selectedStart.isAfter(trackerStart);
  }

  bool _canMoveToNextPeriod(TrackerData tracker) {
    final selectedStart = _trackerController.periodStartFor(
      _selectedPeriodReference,
      tracker.frequency,
    );

    final currentStart = _trackerController.periodStartFor(
      DateTime.now(),
      tracker.frequency,
    );

    return selectedStart.isBefore(currentStart);
  }

  void _moveSelectedPeriod({
    required TrackerData tracker,
    required bool forward,
  }) {
    final selectedStart = _trackerController.periodStartFor(
      _selectedPeriodReference,
      tracker.frequency,
    );

    final targetPeriod = forward
        ? _trackerController.nextPeriodStartFor(
            selectedStart,
            tracker.frequency,
          )
        : _trackerController.previousPeriodStartFor(
            selectedStart,
            tracker.frequency,
          );

    final trackerStart = _trackerController.periodStartFor(
      tracker.startDate,
      tracker.frequency,
    );

    final currentStart = _trackerController.periodStartFor(
      DateTime.now(),
      tracker.frequency,
    );

    if (targetPeriod.isBefore(trackerStart) ||
        targetPeriod.isAfter(currentStart)) {
      return;
    }

    setState(() {
      _selectedPeriodReference = targetPeriod;
    });
  }

  DateTime _entryDateForSelectedPeriod(TrackerData tracker) {
    final now = DateTime.now();

    final selectedStart = _trackerController.periodStartFor(
      _selectedPeriodReference,
      tracker.frequency,
    );

    final currentStart = _trackerController.periodStartFor(
      now,
      tracker.frequency,
    );

    if (selectedStart == currentStart) {
      return now;
    }

    var candidate = DateTime(
      selectedStart.year,
      selectedStart.month,
      selectedStart.day,
      12,
    );

    final trackerStart = DateTime(
      tracker.startDate.year,
      tracker.startDate.month,
      tracker.startDate.day,
      12,
    );

    if (candidate.isBefore(trackerStart)) {
      candidate = trackerStart;
    }

    return candidate;
  }

  void _changeFrequency(TrackerFrequency frequency) {
    setState(() {
      _selectedPeriodReference = DateTime.now();
    });

    _updateTracker((current) => current.copyWith(frequency: frequency));
  }

  String _dateLabel(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]} '
        '${date.year} · $hour:$minute';
  }

  String _entryValueLabel(TrackerEntry entry, TrackerData tracker) {
    if (tracker.metricType == TrackerMetricType.completion) {
      return 'Completado';
    }

    final unit = tracker.unit.trim();

    if (unit.isEmpty) {
      return _formatNumber(entry.value);
    }

    return '${_formatNumber(entry.value)} $unit';
  }

  String _dateOnlyLabel(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showTrackerMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String? _configurationValidationMessage(TrackerData tracker) {
    if (tracker.metricType == TrackerMetricType.completion) {
      return null;
    }

    final target = _parseNumber(_targetController.text);

    if (target == null || target <= 0) {
      return 'La meta debe ser mayor que cero.';
    }

    if (_unitController.text.trim().isEmpty) {
      return 'Debes escribir una unidad.';
    }

    return null;
  }

  Future<void> _changeStartDate(TrackerData tracker) async {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final currentStartDate = DateTime(
      tracker.startDate.year,
      tracker.startDate.month,
      tracker.startDate.day,
    );

    final initialDate = currentStartDate.isAfter(today)
        ? today
        : currentStartDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: today,
      helpText: 'Fecha de inicio del Tracker',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );

    if (selectedDate == null) {
      return;
    }

    final validationMessage = _trackerController.validateStartDate(
      widget.noteId,
      selectedDate,
    );

    if (validationMessage != null) {
      _showTrackerMessage(validationMessage);
      return;
    }

    final updatedTracker = tracker.copyWith(
      startDate: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      ),
    );

    _trackerSaveDebounce?.cancel();

    setState(() {
      _draftTracker = updatedTracker;
      _selectedPeriodReference = DateTime.now();
    });

    await _trackerController.updateTracker(updatedTracker);
  }

  Future<void> _changeStatus(TrackerStatus nextStatus) async {
    final currentTracker =
        _draftTracker ?? _trackerController.trackerByPageId(widget.noteId);

    if (currentTracker == null || currentTracker.status == nextStatus) {
      return;
    }

    final configurationMessage = _configurationValidationMessage(
      currentTracker,
    );

    if (configurationMessage != null) {
      _showTrackerMessage(configurationMessage);
      return;
    }

    _trackerSaveDebounce?.cancel();

    // Guarda primero los cambios pendientes del formulario.
    await _trackerController.updateTracker(currentTracker);

    final updatedTracker = await _trackerController.setStatus(
      widget.noteId,
      nextStatus,
    );

    if (!mounted || updatedTracker == null) {
      return;
    }

    setState(() {
      _draftTracker = updatedTracker;
    });
  }

  Future<ImageSource?> _showEntryImageSourcePicker(BuildContext parentContext) {
    return showModalBottomSheet<ImageSource>(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (sourceContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF17181D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Agregar imagen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: const Color(0xFF111216),
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Tomar una foto',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sourceContext).pop(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: const Color(0xFF111216),
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Elegir de la galería',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sourceContext).pop(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEntryImage(String imagePath) async {
    final imageFile = File(imagePath);

    if (!await imageFile.exists()) {
      _showTrackerMessage('La imagen ya no está disponible.');
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'No fue posible abrir la imagen.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEntrySheet(
    TrackerData tracker, {
    TrackerEntry? entry,
    DateTime? initialDate,
    RecoveredTrackerEntryImage? recoveredImage,
  }) async {
    final isEditing = entry != null;
    final isCompletion = tracker.metricType == TrackerMetricType.completion;

    final valueController = TextEditingController(
      text: isCompletion
          ? '1'
          : recoveredImage != null
          ? recoveredImage.valueText
          : entry == null
          ? ''
          : _formatNumber(entry.value),
    );

    final noteController = TextEditingController(
      text: recoveredImage?.note ?? entry?.note ?? '',
    );

    var selectedDate =
        recoveredImage?.selectedDate ??
        entry?.recordedAt ??
        initialDate ??
        DateTime.now();

    String? selectedImagePath = recoveredImage?.imagePath ?? entry?.imagePath;

    if (selectedImagePath != null && !File(selectedImagePath).existsSync()) {
      selectedImagePath = null;
    }

    XFile? pendingPickedImage = recoveredImage == null
        ? null
        : XFile(recoveredImage.imagePath);

    String? recoveredImagePath = recoveredImage?.imagePath;

    var didSaveEntry = false;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

            final previewFile = selectedImagePath == null
                ? null
                : File(selectedImagePath!);

            final hasPreviewImage = previewFile?.existsSync() ?? false;

            Future<void> chooseImage() async {
              FocusManager.instance.primaryFocus?.unfocus();

              final source = await _showEntryImageSourcePicker(sheetContext);

              if (source == null || !sheetContext.mounted) {
                return;
              }

              try {
                final pickedImage = await _entryImageService.pickImageForEntry(
                  source,
                  pickContext: TrackerEntryImagePickContext(
                    pageId: widget.noteId,
                    entryId: entry?.id,
                    selectedDate: selectedDate,
                    valueText: valueController.text,
                    note: noteController.text,
                  ),
                );

                if (pickedImage == null || !sheetContext.mounted) {
                  return;
                }

                final previousRecoveredImagePath = recoveredImagePath;

                if (previousRecoveredImagePath != null &&
                    previousRecoveredImagePath != pickedImage.path) {
                  await _entryImageService.discardRecoveredImage(
                    previousRecoveredImagePath,
                  );

                  recoveredImagePath = null;
                }

                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  pendingPickedImage = pickedImage;
                  selectedImagePath = pickedImage.path;
                });
              } catch (error, stackTrace) {
                debugPrint('No se pudo agregar la imagen: $error');

                debugPrintStack(stackTrace: stackTrace);

                if (!sheetContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(sheetContext)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No fue posible abrir la cámara '
                        'o la galería.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.92,
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111216),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isEditing ? 'Editar registro' : 'Registrar progreso',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!isCompletion)
                          TextField(
                            controller: valueController,
                            autofocus: !isEditing,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              tracker.unit.trim().isEmpty
                                  ? 'Valor'
                                  : 'Valor en ${tracker.unit}',
                            ),
                          ),
                        if (!isCompletion) const SizedBox(height: 12),
                        Material(
                          color: const Color(0xFF18191E),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: sheetContext,
                                initialDate: selectedDate,
                                firstDate: DateTime(
                                  tracker.startDate.year,
                                  tracker.startDate.month,
                                  tracker.startDate.day,
                                ),
                                lastDate: DateTime.now(),
                                helpText: isEditing
                                    ? 'Cambiar fecha del registro'
                                    : 'Fecha del registro',
                                cancelText: 'Cancelar',
                                confirmText: 'Seleccionar',
                              );

                              if (pickedDate == null) {
                                return;
                              }

                              setSheetState(() {
                                selectedDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  selectedDate.hour,
                                  selectedDate.minute,
                                );
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    color: Colors.white70,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _dateLabel(selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Nota opcional'),
                        ),
                        const SizedBox(height: 14),
                        if (hasPreviewImage) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.file(
                                previewFile!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF18191E),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white38,
                                      size: 34,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isSaving ? null : chooseImage,
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Reemplazar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Quitar imagen',
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final imagePathToDiscard =
                                            recoveredImagePath;

                                        setSheetState(() {
                                          selectedImagePath = null;
                                          pendingPickedImage = null;
                                          recoveredImagePath = null;
                                        });

                                        if (imagePathToDiscard != null) {
                                          await _entryImageService
                                              .discardRecoveredImage(
                                                imagePathToDiscard,
                                              );
                                        }
                                      },
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  backgroundColor: Colors.redAccent.withValues(
                                    alpha: 0.09,
                                  ),
                                  minimumSize: const Size(44, 44),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: isSaving ? null : chooseImage,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Agregar imagen opcional'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final value = isCompletion
                                      ? 1.0
                                      : _parseNumber(valueController.text);

                                  if (value == null || value <= 0) {
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ingresa un valor '
                                          'mayor que cero.',
                                        ),
                                      ),
                                    );

                                    return;
                                  }

                                  final validationMessage = _trackerController
                                      .validateEntry(
                                        pageId: widget.noteId,
                                        value: value,
                                        recordedAt: selectedDate,
                                        excludingEntryId: entry?.id,
                                      );

                                  if (validationMessage != null) {
                                    ScaffoldMessenger.of(sheetContext)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(validationMessage),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );

                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final note = noteController.text.trim();

                                  String? newlyPersistedImagePath;

                                  try {
                                    if (pendingPickedImage != null) {
                                      newlyPersistedImagePath =
                                          await _entryImageService.persistImage(
                                            pageId: widget.noteId,
                                            pickedImage: pendingPickedImage!,
                                          );
                                    }

                                    if (entry == null) {
                                      await _trackerController.addEntry(
                                        pageId: widget.noteId,
                                        value: value,
                                        note: note,
                                        recordedAt: selectedDate,
                                        imagePath: newlyPersistedImagePath,
                                      );
                                    } else {
                                      final clearImage =
                                          selectedImagePath == null;

                                      await _trackerController.updateEntry(
                                        entry.copyWith(
                                          value: value,
                                          note: note,
                                          recordedAt: selectedDate,
                                          imagePath: newlyPersistedImagePath,
                                          clearImagePath: clearImage,
                                        ),
                                      );
                                    }

                                    didSaveEntry = true;

                                    final temporaryRecoveredImagePath =
                                        recoveredImagePath;

                                    recoveredImagePath = null;

                                    if (temporaryRecoveredImagePath != null) {
                                      await _entryImageService
                                          .discardRecoveredImage(
                                            temporaryRecoveredImagePath,
                                          );
                                    }

                                    if (!sheetContext.mounted) {
                                      return;
                                    }

                                    Navigator.of(sheetContext).pop();
                                  } on StateError catch (error) {
                                    await _entryImageService.deleteImage(
                                      newlyPersistedImagePath,
                                    );

                                    if (!sheetContext.mounted) {
                                      return;
                                    }

                                    ScaffoldMessenger.of(sheetContext)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error.message.toString(),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                  } catch (error, stackTrace) {
                                    await _entryImageService.deleteImage(
                                      newlyPersistedImagePath,
                                    );

                                    debugPrint(
                                      'No se pudo guardar '
                                      'el registro: $error',
                                    );

                                    debugPrintStack(stackTrace: stackTrace);

                                    if (!sheetContext.mounted) {
                                      return;
                                    }

                                    ScaffoldMessenger.of(sheetContext)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No fue posible '
                                            'guardar el registro.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                  } finally {
                                    if (sheetContext.mounted) {
                                      setSheetState(() {
                                        isSaving = false;
                                      });
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  isEditing
                                      ? 'Guardar cambios'
                                      : 'Guardar registro',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final imagePathToDiscard = recoveredImagePath;

    if (!didSaveEntry && imagePathToDiscard != null) {
      await _entryImageService.discardRecoveredImage(imagePathToDiscard);
    }

    valueController.dispose();
    noteController.dispose();
  }

  Future<void> _showSaveAsTemplateDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await _flushPendingChanges();

    if (!mounted) {
      return;
    }

    final tracker =
        _draftTracker ?? _trackerController.trackerByPageId(widget.noteId);

    if (tracker == null) {
      _showTrackerMessage(
        'No fue posible cargar la configuración del Tracker.',
      );
      return;
    }

    final configurationMessage = _configurationValidationMessage(tracker);

    if (configurationMessage != null) {
      _showTrackerMessage(configurationMessage);
      return;
    }

    final currentTitle = _resolvedTrackerTitle();

    final nameController = TextEditingController(text: currentTitle);

    final descriptionController = TextEditingController();

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
                'Guardar como plantilla',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'La plantilla conservará la configuración, '
                      'pero no copiará registros, rachas ni historial.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Nombre de la plantilla',
                      ).copyWith(errorText: nameError),
                      onChanged: (_) {
                        if (nameError == null) {
                          return;
                        }

                        setDialogState(() {
                          nameError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Descripción opcional'),
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
                        nameError = 'Escribe un nombre para la plantilla.';
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
      await _templateController.createFromTracker(
        name: result['name'] ?? '',
        description: result['description'] ?? '',
        trackerTitle: currentTitle,
        tracker: tracker,
      );

      if (!mounted) {
        return;
      }

      _showTrackerMessage('Plantilla guardada correctamente.');
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      _showTrackerMessage(
        error.message?.toString() ?? 'No fue posible guardar la plantilla.',
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar la plantilla: $error');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showTrackerMessage('Ocurrió un error al guardar la plantilla.');
    }
  }

  Future<void> _confirmDeleteEntry(TrackerEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181D),
          title: const Text(
            'Eliminar registro',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Este registro se eliminará del historial.',
            style: TextStyle(color: Colors.white60),
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
      await _trackerController.deleteEntry(
        pageId: widget.noteId,
        entryId: entry.id,
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo eliminar el registro: $error');

      debugPrintStack(stackTrace: stackTrace);

      _showTrackerMessage('No fue posible eliminar el registro.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowPop || _isClosing) {
          return;
        }

        unawaited(_closeEditor());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _isClosing
                ? null
                : () {
                    unawaited(_closeEditor());
                  },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Tracker',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Guardar como plantilla',
              onPressed: _isClosing
                  ? null
                  : () {
                      unawaited(_showSaveAsTemplateDialog());
                    },
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedBuilder(
          animation: _trackerController,
          builder: (context, child) {
            final tracker =
                _draftTracker ??
                _trackerController.trackerByPageId(widget.noteId);

            if (tracker == null) {
              if (_trackerController.isLoading(widget.noteId)) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              return Center(
                child: Text(
                  'No fue posible cargar este Tracker.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              );
            }

            final metricIsCompletion =
                tracker.metricType == TrackerMetricType.completion;

            final selectedPeriodEntries = _trackerController.entriesForPeriod(
              widget.noteId,
              _selectedPeriodReference,
            );

            final selectedProgressSummary = _trackerController
                .progressSummaryForPage(
                  widget.noteId,
                  now: _summaryReferenceForSelectedPeriod(tracker.frequency),
                );

            final currentProgressSummary = _trackerController
                .progressSummaryForPage(widget.noteId);

            final analytics = _trackerController.analyticsForPage(
              widget.noteId,
            );

            final selectedPeriodTitle = _periodTitle(
              tracker.frequency,
              _selectedPeriodReference,
            );

            final canMoveToPrevious = _canMoveToPreviousPeriod(tracker);

            final canMoveToNext = _canMoveToNextPeriod(tracker);

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 48),
              children: [
                TextField(
                  controller: _titleController,
                  onChanged: (_) {
                    _scheduleTitleSave();
                  },
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: NotesController.untitledTrackerTitle,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  onChanged: (value) {
                    _updateTracker(
                      (current) => current.copyWith(description: value),
                    );
                  },
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white70),
                  decoration: _inputDecoration('Descripción opcional'),
                ),
                const SizedBox(height: 24),
                _TrackerPeriodNavigator(
                  title: selectedPeriodTitle,
                  onPrevious: canMoveToPrevious
                      ? () {
                          _moveSelectedPeriod(tracker: tracker, forward: false);
                        }
                      : null,
                  onNext: canMoveToNext
                      ? () {
                          _moveSelectedPeriod(tracker: tracker, forward: true);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                _TrackerProgressCard(
                  summary: selectedProgressSummary,
                  streakSummary: currentProgressSummary,
                  tracker: tracker,
                  periodLabel: selectedPeriodTitle,
                  formatNumber: _formatNumber,
                  onAddEntry: tracker.status == TrackerStatus.active
                      ? () {
                          final validationMessage =
                              _configurationValidationMessage(tracker);

                          if (validationMessage != null) {
                            _showTrackerMessage(validationMessage);
                            return;
                          }

                          unawaited(
                            _showEntrySheet(
                              tracker,
                              initialDate: _entryDateForSelectedPeriod(tracker),
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: 'Calendario de actividad'),
                const SizedBox(height: 10),
                TrackerActivityCalendar(
                  tracker: tracker,
                  selectedPeriod: _selectedPeriodReference,
                  activityForPeriod: (referenceDate) {
                    return _trackerController.activityForPeriod(
                      widget.noteId,
                      referenceDate,
                    );
                  },
                  onPeriodSelected: (periodStart) {
                    setState(() {
                      _selectedPeriodReference = periodStart;
                    });
                  },
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: 'Evolución'),
                const SizedBox(height: 10),
                TrackerProgressChart(
                  points: analytics.chartPoints,
                  tracker: tracker,
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: 'Estadísticas'),
                const SizedBox(height: 10),
                TrackerStatisticsPanel(
                  summary: analytics.statistics,
                  tracker: tracker,
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: 'Frecuencia'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TrackerFrequency.values.map((frequency) {
                    return _TrackerOptionChip(
                      label: _frequencyLabel(frequency),
                      selected: tracker.frequency == frequency,
                      onTap: () {
                        _changeFrequency(frequency);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Fecha de inicio'),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFF15161A),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      unawaited(_changeStartDate(tracker));
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _dateOnlyLabel(tracker.startDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Recordatorio'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF15161A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: tracker.reminderEnabled,
                        onChanged: (enabled) {
                          unawaited(_setReminderEnabled(tracker, enabled));
                        },
                        secondary: Icon(
                          tracker.reminderEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Activar recordatorio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          tracker.status == TrackerStatus.active
                              ? tracker.reminderEnabled
                                    ? _reminderDescription(tracker)
                                    : 'Sin recordatorio'
                              : tracker.reminderEnabled
                              ? 'Se reactivará cuando el Tracker '
                                    'vuelva a estar activo.'
                              : 'Sin recordatorio',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      ListTile(
                        enabled: tracker.reminderEnabled,
                        onTap: tracker.reminderEnabled
                            ? () {
                                unawaited(_selectReminderTime(tracker));
                              }
                            : null,
                        leading: const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Hora',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Text(
                          _reminderTimeLabel(tracker),
                          style: TextStyle(
                            color: tracker.reminderEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.25),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Tipo de seguimiento'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TrackerMetricType.values.map((metricType) {
                    return _TrackerOptionChip(
                      label: _metricLabel(metricType),
                      selected: tracker.metricType == metricType,
                      onTap: () {
                        _changeMetricType(metricType);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Objetivo'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetController,
                        enabled: !metricIsCompletion,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: (value) {
                          final target = _parseNumber(value);

                          if (target != null && target > 0) {
                            _updateTracker(
                              (current) =>
                                  current.copyWith(targetValue: target),
                            );
                          }
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Meta'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        enabled: !metricIsCompletion,
                        onChanged: (value) {
                          _updateTracker(
                            (current) => current.copyWith(unit: value),
                          );
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Unidad'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Estado'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TrackerStatus.values.map((status) {
                    return _TrackerOptionChip(
                      label: _statusLabel(status),
                      selected: tracker.status == status,
                      onTap: () {
                        unawaited(_changeStatus(status));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Historial'),
                const SizedBox(height: 10),
                if (selectedPeriodEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15161A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: Colors.white.withValues(alpha: 0.28),
                          size: 28,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'No hay registros en este período.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...selectedPeriodEntries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TrackerHistoryTile(
                        value: _entryValueLabel(entry, tracker),
                        date: _dateLabel(entry.recordedAt),
                        note: entry.note,
                        imagePath: entry.imagePath,
                        onImageTap: () {
                          final imagePath = entry.imagePath;

                          if (imagePath == null) {
                            return;
                          }

                          unawaited(_showEntryImage(imagePath));
                        },
                        onEdit: () {
                          unawaited(_showEntrySheet(tracker, entry: entry));
                        },
                        onDelete: () {
                          unawaited(_confirmDeleteEntry(entry));
                        },
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      filled: true,
      fillColor: const Color(0xFF15161A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.52)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _TrackerOptionChip extends StatelessWidget {
  const _TrackerOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFF17181D),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TrackerPeriodNavigator extends StatelessWidget {
  const _TrackerPeriodNavigator({
    required this.title,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Período anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Período siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _TrackerProgressCard extends StatelessWidget {
  const _TrackerProgressCard({
    required this.summary,
    required this.streakSummary,
    required this.tracker,
    required this.periodLabel,
    required this.formatNumber,
    required this.onAddEntry,
  });

  final TrackerProgressSummary summary;
  final TrackerProgressSummary streakSummary;
  final TrackerData tracker;
  final String periodLabel;
  final String Function(double value) formatNumber;
  final VoidCallback? onAddEntry;

  @override
  Widget build(BuildContext context) {
    final isCompletion = tracker.metricType == TrackerMetricType.completion;

    final percentage = (summary.progress * 100).round();

    final progressText = isCompletion
        ? summary.isCurrentPeriodCompleted
              ? 'Completado'
              : 'Pendiente'
        : '${formatNumber(summary.currentValue)} de '
              '${formatNumber(summary.targetValue)} '
              '${tracker.unit}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.035),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: summary.progress,
                        strokeWidth: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Progreso · $periodLabel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TrackerStatBox(
                  icon: Icons.local_fire_department_outlined,
                  value: '${streakSummary.currentStreak}',
                  label: 'Racha actual',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _TrackerStatBox(
                  icon: Icons.emoji_events_outlined,
                  value: '${streakSummary.bestStreak}',
                  label: 'Mejor racha',
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _TrackerStatBox(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${streakSummary.completedPeriods}',
                  label: 'Completados',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddEntry,
            icon: Icon(
              tracker.status == TrackerStatus.active
                  ? Icons.add_rounded
                  : Icons.lock_outline_rounded,
            ),
            label: Text(switch (tracker.status) {
              TrackerStatus.active => 'Registrar progreso',
              TrackerStatus.paused => 'Tracker pausado',
              TrackerStatus.completed => 'Tracker finalizado',
            }, style: const TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerStatBox extends StatelessWidget {
  const _TrackerStatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerHistoryTile extends StatelessWidget {
  const _TrackerHistoryTile({
    required this.value,
    required this.date,
    required this.note,
    required this.imagePath,
    required this.onImageTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String value;
  final String date;
  final String note;
  final String? imagePath;
  final VoidCallback onImageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageFile = imagePath == null ? null : File(imagePath!);

    final hasImage = imageFile?.existsSync() ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasImage ? onImageTap : null,
            child: Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(hasImage ? 12 : 26),
              ),
              child: hasImage
                  ? Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 21,
                        );
                      },
                    )
                  : const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar registro',
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(
              Icons.edit_outlined,
              color: Colors.white.withValues(alpha: 0.48),
              size: 19,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar registro',
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white.withValues(alpha: 0.34),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
