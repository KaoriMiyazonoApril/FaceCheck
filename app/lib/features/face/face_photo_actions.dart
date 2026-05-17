import 'package:facecheck_app/features/face/face_photo_repository.dart';

class FacePhotoActions {
  static String statusTitle(FacePhotoSummary photo) {
    return switch (photo.status) {
      'ACTIVE' => '可用于识别',
      'FAILED' => '需要重新上传',
      'DELETE_PENDING' => '删除处理中',
      'DELETE_FAILED' => '删除失败',
      'DELETED' => '已删除',
      _ => '处理中',
    };
  }

  static String statusMessage(FacePhotoSummary photo) {
    if (photo.failureReason != null && photo.failureReason!.trim().isNotEmpty) {
      return photo.failureReason!;
    }

    return switch (photo.status) {
      'ACTIVE' => '这张照片已生效，可用于后续识别流程。',
      'FAILED' => '这张照片在校验或注册阶段被后端拒绝，需要重新上传。',
      'DELETE_PENDING' => '删除操作仍在与外部存储和 FRS 引用同步。',
      'DELETE_FAILED' => '删除同步失败，请稍后再次尝试。',
      'DELETED' => '这张照片已经删除。',
      _ => '照片已接收，正在等待异步检测或注册完成。',
    };
  }

  static String photoStatusLabel(String status) {
    return switch (status.toUpperCase()) {
      'ACTIVE' => '生效',
      'FAILED' => '失败',
      'DELETE_PENDING' => '删除处理中',
      'DELETE_FAILED' => '删除失败',
      'DELETED' => '已删除',
      'PENDING' => '处理中',
      _ => status,
    };
  }

  static String detectStatusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => '待处理',
      'PASSED' => '通过',
      'FAILED' => '失败',
      _ => status,
    };
  }

  static String registerStatusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => '待处理',
      'ACTIVE' => '已注册',
      'FAILED' => '失败',
      'DELETED' => '已删除',
      _ => status,
    };
  }
}
