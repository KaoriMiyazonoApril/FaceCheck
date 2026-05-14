import 'package:facecheck_app/features/face/face_photo_actions.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:facecheck_app/features/face/face_photo_repository.dart';
import 'package:flutter/material.dart';

class FacePhotoStatusCard extends StatelessWidget {
  const FacePhotoStatusCard({
    super.key,
    required this.photo,
    required this.isSubmitting,
    required this.onDelete,
    required this.onReplace,
  });

  final FacePhotoSummary photo;
  final bool isSubmitting;
  final VoidCallback onDelete;
  final void Function(PhotoCaptureSource source) onReplace;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.face_retouching_natural, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        FacePhotoActions.statusTitle(photo),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(FacePhotoActions.statusMessage(photo)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('State: ${photo.status}')),
                Chip(label: Text('Detect: ${photo.detectStatus}')),
                Chip(label: Text('Register: ${photo.registerStatus}')),
              ],
            ),
            if (photo.failureCode != null && photo.failureCode!.isNotEmpty) ...<
              Widget
            >[
              const SizedBox(height: 8),
              Text('Failure code: ${photo.failureCode}'),
            ],
            if (photo.previewUrl != null && photo.previewUrl!.isNotEmpty) ...<
              Widget
            >[
              const SizedBox(height: 8),
              Text(
                'Preview ready',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => onReplace(PhotoCaptureSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Replace from gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => onReplace(PhotoCaptureSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Replace with camera'),
                ),
                TextButton.icon(
                  onPressed: isSubmitting ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
