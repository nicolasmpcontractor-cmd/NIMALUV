import 'package:flutter/material.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';

class TrackerStatisticsPanel extends StatelessWidget {
  const TrackerStatisticsPanel({
    super.key,
    required this.summary,
    required this.tracker,
  });

  final TrackerStatisticsSummary summary;
  final TrackerData tracker;

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _valueWithUnit(double value) {
    final formattedValue = _formatNumber(value);

    if (tracker.metricType == TrackerMetricType.completion) {
      return formattedValue;
    }

    final unit = tracker.unit.trim();

    return unit.isEmpty ? formattedValue : '$formattedValue $unit';
  }

  String _bestPeriodLabel() {
    final date = summary.bestPeriodStart;

    if (date == null) {
      return 'Sin datos';
    }

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

    return switch (tracker.frequency) {
      TrackerFrequency.daily =>
        '${date.day} ${months[date.month - 1]} ${date.year}',
      TrackerFrequency.weekly =>
        'Semana del ${date.day} ${months[date.month - 1]}',
      TrackerFrequency.monthly => '${months[date.month - 1]} ${date.year}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final completionPercentage = (summary.completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 9) / 2;

              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.percent_rounded,
                      value: '$completionPercentage%',
                      label: 'Cumplimiento',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.functions_rounded,
                      value: _valueWithUnit(summary.totalValue),
                      label: 'Total acumulado',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.show_chart_rounded,
                      value: _valueWithUnit(summary.averageValue),
                      label: 'Promedio por período',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.emoji_events_outlined,
                      value: summary.bestPeriodStart == null
                          ? '—'
                          : _valueWithUnit(summary.bestPeriodValue),
                      label: 'Mejor período',
                      detail: _bestPeriodLabel(),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.check_circle_outline_rounded,
                      value: '${summary.completedPeriods}',
                      label: 'Completados',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _TrackerStatisticItem(
                      icon: Icons.remove_circle_outline_rounded,
                      value: '${summary.missedPeriods}',
                      label: 'No logrados',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${summary.pausedPeriods} períodos pausados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                '${summary.activePeriods} períodos activos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackerStatisticItem extends StatelessWidget {
  const _TrackerStatisticItem({
    required this.icon,
    required this.value,
    required this.label,
    this.detail,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 18),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 9,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
