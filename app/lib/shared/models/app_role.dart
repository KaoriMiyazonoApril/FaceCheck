enum AppRole {
  user,
  admin;

  static AppRole fromBackend(Object? value) {
    switch ((value ?? '').toString().toUpperCase()) {
      case 'ADMIN':
        return AppRole.admin;
      default:
        return AppRole.user;
    }
  }

  String get backendValue => name.toUpperCase();

  String get label {
    switch (this) {
      case AppRole.admin:
        return '管理员';
      case AppRole.user:
        return '用户';
    }
  }
}
