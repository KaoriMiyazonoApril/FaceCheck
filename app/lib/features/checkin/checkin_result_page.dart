import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/checkin_repository.dart';
import 'package:facecheck_app/features/checkin/checkin_result_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CheckinResultPage extends ConsumerStatefulWidget {
  const CheckinResultPage({
    super.key,
    required this.attemptId,
  });

  final String attemptId;

  @override
  ConsumerState<CheckinResultPage> createState() => _CheckinResultPageState();
}

class _CheckinResultPageState extends ConsumerState<CheckinResultPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(checkinResultControllerProvider(widget.attemptId).notifier)
          .start(attemptId: widget.attemptId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinResultControllerProvider(widget.attemptId));
    final controller = ref.read(
      checkinResultControllerProvider(widget.attemptId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in result'),
      ),
      body: state.isLoading && state.attempt == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                if (state.errorMessage != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Unable to load this attempt',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(state.errorMessage!),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              FilledButton(
                                onPressed: controller.refresh,
                                child: const Text('Retry'),
                              ),
                              OutlinedButton(
                                onPressed: () => context
                                    .go(AppRoutePaths.publicSessionEntry),
                                child: const Text('Scan another QR'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.attempt != null)
                  _ResultSummaryCard(
                    attempt: state.attempt!,
                    onRefresh: controller.refresh,
                  ),
              ],
            ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({
    required this.attempt,
    required this.onRefresh,
  });

  final CheckinAttemptSummary attempt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final presentation = CheckinResultPresentation.fromAttempt(attempt);
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (presentation.tone) {
      ResultTone.success => Colors.green.shade700,
      ResultTone.warning => Colors.orange.shade700,
      ResultTone.processing => colorScheme.primary,
      ResultTone.failure => colorScheme.error,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(presentation.icon, size: 36, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        presentation.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        presentation.message,
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Session: ${attempt.sessionName}'),
            Text('Attempt: ${attempt.attemptId}'),
            Text('Status: ${attempt.status}'),
            Text('Result code: ${attempt.resultCode}'),
            if (attempt.checkinTime != null)
              Text('Check-in time: ${attempt.checkinTime}'),
            if (attempt.maskedUsername != null &&
                attempt.maskedUsername!.isNotEmpty)
              Text('Matched user: ${attempt.maskedUsername}'),
            if (attempt.similarity != null)
              Text(
                'Similarity: ${attempt.similarity!.toStringAsFixed(1)}%',
              ),
            const SizedBox(height: 16),
            const Text(
              'This public route never unlocks personal profile, face library, or private attendance history.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                if (attempt.isProcessing)
                  FilledButton(
                    onPressed: onRefresh,
                    child: const Text('Refresh now'),
                  ),
                OutlinedButton(
                  onPressed: () =>
                      context.go(AppRoutePaths.publicSessionEntry),
                  child: const Text('Scan another QR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum ResultTone { success, warning, processing, failure }

class CheckinResultPresentation {
  const CheckinResultPresentation({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final ResultTone tone;

  factory CheckinResultPresentation.fromAttempt(CheckinAttemptSummary attempt) {
    if (attempt.status == 'PROCESSING') {
      return CheckinResultPresentation(
        icon: Icons.hourglass_top,
        title: 'Still processing',
        message: attempt.resultMessage.isEmpty
            ? 'Your anonymous check-in is still being processed.'
            : attempt.resultMessage,
        tone: ResultTone.processing,
      );
    }

    if (attempt.status == 'SUCCESS') {
      return CheckinResultPresentation(
        icon: Icons.verified_outlined,
        title: 'Check-in successful',
        message: attempt.resultMessage.isEmpty
            ? 'Your attendance was confirmed successfully.'
            : attempt.resultMessage,
        tone: ResultTone.success,
      );
    }

    if (attempt.status == 'DUPLICATE_CHECKIN' ||
        attempt.resultCode == 'DUPLICATE_CHECKIN') {
      return CheckinResultPresentation(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Already checked in',
        message: attempt.resultMessage.isEmpty
            ? 'This user has already completed check-in for the current session.'
            : attempt.resultMessage,
        tone: ResultTone.warning,
      );
    }

    return CheckinResultPresentation(
      icon: Icons.error_outline,
      title: _failureTitleFor(attempt.resultCode),
      message: attempt.resultMessage.isEmpty
          ? _failureMessageFor(attempt.resultCode)
          : attempt.resultMessage,
      tone: ResultTone.failure,
    );
  }

  static String _failureTitleFor(String resultCode) {
    return switch (resultCode) {
      'SESSION_NOT_STARTED' => 'Session not started',
      'EXPIRED_SESSION' => 'Session expired',
      'SESSION_CLOSED' => 'Session closed',
      'SESSION_CANCELED' => 'Session canceled',
      'INVALID_QR_TOKEN' => 'QR code invalid',
      'RATE_LIMITED' => 'Too many attempts',
      'NO_FACE' => 'No face detected',
      'MULTIPLE_FACES' => 'Multiple faces detected',
      'LOW_CONFIDENCE' => 'Face match too weak',
      'INVALID_IMAGE' => 'Image invalid',
      'FRS_TIMEOUT' => 'Recognition timed out',
      'FRS_RATE_LIMITED' => 'Recognition rate limited',
      'FRS_ERROR' => 'Recognition unavailable',
      _ => 'Check-in failed',
    };
  }

  static String _failureMessageFor(String resultCode) {
    return switch (resultCode) {
      'SESSION_NOT_STARTED' =>
        'The session has not opened yet. Wait for the start time and try again.',
      'EXPIRED_SESSION' =>
        'The session is already past its closing time.',
      'SESSION_CLOSED' =>
        'An administrator has already closed this session.',
      'SESSION_CANCELED' =>
        'This session was canceled and no longer accepts anonymous check-ins.',
      'INVALID_QR_TOKEN' =>
        'This QR code is invalid or expired. Ask for a fresh session QR code.',
      'RATE_LIMITED' =>
        'Too many anonymous attempts were sent. Wait a moment before retrying.',
      'NO_FACE' =>
        'No clear face was detected. Retake the photo with one person in frame.',
      'MULTIPLE_FACES' =>
        'More than one face was detected. Keep only one person in the frame.',
      'LOW_CONFIDENCE' =>
        'The face match confidence was too low. Try a clearer photo.',
      'INVALID_IMAGE' =>
        'The uploaded image could not be accepted. Try another photo.',
      'FRS_TIMEOUT' =>
        'The face-recognition request timed out. Retry this check-in once.',
      'FRS_RATE_LIMITED' =>
        'The recognition provider is throttling requests. Retry shortly.',
      'FRS_ERROR' =>
        'The recognition provider returned an error. Retry later.',
      _ => 'The anonymous check-in could not be completed.',
    };
  }
}
