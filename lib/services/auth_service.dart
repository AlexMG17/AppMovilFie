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
    // 1. Crea el usuario en el sistema seguro y enviamos la información extra
    // en el parámetro "data" (metadatos).
    // El Trigger de Supabase (on_auth_user_created) leerá estos datos
    // y los insertará de forma automática y segura en la tabla 'usuarios'.
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre, 'id_rol': idRol},
    );

    // Nota: ¡Eliminamos el "supabase.from('usuarios').insert(...)" de aquí
    // para no chocar con el Trigger y evitar el Error 500!
  }
}
