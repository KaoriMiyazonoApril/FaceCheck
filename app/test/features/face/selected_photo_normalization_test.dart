import 'dart:typed_data';

import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedTime = DateTime.fromMicrosecondsSinceEpoch(123456);

  test('JPEG bytes produce canonical JPEG metadata', () {
    final photo = normalizeSelectedPhoto(
      Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0x00]),
      capturedAt: fixedTime,
    );

    expect(photo.fileName, 'face_123456.jpg');
    expect(photo.contentType, 'image/jpeg');
  });

  test('PNG and WEBP signatures produce matching names and MIME types', () {
    final png = normalizeSelectedPhoto(
      Uint8List.fromList(
        <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
      ),
      capturedAt: fixedTime,
    );
    final webp = normalizeSelectedPhoto(
      Uint8List.fromList(
        <int>[
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ],
      ),
      capturedAt: fixedTime,
    );

    expect((png.fileName, png.contentType), ('face_123456.png', 'image/png'));
    expect(
      (webp.fileName, webp.contentType),
      ('face_123456.webp', 'image/webp'),
    );
  });

  test('HEIC or unknown bytes are rejected before upload', () {
    expect(
      () => normalizeSelectedPhoto(
        Uint8List.fromList(<int>[0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]),
      ),
      throwsA(isA<UnsupportedPhotoFormatException>()),
    );
  });
}
