class User {
  final String id;
  final String email;
  final String role;
  final String name;
  final String? phone;
  final String? deviceName;
  final String? photoUrl;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.deviceName,
    this.photoUrl,
  });

  bool get isAdmin => role == 'admin';
}
