class LocationPoint {
  final int? id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final int? batteryPercentage;
  final bool? chargingStatus;
  final bool gpsEnabled;
  final bool internetAvailable;
  final String? deviceName;
  final DateTime timestamp;

  const LocationPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    this.batteryPercentage,
    this.chargingStatus,
    required this.gpsEnabled,
    required this.internetAvailable,
    this.deviceName,
    required this.timestamp,
  });

  Map<String, dynamic> toSqliteMap() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'battery_percentage': batteryPercentage,
      'charging_status': (chargingStatus ?? false) ? 1 : 0,
      'gps_enabled': gpsEnabled ? 1 : 0,
      'internet_available': internetAvailable ? 1 : 0,
      'device_name': deviceName,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory LocationPoint.fromSqliteMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double,
      speed: map['speed'] as double?,
      batteryPercentage: map['battery_percentage'] as int?,
      chargingStatus: map['charging_status'] == 1,
      gpsEnabled: map['gps_enabled'] == 1,
      internetAvailable: map['internet_available'] == 1,
      deviceName: map['device_name'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toApiMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'batteryPercentage': batteryPercentage,
      'chargingStatus': chargingStatus,
      'gpsEnabled': gpsEnabled,
      'internetAvailable': internetAvailable,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'deviceName': deviceName,
    };
  }
}
