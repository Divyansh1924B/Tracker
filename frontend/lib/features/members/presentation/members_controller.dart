import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/member.dart';
import '../domain/members_repository.dart';
import '../data/members_repository_impl.dart';

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return MembersRepositoryImpl(dioClient);
});

class MembersController extends StateNotifier<AsyncValue<List<Member>>> {
  final MembersRepository _repository;

  MembersController(this._repository) : super(const AsyncLoading()) {
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    state = const AsyncLoading();
    try {
      final list = await _repository.getMembers();
      state = AsyncData(list);
    } catch (e, stack) {
      state = AsyncError(e.toString().replaceFirst('ServerException: ', ''), stack);
    }
  }

  Future<void> addMember({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
  }) async {
    try {
      final newMember = await _repository.createMember(
        email: email,
        password: password,
        name: name,
        phone: phone,
        deviceName: deviceName,
        photoUrl: photoUrl,
      );
      
      final currentList = state.value ?? [];
      state = AsyncData([...currentList, newMember]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> editMember(
    String id, {
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
    String? password,
  }) async {
    try {
      final updatedMember = await _repository.updateMember(
        id,
        name: name,
        phone: phone,
        deviceName: deviceName,
        photoUrl: photoUrl,
        password: password,
      );

      final currentList = state.value ?? [];
      state = AsyncData(
        currentList.map((m) => m.id == id ? updatedMember : m).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMember(String id) async {
    try {
      await _repository.deleteMember(id);
      final currentList = state.value ?? [];
      state = AsyncData(currentList.where((m) => m.id != id).toList());
    } catch (e) {
      rethrow;
    }
  }
}

final membersControllerProvider =
    StateNotifierProvider<MembersController, AsyncValue<List<Member>>>((ref) {
  final repository = ref.watch(membersRepositoryProvider);
  return MembersController(repository);
});
