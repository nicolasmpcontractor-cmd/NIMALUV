import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/welcome_screen.dart';

class NimaluvApp extends StatelessWidget {
  const NimaluvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimaluv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
