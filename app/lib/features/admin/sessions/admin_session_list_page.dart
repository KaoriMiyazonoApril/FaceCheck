import 'package:facecheck_app/features/admin/admin_navigation.dart';
import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminSessionListPage extends ConsumerStatefulWidget {
  const AdminSessionListPage({super.key});

  @override
  ConsumerState<AdminSessionListPage> createState() =>
      _AdminSessionListPageState();
}

class _AdminSessionListPageState extends ConsumerState<AdminSessionListPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<AdminSessionSummary> _sessions = const <AdminSessionSummary>[];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSessions);
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await ref.read(adminRepositoryProvider).fetchSessions();
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _readableMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    final created = await context.push<bool>(AppRoutePaths.adminSessionCreate);
    if (created == true) {
      await _loadSessions();
    }
  }

  Future<void> _openEditForm(AdminSessionSummary session) async {
    final updated = await context.push<bool>(
      AppRoutePaths.adminSessionEdit(
        session.sessionId,
        name: session.name,
        description: session.description,
        startTime: session.startTime.toUtc().toIso8601String(),
        endTime: session.endTime.toUtc().toIso8601String(),
        lateAfterTime: session.lateAfterTime?.toUtc().toIso8601String(),
        status: session.status,
      ),
    );
    if (updated == true) {
      await _loadSessions();
    }
  }

  Future<void> _changeSessionStatus(
    AdminSessionSummary session,
    Future<AdminSessionSummary> Function(String sessionId) action,
  ) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await action(session.sessionId);
      await _loadSessions();
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
      pageKey: AppTestKeys.adminSessionListPage,
      title: '场次管理',
      selectedPath: AppRoutePaths.adminSessions,
      floatingActionButton: FloatingActionButton.extended(
        key: AppTestKeys.adminCreateSessionButton,
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('创建场次'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
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
                      '签到场次列表',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '可创建、编辑、发布、关闭、取消场次，并查看当前二维码和场次记录。',
                    ),
                    const SizedBox(height: 12),
                    Text('共 ${_sessions.length} 个场次'),
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
            if (_isLoading && _sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_isLoading && _sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无场次，请先创建。'),
                  ),
                ),
              ),
            for (final session in _sessions) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(
                            label: Text('状态：${_statusLabel(session.status)}'),
                          ),
                          Chip(label: Text('二维码版本：${session.qrTokenVersion}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_formatWindow(session)),
                      if (session.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(session.description),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () => _openEditForm(session),
                            child: const Text('编辑'),
                          ),
                          FilledButton.tonal(
                            onPressed: session.status == 'PUBLISHED'
                                ? null
                                : () => _changeSessionStatus(
                                      session,
                                      ref
                                          .read(adminRepositoryProvider)
                                          .publishSession,
                                    ),
                            child: const Text('发布'),
                          ),
                          FilledButton.tonal(
                            onPressed: session.status == 'CLOSED'
                                ? null
                                : () => _changeSessionStatus(
                                      session,
                                      ref
                                          .read(adminRepositoryProvider)
                                          .closeSession,
                                    ),
                            child: const Text('关闭'),
                          ),
                          FilledButton.tonal(
                            onPressed: session.status == 'CANCELED'
                                ? null
                                : () => _changeSessionStatus(
                                      session,
                                      ref
                                          .read(adminRepositoryProvider)
                                          .cancelSession,
                                    ),
                            child: const Text('取消'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.push(
                              AppRoutePaths.adminSessionQr(
                                session.sessionId,
                                sessionName: session.name,
                              ),
                            ),
                            child: const Text('查看二维码'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.push(
                              AppRoutePaths.adminSessionRecords(
                                session.sessionId,
                                sessionName: session.name,
                              ),
                            ),
                            child: const Text('场次记录'),
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

  String _formatWindow(AdminSessionSummary session) {
    return '签到时间：${_formatDateTime(session.startTime)} - '
        '${_formatDateTime(session.endTime)}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _statusLabel(String value) {
    return switch (value.toUpperCase()) {
      'PUBLISHED' => '已发布',
      'CLOSED' => '已关闭',
      'CANCELED' => '已取消',
      _ => '草稿',
    };
  }
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法处理场次，请稍后重试。';
}
