import 'package:flutter/material.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';

typedef TrackerActivityResolver =
    TrackerPeriodActivity Function(DateTime referenceDate);

class TrackerActivityCalendar extends StatefulWidget {
  const TrackerActivityCalendar({
    super.key,
    required this.tracker,
    required this.selectedPeriod,
    required this.activityForPeriod,
    required this.onPeriodSelected,
  });

  final TrackerData tracker;
  final DateTime selectedPeriod;
  final TrackerActivityResolver activityForPeriod;
  final ValueChanged<DateTime> onPeriodSelected;

  @override
  State<TrackerActivityCalendar> createState() {
    return _TrackerActivityCalendarState();
  }
}

class _TrackerActivityCalendarState extends State<TrackerActivityCalendar> {
  late DateTime _visibleAnchor;

  @override
  void initState() {
    super.initState();
    _visibleAnchor = widget.selectedPeriod;
  }

  @override
  void didUpdateWidget(covariant TrackerActivityCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectedPeriodChanged =
        oldWidget.selectedPeriod != widget.selectedPeriod;

    final frequencyChanged =
        oldWidget.tracker.frequency != widget.tracker.frequency;

    if (selectedPeriodChanged || frequencyChanged) {
      _visibleAnchor = widget.selectedPeriod;
    }
  }

  DateTime get _visibleMonth {
    return DateTime(_visibleAnchor.year, _visibleAnchor.month);
  }

  DateTime get _trackerStartMonth {
    return DateTime(
      widget.tracker.startDate.year,
      widget.tracker.startDate.month,
    );
  }

  DateTime get _currentMonth {
    final now = DateTime.now();

    return DateTime(now.year, now.month);
  }

  bool get _canMoveBackward {
    switch (widget.tracker.frequency) {
      case TrackerFrequency.daily:
      case TrackerFrequency.weekly:
        return _visibleMonth.isAfter(_trackerStartMonth);

      case TrackerFrequency.monthly:
        return _visibleAnchor.year > widget.tracker.startDate.year;
    }
  }

  bool get _canMoveForward {
    switch (widget.tracker.frequency) {
      case TrackerFrequency.daily:
      case TrackerFrequency.weekly:
        return _visibleMonth.isBefore(_currentMonth);

      case TrackerFrequency.monthly:
        return _visibleAnchor.year < DateTime.now().year;
    }
  }

  void _moveVisiblePeriod(int amount) {
    if (amount < 0 && !_canMoveBackward) {
      return;
    }

    if (amount > 0 && !_canMoveForward) {
      return;
    }

    setState(() {
      switch (widget.tracker.frequency) {
        case TrackerFrequency.daily:
        case TrackerFrequency.weekly:
          _visibleAnchor = DateTime(
            _visibleAnchor.year,
            _visibleAnchor.month + amount,
          );

        case TrackerFrequency.monthly:
          _visibleAnchor = DateTime(_visibleAnchor.year + amount);
      }
    });
  }

  String get _headerTitle {
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

    switch (widget.tracker.frequency) {
      case TrackerFrequency.daily:
        return '${months[_visibleAnchor.month - 1]} '
            '${_visibleAnchor.year}';

      case TrackerFrequency.weekly:
        return 'Semanas · '
            '${months[_visibleAnchor.month - 1]} '
            '${_visibleAnchor.year}';

      case TrackerFrequency.monthly:
        return '${_visibleAnchor.year}';
    }
  }

  bool _isSelected(DateTime periodStart) {
    final selected = widget.selectedPeriod;

    switch (widget.tracker.frequency) {
      case TrackerFrequency.daily:
        return periodStart.year == selected.year &&
            periodStart.month == selected.month &&
            periodStart.day == selected.day;

      case TrackerFrequency.weekly:
        final selectedStart = selected.subtract(
          Duration(days: selected.weekday - DateTime.monday),
        );

        return periodStart.year == selectedStart.year &&
            periodStart.month == selectedStart.month &&
            periodStart.day == selectedStart.day;

      case TrackerFrequency.monthly:
        return periodStart.year == selected.year &&
            periodStart.month == selected.month;
    }
  }

