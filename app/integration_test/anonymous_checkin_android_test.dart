import 'package:facecheck_app/main.dart' as app;
import 'package:facecheck_app/features/checkin/session_confirm_page.dart';
import 'package:facecheck_app/features/checkin/session_entry_repository.dart';
import 'package:facecheck_app/services/api_client.dart';
import 'package:facecheck_app/services/auth_interceptor.dart';
import 'package:facecheck_app/shared/config/app_test_keys.dart';
import 'package:facecheck_app/shared/models/backend_api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/test_debug_helpers.dart';

const String _seedSessionQrToken = 'seed-local-session-token';
const String _seedSessionName = '本地调试示例场次';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('android anonymous check-in seed session flow', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[
        find.byKey(AppTestKeys.loginPage),
        find.byKey(AppTestKeys.homePage),
      ],
      description: '登录页或首页',
    );

    final onLoginPage = find.byKey(AppTestKeys.loginPage).evaluate().isNotEmpty;
    final onHomePage = find.byKey(AppTestKeys.homePage).evaluate().isNotEmpty;
    if (!onLoginPage && !onHomePage) {
      printVisibleTextsOnFailure(tester, '应用启动后未进入预期页面。');
      fail('应用启动后未进入登录页或首页。');
    }

    if (onLoginPage) {
      await waitForAnyWidgetWithDebug(
        tester,
        finders: <Finder>[find.text('人脸签到系统')],
        description: '登录页中文标题',
      );
    }

    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.anonymousCheckinEntryButton),
      '匿名签到入口按钮',
    );
    await tester.tap(find.byKey(AppTestKeys.anonymousCheckinEntryButton));
    await tester.pumpAndSettle();

    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[find.byKey(AppTestKeys.anonymousCheckinEntryPage)],
      description: '匿名签到入口页',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.sessionEntryInput),
      '场次码输入框',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.scanQrButton),
      '扫码区域',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('场次入口'),
      '场次入口标题',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('扫码签到'),
      '扫码签到标题',
    );
    await tester.enterText(
      find.byKey(AppTestKeys.sessionEntryInput),
      _seedSessionQrToken,
    );
    await tester.tap(find.text('进入场次'));
    await tester.pumpAndSettle();

    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[
        find.byKey(AppTestKeys.sessionConfirmPage),
        find.text(_seedSessionName),
      ],
      description: '场次确认页或种子场次名称',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.sessionConfirmPage),
      '场次确认页',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text(_seedSessionName),
      '种子场次名称',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('开始匿名签到'),
      '匿名签到开始按钮文案',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('可以继续进入匿名拍照步骤。'),
      '场次确认中文提示',
    );

    await tester.tap(find.byKey(AppTestKeys.anonymousCheckinStartButton));
    await tester.pumpAndSettle();

    await expectOneWidgetWithDebug(
      tester,
      find.byKey(AppTestKeys.anonymousCheckinCapturePage),
      '匿名拍照页',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('拍摄签到照片'),
      '拍照页标题',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('提交匿名签到'),
      '提交按钮文案',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('尚未选择照片。请使用相机或相册，并确认画面中只有一张清晰人脸。'),
      '拍照页中文提示',
    );

    await tester.tap(find.byKey(AppTestKeys.anonymousCheckinSubmitButton));
    await tester.pumpAndSettle();

    await expectOneWidgetWithDebug(
      tester,
      find.text('提交前请先拍摄或选择一张签到照片。'),
      '未选择照片时的中文错误提示',
    );

    // Manual Android validation checklist for Stage 9:
    // 1. 点击“进入匿名签到”，必要时授权相机权限。
    // 2. 扫描有效场次二维码，或在输入框中粘贴有效 qrToken。
    // 3. 确认场次信息后点击“开始匿名签到”。
    // 4. 拍摄一张签到照片，检查预览后提交。
    // 5. 观察处理中、签到成功、签到失败和重复签到状态。
    // 6. 确认匿名流程不会开放个人资料、人脸照片或个人签到记录。
  });

  testWidgets('android anonymous check-in shows Chinese network failure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sessionEntryRepositoryProvider.overrideWithValue(
            _FailingSessionEntryRepository(),
          ),
        ],
        child: const MaterialApp(
          home: SessionConfirmPage(qrToken: _seedSessionQrToken),
        ),
      ),
    );

    await waitForAnyWidgetWithDebug(
      tester,
      finders: <Finder>[find.text('场次不可用')],
      description: '匿名签到网络失败提示',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('场次不可用'),
      '场次不可用标题',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('当前无法加载场次信息，请检查网络后重试。'),
      '中文网络失败提示',
    );
    await expectOneWidgetWithDebug(
      tester,
      find.text('重新扫码'),
      '重新扫码按钮',
    );
  });
}

class _FailingSessionEntryRepository extends SessionEntryRepository {
  _FailingSessionEntryRepository() : super(_dummyApiClient());

  @override
  Future<SessionEntryDetails> resolveSession(String qrToken) async {
    throw const BackendApiException(
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the backend service.',
    );
  }
}

ApiClient _dummyApiClient() {
  return ApiClient(
    baseUrl: 'http://localhost',
    authInterceptor: AuthInterceptor(
      readAccessToken: () async => null,
    ),
  );
}
