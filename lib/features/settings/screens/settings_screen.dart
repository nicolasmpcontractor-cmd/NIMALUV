import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimahub_app/core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _privateModeEnabled = true;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: nimahubSystemUiStyle,
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 20,
          systemOverlayStyle: nimahubSystemUiStyle,
          title: const Text(
            'Configuración',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 110 + bottomInset),
          children: [
            const Text(
              'Administra las preferencias y la privacidad de NIMAHUB.',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            _SettingsSection(
              title: 'Preferencias',
              children: [
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  accentColor: AppColors.neonPink,
                  title: 'Notificaciones',
                  subtitle: 'Recordatorios, fechas y actividad',
                  trailing: Switch.adaptive(
                    value: _notificationsEnabled,
                    activeTrackColor: AppColors.neonPink.withValues(
                      alpha: 0.70,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.vibration_rounded,
                  accentColor: AppColors.neonPurple,
                  title: 'Vibración',
                  subtitle: 'Respuesta háptica de botones y menú',
                  trailing: Switch.adaptive(
                    value: _hapticsEnabled,
                    activeTrackColor: AppColors.neonPurple.withValues(
                      alpha: 0.70,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _hapticsEnabled = value;
                      });
                    },
                  ),
                ),
                const _SettingsTile(
                  icon: Icons.palette_outlined,
                  accentColor: AppColors.neonBlue,
                  title: 'Apariencia',
                  subtitle: 'Tema, colores y efectos visuales',
                  showArrow: true,
                ),
              ],
            ),

            const SizedBox(height: 18),

            _SettingsSection(
              title: 'Privacidad y seguridad',
              children: [
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  accentColor: AppColors.neonCyan,
                  title: 'Espacio privado',
                  subtitle: 'Protección del contenido de pareja',
                  trailing: Switch.adaptive(
                    value: _privateModeEnabled,
                    activeTrackColor: AppColors.neonCyan.withValues(
                      alpha: 0.70,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _privateModeEnabled = value;
                      });
                    },
                  ),
                ),
                const _SettingsTile(
                  icon: Icons.shield_outlined,
                  accentColor: AppColors.neonGreen,
                  title: 'Seguridad',
                  subtitle: 'PIN, biometría y sesiones',
                  showArrow: true,
                ),
                const _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  accentColor: AppColors.neonOrange,
                  title: 'Cuenta y pareja',
                  subtitle: 'Perfiles y vinculación',
                  showArrow: true,
                ),
              ],
            ),

            const SizedBox(height: 18),

            const _SettingsSection(
              title: 'Aplicación',
              children: [
                _SettingsTile(
                  icon: Icons.cloud_outlined,
                  accentColor: AppColors.neonBlue,
                  title: 'Datos y respaldo',
                  subtitle: 'Sincronización y copias de seguridad',
                  showArrow: true,
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  accentColor: AppColors.neonPurple,
                  title: 'Acerca de NIMAHUB',
                  subtitle: 'Versión, licencias y soporte',
                  showArrow: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showArrow = false,
    this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showArrow)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 23,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
