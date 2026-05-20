import 'package:supabase_flutter/supabase_flutter.dart';

/// Punto de acceso global al cliente de Supabase.
/// Uso: SupabaseService.client
class SupabaseService {
  SupabaseService._();

  static const String supabaseUrl = 'https://nnglhmbldffzlsnraryv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uZ2xobWJsZGZmemxzbnJhcnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4Mjk3MjksImV4cCI6MjA5MTQwNTcyOX0.aIH1G7t7UKty6lQE0RSx0EDxHWjgHAuLBd5GecCP1Gg';

  /// Inicializa Supabase. Llamar una sola vez en main().
  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  /// Cliente Supabase listo para usar en cualquier parte de la app.
  static SupabaseClient get client => Supabase.instance.client;

  /// Usuario actualmente autenticado (null si no hay sesión).
  static User? get currentUser => client.auth.currentUser;

  /// Stream de cambios de sesión.
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  // ── Auth helpers ──────────────────────────────────────────────

  /// Inicia sesión con email y contraseña.
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión actual.
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
