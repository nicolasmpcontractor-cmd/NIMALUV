import 'package:flutter/material.dart';
import 'package:nimaluv_app/core/theme/app_theme.dart';

class KpiScreen extends StatelessWidget {
  const KpiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      {
        'title': 'Días juntos',
        'value': '528',
        'subtitle': 'Desde que empezó la relación',
        'icon': Icons.favorite_border,
        'color': AppColors.neonPink,
      },
      {
        'title': 'Recuerdos este mes',
        'value': '12',
        'subtitle': 'Fotos o entradas guardadas',
        'icon': Icons.image_outlined,
        'color': AppColors.neonBlue,
      },
      {
        'title': 'Citas planeadas',
        'value': '4',
        'subtitle': 'Planes activos en Date Planner',
        'icon': Icons.calendar_month_outlined,
        'color': AppColors.neonPurple,
      },
      {
        'title': 'Racha diaria',
        'value': '8',
        'subtitle': 'Días subiendo una foto diaria',
        'icon': Icons.local_fire_department_outlined,
        'color': AppColors.neonOrange,
      },
      {
        'title': 'Metas activas',
        'value': '3',
        'subtitle': 'Sueños compartidos en progreso',
        'icon': Icons.flag_outlined,
        'color': AppColors.neonGreen,
      },
      {
        'title': 'Balance de presupuesto',
        'value': '82%',
        'subtitle': 'Progreso financiero compartido',
        'icon': Icons.account_balance_wallet_outlined,
        'color': AppColors.neonCyan,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('KPI de pareja'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métricas medibles',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Indicadores para entender, mejorar y cuidar la relación.',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: GridView.builder(
                itemCount: metrics.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final metric = metrics[index];

                  return _KpiCard(
                    title: metric['title'] as String,
                    value: metric['value'] as String,
                    subtitle: metric['subtitle'] as String,
                    icon: metric['icon'] as IconData,
                    color: metric['color'] as Color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.95),
            AppColors.surface.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -8,
            child: Icon(icon, size: 82, color: color.withValues(alpha: 0.18)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.45)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.primary, size: 25),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
