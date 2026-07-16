import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/db_helper.dart';
import '../../auth/data/auth_providers.dart';
import 'local_locations_repository.dart';
import 'remote_locations_repository.dart';

final dbHelperProvider = Provider<DbHelper>((ref) {
  return DbHelper();
});

final localLocationsRepositoryProvider = Provider<LocalLocationsRepository>((ref) {
  final dbHelper = ref.watch(dbHelperProvider);
  return LocalLocationsRepository(dbHelper);
});

final remoteLocationsRepositoryProvider = Provider<RemoteLocationsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return RemoteLocationsRepository(dioClient);
});
