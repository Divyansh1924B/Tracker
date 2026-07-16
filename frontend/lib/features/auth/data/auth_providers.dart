import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/constants.dart';
import '../domain/auth_repository.dart';
import 'auth_repository_impl.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(baseUrl: AppConstants.baseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepositoryImpl(dioClient);
});
