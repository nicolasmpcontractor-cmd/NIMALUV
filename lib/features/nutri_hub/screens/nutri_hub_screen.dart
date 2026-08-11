import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimahub_app/core/theme/app_theme.dart';

class NutriHubScreen extends StatelessWidget {
  const NutriHubScreen({super.key});

  static const Color _background = Color(0xFF07070B);
  static const Color _surface = Color(0xFF14151C);
  static const Color _accent = Color(0xFF7CFFB2);

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: nimahubSystemUiStyle,
      child: Scaffold(
        extendBody: true,
        backgroundColor: _background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: _background,
          foregroundColor: Colors.white,
          systemOverlayStyle: nimahubSystemUiStyle,
          title: const Text(
            'Nutri Hub',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: _background),

            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  110 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _buildTodaySummary(),
                  const SizedBox(height: 26),
                  const Text(
                    'Herramientas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    children: [
                      _NutriHubCard(
                        title: 'Plan nutricional',
                        subtitle: 'Objetivos y alimentación',
                        icon: Icons.calendar_month_rounded,
                        color: _accent,
                        onTap: () {
                          _showComingSoon(context, 'Plan nutricional');
                        },
                      ),
                      _NutriHubCard(
                        title: 'Comidas',
                        subtitle: 'Registro diario',
                        icon: Icons.restaurant_menu_rounded,
                        color: const Color(0xFFFFB86B),
                        onTap: () {
                          _showComingSoon(context, 'Registro de comidas');
                        },
                      ),
                      _NutriHubCard(
                        title: 'Lista de compras',
                        subtitle: 'Compras compartidas',
                        icon: Icons.shopping_cart_checkout_rounded,
                        color: const Color(0xFF65D8FF),
                        onTap: () {
                          _showComingSoon(context, 'Lista de compras');
                        },
                      ),
                      _NutriHubCard(
                        title: 'Hidratación',
                        subtitle: 'Agua diaria',
                        icon: Icons.water_drop_rounded,
                        color: const Color(0xFF78A7FF),
                        onTap: () {
                          _showComingSoon(context, 'Control de hidratación');
                        },
                      ),
                      _NutriHubCard(
                        title: 'Progreso',
                        subtitle: 'Peso y medidas',
                        icon: Icons.monitor_weight_rounded,
                        color: const Color(0xFFFF6FB7),
                        onTap: () {
                          _showComingSoon(context, 'Progreso nutricional');
                        },
                      ),
                      _NutriHubCard(
                        title: 'Insights',
                        subtitle: 'Hábitos de la pareja',
                        icon: Icons.insights_rounded,
                        color: const Color(0xFFC68CFF),
                        onTap: () {
                          _showComingSoon(context, 'Insights nutricionales');
                        },
                      ),
                    ], // children del GridView.count
                  ), // GridView.count
                ], // children del ListView
              ), // ListView
            ), // SafeArea
          ], // children del Stack
        ), // Stack
      ), // Scaffold
    ); // AnnotatedRegion
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent.withValues(alpha: 0.18), _surface],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.12),
              border: Border.all(color: _accent.withValues(alpha: 0.48)),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: _accent,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrición en pareja',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Organicen sus comidas, objetivos y hábitos saludables.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de hoy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: _NutriSummaryItem(value: '0', label: 'Comidas'),
              ),
              Expanded(
                child: _NutriSummaryItem(value: '0 / 8', label: 'Vasos'),
              ),
              Expanded(
                child: _NutriSummaryItem(value: '0%', label: 'Plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutriSummaryItem extends StatelessWidget {
  const _NutriSummaryItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7CFFB2);

    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _NutriHubCard extends StatelessWidget {
  const _NutriHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14151C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
