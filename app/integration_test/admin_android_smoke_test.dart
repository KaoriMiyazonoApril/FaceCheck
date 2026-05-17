import 'package:dio/dio.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/main.dart' as app;
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/config/app_env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'support/test_debug_helpers.dart';

const String _adminUsername = 'admin';
const String _adminPassword = 'Admin123!';
const String _ordinaryUsername = 'alice';
const String _ordinaryPassword = 'user123!!';
const String _seedSessionId = '55555555-5555-5555-5555-555555555555';
const String _seedSessionName = '本地调试示例场次';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('android admin smoke flow', (WidgetTester tester) async {
    await _verifyBackendPreflight();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await _normalizeToLoginPage(tester);
    await _login(tester, _adminUsername, _adminPassword);

    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[find.byKey(AppTestKeys.homePage)],
      description: '管理员首页',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('当前身份：管理员'),
      '管理员身份文案',
    );

    await tester.tap(find.text('管理工作台'));
    await tester.pumpAndSettle();
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminWorkspacePage),
      '管理工作台',
    );
    _expectNoFrameworkException(tester, '管理工作台');

    await _goToRoute(tester, AppRoutePaths.adminUsers);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminUserListPage),
      '用户管理页',
    );
    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[find.text('admin'), find.text('alice')],
      description: '用户列表种子数据',
    );
    _expectNoFrameworkException(tester, '用户管理页');

    await _goToRoute(tester, AppRoutePaths.adminSessions);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminSessionListPage),
      '场次管理页',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text(_seedSessionName),
      '种子场次',
    );
    _expectNoFrameworkException(tester, '场次管理页');

    await _goToRoute(
      tester,
      AppRoutePaths.adminSessionQr(
        _seedSessionId,
        sessionName: _seedSessionName,
      ),
    );
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminSessionQrPage),
      '二维码页',
    );
    _expectNoFrameworkException(tester, '二维码页');

    await _goToRoute(
      tester,
      AppRoutePaths.adminSessionRecords(
        _seedSessionId,
        sessionName: _seedSessionName,
      ),
    );
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminSessionRecordsPage),
      '场次记录页',
    );
    _expectNoFrameworkException(tester, '场次记录页');

    await _goToRoute(tester, AppRoutePaths.adminRecords);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminGlobalRecordsPage),
      '全局记录页',
    );
    _expectNoFrameworkException(tester, '全局记录页');

    await _goToRoute(tester, AppRoutePaths.adminReview);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminExceptionReviewPage),
      '异常复核页',
    );
    _expectNoFrameworkException(tester, '异常复核页');

    await _goToRoute(tester, AppRoutePaths.adminSystemState);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminSystemStatePage),
      '系统状态页',
    );
    _expectNoFrameworkException(tester, '系统状态页');

    await _goToRoute(tester, AppRoutePaths.adminSystemConfig);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.adminSystemConfigPage),
      '系统配置页',
    );
    _expectNoFrameworkException(tester, '系统配置页');

    await _goToRoute(tester, AppRoutePaths.home);
    await _logout(tester);
    await _goToRoute(tester, AppRoutePaths.admin);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.loginPage),
      '匿名访问管理员页后的登录页重定向',
    );

    await _login(tester, _ordinaryUsername, _ordinaryPassword);
    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[find.byKey(AppTestKeys.homePage)],
      description: '普通用户首页',
    );
    await _goToRoute(tester, AppRoutePaths.adminUsers);
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.homePage),
      '普通用户访问管理员页后的首页重定向',
    );
    expect(find.byKey(AppTestKeys.adminUserListPage), findsNothing);

    // Manual Android validation checklist for Phase 11:
    // 1. 在 Android 模拟器或真机上确认所有中文文案可读，无明显布局溢出。
    // 2. 在“场次管理 -> 二维码”页确认二维码可见，并与本地 seed 场次一致。
    // 3. 用匿名入口继续执行真实扫码、拍照、上传链路时，确认仍只通过后端 API。
  });
}

Future<void> _verifyBackendPreflight() async {
  final env = AppEnv.current();
  debugPrint('Admin smoke baseUrl: ${env.baseUrl}');

  final dio = Dio(
    BaseOptions(
      baseUrl: env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const <String, Object>{'Accept': 'application/json'},
    ),
  );

  final healthResponse = await dio.get<Object?>('/api/health');
  debugPrint('Admin smoke health status: ${healthResponse.statusCode}');

  final loginResponse = await dio.post<Object?>(
    '/api/auth/login',
    data: <String, Object>{
      'username': _adminUsername,
      'password': _adminPassword,
    },
  );
  debugPrint('Admin smoke login preflight status: ${loginResponse.statusCode}');
}

Future<void> _normalizeToLoginPage(WidgetTester tester) async {
  await waitForAnyWidgetWithDebug(
    tester,
    finders: <Finder>[
      find.byKey(AppTestKeys.loginPage),
      find.byKey(AppTestKeys.homePage),
    ],
    description: '登录页或首页',
  );

  if (find.byKey(AppTestKeys.homePage).evaluate().isNotEmpty) {
    await _logout(tester);
  }

  await expectOneWidgetWithDebug(
    tester,
    find.byKey(AppTestKeys.loginPage),
    '登录页',
  );
}

Future<void> _login(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(find.byKey(AppTestKeys.loginUsernameInput), username);
  await tester.enterText(find.byKey(AppTestKeys.loginPasswordInput), password);
  await tester.tap(find.byKey(AppTestKeys.loginSubmitButton));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

Future<void> _logout(WidgetTester tester) async {
  await expectOneWidgetWithDebug(
    tester,
    find.byKey(AppTestKeys.logoutButton),
    '退出登录按钮',
  );
  await tester.tap(find.byKey(AppTestKeys.logoutButton));
  await tester.pumpAndSettle();
}

Future<void> _goToRoute(WidgetTester tester, String location) async {
  final candidates = <Finder>[
    find.byKey(AppTestKeys.adminWorkspacePage),
    find.byKey(AppTestKeys.adminUserListPage),
    find.byKey(AppTestKeys.adminSessionListPage),
    find.byKey(AppTestKeys.adminSessionQrPage),
    find.byKey(AppTestKeys.adminSessionRecordsPage),
    find.byKey(AppTestKeys.adminGlobalRecordsPage),
    find.byKey(AppTestKeys.adminExceptionReviewPage),
    find.byKey(AppTestKeys.adminSystemStatePage),
    find.byKey(AppTestKeys.adminSystemConfigPage),
    find.byKey(AppTestKeys.homePage),
    find.byKey(AppTestKeys.loginPage),
  ];
  final anchor = candidates.firstWhere(
    (Finder candidate) => candidate.evaluate().isNotEmpty,
    orElse: () => find.byType(Scaffold).first,
  );
  final BuildContext context = tester.element(anchor);
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void _expectNoFrameworkException(WidgetTester tester, String pageName) {
  final exception = tester.takeException();
  if (exception == null) {
    return;
  }
  printVisibleTextsOnFailure(tester, '页面 $pageName 出现异常。');
  fail('页面 $pageName 出现异常：$exception');
}
