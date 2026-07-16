import 'dart:io';
import 'local_locations_repository.dart';
import 'remote_locations_repository.dart';

class SyncService {
  final LocalLocationsRepository _localRepo;
  final RemoteLocationsRepository _remoteRepo;
  bool _isSyncing = false;

  SyncService(this._localRepo, this._remoteRepo);

  bool get isSyncing => _isSyncing;

  Future<void> syncPendingLocations({int batchSize = 20}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      while (true) {
        bool internet = false;
        try {
          final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            internet = true;
          }
        } catch (_) {
          internet = false;
        }

        if (!internet) {
          break;
        }

        final pending = await _localRepo.getPendingLocations(batchSize);
        if (pending.isEmpty) {
          break;
        }

        await _remoteRepo.uploadBatch(pending);

        final ids = pending.map((p) => p.id!).toList();
        await _localRepo.deleteLocations(ids);
      }
    } finally {
      _isSyncing = false;
    }
  }
}
