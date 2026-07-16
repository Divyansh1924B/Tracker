import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../domain/location_point.dart';

class RemoteLocationsRepository {
  final DioClient _client;

  RemoteLocationsRepository(this._client);

  Future<void> uploadBatch(List<LocationPoint> points) async {
    if (points.isEmpty) return;
    try {
      final pointsData = points.map((p) => p.toApiMap()).toList();
      final response = await _client.dio.post(
        '/locations/sync',
        data: {'points': pointsData},
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to upload coordinates batch');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<Map<String, dynamic>> fetchRouteHistory(
    String userId,
    String startDate,
    String endDate,
  ) async {
    try {
      final response = await _client.dio.get(
        '/locations/history',
        queryParameters: {
          'userId': userId,
          'startDate': startDate,
          'endDate': endDate,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ServerException('Failed to load route history');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
