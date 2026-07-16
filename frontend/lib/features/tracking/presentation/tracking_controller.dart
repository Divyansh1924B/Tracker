import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/location_point.dart';
import '../data/tracking_providers.dart';
import '../data/permission_service.dart';
import '../data/tracking_service.dart';
import '../data/sync_service.dart';
import '../../auth/presentation/auth_controller.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final trackingServiceProvider = Provider<TrackingService>((ref) {
  final localRepo = ref.watch(localLocationsRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final deviceName = authState is Authenticated ? (authState.user.deviceName ?? 'Unknown Device') : 'Unknown Device';
  return TrackingService(localRepo, deviceName);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final localRepo = ref.watch(localLocationsRepositoryProvider);
  final remoteRepo = ref.watch(remoteLocationsRepositoryProvider);
  return SyncService(localRepo, remoteRepo);
});

class TrackingEngineState {
  final bool isTracking;
  final LocationPermission permissionStatus;
  final int pendingUploadCount;
  final LocationPoint? lastCapturedPoint;
  final bool gpsEnabled;
  final bool internetAvailable;

  TrackingEngineState({
    required this.isTracking,
    required this.permissionStatus,
    required this.pendingUploadCount,
    this.lastCapturedPoint,
    required this.gpsEnabled,
    required this.internetAvailable,
  });

  TrackingEngineState copyWith({
    bool? isTracking,
    LocationPermission? permissionStatus,
    int? pendingUploadCount,
    LocationPoint? lastCapturedPoint,
    bool? gpsEnabled,
    bool? internetAvailable,
  }) {
    return TrackingEngineState(
      isTracking: isTracking ?? this.isTracking,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
      lastCapturedPoint: lastCapturedPoint ?? this.lastCapturedPoint,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      internetAvailable: internetAvailable ?? this.internetAvailable,
    );
  }
}

class TrackingController extends StateNotifier<TrackingEngineState> {
  final PermissionService _permissionService;
  final TrackingService _trackingService;
  final SyncService _syncService;
  final Ref _ref;
  Timer? _syncTimer;
  Timer? _statusTimer;

  TrackingController(
    this._permissionService,
    this._trackingService,
    this._syncService,
    this._ref,
  ) : super(TrackingEngineState(
          isTracking: false,
          permissionStatus: LocationPermission.denied,
          pendingUploadCount: 0,
          gpsEnabled: true,
          internetAvailable: true,
        )) {
    _init();
  }

  void _init() async {
    final permission = await _permissionService.checkLocationPermission();
    final gps = await _permissionService.isLocationEnabled();
    final count = await _ref.read(localLocationsRepositoryProvider).getPendingCount();
    final isTracking = await _trackingService.checkServiceState();
    final lastPoint = await _ref.read(localLocationsRepositoryProvider).getLastCapturedLocation();

    state = state.copyWith(
      permissionStatus: permission,
      gpsEnabled: gps,
      pendingUploadCount: count,
      isTracking: isTracking,
      lastCapturedPoint: lastPoint,
    );

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshStatusInfo());
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => triggerSync());
  }

  Future<void> refreshStatusInfo() async {
    final permission = await _permissionService.checkLocationPermission();
    final gps = await _permissionService.isLocationEnabled();
    final count = await _ref.read(localLocationsRepositoryProvider).getPendingCount();
    final isTracking = await _trackingService.checkServiceState();
    final lastPoint = await _ref.read(localLocationsRepositoryProvider).getLastCapturedLocation();

    bool internet = false;
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        internet = true;
      }
    } catch (_) {
      internet = false;
    }

    state = state.copyWith(
      permissionStatus: permission,
      gpsEnabled: gps,
      pendingUploadCount: count,
      internetAvailable: internet,
      isTracking: isTracking,
      lastCapturedPoint: lastPoint,
    );
  }

  Future<void> requestPermissions() async {
    final result = await _permissionService.requestLocationPermission();
    state = state.copyWith(permissionStatus: result);
  }

  Future<void> toggleTracking() async {
    if (state.isTracking) {
      await _trackingService.stopTracking();
      state = state.copyWith(isTracking: false);
    } else {
      await _trackingService.startTracking((point) {
        state = state.copyWith(
          lastCapturedPoint: point,
          pendingUploadCount: state.pendingUploadCount + 1,
        );
        triggerSync();
      });
      state = state.copyWith(isTracking: true);
    }
  }

  Future<void> triggerSync() async {
    await _syncService.syncPendingLocations();
    final count = await _ref.read(localLocationsRepositoryProvider).getPendingCount();
    state = state.copyWith(pendingUploadCount: count);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _statusTimer?.cancel();
    _trackingService.stopTracking();
    super.dispose();
  }
}

final trackingControllerProvider =
    StateNotifierProvider<TrackingController, TrackingEngineState>((ref) {
  final permissionService = ref.watch(permissionServiceProvider);
  final trackingService = ref.watch(trackingServiceProvider);
  final syncService = ref.watch(syncServiceProvider);
  return TrackingController(permissionService, trackingService, syncService, ref);
});
