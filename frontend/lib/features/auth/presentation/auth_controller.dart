import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../data/auth_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  final String? errorMessage;
  const Unauthenticated({this.errorMessage});
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  static const _storage = FlutterSecureStorage();

  AuthController(this._repository) : super(const AuthInitial()) {
    checkAuthStatus();
  }

  Future<void> _saveSession(User user, String token) async {
    await _storage.write(key: 'jwt_token', value: token);
    await _storage.write(key: 'user_id', value: user.id);
    await _storage.write(key: 'user_email', value: user.email);
    await _storage.write(key: 'user_role', value: user.role);
    await _storage.write(key: 'user_name', value: user.name);
    await _storage.write(key: 'user_phone', value: user.phone ?? '');
    await _storage.write(key: 'device_name', value: user.deviceName ?? '');
    await _storage.write(key: 'photo_url', value: user.photoUrl ?? '');
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_phone');
    await _storage.delete(key: 'device_name');
    await _storage.delete(key: 'photo_url');
  }

  Future<void> checkAuthStatus() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      state = const Unauthenticated();
      return;
    }

    final id = await _storage.read(key: 'user_id');
    final email = await _storage.read(key: 'user_email');
    final role = await _storage.read(key: 'user_role');
    final name = await _storage.read(key: 'user_name');
    final phone = await _storage.read(key: 'user_phone');
    final deviceName = await _storage.read(key: 'device_name');
    final photoUrl = await _storage.read(key: 'photo_url');

    if (id == null || email == null || role == null || name == null) {
      await _clearSession();
      state = const Unauthenticated();
      return;
    }

    // Initialize in-memory API token
    DioClient.setToken(token);

    final cachedUser = User(
      id: id,
      email: email,
      role: role,
      name: name,
      phone: (phone == null || phone.isEmpty) ? null : phone,
      deviceName: (deviceName == null || deviceName.isEmpty) ? null : deviceName,
      photoUrl: (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl,
    );

    // Boot straight to dashboard using the cached credentials
    state = Authenticated(cachedUser);

    // Perform validation and fetch updates in background
    try {
      final user = await _repository.getProfile();
      await _saveSession(user, token);
      state = Authenticated(user);
    } catch (e) {
      final errorMsg = e.toString();
      // Only clean credentials if server explicitly reports unauthorized
      if (errorMsg.contains('SESSION_INVALIDATED') || 
          errorMsg.contains('Unauthorized') || 
          errorMsg.contains('401') || 
          errorMsg.contains('403')) {
        await _clearSession();
        DioClient.setToken(null);
        state = const Unauthenticated();
      }
    }
  }

  Future<void> login(String email, String password, String deviceName) async {
    state = const AuthLoading();
    try {
      final user = await _repository.login(email, password, deviceName);
      final token = DioClient.token;
      if (token != null) {
        await _saveSession(user, token);
      }
      state = Authenticated(user);
    } catch (e) {
      state = Unauthenticated(errorMessage: e.toString().replaceFirst('ServerException: ', ''));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String adminPassword,
    String? phone,
    String? deviceName,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repository.register(
        name: name,
        email: email,
        password: password,
        adminPassword: adminPassword,
        phone: phone,
        deviceName: deviceName,
      );
      final token = DioClient.token;
      if (token != null) {
        await _saveSession(user, token);
      }
      state = Authenticated(user);
    } catch (e) {
      state = Unauthenticated(errorMessage: e.toString().replaceFirst('ServerException: ', ''));
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    try {
      await _repository.logout();
    } finally {
      await _clearSession();
      DioClient.setToken(null);
      state = const Unauthenticated();
    }
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
  }) async {
    final currentState = state;
    if (currentState is Authenticated) {
      state = const AuthLoading();
      try {
        final updatedUser = await _repository.updateProfile(
          name: name,
          phone: phone,
          deviceName: deviceName,
          photoUrl: photoUrl,
        );
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          await _saveSession(updatedUser, token);
        }
        state = Authenticated(updatedUser);
      } catch (e) {
        state = currentState;
        rethrow;
      }
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
