import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TrackerEntryImagePickContext {
  const TrackerEntryImagePickContext({
    required this.pageId,
    required this.selectedDate,
    required this.valueText,
    required this.note,
    this.entryId,
  });

  final String pageId;
  final String? entryId;
  final DateTime selectedDate;
  final String valueText;
  final String note;

  Map<String, Object?> toJson() {
    return {
      'pageId': pageId,
      'entryId': entryId,
      'selectedDate': selectedDate.millisecondsSinceEpoch,
      'valueText': valueText,
      'note': note,
    };
  }

  factory TrackerEntryImagePickContext.fromJson(Map<String, dynamic> json) {
    final selectedDateMilliseconds = (json['selectedDate'] as num?)?.toInt();

    return TrackerEntryImagePickContext(
      pageId: json['pageId'] as String? ?? '',
      entryId: json['entryId'] as String?,
      selectedDate: selectedDateMilliseconds == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(selectedDateMilliseconds),
      valueText: json['valueText'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

class RecoveredTrackerEntryImage {
  const RecoveredTrackerEntryImage({
    required this.pageId,
    required this.selectedDate,
    required this.valueText,
    required this.note,
    required this.imagePath,
    this.entryId,
  });

  final String pageId;
  final String? entryId;
  final DateTime selectedDate;
  final String valueText;
  final String note;
  final String imagePath;

  Map<String, Object?> toJson() {
    return {
      'pageId': pageId,
      'entryId': entryId,
      'selectedDate': selectedDate.millisecondsSinceEpoch,
      'valueText': valueText,
      'note': note,
      'imagePath': imagePath,
    };
  }

  factory RecoveredTrackerEntryImage.fromJson(Map<String, dynamic> json) {
    final selectedDateMilliseconds = (json['selectedDate'] as num?)?.toInt();

    return RecoveredTrackerEntryImage(
      pageId: json['pageId'] as String? ?? '',
      entryId: json['entryId'] as String?,
      selectedDate: selectedDateMilliseconds == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(selectedDateMilliseconds),
      valueText: json['valueText'] as String? ?? '',
      note: json['note'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
    );
  }
}

class TrackerEntryImageService {
  TrackerEntryImageService._();

  static final TrackerEntryImageService instance = TrackerEntryImageService._();

  final ImagePicker _imagePicker = ImagePicker();

  Future<void>? _initializationFuture;

  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _recoverLostData();
      await _deleteStaleRecoveryFiles();
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo inicializar la recuperación '
        'de imágenes: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo seleccionar la imagen: $error');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<XFile?> pickImageForEntry(
    ImageSource source, {
    required TrackerEntryImagePickContext pickContext,
  }) async {
    await initialize();
    await _writePendingContext(pickContext);

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );

      await _clearPendingContext();

      return pickedImage;
    } catch (error, stackTrace) {
      await _clearPendingContext();

      debugPrint('No se pudo seleccionar la imagen: $error');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<RecoveredTrackerEntryImage?> takeRecoveredImage(String pageId) async {
    await initialize();

    final recoveredImage = await _readRecoveredImage();

    if (recoveredImage == null || recoveredImage.pageId != pageId) {
      return null;
    }

    final imageFile = File(recoveredImage.imagePath);

    if (!await imageFile.exists()) {
      await _clearRecoveredImageMetadata();
      return null;
    }

    return recoveredImage;
  }

  Future<void> discardRecoveredImage(String imagePath) async {
    final recoveredImage = await _readRecoveredImage();

    if (recoveredImage?.imagePath == imagePath) {
      await _clearRecoveredImageMetadata();
    }

    await deleteImage(imagePath);
  }

  Future<String> persistImage({
    required String pageId,
    required XFile pickedImage,
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final imagesDirectory = Directory(
      path.join(documentsDirectory.path, 'tracker_entry_images', pageId),
    );

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    final originalExtension = path.extension(pickedImage.path).toLowerCase();

    final extension = originalExtension.isEmpty ? '.jpg' : originalExtension;

    final fileName =
        'tracker_${DateTime.now().microsecondsSinceEpoch}'
        '$extension';

    final permanentPath = path.join(imagesDirectory.path, fileName);

    final copiedFile = await File(pickedImage.path).copy(permanentPath);

    return copiedFile.path;
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    try {
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo eliminar la imagen '
        '$imagePath: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deleteImagesForPage(String pageId) async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();

      final imagesDirectory = Directory(
        path.join(documentsDirectory.path, 'tracker_entry_images', pageId),
      );

      if (await imagesDirectory.exists()) {
        await imagesDirectory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudieron eliminar las imágenes '
        'del Tracker $pageId: $error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _recoverLostData() async {
    if (!Platform.isAndroid) {
      return;
    }

    final response = await _imagePicker.retrieveLostData();

    if (response.isEmpty) {
      await _clearPendingContext();
      return;
    }

    final pendingContext = await _readPendingContext();

    final recoveredFiles = response.files;

    if (response.exception != null) {
      debugPrint(
        'ImagePicker reportó un error al recuperar '
        'la imagen: ${response.exception}',
      );
    }

    if (pendingContext == null ||
        recoveredFiles == null ||
        recoveredFiles.isEmpty) {
      await _clearPendingContext();
      return;
    }

    final previousRecoveredImage = await _readRecoveredImage();

    if (previousRecoveredImage != null) {
      await deleteImage(previousRecoveredImage.imagePath);
    }

    final stagedImagePath = await _persistRecoveredImage(recoveredFiles.first);

    final recoveredImage = RecoveredTrackerEntryImage(
      pageId: pendingContext.pageId,
      entryId: pendingContext.entryId,
      selectedDate: pendingContext.selectedDate,
      valueText: pendingContext.valueText,
      note: pendingContext.note,
      imagePath: stagedImagePath,
    );

    await _writeRecoveredImage(recoveredImage);

    await _clearPendingContext();
  }

  Future<String> _persistRecoveredImage(XFile recoveredImage) async {
    final recoveryFilesDirectory = await _recoveryFilesDirectory();

    final originalExtension = path.extension(recoveredImage.path).toLowerCase();

    final extension = originalExtension.isEmpty ? '.jpg' : originalExtension;

    final recoveredPath = path.join(
      recoveryFilesDirectory.path,
      'recovered_${DateTime.now().microsecondsSinceEpoch}'
      '$extension',
    );

    final copiedFile = await File(recoveredImage.path).copy(recoveredPath);

    return copiedFile.path;
  }

  Future<void> _writePendingContext(
    TrackerEntryImagePickContext pickContext,
  ) async {
    final file = await _pendingContextFile();

    await _writeJson(file, pickContext.toJson());
  }

  Future<TrackerEntryImagePickContext?> _readPendingContext() async {
    final json = await _readJson(await _pendingContextFile());

    if (json == null) {
      return null;
    }

    final pickContext = TrackerEntryImagePickContext.fromJson(json);

    if (pickContext.pageId.trim().isEmpty) {
      return null;
    }

    return pickContext;
  }

  Future<void> _writeRecoveredImage(
    RecoveredTrackerEntryImage recoveredImage,
  ) async {
    final file = await _recoveredImageFile();

    await _writeJson(file, recoveredImage.toJson());
  }

  Future<RecoveredTrackerEntryImage?> _readRecoveredImage() async {
    final json = await _readJson(await _recoveredImageFile());

    if (json == null) {
      return null;
    }

    final recoveredImage = RecoveredTrackerEntryImage.fromJson(json);

    if (recoveredImage.pageId.trim().isEmpty ||
        recoveredImage.imagePath.trim().isEmpty) {
      return null;
    }

    return recoveredImage;
  }

  Future<void> _clearPendingContext() async {
    await _deleteFileIfPresent(await _pendingContextFile());
  }

  Future<void> _clearRecoveredImageMetadata() async {
    await _deleteFileIfPresent(await _recoveredImageFile());
  }

  Future<Directory> _recoveryDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();

    final directory = Directory(
      path.join(supportDirectory.path, 'tracker_entry_image_recovery'),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> _recoveryFilesDirectory() async {
    final recoveryDirectory = await _recoveryDirectory();

    final directory = Directory(path.join(recoveryDirectory.path, 'files'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> _pendingContextFile() async {
    final recoveryDirectory = await _recoveryDirectory();

    return File(path.join(recoveryDirectory.path, 'pending_pick.json'));
  }

  Future<File> _recoveredImageFile() async {
    final recoveryDirectory = await _recoveryDirectory();

    return File(path.join(recoveryDirectory.path, 'recovered_pick.json'));
  }

  Future<void> _writeJson(File file, Map<String, Object?> value) async {
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());

      if (decoded is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(decoded);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo leer el estado '
        'de recuperación: $error',
      );

      debugPrintStack(stackTrace: stackTrace);

      await _deleteFileIfPresent(file);

      return null;
    }
  }

  Future<void> _deleteFileIfPresent(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _deleteStaleRecoveryFiles() async {
    final recoveryFilesDirectory = await _recoveryFilesDirectory();

    final currentRecoveredImage = await _readRecoveredImage();

    final expirationDate = DateTime.now().subtract(const Duration(days: 7));

    await for (final entity in recoveryFilesDirectory.list()) {
      if (entity is! File || entity.path == currentRecoveredImage?.imagePath) {
        continue;
      }

      final stat = await entity.stat();

      if (stat.modified.isBefore(expirationDate)) {
        await deleteImage(entity.path);
      }
    }
  }
}
