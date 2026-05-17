import 'package:facecheck_app/shared/models/backend_api_exception.dart';

final RegExp _containsChineseCharacters = RegExp(r'[\u4E00-\u9FFF]');

String sessionEntryErrorMessage(Object error) {
  return _checkinErrorMessage(
    error,
    networkMessage: '当前无法加载场次信息，请检查网络后重试。',
    timeoutMessage: '场次信息加载超时，请稍后重试。',
    fallbackMessage: '当前无法加载场次信息，请稍后重试。',
  );
}

String anonymousSubmitErrorMessage(Object error) {
  return _checkinErrorMessage(
    error,
    networkMessage: '当前无法提交匿名签到，请检查网络后重试。',
    timeoutMessage: '匿名签到提交超时，请稍后重试。',
    fallbackMessage: '当前无法提交匿名签到，请稍后重试。',
  );
}

String checkinResultErrorMessage(Object error) {
  return _checkinErrorMessage(
    error,
    networkMessage: '当前无法加载签到结果，请检查网络后重试。',
    timeoutMessage: '签到结果查询超时，请稍后重试。',
    fallbackMessage: '当前无法加载签到结果，请稍后重试。',
  );
}

String _checkinErrorMessage(
  Object error, {
  required String networkMessage,
  required String timeoutMessage,
  required String fallbackMessage,
}) {
  if (error is! BackendApiException) {
    return fallbackMessage;
  }

  switch (error.code) {
    case 'NETWORK_ERROR':
      return networkMessage;
    case 'NETWORK_TIMEOUT':
      return timeoutMessage;
    case 'INVALID_QR_TOKEN':
      return '二维码无效或已过期，请重新扫码。';
    case 'SESSION_NOT_STARTED':
      return '该场次尚未开始，请稍后再试。';
    case 'EXPIRED_SESSION':
      return '该场次已经结束，请重新确认场次。';
    case 'SESSION_CLOSED':
      return '该场次已经关闭，请重新扫码。';
    case 'SESSION_CANCELED':
      return '该场次已被取消，请重新扫码。';
    default:
      if (_containsChineseCharacters.hasMatch(error.message)) {
        return error.message;
      }
      return fallbackMessage;
  }
}
