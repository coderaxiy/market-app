// Mirrors openapi/api.yaml -> UserRead (the auth request bodies and TokenResponse /
// MessageResponse are built/ignored inline by the repository).

class UserRead {
  const UserRead({
    required this.id,
    required this.email,
    required this.isActive,
    required this.roles,
    this.fullName,
    this.phone,
  });

  factory UserRead.fromJson(Map<String, dynamic> json) => UserRead(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
    isActive: json['is_active'] as bool,
    roles: (json['roles'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>(),
  );

  final int id;
  final String email;
  final String? fullName;
  final String? phone;
  final bool isActive;
  final List<String> roles;
}
