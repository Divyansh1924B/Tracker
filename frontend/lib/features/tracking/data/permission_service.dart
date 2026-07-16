import 'package:geolocator/geolocator.dart';

class PermissionService {
  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<bool> hasAlwaysPermission() async {
    final status = await checkLocationPermission();
    return status == LocationPermission.always;
  }
}
