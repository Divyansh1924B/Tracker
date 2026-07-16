import '../domain/member.dart';

class MemberModel extends Member {
  const MemberModel({
    required super.id,
    required super.email,
    required super.role,
    required super.name,
    super.phone,
    super.deviceName,
    super.photoUrl,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      deviceName: json['device_name'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'device_name': deviceName,
      'photo_url': photoUrl,
    };
  }
}
