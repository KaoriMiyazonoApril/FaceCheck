import 'package:facecheck_app/features/admin/admin_navigation.dart';
import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminUserListPage extends ConsumerStatefulWidget {
  const AdminUserListPage({super.key});

  @override
  ConsumerState<AdminUserListPage> createState() => _AdminUserListPageState();
}

class _AdminUserListPageState extends ConsumerState<AdminUserListPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<AdminManagedUser> _users = const <AdminManagedUser>[];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await ref.read(adminRepositoryProvider).fetchUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _readableMessage(error);
      });
    }
  }

  Future<void> _openCreateForm() async {
    final created = await context.push<bool>(AppRoutePaths.adminUserCreate);
    if (created == true) {
      await _loadUsers();
    }
  }

  Future<void> _openEditForm(AdminManagedUser user) async {
    final updated = await context.push<bool>(
      AppRoutePaths.adminUserEdit(
        user.userId,
        username: user.username,
        role: user.role,
        status: user.status,
      ),
    );
    if (updated == true) {
      await _loadUsers();
    }
  }

  Future<void> _disableUser(AdminManagedUser user) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await ref.read(adminRepositoryProvider).disableUser(user.userId);
      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _readableMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminNavigation(
      pageKey: AppTestKeys.adminUserListPage,
      title: '用户管理',
      selectedPath: AppRoutePaths.adminUsers,
      floatingActionButton: FloatingActionButton.extended(
        key: AppTestKeys.adminCreateUserButton,
        onPressed: _openCreateForm,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('新增用户'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
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
                      '管理员用户列表',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '当前阶段只以用户名作为业务标识；支持新增、编辑和停用用户。',
                    ),
                    const SizedBox(height: 12),
                    Text('共 ${_users.length} 个用户'),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (_isLoading && _users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_isLoading && _users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无用户，请先新增。'),
                  ),
                ),
              ),
            for (final user in _users) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(label: Text('角色：${_roleLabel(user.role)}')),
                          Chip(label: Text('状态：${_statusLabel(user.status)}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '用户 ID：${user.userId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => _openEditForm(user),
                            child: const Text('编辑'),
                          ),
                          FilledButton.tonal(
                            onPressed: user.status == 'DISABLED'
                                ? null
                                : () => _disableUser(user),
                            child: const Text('停用'),
                          ),
                        ],
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

  String _roleLabel(String value) {
    return switch (value.toUpperCase()) {
      'ADMIN' => '管理员',
      _ => '普通用户',
    };
  }

  String _statusLabel(String value) {
    return switch (value.toUpperCase()) {
      'DISABLED' => '停用',
      'LOCKED' => '锁定',
      _ => '启用',
    };
  }
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法读取用户列表，请稍后重试。';
}
