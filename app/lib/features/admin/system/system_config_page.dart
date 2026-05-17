import 'package:facecheck_app/features/admin/admin_navigation.dart';
import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemConfigPage extends ConsumerStatefulWidget {
  const SystemConfigPage({super.key});

  @override
  ConsumerState<SystemConfigPage> createState() => _SystemConfigPageState();
}

class _SystemConfigPageState extends ConsumerState<SystemConfigPage> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<SystemConfigItem> _configs = const <SystemConfigItem>[];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadConfigs);
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final configs =
          await ref.read(adminRepositoryProvider).fetchSystemConfigs();
      if (!mounted) {
        return;
      }
      setState(() {
        _configs = configs;
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

  Future<void> _editConfig(SystemConfigItem config) async {
    final controller = TextEditingController(text: config.configValue);
    final submitted = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('更新 ${config.configKey}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '配置值',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (submitted == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(adminRepositoryProvider).updateSystemConfig(
            configKey: config.configKey,
            configValue: submitted,
          );
      await _loadConfigs();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = _readableMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminNavigation(
      pageKey: AppTestKeys.adminSystemConfigPage,
      title: '系统配置',
      selectedPath: AppRoutePaths.adminSystemConfig,
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
                    '白名单配置项',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('当前阶段只允许管理员查看和更新明确开放的配置项。'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadConfigs,
                    child: const Text('刷新配置'),
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
          if (_isLoading && _configs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final config in _configs) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(config.configKey),
                subtitle: Text(
                  '${config.description}\n当前值：${config.configValue}',
                ),
                isThreeLine: true,
                trailing: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: '编辑配置',
                        onPressed: () => _editConfig(config),
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法读取系统配置，请稍后重试。';
}
