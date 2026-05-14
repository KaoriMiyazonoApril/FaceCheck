import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class QrScanState {
  const QrScanState({
    this.lastPayload,
    this.errorMessage,
  });

  final String? lastPayload;
  final String? errorMessage;

  QrScanState copyWith({
    String? lastPayload,
    String? errorMessage,
    bool clearError = false,
  }) {
    return QrScanState(
      lastPayload: lastPayload ?? this.lastPayload,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class QrScanController extends StateNotifier<QrScanState> {
  QrScanController() : super(const QrScanState());

  String? resolvePayload(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Scan a FaceCheck QR code or paste a valid session token.',
      );
      return null;
    }

    final parsedToken = _extractQrToken(trimmed);
    if (parsedToken == null || parsedToken.isEmpty) {
      state = state.copyWith(
        lastPayload: trimmed,
        errorMessage:
            'This QR payload is invalid. Scan a FaceCheck session QR code instead.',
      );
      return null;
    }

    state = state.copyWith(
      lastPayload: trimmed,
      clearError: true,
    );
    return parsedToken;
  }

  String? _extractQrToken(String payload) {
    final queryToken = _extractFromQuery(payload);
    if (queryToken != null && queryToken.isNotEmpty) {
      return queryToken;
    }

    if (!_looksLikeStructuredPayload(payload)) {
      return payload;
    }

    return null;
  }

  String? _extractFromQuery(String payload) {
    try {
      final uri = Uri.parse(payload);
      final directToken = uri.queryParameters['qrToken'];
      if (directToken != null && directToken.trim().isNotEmpty) {
        return directToken.trim();
      }
    } catch (_) {
      // Fall back to regex parsing for partially structured values.
    }

    final match = RegExp(r'qrToken=([^&\s]+)').firstMatch(payload);
    if (match == null) {
      return null;
    }
    return Uri.decodeComponent(match.group(1) ?? '');
  }

  bool _looksLikeStructuredPayload(String payload) {
    return payload.contains('://') ||
        payload.contains('?') ||
        payload.contains('&') ||
        payload.contains('=');
  }
}

final qrScanControllerProvider =
    StateNotifierProvider.autoDispose<QrScanController, QrScanState>(
  (Ref ref) => QrScanController(),
);
