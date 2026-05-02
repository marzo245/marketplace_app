import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  final ImagePicker _picker = ImagePicker();

  static const int maxFileSizeMB = 10;
  static const int targetImageWidth = 1600;
  static const int imageQuality = 85;

  Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> ensurePhotosPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  Future<File?> pickFromCamera() async {
    if (!await ensureCameraPermission()) {
      throw PhotoServiceException(
        'camera_denied',
        'Necesitas dar permiso de cámara en ajustes',
      );
    }

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: targetImageWidth.toDouble(),
      imageQuality: imageQuality,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return null;
    return _validateAndReturn(File(picked.path));
  }

  Future<List<File>> pickFromGallery({int maxCount = 4}) async {
    if (!await ensurePhotosPermission()) {
      throw PhotoServiceException(
        'photos_denied',
        'Necesitas dar permiso para acceder a fotos',
      );
    }

    final List<XFile> picked = await _picker.pickMultiImage(
      maxWidth: targetImageWidth.toDouble(),
      imageQuality: imageQuality,
      limit: maxCount,
    );

    final files = <File>[];
    for (final x in picked.take(maxCount)) {
      final valid = _validateAndReturn(File(x.path));
      if (valid != null) files.add(valid);
    }
    return files;
  }

  File? _validateAndReturn(File file) {
    final sizeBytes = file.lengthSync();
    final sizeMB = sizeBytes / (1024 * 1024);

    if (sizeMB > maxFileSizeMB) {
      throw PhotoServiceException(
        'file_too_large',
        'La foto pesa ${sizeMB.toStringAsFixed(1)}MB, el máximo es ${maxFileSizeMB}MB',
      );
    }

    return file;
  }
}

class PhotoServiceException implements Exception {
  final String code;
  final String message;
  PhotoServiceException(this.code, this.message);

  @override
  String toString() => message;
}
