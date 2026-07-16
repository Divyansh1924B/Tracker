import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DioClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<User> login(String email, String password, String deviceName) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'deviceName': deviceName,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String;
        DioClient.setToken(token);
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        throw ServerException('Login failed with status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } finally {
      DioClient.setToken(null);
    }
  }

  @override
  Future<User> getProfile() async {
    try {
      final response = await _client.dio.get('/auth/profile');
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to load profile');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      if (resData?['code'] == 'SESSION_INVALIDATED') {
        DioClient.setToken(null);
        throw ServerException('SESSION_INVALIDATED');
      }
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<User> updateProfile({
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
  }) async {
    try {
      final response = await _client.dio.put(
        '/auth/profile',
        data: {
          'name': name,
          'phone': phone,
          'deviceName': deviceName,
          'photoUrl': photoUrl,
        },
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to update profile');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String adminPassword,
    String? phone,
    String? deviceName,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'adminPassword': adminPassword,
          'phone': phone,
          'deviceName': deviceName,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String;
        DioClient.setToken(token);
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      } else {
        throw ServerException('Registration failed with status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
