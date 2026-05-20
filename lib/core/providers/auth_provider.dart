import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

// Auth State
class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({bool? isLoggedIn, bool? isLoading, UserModel? user, String? error}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        final user = await _api.getMe();
        state = AuthState(isLoggedIn: true, user: user);
      } else {
        state = const AuthState(isLoggedIn: false);
      }
    } catch (_) {
      state = const AuthState(isLoggedIn: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.login(email, password);
      await _storage.write(key: 'access_token', value: result['accessToken']);
      await _storage.write(key: 'refresh_token', value: result['refreshToken']);

      final user = UserModel.fromJson(result['user']);
      state = AuthState(isLoggedIn: true, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _storage.deleteAll();
    state = const AuthState(isLoggedIn: false);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _api.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  const storage = FlutterSecureStorage();
  return AuthNotifier(api, storage);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateProvider).user;
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == 'super_admin' || user?.role == 'hr';
});

final userRoleProvider = Provider<String>((ref) {
  return ref.watch(currentUserProvider)?.role ?? 'employee';
});
