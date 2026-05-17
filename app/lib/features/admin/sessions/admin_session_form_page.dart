import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSessionFormPage extends ConsumerStatefulWidget {
  const AdminSessionFormPage({
    super.key,
    this.sessionId,
    this.initialName,
    this.initialDescription,
    this.initialStartTime,
    this.initialEndTime,
    this.initialLateAfterTime,
    this.initialStatus,
  });

  final String? sessionId;
  final String? initialName;
  final String? initialDescription;
  final String? initialStartTime;
  final String? initialEndTime;
  final String? initialLateAfterTime;
  final String? initialStatus;

  bool get isEditing => sessionId != null;

  @override
  ConsumerState<AdminSessionFormPage> createState() =>
      _AdminSessionFormPageState();
}

class _AdminSessionFormPageState extends ConsumerState<AdminSessionFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _lateAfterTimeController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _startTimeController = TextEditingController(
      text: widget.initialStartTime ?? '',
    );
    _endTimeController =
        TextEditingController(text: widget.initialEndTime ?? '');
    _lateAfterTimeController = TextEditingController(
      text: widget.initialLateAfterTime ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _lateAfterTimeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final normalizedStartTime = _normalizeInstant(_startTimeController.text);
    final normalizedEndTime = _normalizeInstant(_endTimeController.text);
    final normalizedLateAfterTime = _lateAfterTimeController.text.trim().isEmpty
        ? null
        : _normalizeInstant(_lateAfterTimeController.text);

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '场次名称不能为空。';
      });
      return;
    }
    if (normalizedStartTime == null || normalizedEndTime == null) {
      setState(() {
        _errorMessage = '请使用 ISO-8601 时间格式，例如 2026-05-16T09:00:00Z。';
      });
      return;
    }
    if (_lateAfterTimeController.text.trim().isNotEmpty &&
        normalizedLateAfterTime == null) {
      setState(() {
        _errorMessage = '迟到时间必须是合法的 ISO-8601 时间。';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final repository = ref.read(adminRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repository.updateSession(
          sessionId: widget.sessionId!,
          name: _nameController.text,
          description: _descriptionController.text,
          startTime: normalizedStartTime,
          endTime: normalizedEndTime,
          lateAfterTime: normalizedLateAfterTime,
        );
      } else {
        await repository.createSession(
          name: _nameController.text,
          description: _descriptionController.text,
          startTime: normalizedStartTime,
          endTime: normalizedEndTime,
          lateAfterTime: normalizedLateAfterTime,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = _readableMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppTestKeys.adminSessionFormPage,
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑场次' : '创建场次'),
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
                    widget.isEditing ? '更新场次信息' : '创建新场次',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? '发布后可生成二维码入口；更新时请保持时间窗口合法。'
                        : '第一阶段要求填写名称、开始时间和截止时间；说明与迟到时间为可选项。',
                  ),
                  if (widget.initialStatus != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Chip(
                        label: Text(
                            '当前状态：${_statusLabel(widget.initialStatus!)}')),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '场次名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '说明（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                      labelText: '开始时间（ISO-8601）',
                      hintText: '2026-05-16T09:00:00Z',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                      labelText: '截止时间（ISO-8601）',
                      hintText: '2026-05-16T10:00:00Z',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lateAfterTimeController,
                    decoration: const InputDecoration(
                      labelText: '迟到时间（可选）',
                      hintText: '2026-05-16T09:15:00Z',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: Text(_isSaving ? '保存中...' : '保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

String? _normalizeInstant(String input) {
  final value = DateTime.tryParse(input.trim());
  return value?.toUtc().toIso8601String();
}

String _readableMessage(Object error) {
  if (error is BackendApiException) {
    return error.message;
  }
  return '当前无法保存场次，请稍后重试。';
}
