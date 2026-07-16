import 'member.dart';

abstract class MembersRepository {
  Future<List<Member>> getMembers();
  Future<Member> getMemberDetails(String id);
  Future<Member> createMember({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
  });
  Future<Member> updateMember(
    String id, {
    required String name,
    String? phone,
    String? deviceName,
    String? photoUrl,
    String? password,
  });
  Future<void> deleteMember(String id);
}
