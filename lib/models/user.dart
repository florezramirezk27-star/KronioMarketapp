import '../utils/json_parsing.dart';

/// Cuenta del usuario autenticado.
///
/// El backend manda nombres de campo en ingles y el rol como string
/// (`"USER"` / `"ADMIN"`). Se parsea de forma defensiva porque el perfil puede
/// llegar envuelto (`{"user": {...}}`) o plano segun el endpoint.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;

  /// Rol del backend. Hoy solo distingue `ADMIN` del resto.
  final String? role;

  final String? phone;
  final DateTime? createdAt;

  bool get isAdmin => role == 'ADMIN';

  /// Nombre para saludar; cae al correo si el backend no manda nombre.
  String get displayName => name.isNotEmpty ? name : email;

  /// Iniciales para el avatar, maximo dos letras.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts[1].substring(0, 1).toUpperCase()}';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    return User(
      id: asString(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
      role: _nullIfEmpty(asString(json['role'])),
      phone: _nullIfEmpty(asString(json['phone'])),
      createdAt: rawCreatedAt == null
          ? null
          : DateTime.tryParse(rawCreatedAt.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    if (role != null) 'role': role,
    if (phone != null) 'phone': phone,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  static String? _nullIfEmpty(String value) => value.isEmpty ? null : value;
}