  String _shortDate(DateTime date) {
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

    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          switch (widget.tracker.frequency) {
            TrackerFrequency.daily => _buildDailyCalendar(),
            TrackerFrequency.weekly => _buildWeeklyCalendar(),
            TrackerFrequency.monthly => _buildMonthlyCalendar(),
          },
          const SizedBox(height: 14),
          const _TrackerActivityLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Anterior',
          onPressed: _canMoveBackward
              ? () {
                  _moveVisiblePeriod(-1);
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: Colors.white,
          disabledColor: Colors.white24,
        ),
        Expanded(
          child: Text(
            _headerTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: _canMoveForward
              ? () {
                  _moveVisiblePeriod(1);
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: Colors.white,
          disabledColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildDailyCalendar() {
    final monthStart = DateTime(_visibleAnchor.year, _visibleAnchor.month);

    final daysInMonth = DateUtils.getDaysInMonth(
      monthStart.year,
      monthStart.month,
    );

    final leadingEmptyCells = monthStart.weekday - DateTime.monday;

    final usedCells = leadingEmptyCells + daysInMonth;

    final totalCells = ((usedCells + 6) ~/ 7) * 7;

    return Column(
      children: [
        const Row(
          children: [
            _WeekdayLabel('L'),
            _WeekdayLabel('M'),
            _WeekdayLabel('X'),
            _WeekdayLabel('J'),
            _WeekdayLabel('V'),
            _WeekdayLabel('S'),
            _WeekdayLabel('D'),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingEmptyCells + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(monthStart.year, monthStart.month, dayNumber);

            final activity = widget.activityForPeriod(date);

            return _TrackerActivityDayCell(
              day: dayNumber,
              activity: activity,
              selected: _isSelected(activity.periodStart),
              onTap: activity.isSelectable
                  ? () {
                      widget.onPeriodSelected(activity.periodStart);
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendar() {
    final monthStart = DateTime(_visibleAnchor.year, _visibleAnchor.month);

    final monthEnd = DateTime(_visibleAnchor.year, _visibleAnchor.month + 1, 0);

    var weekStart = monthStart.subtract(
      Duration(days: monthStart.weekday - DateTime.monday),
    );

    final weeks = <DateTime>[];

    while (!weekStart.isAfter(monthEnd)) {
      weeks.add(weekStart);
      weekStart = weekStart.add(const Duration(days: 7));
    }

    return Column(
      children: weeks.map((start) {
        final end = start.add(const Duration(days: 6));

        final activity = widget.activityForPeriod(start);

        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _TrackerActivityPeriodTile(
            title:
                '${_shortDate(start)} – '
                '${_shortDate(end)}',
            activity: activity,
            selected: _isSelected(activity.periodStart),
            onTap: activity.isSelectable
                ? () {
                    widget.onPeriodSelected(activity.periodStart);
                  }
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyCalendar() {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final monthStart = DateTime(_visibleAnchor.year, index + 1);

        final activity = widget.activityForPeriod(monthStart);

        return _TrackerActivityPeriodTile(
          title: months[index],
          compact: true,
          activity: activity,
          selected: _isSelected(activity.periodStart),
          onTap: activity.isSelectable
              ? () {
                  widget.onPeriodSelected(activity.periodStart);
                }
              : null,
        );
      },
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrackerActivityDayCell extends StatelessWidget {
  const _TrackerActivityDayCell({
    required this.day,
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final TrackerPeriodActivity activity;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final completed = activity.state == TrackerActivityState.completed;

    final paused = activity.state == TrackerActivityState.paused;

    final incomplete = activity.state == TrackerActivityState.incomplete;

    final disabled = !activity.isSelectable;

    final backgroundColor = completed
        ? Colors.white
        : paused
        ? Colors.white.withValues(alpha: 0.11)
        : incomplete
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.transparent;

    final foregroundColor = completed
        ? Colors.black
        : disabled
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.72);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: disabled ? 0.03 : 0.10),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: completed ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              if (paused)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Icon(
                    Icons.pause_rounded,
                    size: 9,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                )
              else if (incomplete)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else if (completed)
                const Positioned(
                  right: 3,
                  bottom: 3,
                  child: Icon(
                    Icons.check_rounded,
                    size: 9,
                    color: Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerActivityPeriodTile extends StatelessWidget {
  const _TrackerActivityPeriodTile({
    required this.title,
    required this.activity,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final TrackerPeriodActivity activity;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final completed = activity.state == TrackerActivityState.completed;

    final paused = activity.state == TrackerActivityState.paused;

    final disabled = !activity.isSelectable;

    final percentage = (activity.progress * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: completed
                ? Colors.white
                : paused
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: disabled ? 0.03 : 0.09),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: completed
                            ? Colors.black
                            : disabled
                            ? Colors.white24
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _activityLabel(activity, percentage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: completed ? Colors.black54 : Colors.white38,
                        fontSize: 8,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: completed
                              ? Colors.black
                              : disabled
                              ? Colors.white24
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      _activityLabel(activity, percentage),
                      style: TextStyle(
                        color: completed
                            ? Colors.black54
                            : Colors.white.withValues(alpha: 0.42),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _activityLabel(TrackerPeriodActivity activity, int percentage) {
    switch (activity.state) {
      case TrackerActivityState.beforeStart:
        return 'No iniciado';

      case TrackerActivityState.future:
        return 'Futuro';

      case TrackerActivityState.noActivity:
        return 'Sin actividad';

      case TrackerActivityState.incomplete:
        return '$percentage%';

      case TrackerActivityState.completed:
        return 'Completado';

      case TrackerActivityState.paused:
        return 'Pausado';
    }
  }
}

class _TrackerActivityLegend extends StatelessWidget {
  const _TrackerActivityLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _TrackerActivityLegendItem(
          label: 'Completado',
          state: TrackerActivityState.completed,
        ),
        _TrackerActivityLegendItem(
          label: 'Incompleto',
          state: TrackerActivityState.incomplete,
        ),
        _TrackerActivityLegendItem(
          label: 'Pausado',
          state: TrackerActivityState.paused,
        ),
        _TrackerActivityLegendItem(
          label: 'Sin actividad',
          state: TrackerActivityState.noActivity,
        ),
      ],
    );
  }
}

class _TrackerActivityLegendItem extends StatelessWidget {
  const _TrackerActivityLegendItem({required this.label, required this.state});

  final String label;
  final TrackerActivityState state;

  @override
  Widget build(BuildContext context) {
    final completed = state == TrackerActivityState.completed;

    final paused = state == TrackerActivityState.paused;

    final incomplete = state == TrackerActivityState.incomplete;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: completed
                ? Colors.white
                : paused
                ? Colors.white.withValues(alpha: 0.20)
                : incomplete
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Colors.white.withValues(alpha: completed ? 1 : 0.18),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
