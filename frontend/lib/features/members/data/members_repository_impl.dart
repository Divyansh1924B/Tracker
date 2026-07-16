import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../domain/member.dart';
import '../domain/members_repository.dart';
import 'member_model.dart';

class MembersRepositoryImpl implements MembersRepository {
  final DioClient _client;

  MembersRepositoryImpl(this._client);

  @override
  Future<List<Member>> getMembers() async {
    try {
      final response = await _client.dio.get('/members');
      if (response.statusCode == 200) {
        final list = response.data as List<dynamic>;
        return list.map((item) => MemberModel.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        throw ServerException('Failed to fetch members list');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Member> getMemberDetails(String id) async {
    try {
      final response = await _client.dio.get('/members/$id');
      if (response.statusCode == 200) {
        return MemberModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to fetch member details');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Member> createMember({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
  }) async {
    try {
      final response = await _client.dio.post(
        '/members',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
          'deviceName': deviceName,
          'photoUrl': photoUrl,
        },
      );

      if (response.statusCode == 201) {
        return MemberModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to create member');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Member> updateMember(
    String id, {
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
    String? password,
  }) async {
    try {
      final response = await _client.dio.put(
        '/members/$id',
        data: {
          'name': name,
          'phone': phone,
          'deviceName': deviceName,
          'photoUrl': photoUrl,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return MemberModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to update member');
      }
    } on DioException catch (e) {
      final Map<String, dynamic>? resData = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : null;
      final msg = resData?['error']?.toString() ?? e.message ?? 'Unknown error';
      throw ServerException(msg);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteMember(String id) async {
    try {
      final response = await _client.dio.delete('/members/$id');
      if (response.statusCode != 200) {
        throw ServerException('Failed to delete member');
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
