class TravelStatistics {
  final double totalDistanceKm;
  final int movingTimeSeconds;
  final int stoppedTimeSeconds;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final int pointsCount;
  final DateTime? firstLocationTime;
  final DateTime? lastLocationTime;

  const TravelStatistics({
    required this.totalDistanceKm,
    required this.movingTimeSeconds,
    required this.stoppedTimeSeconds,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.pointsCount,
    this.firstLocationTime,
    this.lastLocationTime,
  });

  factory TravelStatistics.fromJson(Map<String, dynamic> json) {
    return TravelStatistics(
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      movingTimeSeconds: json['movingTimeSeconds'] as int,
      stoppedTimeSeconds: json['stoppedTimeSeconds'] as int,
      averageSpeedKmh: (json['averageSpeedKmh'] as num).toDouble(),
      maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
      pointsCount: json['pointsCount'] as int,
      firstLocationTime: json['firstLocationTime'] != null
          ? DateTime.parse(json['firstLocationTime'] as String)
          : null,
      lastLocationTime: json['lastLocationTime'] != null
          ? DateTime.parse(json['lastLocationTime'] as String)
          : null,
    );
  }
}
