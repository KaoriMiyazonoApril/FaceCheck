import 'package:facecheck_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap page renders', (tester) async {
    await tester.pumpWidget(const FaceCheckApp());

    expect(find.text('FaceCheck bootstrap'), findsOneWidget);
  });
}
