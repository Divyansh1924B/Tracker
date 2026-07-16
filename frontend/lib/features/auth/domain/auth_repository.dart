import 'user.dart';

abstract class AuthRepository {
  Future<User> login(String email, String password, String deviceName);
  Future<void> logout();
  Future<User> getProfile();
  Future<User> updateProfile({required String name, String? phone, String? deviceName, String? photoUrl});
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String adminPassword,
    String? phone,
    String? deviceName,
  });
}
