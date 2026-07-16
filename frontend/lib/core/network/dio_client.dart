import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  final Dio dio;
  static const _storage = FlutterSecureStorage();
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? get token => _token;

  DioClient({required String baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Read from secure storage if in-memory token is not set
          final currentToken = _token ?? await _storage.read(key: 'jwt_token');
          if (currentToken != null) {
            options.headers['Authorization'] = 'Bearer $currentToken';
          }
          return handler.next(options);
        },
      ),
    );
  }
}
