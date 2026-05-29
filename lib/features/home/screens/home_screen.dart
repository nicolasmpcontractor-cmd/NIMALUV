import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nimaluv_app/core/theme/app_theme.dart';
import 'package:nimaluv_app/features/albums/screens/albums_screen.dart';
import 'package:nimaluv_app/features/budget/screens/budget_screen.dart';
import 'package:nimaluv_app/features/date_planner/screens/date_planner_screen.dart';
import 'package:nimaluv_app/features/dates/screens/important_dates_screen.dart';
import 'package:nimaluv_app/features/goals/screens/goals_screen.dart';
import 'package:nimaluv_app/features/notes/screens/notes_screen.dart';
import 'package:nimaluv_app/features/trips/screens/trips_screen.dart';
import 'package:nimaluv_app/features/kpi/screens/kpi_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isQuickMenuOpen = false;

  void openScreen(BuildContext context, Widget screen) {
    setState(() {
      _isQuickMenuOpen = false;
    });

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void toggleQuickMenu() {
    setState(() {
      _isQuickMenuOpen = !_isQuickMenuOpen;
    });
  }

  void closeQuickMenu() {
    setState(() {
      _isQuickMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _BackgroundGlow(),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HomeHeader(),
                        const SizedBox(height: 12),
                        const _StatsRow(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons.image_outlined,
                                        title: 'Álbum',
                                        subtitle: 'Nuestros recuerdos',
                                        accentColor: AppColors.neonBlue,
                                        visualType: _FeatureVisualType.album,
                                        onTap: () => openScreen(
                                          context,
                                          const AlbumsScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons.calendar_month_outlined,
                                        title: 'Date Planner',
                                        subtitle: 'Planes juntos',
                                        accentColor: AppColors.neonPink,
                                        visualType: _FeatureVisualType.calendar,
                                        onTap: () => openScreen(
                                          context,
                                          const DatePlannerScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons.luggage_outlined,
                                        title: 'Viajes',
                                        subtitle: 'Aventuras',
                                        accentColor: AppColors.neonCyan,
                                        visualType: _FeatureVisualType.travel,
                                        onTap: () => openScreen(
                                          context,
                                          const TripsScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons.favorite_border,
                                        title: 'Fechas',
                                        subtitle: 'Especiales',
                                        accentColor: AppColors.neonPink,
                                        visualType: _FeatureVisualType.heart,
                                        onTap: () => openScreen(
                                          context,
                                          const ImportantDatesScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons
                                            .account_balance_wallet_outlined,
                                        title: 'Presupuesto',
                                        subtitle: 'Finanzas',
                                        accentColor: AppColors.neonGreen,
                                        visualType: _FeatureVisualType.budget,
                                        onTap: () => openScreen(
                                          context,
                                          const BudgetScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _PremiumFeatureCard(
                                        icon: Icons.flag_outlined,
                                        title: 'Metas',
                                        subtitle: 'Sueños juntos',
                                        accentColor: AppColors.neonOrange,
                                        visualType: _FeatureVisualType.goals,
                                        onTap: () => openScreen(
                                          context,
                                          const GoalsScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _NimaluvBottomNav(
                  onHomeTap: () {},
                  onNotesTap: () => openScreen(context, const NotesScreen()),
                  onCenterTap: toggleQuickMenu,
                  onUsTap: () => openScreen(context, const KpiScreen()),
                  onMoreTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Más opciones próximamente.'),
                      ),
                    );
                  },
                ),
              ],
            ),

            if (_isQuickMenuOpen)
              _QuickActionOverlay(
                onClose: closeQuickMenu,
                onQuickNote: () => openScreen(context, const NotesScreen()),
                onQuickPicture: () => openScreen(context, const AlbumsScreen()),
                onQuickDate: () =>
                    openScreen(context, const DatePlannerScreen()),
                onQuickKpi: () => openScreen(context, const KpiScreen()),
              ),
          ],
        ),
      ),
    ); //coment to know
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            height: 240,
            width: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonPurple.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.18),
                  blurRadius: 90,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 330,
          left: -100,
          child: Container(
            height: 220,
            width: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonBlue.withValues(alpha: 0.13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue.withValues(alpha: 0.16),
                  blurRadius: 90,
                  spreadRadius: 28,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'NIMA',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5.5,
                      ),
                    ),
                    TextSpan(
                      text: 'LUV',
                      style: TextStyle(
                        color: AppColors.neonPurple,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nuestro espacio privado',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 16),
              _HeaderAccentLine(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          height: 76,
          width: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPurple.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/images/nimaluv_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAccentLine extends StatelessWidget {
  const _HeaderAccentLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      width: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: const LinearGradient(
          colors: [AppColors.neonPink, AppColors.neonPurple],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: Row(
        children: const [
          Expanded(
            child: _StatCard(
              icon: Icons.favorite_border,
              value: '528',
              label: 'juntos',
              accentColor: AppColors.neonPink,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.calendar_month_outlined,
              value: '24',
              label: 'aniversario',
              accentColor: AppColors.neonPurple,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.image_outlined,
              value: '12',
              label: 'recuerdos',
              accentColor: AppColors.neonBlue,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.access_time,
              value: 'Sáb',
              label: 'cita',
              accentColor: AppColors.neonCyan,
              isTextValue: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    this.isTextValue = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
  final bool isTextValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.10), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isTextValue ? accentColor : AppColors.primary,
              fontSize: isTextValue ? 14 : 17,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 9,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

enum _FeatureVisualType { album, calendar, travel, heart, budget, goals }

class _PremiumFeatureCard extends StatelessWidget {
  const _PremiumFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.visualType,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final _FeatureVisualType visualType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight.withValues(alpha: 0.95),
                AppColors.surface.withValues(alpha: 0.98),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -36,
                bottom: -34,
                child: _CardVisual(type: visualType, color: accentColor),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: _NeonIconBox(icon: icon, color: accentColor),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeonIconBox extends StatelessWidget {
  const _NeonIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.45)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}

class _CardVisual extends StatelessWidget {
  const _CardVisual({required this.type, required this.color});

  final _FeatureVisualType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case _FeatureVisualType.album:
        return _PolaroidVisual(color: color);
      case _FeatureVisualType.calendar:
        return _CalendarVisual(color: color);
      case _FeatureVisualType.travel:
        return _TravelVisual(color: color);
      case _FeatureVisualType.heart:
        return _HeartVisual(color: color);
      case _FeatureVisualType.budget:
        return _BudgetVisual(color: color);
      case _FeatureVisualType.goals:
        return _GoalsVisual(color: color);
    }
  }
}

class _PolaroidVisual extends StatelessWidget {
  const _PolaroidVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Transform.rotate(
        angle: -0.18,
        child: Icon(
          Icons.collections_outlined,
          size: 92,
          color: color.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _CalendarVisual extends StatelessWidget {
  const _CalendarVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.calendar_today_outlined,
      size: 84,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _TravelVisual extends StatelessWidget {
  const _TravelVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.35,
      child: Icon(
        Icons.flight_rounded,
        size: 88,
        color: color.withValues(alpha: 0.55),
      ),
    );
  }
}

class _HeartVisual extends StatelessWidget {
  const _HeartVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite_border_rounded,
      size: 92,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _BudgetVisual extends StatelessWidget {
  const _BudgetVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 115,
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          return Container(
            width: 14,
            height: 28 + (index * 14),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.neonBlue.withValues(alpha: 0.7),
                  color.withValues(alpha: 0.95),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GoalsVisual extends StatelessWidget {
  const _GoalsVisual({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.terrain_outlined,
      size: 90,
      color: color.withValues(alpha: 0.55),
    );
  }
}

class _QuickActionOverlay extends StatelessWidget {
  const _QuickActionOverlay({
    required this.onClose,
    required this.onQuickNote,
    required this.onQuickPicture,
    required this.onQuickDate,
    required this.onQuickKpi,
  });

  final VoidCallback onClose;
  final VoidCallback onQuickNote;
  final VoidCallback onQuickPicture;
  final VoidCallback onQuickDate;
  final VoidCallback onQuickKpi;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(color: Colors.black.withValues(alpha: 0.48)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 265,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final centerX = constraints.maxWidth / 2;
                const centerY = 205.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(constraints.maxWidth, 230),
                      painter: _QuickMenuArcPainter(),
                    ),

                    _PositionedQuickAction(
                      centerX: centerX,
                      centerY: centerY,
                      dx: -122,
                      dy: -68,
                      label: 'Quick note',
                      icon: Icons.edit_note_rounded,
                      color: AppColors.neonPurple,
                      onTap: onQuickNote,
                    ),
                    _PositionedQuickAction(
                      centerX: centerX,
                      centerY: centerY,
                      dx: -48,
                      dy: -140,
                      label: 'Quick Picture',
                      icon: Icons.photo_camera_outlined,
                      color: AppColors.neonPink,
                      onTap: onQuickPicture,
                    ),
                    _PositionedQuickAction(
                      centerX: centerX,
                      centerY: centerY,
                      dx: 48,
                      dy: -140,
                      label: 'Quick date',
                      icon: Icons.calendar_month_outlined,
                      color: AppColors.neonBlue,
                      onTap: onQuickDate,
                    ),
                    _PositionedQuickAction(
                      centerX: centerX,
                      centerY: centerY,
                      dx: 122,
                      dy: -68,
                      label: 'Quick KPI',
                      icon: Icons.bar_chart_rounded,
                      color: AppColors.neonCyan,
                      onTap: onQuickKpi,
                    ),

                    Positioned(
                      left: centerX - 54,
                      top: centerY - 54,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          height: 108,
                          width: 108,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(
                              color: AppColors.neonPink.withValues(alpha: 0.95),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPink.withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 34,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: AppColors.neonPurple.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 42,
                                spreadRadius: 7,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/nimaluv_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionedQuickAction extends StatelessWidget {
  const _PositionedQuickAction({
    required this.centerX,
    required this.centerY,
    required this.dx,
    required this.dy,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final double centerX;
  final double centerY;
  final double dx;
  final double dy;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const itemWidth = 96.0;
    const circleSize = 78.0;

    return Positioned(
      left: centerX + dx - (itemWidth / 2),
      top: centerY + dy - 39,
      child: SizedBox(
        width: itemWidth,
        height: circleSize,
        child: Center(
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: circleSize,
                  width: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.18),
                        AppColors.surface.withValues(alpha: 0.98),
                      ],
                    ),
                    border: Border.all(
                      color: color.withValues(alpha: 0.95),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.50),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 42,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: circleSize,
                  width: circleSize,
                  child: CustomPaint(
                    painter: _CurvedLabelPainter(
                      text: label.toUpperCase(),
                      color: AppColors.primary,
                    ),
                  ),
                ),

                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface.withValues(alpha: 0.82),
                    border: Border.all(
                      color: color.withValues(alpha: 0.20),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvedLabelPainter extends CustomPainter {
  const _CurvedLabelPainter({required this.text, required this.color});

  final String text;
  final Color color;

  String _normalizeLabel(String value) {
    final clean = value.trim().toUpperCase();

    const targetLength = 13;

    if (clean.length >= targetLength) return clean;

    final totalPadding = targetLength - clean.length;
    final leftPadding = totalPadding ~/ 2;
    final rightPadding = totalPadding - leftPadding;

    return (' ' * leftPadding) + clean + (' ' * rightPadding);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final normalizedText = _normalizeLabel(text);
    if (normalizedText.trim().isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    // proporcional al círculo más pequeño
    final radius = size.width * 0.395;

    final characters = normalizedText.split('');
    final count = characters.length;

    if (count == 0) return;

    const totalArc = 1.95;
    final spacing = count > 1 ? totalArc / (count - 1) : 0.0;

    final startAngle = -math.pi / 2 - (totalArc / 2);

    for (int i = 0; i < count; i++) {
      final char = characters[i];
      final angle = startAngle + (spacing * i);

      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      if (char == ' ') {
        continue;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: color.withValues(alpha: 0.96),
            fontSize: 7.6,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.0,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.35), blurRadius: 5),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + math.pi / 2);

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedLabelPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.color != color;
  }
}

class _QuickMenuArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 210);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [
          AppColors.neonPurple,
          AppColors.neonPink,
          AppColors.neonBlue,
          AppColors.neonCyan,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 145));

    final arcRect = Rect.fromCircle(center: center, radius: 145);

    canvas.drawArc(arcRect, 3.14, 3.14, false, arcPaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.primary;

    final dots = [
      Offset(center.dx - 122, center.dy - 68),
      Offset(center.dx - 48, center.dy - 140),
      Offset(center.dx + 48, center.dy - 140),
      Offset(center.dx + 122, center.dy - 68),
    ];

    for (final dot in dots) {
      canvas.drawCircle(dot, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _NimaluvBottomNav extends StatelessWidget {
  const _NimaluvBottomNav({
    required this.onHomeTap,
    required this.onNotesTap,
    required this.onCenterTap,
    required this.onUsTap,
    required this.onMoreTap,
  });

  final VoidCallback onHomeTap;
  final VoidCallback onNotesTap;
  final VoidCallback onCenterTap;
  final VoidCallback onUsTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            label: 'Inicio',
            isSelected: true,
            onTap: onHomeTap,
          ),
          _BottomNavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Notas',
            onTap: onNotesTap,
          ),
          _CenterMemoryButton(onTap: onCenterTap),
          _BottomNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'KPI',
            onTap: onUsTap,
          ),
          _BottomNavItem(
            icon: Icons.more_horiz,
            label: 'Más',
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }
}

class _CenterMemoryButton extends StatelessWidget {
  const _CenterMemoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -22),
        child: Container(
          height: 74,
          width: 74,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.neonPurple.withValues(alpha: 0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.neonPink.withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/nimaluv_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.muted;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
