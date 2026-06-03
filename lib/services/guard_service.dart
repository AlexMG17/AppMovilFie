import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_unique_service.dart';
import 'supabase_service.dart';

/// Modelo con el resultado de una validación de QR.
class ScanResult {
  final String resultado; // 'valido' | 'invalido' | 'usado' | 'expirado' | 'evento_incorrecto'
  final String nombreAsistente;
  final String? codigoQR;
  final String? razon;
  final DateTime? fechaExpiracion;
  final DateTime timestamp;

  ScanResult({
    required this.resultado,
    required this.nombreAsistente,
    this.codigoQR,
    this.razon,
    this.fechaExpiracion,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Estadísticas de escaneo en tiempo real.
class ScanStats {
  final int ingresados;
  final int invalidos;
  final int usados;

  ScanStats({
    required this.ingresados,
    required this.invalidos,
    required this.usados,
  });
}

/// Servicio para las operaciones del guardia/validador.
class GuardService {
  GuardService._();

  static SupabaseClient get _client => SupabaseService.client;

  // ── Rol del usuario actual ────────────────────────────────────

  static const _kRoleKey = 'cached_user_role';

  /// Returns the role cached from the last successful fetch (instant, no network).
  static Future<String?> getCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRoleKey);
  }

  /// Fetches the role from Supabase (1 JOIN query) and updates the local cache.
  static Future<String?> getCurrentUserRole() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('usuarios')
          .select('roles(nombre)')
          .eq('email', user.email!)
          .single();

      final role =
          (data['roles'] as Map?)?['nombre']?.toString().toLowerCase().trim();

      if (role != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kRoleKey, role);
      }
      return role;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isCurrentUserValidator() async {
    final role = await getCurrentUserRole();
    return role == 'validador';
  }

  static Future<int?> getCurrentGuardId() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('usuarios')
          .select('id_usuario')
          .eq('email', user.email!)
          .single();
      return data['id_usuario'] as int;
    } catch (_) {
      return null;
    }
  }

  // ── Validar código QR ─────────────────────────────────────────

  /// Valida un código QR delegando toda la lógica a [QrUniqueService].
  /// Incluye: verificación de evento, expiración, estado y marcado como usado.
  static Future<ScanResult> validateQR({
    required String codigoQR,
    int? idGuardia,
    int? idEvento,
  }) async {
    final qrResult = await QrUniqueService.validateQR(
      codigoQR: codigoQR,
      idEventoEsperado: idEvento,
      idGuardia: idGuardia,
    );

    if (idGuardia != null) {
      await _logScan(
        codigoQR: codigoQR,
        resultado: qrResult.resultado,
        idGuardia: idGuardia,
        idEvento: qrResult.idEvento ?? idEvento,
        nombreAsistente: qrResult.nombreAsistente,
      );
    }

    return ScanResult(
      resultado: qrResult.resultado,
      nombreAsistente: qrResult.nombreAsistente,
      codigoQR: codigoQR,
      razon: qrResult.razon,
      fechaExpiracion: qrResult.fechaExpiracion,
    );
  }

  // ── Registro de escaneo (scan_logs) ───────────────────────────

  static Future<void> _logScan({
    required String codigoQR,
    required String resultado,
    required int idGuardia,
    int? idEvento,
    String? nombreAsistente,
  }) async {
    try {
      await _client.from('scan_logs').insert({
        'codigo_qr': codigoQR,
        'resultado': resultado,
        'id_guardia': idGuardia,
        'id_evento': idEvento,
        'nombre_asistente': nombreAsistente,
        'escaneado_en': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Historial de escaneos recientes ───────────────────────────

  static Future<List<ScanResult>> getRecentScans({
    required int idGuardia,
    int limit = 10,
  }) async {
    try {
      final rows = await _client
          .from('scan_logs')
          .select()
          .eq('id_guardia', idGuardia)
          .order('escaneado_en', ascending: false)
          .limit(limit);

      return (rows as List).map((row) {
        return ScanResult(
          resultado: row['resultado'] ?? 'invalido',
          nombreAsistente: row['nombre_asistente'] ?? 'Desconocido',
          codigoQR: row['codigo_qr'],
          timestamp:
              DateTime.tryParse(row['escaneado_en'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Estadísticas en tiempo real ───────────────────────────────

  /// Revierte un ingreso válido: resetea dentro_evento = false y elimina la última asistencia.
  static Future<bool> undoEntry({required String codigoQR}) async {
    try {
      final row = await _client
          .from('entradas')
          .select('id_entrada')
          .eq('codigo_qr', codigoQR)
          .maybeSingle();

      if (row == null) return false;
      final idEntrada = row['id_entrada'] as int;

      await _client
          .from('entradas')
          .update({'dentro_evento': false})
          .eq('id_entrada', idEntrada);

      final asist = await _client
          .from('asistencias')
          .select('id_asistencia')
          .eq('id_entrada', idEntrada)
          .order('fecha_ingreso', ascending: false)
          .limit(1)
          .maybeSingle();

      if (asist != null) {
        await _client
            .from('asistencias')
            .delete()
            .eq('id_asistencia', asist['id_asistencia'] as int);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 'valido' → ingresados | 'usado' → usados | todo lo demás → invalidos
  static Future<ScanStats> getStats({required int idGuardia}) async {
    try {
      final rows = await _client
          .from('scan_logs')
          .select('resultado')
          .eq('id_guardia', idGuardia);

      int ingresados = 0;
      int invalidos = 0;
      int usados = 0;

      for (final row in rows) {
        switch (row['resultado']) {
          case 'valido':
            ingresados++;
            break;
          case 'usado':
            usados++;
            break;
          default:
            invalidos++;
        }
      }

      return ScanStats(
        ingresados: ingresados,
        invalidos: invalidos,
        usados: usados,
      );
    } catch (_) {
      return ScanStats(ingresados: 0, invalidos: 0, usados: 0);
    }
  }
}
