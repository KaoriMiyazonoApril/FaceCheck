import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoCaptureSource { gallery, camera }

class SelectedPhoto {
  const SelectedPhoto({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
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

    return SelectedPhoto(
      fileName: picked.name,
      bytes: await picked.readAsBytes(),
    );
  }
}

final facePhotoCaptureServiceProvider = Provider<FacePhotoCaptureService>(
  (Ref ref) => ImagePickerFacePhotoCaptureService(),
);
