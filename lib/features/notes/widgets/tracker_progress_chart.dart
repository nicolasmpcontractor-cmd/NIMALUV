import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nimahub_app/features/notes/models/tracker_models.dart';

class TrackerProgressChart extends StatelessWidget {
  const TrackerProgressChart({
    super.key,
    required this.points,
    required this.tracker,
  });

  final List<TrackerChartPoint> points;
  final TrackerData tracker;

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _valueLabel(double value) {
    if (tracker.metricType == TrackerMetricType.completion) {
      return value >= tracker.targetValue ? 'Completado' : 'Pendiente';
    }

    final unit = tracker.unit.trim();

    return unit.isEmpty
        ? _formatNumber(value)
        : '${_formatNumber(value)} $unit';
  }

  String _periodRangeLabel() {
    final amount = points.length;

    return switch (tracker.frequency) {
      TrackerFrequency.daily => 'Últimos $amount días',
      TrackerFrequency.weekly => 'Últimas $amount semanas',
      TrackerFrequency.monthly => 'Últimos $amount meses',
    };
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

    return switch (tracker.frequency) {
      TrackerFrequency.daily => '${date.day} ${months[date.month - 1]}',
      TrackerFrequency.weekly => '${date.day} ${months[date.month - 1]}',
      TrackerFrequency.monthly => '${months[date.month - 1]} ${date.year}',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF15161A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Text(
          'Todavía no hay períodos para mostrar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        ),
      );
    }

    final latestPoint = points.last;
    final middlePoint = points[points.length ~/ 2];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _periodRangeLabel(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _valueLabel(latestPoint.value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrackerLineChartPainter(
                points: points,
                targetValue: tracker.targetValue,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  _shortDate(points.first.periodStart),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 9,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _shortDate(middlePoint.periodStart),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 9,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _shortDate(points.last.periodStart),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              const _ChartLegendItem(label: 'Progreso', solid: true),
              _ChartLegendItem(
                label: 'Meta ${_formatNumber(tracker.targetValue)}',
                solid: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackerLineChartPainter extends CustomPainter {
  const _TrackerLineChartPainter({
    required this.points,
    required this.targetValue,
  });

  final List<TrackerChartPoint> points;
  final double targetValue;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 6.0;
    const rightPadding = 6.0;
    const topPadding = 8.0;
    const bottomPadding = 8.0;

    final chartWidth = size.width - leftPadding - rightPadding;

    final chartHeight = size.height - topPadding - bottomPadding;

    var maximumValue = math.max(
      targetValue,
      points.fold<double>(0, (currentMaximum, point) {
        return math.max(currentMaximum, point.value);
      }),
    );

    if (maximumValue <= 0) {
      maximumValue = 1;
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    for (var index = 0; index <= 3; index++) {
      final y = topPadding + chartHeight * index / 3;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    double xForIndex(int index) {
      if (points.length == 1) {
        return leftPadding + chartWidth / 2;
      }

      return leftPadding + chartWidth * index / (points.length - 1);
    }

    double yForValue(double value) {
      final normalized = (value / maximumValue).clamp(0.0, 1.0);

      return topPadding + chartHeight * (1 - normalized);
    }

    final targetY = yForValue(targetValue);

    final targetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1;

    var dashX = leftPadding;

    while (dashX < size.width - rightPadding) {
      final dashEnd = math.min(dashX + 5, size.width - rightPadding);

      canvas.drawLine(
        Offset(dashX, targetY),
        Offset(dashEnd, targetY),
        targetPaint,
      );

      dashX += 9;
    }

    final linePath = Path();

    for (var index = 0; index < points.length; index++) {
      final point = Offset(xForIndex(index), yForValue(points[index].value));

      if (index == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length > 1) {
      canvas.drawPath(linePath, linePaint);
    }

    for (var index = 0; index < points.length; index++) {
      final chartPoint = points[index];

      final point = Offset(xForIndex(index), yForValue(chartPoint.value));

      final isPaused = chartPoint.state == TrackerActivityState.paused;

      final isCompleted = chartPoint.state == TrackerActivityState.completed;

      final pointPaint = Paint()
        ..color = isCompleted
            ? Colors.white
            : Colors.white.withValues(alpha: isPaused ? 0.25 : 0.62)
        ..style = isPaused ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.5;

      canvas.drawCircle(point, isCompleted ? 3.8 : 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackerLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetValue != targetValue;
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.label, required this.solid});

  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: solid ? Colors.white : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
