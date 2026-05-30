import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/network/dio_client.dart';
import '../../core/services/fcm_service.dart';
import '../../core/utils/idempotency.dart';

/// Keychain (iOS) / Keystore (Android) / OS-encrypted credential vault (Win/macOS/Linux).
/// Replaces the previous plaintext Hive box. The first run after upgrade migrates
/// any token sitting in the old Hive box and then deletes it.
const _secureStorage = FlutterSecureStorage();
const _kTokenKey = 'auth_token';
const _kUserKey = 'auth_user';

class AuthState {
  final UserEntity? user;
  final String? token;
  final bool isLoading;
  final bool isRestoring;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
  });

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    UserEntity? user,
    String? token,
    bool? isLoading,
    bool? isRestoring,
    String? error,
  }) => AuthState(
        user: user ?? this.user,
        token: token ?? this.token,
        isLoading: isLoading ?? this.isLoading,
        isRestoring: isRestoring ?? this.isRestoring,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const _boxName = 'auth';
  StreamSubscription<void>? _unauthorizedSub;

  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
    // Any request that returns 401 logs the user out automatically so the
    // UI stops sitting in a half-authenticated zombie state.
    _unauthorizedSub = unauthorizedEvents.stream.listen((_) {
      if (state.isAuthenticated) logout();
    });
  }

  @override
  void dispose() {
    _unauthorizedSub?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      // 1. Try secure storage first.
      var token = await _secureStorage.read(key: _kTokenKey);
      var userJson = await _secureStorage.read(key: _kUserKey);

      // 2. Fall back to the legacy plaintext Hive box and migrate.
      if (token == null || userJson == null) {
        final box = await Hive.openBox<String>(_boxName);
        final legacyToken = box.get('token');
        final legacyUser = box.get('user');
        if (legacyToken != null && legacyUser != null) {
          await _secureStorage.write(key: _kTokenKey, value: legacyToken);
          await _secureStorage.write(key: _kUserKey, value: legacyUser);
          await box.deleteAll(['token', 'user']);
          token = legacyToken;
          userJson = legacyUser;
        }
      }

      if (token != null && userJson != null) {
        final user = _parseUser(jsonDecode(userJson));
        state = AuthState(user: user, token: token, isRestoring: false);
        return;
      }
    } catch (_) {}
    state = const AuthState(isRestoring: false);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = createDioClient(null);
      final res = await dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
        options: Options(headers: {
          'Idempotency-Key': newIdempotencyKey('login'),
        }),
      );
      final token = res.data['accessToken'] as String;
      final user = _parseUser(res.data['user']);

      await _secureStorage.write(key: _kTokenKey, value: token);
      await _secureStorage.write(
          key: _kUserKey, value: jsonEncode(res.data['user']));

      state = AuthState(user: user, token: token, isRestoring: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'];
      final errStr = msg is List
          ? msg.first.toString()
          : (msg?.toString() ?? 'Login failed. Check credentials.');
      state = state.copyWith(isLoading: false, isRestoring: false, error: errStr);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, isRestoring: false, error: 'Unexpected error. Try again.');
      return false;
    }
  }

  Future<void> logout() async {
    // Tell the server to deactivate every FCM token for this user BEFORE
    // we drop the JWT — once the token is gone we can't authenticate the
    // clear request, and the next user on the device would silently keep
    // receiving the previous user's pushes.
    final token = state.token;
    if (token != null) {
      try {
        await FcmService.instance.clearToken(token);
      } catch (_) {}
    }
    await _secureStorage.delete(key: _kTokenKey);
    await _secureStorage.delete(key: _kUserKey);
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.deleteAll(['token', 'user']);
    } catch (_) {}
    state = const AuthState(isRestoring: false);
  }

  UserEntity _parseUser(dynamic data) => UserEntity(
        id: data['id'] ?? data['_id'] ?? '',
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == data['role'],
          orElse: () => UserRole.waiter,
        ),
        branchId: data['branchId'] as String?,
        photoUrl: data['photoUrl'] as String?,
        updatedAt: data['updatedAt'] != null
            ? DateTime.tryParse(data['updatedAt'].toString())
            : null,
      );

  /// Re-fetch /auth/me and update the in-memory user. Call this after any
  /// mutation that changes the current user (profile edit, photo upload,
  /// password change) so the AppBar avatar and other authProvider watchers
  /// see the new data without needing the user to log out.
  Future<void> refreshUser() async {
    final token = state.token;
    if (token == null) return;
    try {
      final dio = createDioClient(token);
      final res = await dio.get('/auth/me');
      final user = _parseUser(res.data);
      state = state.copyWith(user: user);
      // Persist the updated user JSON so a cold start sees the new photoUrl.
      await _secureStorage.write(key: _kUserKey, value: jsonEncode(res.data));
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
