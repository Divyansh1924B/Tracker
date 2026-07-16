import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tracking/data/tracking_providers.dart';
import '../../tracking/domain/location_point.dart';
import '../domain/travel_statistics.dart';

class HistoryData {
  final TravelStatistics statistics;
  final List<LocationPoint> points;

  HistoryData({required this.statistics, required this.points});
}

enum HistoryRange { today, yesterday, last7Days, last30Days, custom }

class HistoryController extends StateNotifier<AsyncValue<HistoryData?>> {
  final Ref _ref;
  final String _memberId;
  HistoryRange _selectedRange = HistoryRange.today;
  DateTimeRange? _customDateRange;

  HistoryController(this._ref, this._memberId) : super(const AsyncData(null)) {
    loadHistory();
  }

  HistoryRange get selectedRange => _selectedRange;
  DateTimeRange? get customDateRange => _customDateRange;

  void setRange(HistoryRange range, {DateTimeRange? customRange}) {
    _selectedRange = range;
    if (range == HistoryRange.custom && customRange != null) {
      _customDateRange = customRange;
    }
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncLoading();
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      switch (_selectedRange) {
        case HistoryRange.today:
          start = DateTime(now.year, now.month, now.day);
          break;
        case HistoryRange.yesterday:
          start = DateTime(now.year, now.month, now.day - 1);
          end = DateTime(now.year, now.month, now.day).subtract(const Duration(milliseconds: 1));
          break;
        case HistoryRange.last7Days:
          start = now.subtract(const Duration(days: 7));
          break;
        case HistoryRange.last30Days:
          start = now.subtract(const Duration(days: 30));
          break;
        case HistoryRange.custom:
          if (_customDateRange == null) {
            state = const AsyncData(null);
            return;
          }
          start = _customDateRange!.start;
          end = _customDateRange!.end;
          break;
      }

      final repo = _ref.read(remoteLocationsRepositoryProvider);
      final data = await repo.fetchRouteHistory(
        _memberId,
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      );

      final statistics = TravelStatistics.fromJson(data['statistics'] as Map<String, dynamic>);
      final pointsList = (data['points'] as List<dynamic>)
          .map((p) => LocationPoint(
                latitude: (p['latitude'] as num).toDouble(),
                longitude: (p['longitude'] as num).toDouble(),
                accuracy: (p['accuracy'] as num).toDouble(),
                speed: (p['speed'] as num?)?.toDouble(),
                batteryPercentage: p['batteryPercentage'] as int?,
                chargingStatus: p['chargingStatus'] as bool?,
                gpsEnabled: p['gpsEnabled'] as bool? ?? true,
                internetAvailable: p['internetAvailable'] as bool? ?? true,
                timestamp: DateTime.parse(p['timestamp'] as String),
              ))
          .toList();

      state = AsyncData(HistoryData(statistics: statistics, points: pointsList));
    } catch (e, stack) {
      state = AsyncError(e.toString().replaceFirst('ServerException: ', ''), stack);
    }
  }
}

final historyControllerProvider =
    StateNotifierProvider.family<HistoryController, AsyncValue<HistoryData?>, String>((ref, memberId) {
  return HistoryController(ref, memberId);
});
