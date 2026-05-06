import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Instancia de Supabase para comunicarnos con tu base de datos
  final supabase = Supabase.instance.client;

  // ==========================================
  // INICIAR SESIÓN
  // ==========================================
  Future<void> signIn({required String email, required String password}) async {
    // Esto valida el correo y la contraseña contra el sistema seguro de Supabase Auth
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  // ==========================================
  // REGISTRARSE
  // ==========================================
  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    required int idRol, // Ej: 1 para Estudiante, 2 para Externo
  }) async {
    // 1. Crea el usuario en el sistema de autenticación seguro de Supabase
    final AuthResponse res = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    // 2. Si se creó exitosamente, guardamos los datos extra en tu tabla pública 'usuarios'
    if (res.user != null) {
      await supabase.from('usuarios').insert({
        // No mandamos el 'id_usuario' porque en tu diagrama es 'Identity' (se autogenera)
        'nombre': nombre,
        'email': email,
        'id_rol': idRol,
      });
    }
  }
}
