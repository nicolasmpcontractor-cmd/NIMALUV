import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/welcome_screen.dart';

const SystemUiOverlayStyle nimaluvNavigationBarStyle = SystemUiOverlayStyle(
  // Barra superior transparente.
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,

  // Barra inferior transparente.
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

class NimaluvApp extends StatelessWidget {
  const NimaluvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimaluv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: nimaluvNavigationBarStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const WelcomeScreen(),
    );
  }
}
