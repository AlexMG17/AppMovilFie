import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Instancia de Supabase para comunicarnos con tu base de datos
  final supabase = Supabase.instance.client;

  // ==========================================
  // INICIAR SESIÓN (CORREO)
  // ==========================================
  Future<void> signIn({required String email, required String password}) async {
    // Esto valida el correo y la contraseña contra el sistema seguro de Supabase Auth
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  // ==========================================
  // REGISTRARSE (CORREO)
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

  // ==========================================
  // INICIAR SESIÓN CON GOOGLE (NATIVO - SIN NAVEGADOR)
  // ==========================================
  Future<void> signInWithGoogle() async {
    // ⚠️ REEMPLAZA ESTO: Pon aquí el "Web client ID" de tu Google Cloud Console.
    // ¡Asegúrate de que sea el de TIPO WEB, no el de Android!
    const webClientId = '20543870962-g64kl64vhdu5dlthkmlglgq5qfl6ocg0.apps.googleusercontent.com';

    // Inicializamos Google Sign In pidiendo el token del servidor
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
      scopes: ['email', 'profile'],
    );

    // Esto levanta el cuadrito nativo de Android desde abajo de la pantalla
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw 'Inicio de sesión cancelado por el usuario';
    }

    // Obtenemos las llaves criptográficas de Google
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw 'Fallo al obtener los tokens de Google';
    }

    // Enviamos esas llaves a Supabase por detrás para iniciar sesión
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }
}
