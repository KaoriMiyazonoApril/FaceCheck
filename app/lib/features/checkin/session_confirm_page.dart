import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/session_entry_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionConfirmPage extends ConsumerStatefulWidget {
  const SessionConfirmPage({
    super.key,
    required this.qrToken,
  });

  final String qrToken;

  @override
  ConsumerState<SessionConfirmPage> createState() => _SessionConfirmPageState();
}

class _SessionConfirmPageState extends ConsumerState<SessionConfirmPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(sessionEntryControllerProvider(widget.qrToken).notifier)
          .loadSession(widget.qrToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionEntryControllerProvider(widget.qrToken));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm session'),
      ),
      body: state.isLoading && state.session == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(sessionEntryControllerProvider(widget.qrToken).notifier)
                  .loadSession(widget.qrToken),
              child: ListView(
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
                              'Session unavailable',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(state.errorMessage!),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  context.go(AppRoutePaths.publicSessionEntry),
                              child: const Text('Scan another QR'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (state.session != null) ...<Widget>[
                    _SessionSummaryCard(session: state.session!),
                    const SizedBox(height: 16),
                    if (state.session!.canCheckin)
                      FilledButton.icon(
                        onPressed: () => _continueToCapture(state.session!),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Continue to camera'),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Check-in unavailable',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.session!.refusalReason ??
                                    _fallbackRefusalMessage(
                                      state.session!.refusalCode,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () => context
                                    .go(AppRoutePaths.publicSessionEntry),
                                child: const Text('Back to scanner'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  void _continueToCapture(SessionEntryDetails session) {
    final encodedToken = Uri.encodeQueryComponent(widget.qrToken);
    final encodedName = Uri.encodeQueryComponent(session.name);
    context.go(
      '${AppRoutePaths.publicCheckinCapture}?qrToken=$encodedToken&sessionName=$encodedName',
    );
  }

  String _fallbackRefusalMessage(String? refusalCode) {
    return switch (refusalCode) {
      'SESSION_NOT_STARTED' => 'This session has not started yet.',
      'EXPIRED_SESSION' => 'This session is already past its closing time.',
      'SESSION_CLOSED' => 'This session has already been closed.',
      'SESSION_CANCELED' => 'This session was canceled by an administrator.',
      _ => 'This session is not available for anonymous check-in right now.',
    };
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.session,
  });

  final SessionEntryDetails session;

  @override
  Widget build(BuildContext context) {
    final statusColor = session.canCheckin
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              session.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (session.description != null && session.description!.isNotEmpty)
              ...<Widget>[
                const SizedBox(height: 8),
                Text(session.description!),
              ],
            const SizedBox(height: 16),
            Text('Status: ${session.status}'),
            const SizedBox(height: 4),
            Text('Starts: ${session.startTime}'),
            const SizedBox(height: 4),
            Text('Ends: ${session.endTime}'),
            const SizedBox(height: 16),
            Text(
              session.canCheckin
                  ? 'You can continue to the anonymous photo step.'
                  : (session.refusalReason ??
                      'This session is not open for anonymous check-in.'),
              style: TextStyle(color: statusColor),
            ),
          ],
        ),
      ),
    );
  }
}
