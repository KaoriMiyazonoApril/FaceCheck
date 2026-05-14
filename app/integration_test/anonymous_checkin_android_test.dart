import 'package:facecheck_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('android anonymous check-in launch checklist', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('FaceCheck Sign in'), findsOneWidget);

    // Manual Android validation checklist for Stage 9:
    // 1. Tap "Continue to public session entry".
    // 2. Grant camera permission when prompted.
    // 3. Scan a valid session QR code or paste a valid qrToken.
    // 4. Confirm the session details and continue to the camera page.
    // 5. Capture one photo, verify the preview, then submit it.
    // 6. Observe PROCESSING, SUCCESS, FAILED, and DUPLICATE_CHECKIN states.
    // 7. Confirm the public route never unlocks profile, face photos, or
    //    personal history without a real login.
  });
}
