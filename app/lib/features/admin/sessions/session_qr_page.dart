import 'package:facecheck_app/features/admin/admin_navigation.dart';
import 'package:facecheck_app/features/admin/admin_repository.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionQrPage extends ConsumerStatefulWidget {
  const SessionQrPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  final String sessionId;
  final String sessionName;

  @override
  ConsumerState<SessionQrPage> createState() => _SessionQrPageState();
}

class _SessionQrPageState extends ConsumerState<SessionQrPage> {
  bool _isLoading = false;
  String? _errorMessage;
  SessionQrToken? _qrToken;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadQrToken);
  }

  Future<void> _loadQrToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final qrToken = await ref
          .read(adminRepositoryProvider)
          .fetchQrToken(widget.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrToken = qrToken;
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

  Future<void> _resetQrToken() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final qrToken = await ref
          .read(adminRepositoryProvider)
          .resetQrToken(widget.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _qrToken = qrToken;
      });
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
      pageKey: AppTestKeys.adminSessionQrPage,
      title: '场次二维码',
      selectedPath: AppRoutePaths.adminSessions,
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
                    widget.sessionName.isEmpty ? '场次二维码' : widget.sessionName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '当前阶段展示二维码载荷和 token 文本；如需重新生成，可立即轮换旧入口。',
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
          if (_isLoading && _qrToken == null)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_qrToken != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '当前二维码载荷',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(_qrToken!.qrContent),
                    const SizedBox(height: 16),
                    Text(
                      '当前 token',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_qrToken!.qrToken),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _resetQrToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新生成二维码'),
                    ),
                  ],
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
  return '当前无法读取二维码信息，请稍后重试。';
}
