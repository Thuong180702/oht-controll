import 'dart:convert';

class UserAccount {
  final String username;
  final String password;
  final int role; // 0 = Admin, 1 = User điều khiển, 2 = User chỉ giám sát
  final bool isLocked;
  final String createdAt;

  const UserAccount({
    required this.username,
    required this.password,
    this.role = 1,
    this.isLocked = false,
    required this.createdAt,
  });

  bool get isAdmin => role == 0;
  bool get isOperator => role == 1;
  bool get isViewer => role == 2;

  String get roleLabel {
    return switch (role) {
      0 => 'Admin (Quản trị)',
      1 => 'Điều khiển (Operator)',
      2 => 'Chỉ giám sát (Viewer)',
      _ => 'User',
    };
  }

  UserAccount copyWith({
    String? username,
    String? password,
    int? role,
    bool? isLocked,
    String? createdAt,
  }) {
    return UserAccount(
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'isLocked': isLocked,
      'createdAt': createdAt,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      role: (json['role'] as num?)?.toInt() ?? 1,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory UserAccount.decode(String source) =>
      UserAccount.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
