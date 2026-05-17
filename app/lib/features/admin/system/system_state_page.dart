import 'package:facecheck_app/features/admin/admin_navigation.dart';
import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemStatePage extends ConsumerStatefulWidget {
  const SystemStatePage({super.key});

  @override
  ConsumerState<SystemStatePage> createState() => _SystemStatePageState();
}

class _SystemStatePageState extends ConsumerState<SystemStatePage> {
  bool _isLoading = false;
  String? _errorMessage;
  SystemStateSummary? _systemState;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadState);
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final summary =
          await ref.read(adminRepositoryProvider).fetchSystemState();
      if (!mounted) {
        return;
      }
      setState(() {
        _systemState = summary;
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

  @override
  Widget build(BuildContext context) {
    return AdminNavigation(
      pageKey: AppTestKeys.adminSystemStatePage,
      title: '系统状态',
      selectedPath: AppRoutePaths.adminSystemState,
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
                    '依赖健康摘要',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('查看数据库、Redis、RabbitMQ、FRS 和 OBS 的当前健康状态。'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadState,
                    child: const Text('刷新状态'),
                  ),
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
          if (_isLoading && _systemState == null)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_systemState != null) ...<Widget>[
            const SizedBox(height: 16),
            for (final entry in <MapEntry<String, String>>[
              MapEntry('PostgreSQL', _systemState!.database),
              MapEntry('Redis', _systemState!.redis),
              MapEntry('RabbitMQ', _systemState!.rabbitmq),
              MapEntry('华为云 FRS', _systemState!.frs),
              MapEntry('华为云 OBS', _systemState!.obs),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Chip(label: Text(entry.value)),
                  ),
                ),
              ),
            Text('检查时间：${_formatDateTime(_systemState!.checkedAt)}'),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法读取系统状态，请稍后重试。';
}
