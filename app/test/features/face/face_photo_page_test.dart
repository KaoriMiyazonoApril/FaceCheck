import 'dart:typed_data';

import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/features/face/face_photo_page.dart';
import 'package:facecheck_app/features/face/face_photo_repository.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('face photo page shows current count and failure details', (
    WidgetTester tester,
  ) async {
    final repository = _FakeFacePhotoRepository(
      photos: <FacePhotoSummary>[
        _photo(
          photoId: 'photo-1',
          status: 'FAILED',
          registerStatus: 'FAILED',
          failureReason: '仅支持 JPEG、PNG 和 WEBP 图片。',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          facePhotoRepositoryProvider.overrideWithValue(repository),
          facePhotoCaptureServiceProvider.overrideWithValue(
            _FakeFacePhotoCaptureService(),
          ),
        ],
        child: const MaterialApp(home: FacePhotoPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(AppTestKeys.facePhotoPage), findsOneWidget);
    expect(find.text('1 / 5 张已占用'), findsOneWidget);
    expect(find.text('4 个可上传名额'), findsOneWidget);
    expect(find.text('需要重新上传'), findsOneWidget);
    expect(
      find.text('仅支持 JPEG、PNG 和 WEBP 图片。'),
      findsOneWidget,
    );
  });

  testWidgets('face photo page blocks a sixth photo before submission', (
    WidgetTester tester,
  ) async {
    final repository = _FakeFacePhotoRepository(
      photos: List<FacePhotoSummary>.generate(
        5,
        (int index) => _photo(photoId: 'photo-$index'),
      ),
    );
    final captureService = _FakeFacePhotoCaptureService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          facePhotoRepositoryProvider.overrideWithValue(repository),
          facePhotoCaptureServiceProvider.overrideWithValue(captureService),
        ],
        child: const MaterialApp(home: FacePhotoPage()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('从相册上传'));
    await tester.pumpAndSettle();

    expect(find.text('最多只能保留五张人脸照片。'), findsOneWidget);
    expect(captureService.pickCalls, 0);
    expect(repository.uploadCalls, 0);
  });
}

class _FakeFacePhotoRepository extends FacePhotoRepository {
  _FakeFacePhotoRepository({
    required List<FacePhotoSummary> photos,
  })  : _photos = photos,
        super(_dummyApiClient());

  final List<FacePhotoSummary> _photos;
  int uploadCalls = 0;

  @override
  Future<List<FacePhotoSummary>> fetchPhotos() async {
    return List<FacePhotoSummary>.from(_photos);
  }

  @override
  Future<FacePhotoSummary> uploadPhoto(SelectedPhoto photo) async {
    uploadCalls += 1;
    final created = _photo(photoId: 'new-photo');
    _photos.insert(0, created);
    return created;
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    _photos.removeWhere((FacePhotoSummary photo) => photo.photoId == photoId);
  }
}

class _FakeFacePhotoCaptureService implements FacePhotoCaptureService {
  int pickCalls = 0;

  @override
  Future<SelectedPhoto?> pickPhoto(PhotoCaptureSource source) async {
    pickCalls += 1;
    return SelectedPhoto(
      fileName: 'photo.png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: 'image/png',
    );
  }
}

FacePhotoSummary _photo({
  required String photoId,
  String status = 'ACTIVE',
  String registerStatus = 'ACTIVE',
  String? failureReason,
}) {
  return FacePhotoSummary(
    photoId: photoId,
    userId: 'user-1',
    status: status,
    detectStatus: status == 'FAILED' ? 'FAILED' : 'PASSED',
    registerStatus: registerStatus,
    enabled: true,
    createdAt: DateTime.utc(2026, 5, 13, 10, 0, 0),
    failureCode: failureReason == null ? null : 'INVALID_IMAGE',
    failureReason: failureReason,
    previewUrl: 'https://preview.example.com/$photoId',
  );
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(
      readAccessToken: () async => null,
    ),
  );
}
