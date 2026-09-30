// Mirrors openapi/api.yaml -> UserRead (LoginRequest, RegisterRequest and TokenResponse
// are sent/ignored inline by the repository).

class UserRead {
  const UserRead({
    required this.id,
    required this.email,
    required this.isActive,
    required this.roles,
    this.fullName,
  });

  factory UserRead.fromJson(Map<String, dynamic> json) => UserRead(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    isActive: json['is_active'] as bool,
    roles: (json['roles'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>(),
  );

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final List<String> roles;
}
