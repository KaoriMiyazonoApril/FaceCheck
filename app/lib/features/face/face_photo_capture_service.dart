import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoCaptureSource { gallery, camera }

class SelectedPhoto {
  const SelectedPhoto({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
}

class UnsupportedPhotoFormatException implements Exception {
  const UnsupportedPhotoFormatException();

  @override
  String toString() => '仅支持 JPEG、PNG 或 WEBP 图片，请重新选择。';
}

SelectedPhoto normalizeSelectedPhoto(
  Uint8List bytes, {
  DateTime? capturedAt,
}) {
  final format = _detectImageFormat(bytes);
  if (format == null) {
    throw const UnsupportedPhotoFormatException();
  }
  final timestamp = (capturedAt ?? DateTime.now()).microsecondsSinceEpoch;
  return SelectedPhoto(
    fileName: 'face_$timestamp.${format.extension}',
    bytes: bytes,
    contentType: format.contentType,
  );
}

_SupportedImageFormat? _detectImageFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return _SupportedImageFormat.jpeg;
  }
  const pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= pngSignature.length && _matches(bytes, 0, pngSignature)) {
    return _SupportedImageFormat.png;
  }
  if (bytes.length >= 12 &&
      _matches(bytes, 0, const <int>[0x52, 0x49, 0x46, 0x46]) &&
      _matches(bytes, 8, const <int>[0x57, 0x45, 0x42, 0x50])) {
    return _SupportedImageFormat.webp;
  }
  return null;
}

bool _matches(Uint8List bytes, int offset, List<int> signature) {
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[offset + index] != signature[index]) {
      return false;
    }
  }
  return true;
}

enum _SupportedImageFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp');

  const _SupportedImageFormat(this.extension, this.contentType);

  final String extension;
  final String contentType;
}

abstract interface class FacePhotoCaptureService {
  Future<SelectedPhoto?> pickPhoto(PhotoCaptureSource source);
}

class ImagePickerFacePhotoCaptureService implements FacePhotoCaptureService {
  ImagePickerFacePhotoCaptureService([ImagePicker? imagePicker])
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<SelectedPhoto?> pickPhoto(PhotoCaptureSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source == PhotoCaptureSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null) {
      return null;
    }

    return normalizeSelectedPhoto(await picked.readAsBytes());
  }
}

final facePhotoCaptureServiceProvider = Provider<FacePhotoCaptureService>(
  (Ref ref) => ImagePickerFacePhotoCaptureService(),
);
