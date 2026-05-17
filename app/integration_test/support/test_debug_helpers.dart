import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

List<String> dumpVisibleTexts(WidgetTester tester) {
  final values = <String>{};
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget;
    if (widget is! Text) {
      continue;
    }
    final text = widget.data ?? widget.textSpan?.toPlainText();
    if (text == null) {
      continue;
    }
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      values.add(trimmed);
    }
  }
  return values.toList()..sort();
}

void printVisibleTextsOnFailure(WidgetTester tester, String reason) {
  final visibleTexts = dumpVisibleTexts(tester);
  debugPrint('--- Integration test debug: $reason ---');
  if (visibleTexts.isEmpty) {
    debugPrint('No visible Text widgets found.');
  } else {
    for (final text in visibleTexts) {
      debugPrint('TEXT: $text');
    }
  }
  debugPrint('--- Widget tree ---');
  debugDumpApp();
}

Future<void> expectOneWidgetWithDebug(
  WidgetTester tester,
  Finder finder,
  String description,
) async {
  await tester.pump();
  final matches = finder.evaluate().length;
  if (matches == 1) {
    return;
  }
  printVisibleTextsOnFailure(
    tester,
    'Expected one widget for "$description", found $matches.',
  );
  fail('Expected exactly one widget for "$description", found $matches.');
}

Future<void> waitForAnyWidgetWithDebug(
  WidgetTester tester, {
  required List<Finder> finders,
  required String description,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finders.any((Finder finder) => finder.evaluate().isNotEmpty)) {
      return;
    }
  }
  printVisibleTextsOnFailure(
    tester,
    'Timed out while waiting for $description.',
  );
  fail('Timed out while waiting for $description.');
}
