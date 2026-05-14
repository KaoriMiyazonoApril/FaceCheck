import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/anonymous_checkin_controller.dart';
import 'package:facecheck_app/features/face/face_photo_capture_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckinCapturePage extends ConsumerWidget {
  const CheckinCapturePage({
    super.key,
    required this.qrToken,
    required this.sessionName,
  });

  final String qrToken;
  final String sessionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(anonymousCheckinControllerProvider);
    final controller = ref.read(anonymousCheckinControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture check-in photo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sessionName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stay anonymous here: capture one clear face photo, submit it once, and then wait for this attempt result only.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: state.isPicking || state.isSubmitting
                            ? null
                            : () => controller.pickPhoto(
                                  PhotoCaptureSource.camera,
                                ),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.isPicking || state.isSubmitting
                            ? null
                            : () => controller.pickPhoto(
                                  PhotoCaptureSource.gallery,
                                ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose from gallery'),
                      ),
                      if (state.photo != null)
                        TextButton(
                          onPressed: state.isSubmitting
                              ? null
                              : controller.clearPhoto,
                          child: const Text('Remove preview'),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: state.photo == null
                  ? const Text(
                      'No photo selected yet. Use the camera or gallery and confirm that one face is clearly visible.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Preview: ${state.photo!.fileName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            state.photo!.bytes,
                            height: 240,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () => _submit(context, ref, qrToken),
            child: Text(
              state.isSubmitting ? 'Submitting...' : 'Submit anonymous check-in',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    String qrToken,
  ) async {
    final result = await ref
        .read(anonymousCheckinControllerProvider.notifier)
        .submit(qrToken: qrToken);
    if (result == null || !context.mounted) {
      return;
    }

    final encodedAttemptId = Uri.encodeQueryComponent(result.attemptId);
    context.go('${AppRoutePaths.publicCheckinResult}?attemptId=$encodedAttemptId');
  }
}
