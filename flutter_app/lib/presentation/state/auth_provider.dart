import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/network/dio_client.dart';

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

  AuthNotifier() : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final token = box.get('token');
      final userJson = box.get('user');
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
        options: Options(headers: {'Idempotency-Key': 'login-${email.hashCode}'}),
      );
      final token = res.data['accessToken'] as String;
      final user = _parseUser(res.data['user']);

      final box = await Hive.openBox<String>(_boxName);
      await box.put('token', token);
      await box.put('user', jsonEncode(res.data['user']));

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
    final box = await Hive.openBox<String>(_boxName);
    await box.deleteAll(['token', 'user']);
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
      );
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
