import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/features/face/face_photo_upload_controller.dart';
import 'package:facecheck_app/features/face/widgets/face_photo_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FacePhotoPage extends ConsumerStatefulWidget {
  const FacePhotoPage({super.key});

  @override
  ConsumerState<FacePhotoPage> createState() => _FacePhotoPageState();
}

class _FacePhotoPageState extends ConsumerState<FacePhotoPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(facePhotoUploadControllerProvider.notifier).loadPhotos(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(facePhotoUploadControllerProvider);
    final controller = ref.read(facePhotoUploadControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Face photo library')),
      body: state.isLoading && state.photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.loadPhotos,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Your recognition set',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.photos.length} / ${FacePhotoUploadState.maxPhotos} photos in use',
                          ),
                          const SizedBox(height: 4),
                          Text('${state.remainingSlots} upload slots remaining'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => controller.uploadFromSource(
                                          PhotoCaptureSource.gallery,
                                        ),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Upload from gallery'),
                              ),
                              OutlinedButton.icon(
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => controller.uploadFromSource(
                                          PhotoCaptureSource.camera,
                                        ),
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Use camera'),
                              ),
                            ],
                          ),
                          if (state.errorMessage != null) ...<Widget>[
                            const SizedBox(height: 16),
                            Text(
                              state.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          if (state.successMessage != null) ...<Widget>[
                            const SizedBox(height: 16),
                            Text(
                              state.successMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state.photos.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No face photos yet. Upload one from the gallery or camera to start the registration flow.',
                        ),
                      ),
                    ),
                  for (final photo in state.photos) ...<Widget>[
                    FacePhotoStatusCard(
                      photo: photo,
                      isSubmitting: state.isSubmitting,
                      onDelete: () => controller.deletePhoto(photo.photoId),
                      onReplace: (PhotoCaptureSource source) =>
                          controller.replacePhoto(photo.photoId, source),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}
