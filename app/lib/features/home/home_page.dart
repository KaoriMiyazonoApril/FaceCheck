import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/auth/logout_action.dart';
import 'package:facecheck_app/shared/providers/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    if (session == null) {
      return const Scaffold(
        body: Center(
          child: Text('No active session'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FaceCheck Home'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => LogoutAction.execute(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            'Welcome back, ${session.username}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in as ${session.role.label}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _HomeActionCard(
            title: 'Public QR session flow',
            subtitle:
                'Anonymous session entry remains publicly accessible and role-isolated.',
            onTap: () => context.go(AppRoutePaths.publicSessionEntry),
          ),
          _HomeActionCard(
            title: 'My profile',
            subtitle: 'Update your username and password safely in-app.',
            onTap: () => context.go(AppRoutePaths.profile),
          ),
          _HomeActionCard(
            title: 'Face photo library',
            subtitle:
                'Review photo processing status, upload new photos, or replace existing ones.',
            onTap: () => context.go(AppRoutePaths.facePhotos),
          ),
          _HomeActionCard(
            title: 'Attendance history',
            subtitle:
                'See only your own validated attendance records and status notes.',
            onTap: () => context.go(AppRoutePaths.attendanceRecords),
          ),
          if (session.isAdmin)
            _HomeActionCard(
              title: 'Admin workspace',
              subtitle:
                  'Admin-only routes are registered and blocked from ordinary users.',
              onTap: () => context.go(AppRoutePaths.admin),
            ),
        ],
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
