import 'package:facecheck_app/features/auth/access_policy.dart';
import 'package:facecheck_app/features/auth/login_page.dart';
import 'package:facecheck_app/features/face/face_photo_page.dart';
import 'package:facecheck_app/features/home/home_page.dart';
import 'package:facecheck_app/features/profile/profile_page.dart';
import 'package:facecheck_app/features/records/personal_records_page.dart';
import 'package:facecheck_app/shared/models/auth_session.dart';
import 'package:facecheck_app/shared/widgets/placeholder_page.dart';
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
            return const PlaceholderPage(
              title: 'Session Check-in',
              message:
                  'The public QR session confirmation flow will be implemented in Stage 9.',
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
            return const PlaceholderPage(
              title: 'Admin Workspace',
              message:
                  'Admin user, session, record, and review pages will be added in Stage 10.',
            );
          },
        ),
      ],
    );
  }
}
