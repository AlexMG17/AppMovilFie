import 'supabase_service.dart';

class AppUser {
  final int id;
  final String nombre;
  final String email;
  final int idRol;
  final String rolNombre;

  const AppUser({
    required this.id,
    required this.nombre,
    required this.email,
    required this.idRol,
    required this.rolNombre,
  });

  AppUser copyWith({int? idRol, String? rolNombre}) => AppUser(
    id: id,
    nombre: nombre,
    email: email,
    idRol: idRol ?? this.idRol,
    rolNombre: rolNombre ?? this.rolNombre,
  );
}

class RoleOption {
  final int id;
  final String nombre;

  const RoleOption({required this.id, required this.nombre});
}

class UserManagementService {
  UserManagementService._();

  static dynamic get _client => SupabaseService.client;

  static Future<List<AppUser>> getAllUsers() async {
    final rows = await _client
        .from('usuarios')
        .select('id_usuario, nombre, email, id_rol, roles(nombre)')
        .order('nombre');

    return (rows as List).map((row) {
      final dynamic roleData = row['roles'];
      String rolNombre = 'sin rol';
      if (roleData is Map) {
        rolNombre = (roleData['nombre'] ?? 'sin rol').toString().toLowerCase().trim();
      }
      return AppUser(
        id: row['id_usuario'] as int,
        nombre: row['nombre'] ?? '',
        email: row['email'] ?? '',
        idRol: (row['id_rol'] as int?) ?? 0,
        rolNombre: rolNombre,
      );
    }).toList();
  }

  static Future<List<RoleOption>> getAllRoles() async {
    final rows = await _client
        .from('roles')
        .select('id_rol, nombre')
        .order('id_rol');

    return (rows as List)
        .map((row) => RoleOption(
              id: row['id_rol'] as int,
              nombre: (row['nombre'] ?? '').toString(),
            ))
        .toList();
  }

  static Future<void> updateUserRole(int userId, int newRoleId) async {
    await _client
        .from('usuarios')
        .update({'id_rol': newRoleId})
        .eq('id_usuario', userId);
  }
}
