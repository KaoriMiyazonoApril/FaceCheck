import 'package:facecheck_app/features/admin/admin_home_page.dart';
import 'package:facecheck_app/features/admin/records/global_records_page.dart';
import 'package:facecheck_app/features/admin/records/session_records_page.dart';
import 'package:facecheck_app/features/admin/review/exception_review_page.dart';
import 'package:facecheck_app/features/admin/sessions/admin_session_form_page.dart';
import 'package:facecheck_app/features/admin/sessions/admin_session_list_page.dart';
import 'package:facecheck_app/features/admin/sessions/session_qr_page.dart';
import 'package:facecheck_app/features/admin/system/system_config_page.dart';
import 'package:facecheck_app/features/admin/system/system_state_page.dart';
import 'package:facecheck_app/features/admin/users/admin_user_form_page.dart';
import 'package:facecheck_app/features/admin/users/admin_user_list_page.dart';
import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/checkin/anonymous_access_policy.dart';
import 'package:facecheck_app/features/checkin/checkin_capture_page.dart';
import 'package:facecheck_app/features/checkin/checkin_result_page.dart';
import 'package:facecheck_app/features/checkin/qr_scan_page.dart';
import 'package:facecheck_app/features/checkin/session_confirm_page.dart';
import 'package:facecheck_app/features/auth/login_page.dart';
import 'package:facecheck_app/features/face/face_photo_page.dart';
import 'package:facecheck_app/features/home/home_page.dart';
import 'package:facecheck_app/features/profile/profile_page.dart';
import 'package:facecheck_app/features/records/personal_records_page.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter buildRouter({
    required AuthSession? session,
    String initialLocation = AppRoutePaths.root,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      redirect: (BuildContext context, GoRouterState state) {
        final anonymousRedirect = AnonymousAccessPolicy.redirectFor(
          state.uri,
          session,
        );
        if (anonymousRedirect != null) {
          return anonymousRedirect;
        }
        return AccessPolicy.redirectFor(state.uri.path, session);
      },
      routes: <GoRoute>[
        GoRoute(
          path: AppRoutePaths.root,
          builder: (BuildContext context, GoRouterState state) {
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: AppRoutePaths.login,
          builder: (BuildContext context, GoRouterState state) {
            return const LoginPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.home,
          builder: (BuildContext context, GoRouterState state) {
            return const HomePage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.publicSessionEntry,
          builder: (BuildContext context, GoRouterState state) {
            return QrScanPage(
              initialQrToken: state.uri.queryParameters['qrToken'],
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.publicSessionConfirm,
          builder: (BuildContext context, GoRouterState state) {
            return SessionConfirmPage(
              qrToken: state.uri.queryParameters['qrToken'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.publicCheckinCapture,
          builder: (BuildContext context, GoRouterState state) {
            return CheckinCapturePage(
              qrToken: state.uri.queryParameters['qrToken'] ?? '',
              sessionName: state.uri.queryParameters['sessionName'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.publicCheckinResult,
          builder: (BuildContext context, GoRouterState state) {
            return CheckinResultPage(
              attemptId: state.uri.queryParameters['attemptId'] ?? '',
              qrToken: state.uri.queryParameters['qrToken'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.profile,
          builder: (BuildContext context, GoRouterState state) {
            return const ProfilePage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.facePhotos,
          builder: (BuildContext context, GoRouterState state) {
            return const FacePhotoPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.attendanceRecords,
          builder: (BuildContext context, GoRouterState state) {
            return const PersonalRecordsPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.admin,
          builder: (BuildContext context, GoRouterState state) {
            return const AdminHomePage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminUsers,
          builder: (BuildContext context, GoRouterState state) {
            return const AdminUserListPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminUserCreate,
          builder: (BuildContext context, GoRouterState state) {
            return const AdminUserFormPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminUserEditPattern,
          builder: (BuildContext context, GoRouterState state) {
            return AdminUserFormPage(
              userId: state.pathParameters['userId'],
              initialUsername: state.uri.queryParameters['username'],
              initialRole: state.uri.queryParameters['role'],
              initialStatus: state.uri.queryParameters['status'],
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSessions,
          builder: (BuildContext context, GoRouterState state) {
            return const AdminSessionListPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSessionCreate,
          builder: (BuildContext context, GoRouterState state) {
            return const AdminSessionFormPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSessionEditPattern,
          builder: (BuildContext context, GoRouterState state) {
            return AdminSessionFormPage(
              sessionId: state.pathParameters['sessionId'],
              initialName: state.uri.queryParameters['name'],
              initialDescription: state.uri.queryParameters['description'],
              initialStartTime: state.uri.queryParameters['startTime'],
              initialEndTime: state.uri.queryParameters['endTime'],
              initialLateAfterTime: state.uri.queryParameters['lateAfterTime'],
              initialStatus: state.uri.queryParameters['status'],
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSessionQrPattern,
          builder: (BuildContext context, GoRouterState state) {
            return SessionQrPage(
              sessionId: state.pathParameters['sessionId'] ?? '',
              sessionName: state.uri.queryParameters['sessionName'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSessionRecordsPattern,
          builder: (BuildContext context, GoRouterState state) {
            return SessionRecordsPage(
              sessionId: state.pathParameters['sessionId'] ?? '',
              sessionName: state.uri.queryParameters['sessionName'] ?? '',
            );
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminRecords,
          builder: (BuildContext context, GoRouterState state) {
            return const GlobalRecordsPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminReview,
          builder: (BuildContext context, GoRouterState state) {
            return const ExceptionReviewPage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSystemState,
          builder: (BuildContext context, GoRouterState state) {
            return const SystemStatePage();
          },
        ),
        GoRoute(
          path: AppRoutePaths.adminSystemConfig,
          builder: (BuildContext context, GoRouterState state) {
            return const SystemConfigPage();
          },
        ),
      ],
    );
  }
}
