import 'database_helper.dart';
import 'firebase_auth_service.dart';
import 'models.dart';

class AppSessionRole {
  static const admin = 'admin';
  static const user = 'user';
}

class RestoredAppSession {
  final String role;
  final UserModel? user;

  const RestoredAppSession({
    required this.role,
    this.user,
  });
}

class AppSessionService {
  AppSessionService({
    DatabaseHelper? database,
    FirebaseAuthService? authService,
  })  : _database = database ?? DatabaseHelper(),
        _authService = authService ?? FirebaseAuthService();

  static const Duration maxAge = Duration(days: 90);
  static const String _roleKey = 'session_role';
  static const String _startedAtKey = 'session_started_at';

  final DatabaseHelper _database;
  final FirebaseAuthService _authService;

  Future<void> saveAdminSession() => _saveSession(AppSessionRole.admin);

  Future<void> saveUserSession() => _saveSession(AppSessionRole.user);

  Future<RestoredAppSession?> restore() async {
    final role = await _database.getSessionValue(_roleKey);
    final startedAtRaw = await _database.getSessionValue(_startedAtKey);
    final startedAt =
        startedAtRaw == null ? null : DateTime.tryParse(startedAtRaw);

    if (role == null || startedAt == null || _isExpired(startedAt)) {
      await clear();
      return null;
    }

    if (role == AppSessionRole.admin) {
      return const RestoredAppSession(role: AppSessionRole.admin);
    }

    if (role == AppSessionRole.user) {
      final user = await _authService.restoreSignedInUser();
      if (user == null) {
        await clear();
        return null;
      }
      SessionManager.login(user);
      return RestoredAppSession(role: AppSessionRole.user, user: user);
    }

    await clear();
    return null;
  }

  Future<void> clear() async {
    await _database.clearSessionValues();
    SessionManager.logout();
    await _authService.signOut();
  }

  Future<void> _saveSession(String role) async {
    await _database.setSessionValue(_roleKey, role);
    await _database.setSessionValue(
      _startedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  bool _isExpired(DateTime startedAt) {
    return DateTime.now().difference(startedAt) > maxAge;
  }
}
