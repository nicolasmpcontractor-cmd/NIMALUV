import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimahub_app/features/notes/services/tracker_entry_image_service.dart';
import 'package:nimahub_app/features/notes/services/tracker_reminder_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TrackerEntryImageService.instance.initialize();
  await TrackerReminderService.instance.initialize();

  // Conserva la barra superior y oculta la navegación inferior de Android.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(nimahubNavigationBarStyle);

  runApp(const NimahubApp());
}
