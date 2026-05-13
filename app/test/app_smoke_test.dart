import 'package:facecheck_app/main.dart';
import 'package:facecheck_app/services/secure_storage_service.dart';
import 'package:facecheck_app/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into the login shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureKeyValueStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: const FaceCheckApp(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('FaceCheck Sign in'), findsOneWidget);
  });
}

class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
