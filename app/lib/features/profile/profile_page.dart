import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _didSeedUsername = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).loadProfile(),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final success = await ref.read(profileControllerProvider.notifier).saveProfile(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (success && mounted) {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;

    if (!_didSeedUsername && profile != null) {
      _usernameController.text = profile.username;
      _didSeedUsername = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: state.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Account settings',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Update your username or rotate your password without exposing any extra profile fields.',
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            hintText: 'Leave blank to keep the current password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (profile != null)
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              Chip(label: Text('Role: ${profile.role}')),
                              Chip(label: Text('Status: ${profile.status}')),
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
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: state.isSaving ? null : _save,
                          child: Text(
                            state.isSaving ? 'Saving...' : 'Save changes',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        title: const Text('Face photo library'),
                        subtitle: const Text(
                          'Manage up to five active face photos and inspect their processing status.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(AppRoutePaths.facePhotos),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Attendance history'),
                        subtitle: const Text(
                          'Review only your own attendance records and the result note saved for each session.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(AppRoutePaths.attendanceRecords),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
