import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    required int idRol,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nombre': nombre, 'id_rol': idRol},
    );
  }

  // Inyectar con --dart-define=GOOGLE_CLIENT_ID=...
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '20543870962-g64kl64vhdu5dlthkmlglgq5qfl6ocg0.apps.googleusercontent.com',
  );

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: _webClientId,
      scopes: ['email', 'profile'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw 'Inicio de sesión cancelado por el usuario';

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw 'Fallo al obtener los tokens de Google';

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }
}
