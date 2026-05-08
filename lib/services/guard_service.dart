import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Modelo con el resultado de una validación de QR.
class ScanResult {
  final String resultado; // 'valido' | 'invalido' | 'usado'
  final String nombreAsistente;
  final String? codigoQR;
  final DateTime timestamp;

  ScanResult({
    required this.resultado,
    required this.nombreAsistente,
    this.codigoQR,
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

  // ── Verificar si el usuario actual es validador ────────────────

  /// Devuelve true si el usuario logueado tiene rol de validador.
  static Future<bool> isCurrentUserValidator() async {
    final user = SupabaseService.currentUser;
    if (user == null) return false;

    try {
      // 1. Obtener el id_rol del usuario
      final userData = await _client
          .from('usuarios')
          .select('id_rol')
          .eq('email', user.email!)
          .single();

      final idRol = userData['id_rol'];
      if (idRol == null) {
        print('El usuario no tiene un id_rol asignado.');
        return false;
      }

      // 2. Obtener el nombre del rol
      final roleData = await _client
          .from('roles')
          .select('nombre')
          .eq('id_rol', idRol)
          .single();

      final nombreRol = roleData['nombre']?.toString().toLowerCase().trim();
      print('Nombre del rol detectado: \$nombreRol');

      return nombreRol == 'validador';
    } catch (e) {
      print('Error en isCurrentUserValidator: \$e');
      return false;
    }
  }

  /// Obtiene el id_usuario del usuario autenticado.
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

  /// Valida un código QR y devuelve el resultado.
  /// - Si no existe en 'entradas' → invalido
  /// - Si estado == 'usado' → usado
  /// - Si estado == 'valido' → valido (registra ingreso)
  static Future<ScanResult> validateQR({
    required String codigoQR,
    required int idGuardia,
    int? idEvento,
  }) async {
    try {
      // 1) Buscar la entrada con ese código QR
      final List<dynamic> rows = await _client
          .from('entradas')
          .select('id_entrada, id_usuario, id_evento, estado, usuarios(nombre)')
          .eq('codigo_qr', codigoQR);

      if (rows.isEmpty) {
        // No existe → inválido
        await _logScan(
          codigoQR: codigoQR,
          resultado: 'invalido',
          idGuardia: idGuardia,
          idEvento: idEvento,
          nombreAsistente: 'Código inválido',
        );
        return ScanResult(
          resultado: 'invalido',
          nombreAsistente: 'Código inválido',
          codigoQR: codigoQR,
        );
      }

      final entrada = rows.first;
      final estado = entrada['estado'] as String;
      final usuarioData = entrada['usuarios'];
      final nombre = usuarioData != null
          ? (usuarioData['nombre'] ?? 'Sin nombre')
          : 'Sin nombre';
      final idEntrada = entrada['id_entrada'];
      final idEventoEntrada = entrada['id_evento'];

      if (estado == 'usado') {
        // Ya fue utilizado
        await _logScan(
          codigoQR: codigoQR,
          resultado: 'usado',
          idGuardia: idGuardia,
          idEvento: idEventoEntrada,
          nombreAsistente: nombre,
        );
        return ScanResult(
          resultado: 'usado',
          nombreAsistente: nombre,
          codigoQR: codigoQR,
        );
      }

      if (estado == 'cancelado') {
        await _logScan(
          codigoQR: codigoQR,
          resultado: 'invalido',
          idGuardia: idGuardia,
          idEvento: idEventoEntrada,
          nombreAsistente: nombre,
        );
        return ScanResult(
          resultado: 'invalido',
          nombreAsistente: '$nombre (cancelado)',
          codigoQR: codigoQR,
        );
      }

      // estado == 'valido' → registrar ingreso
      // 2) Actualizar estado a 'usado'
      await _client
          .from('entradas')
          .update({'estado': 'usado'})
          .eq('id_entrada', idEntrada);

      // 3) Crear registro en asistencias
      await _client.from('asistencias').insert({
        'id_entrada': idEntrada,
        'fecha_ingreso': DateTime.now().toIso8601String(),
        'validado_por': idGuardia,
      });

      // 4) Log del escaneo
      await _logScan(
        codigoQR: codigoQR,
        resultado: 'valido',
        idGuardia: idGuardia,
        idEvento: idEventoEntrada,
        nombreAsistente: nombre,
      );

      return ScanResult(
        resultado: 'valido',
        nombreAsistente: nombre,
        codigoQR: codigoQR,
      );
    } catch (e) {
      return ScanResult(
        resultado: 'invalido',
        nombreAsistente: 'Error: ${e.toString()}',
        codigoQR: codigoQR,
      );
    }
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
    } catch (_) {
      // No bloquear flujo si falla el log
    }
  }

  // ── Historial de escaneos recientes ───────────────────────────

  /// Obtiene los últimos [limit] escaneos del guardia actual.
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

  /// Devuelve las estadísticas de escaneos del guardia.
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
          case 'invalido':
            invalidos++;
            break;
          case 'usado':
            usados++;
            break;
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
