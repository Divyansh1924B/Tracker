import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/constants.dart';
import '../domain/location_point.dart';
import 'local_locations_repository.dart';

class TrackingService {
  final LocalLocationsRepository _localRepo;
  StreamSubscription<Position>? _positionSubscription;
  final String _deviceName;
  bool _isTracking = false;
  static const _channel = MethodChannel('com.example.family_tracker/tracking');

  TrackingService(this._localRepo, this._deviceName);

  bool get isTracking => _isTracking;

  Future<bool> checkServiceState() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bool running = await _channel.invokeMethod('isServiceRunning') ?? false;
        _isTracking = running;
        return running;
      } catch (_) {
        return false;
      }
    }
    return _isTracking;
  }

  Future<void> startTracking(Function(LocationPoint) onPointCaptured) async {
    if (_isTracking) return;

    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission == LocationPermission.denied ||
        hasPermission == LocationPermission.deniedForever) {
      throw Exception('Location permission not granted');
    }

    _isTracking = true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('startService', {
          'deviceName': _deviceName,
          'jwtToken': DioClient.token,
          'apiBaseUrl': AppConstants.baseUrl,
        });
      } catch (e) {
        _isTracking = false;
        rethrow;
      }
    } else {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) async {
        final point = await _buildLocationPoint(position);
        await _localRepo.saveLocation(point);
        onPointCaptured(point);
      });
    }
  }

  Future<void> stopTracking() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod('stopService');
    } else {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
    }
    _isTracking = false;
  }

  Future<LocationPoint> _buildLocationPoint(Position position) async {
    bool internet = false;
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        internet = true;
      }
    } catch (_) {
      internet = false;
    }

    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      batteryPercentage: 85,
      chargingStatus: false,
      gpsEnabled: gpsEnabled,
      internetAvailable: internet,
      deviceName: _deviceName,
      timestamp: DateTime.now(),
    );
  }
}
