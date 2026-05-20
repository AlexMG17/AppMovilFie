import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

const _kExpirationDays = 90;

/// Resultado completo de una validación de QR.
class QrValidationResult {
  final String resultado; // 'valido' | 'invalido' | 'usado' | 'expirado' | 'evento_incorrecto'
  final String nombreAsistente;
  final String? codigoQR;
  final String? razon;
  final int? idEntrada;
  final int? idEvento;
  final DateTime? fechaExpiracion;
  final int? versionQr;
  final DateTime timestamp;

  QrValidationResult({
    required this.resultado,
    required this.nombreAsistente,
    this.codigoQR,
    this.razon,
    this.idEntrada,
    this.idEvento,
    this.fechaExpiracion,
    this.versionQr,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Servicio central para QR únicos: generación UUID y validación completa.
class QrUniqueService {
  QrUniqueService._();

  static SupabaseClient get _client => SupabaseService.client;
  static const _uuid = Uuid();

  /// Genera un código QR único (UUID v4).
  static String generateCode() => _uuid.v4();

  /// Crea una nueva entrada o renueva una existente con QR único.
  /// Incrementa version_qr si ya existía.
  /// Retorna el nuevo código QR.
  static Future<String> createOrRenewEntry({
    required int idUsuario,
    required int idEvento,
    int? existingEntradaId,
  }) async {
    final now = DateTime.now();
    final codigoQR = generateCode();
    final expiresAt = now.add(const Duration(days: _kExpirationDays));

    if (existingEntradaId != null) {
      final current = await _client
          .from('entradas')
          .select('version_qr')
          .eq('id_entrada', existingEntradaId)
          .maybeSingle();

      final nextVersion = ((current?['version_qr'] as int?) ?? 0) + 1;

      await _client.from('entradas').update({
        'codigo_qr': codigoQR,
        'estado': 'activo',
        'fecha_generacion': now.toIso8601String(),
        'fecha_expiracion': expiresAt.toIso8601String(),
        'version_qr': nextVersion,
      }).eq('id_entrada', existingEntradaId);
    } else {
      await _client.from('entradas').insert({
        'id_usuario': idUsuario,
        'id_evento': idEvento,
        'codigo_qr': codigoQR,
        'estado': 'activo',
        'fecha_generacion': now.toIso8601String(),
        'fecha_expiracion': expiresAt.toIso8601String(),
        'version_qr': 1,
      });
    }

    return codigoQR;
  }

  /// Valida un código QR con todas las verificaciones:
  ///   1. Existe en la tabla entradas
  ///   2. Pertenece al evento esperado (si idEventoEsperado != null)
  ///   3. No está expirado
  ///   4. Estado es 'activo'
  ///
  /// Si es válido → marca como 'usado' e inserta en asistencias.
  static Future<QrValidationResult> validateQR({
    required String codigoQR,
    int? idEventoEsperado,
    int? idGuardia,
  }) async {
    try {
      final List<dynamic> rows = await _client
          .from('entradas')
          .select(
              'id_entrada, id_usuario, id_evento, estado, '
              'fecha_expiracion, version_qr, usuarios(nombre)')
          .eq('codigo_qr', codigoQR);

      if (rows.isEmpty) {
        return QrValidationResult(
          resultado: 'invalido',
          nombreAsistente: 'Código no encontrado',
          codigoQR: codigoQR,
          razon: 'El código QR no existe en el sistema.',
        );
      }

      final entrada = rows.first as Map<String, dynamic>;
      final estado = entrada['estado'] as String? ?? '';
      final idEventoEntrada = entrada['id_evento'] as int?;
      final idEntrada = entrada['id_entrada'] as int;
      final usuarioData = entrada['usuarios'];
      final nombre = usuarioData is Map
          ? (usuarioData['nombre'] as String? ?? 'Sin nombre')
          : 'Sin nombre';

      DateTime? fechaExpiracion;
      if (entrada['fecha_expiracion'] != null) {
        fechaExpiracion =
            DateTime.tryParse(entrada['fecha_expiracion'].toString());
      }
      final versionQr = entrada['version_qr'] as int?;

      // 1. Verificar evento
      if (idEventoEsperado != null &&
          idEventoEntrada != null &&
          idEventoEntrada != idEventoEsperado) {
        return QrValidationResult(
          resultado: 'evento_incorrecto',
          nombreAsistente: nombre,
          codigoQR: codigoQR,
          razon: 'Este QR pertenece a otro evento.',
          idEntrada: idEntrada,
          idEvento: idEventoEntrada,
          fechaExpiracion: fechaExpiracion,
          versionQr: versionQr,
        );
      }

      // 2. Verificar expiración
      if (fechaExpiracion != null && DateTime.now().isAfter(fechaExpiracion)) {
        return QrValidationResult(
          resultado: 'expirado',
          nombreAsistente: nombre,
          codigoQR: codigoQR,
          razon: 'El código QR ha expirado.',
          idEntrada: idEntrada,
          idEvento: idEventoEntrada,
          fechaExpiracion: fechaExpiracion,
          versionQr: versionQr,
        );
      }

      // 3. Verificar estado
      if (estado == 'usado') {
        return QrValidationResult(
          resultado: 'usado',
          nombreAsistente: nombre,
          codigoQR: codigoQR,
          razon: 'Este QR ya fue utilizado para ingresar.',
          idEntrada: idEntrada,
          idEvento: idEventoEntrada,
          fechaExpiracion: fechaExpiracion,
          versionQr: versionQr,
        );
      }

      if (estado == 'cancelado') {
        return QrValidationResult(
          resultado: 'invalido',
          nombreAsistente: '$nombre (cancelado)',
          codigoQR: codigoQR,
          razon: 'La entrada fue cancelada.',
          idEntrada: idEntrada,
          idEvento: idEventoEntrada,
          fechaExpiracion: fechaExpiracion,
          versionQr: versionQr,
        );
      }

      // 4. QR válido → marcar como usado
      await _client
          .from('entradas')
          .update({'estado': 'usado'})
          .eq('id_entrada', idEntrada);

      // 5. Registrar asistencia (falla silenciosamente si la tabla no existe)
      try {
        await _client.from('asistencias').insert({
          'id_entrada': idEntrada,
          'fecha_ingreso': DateTime.now().toIso8601String(),
          'validado_por': idGuardia,
        });
      } catch (_) {}

      return QrValidationResult(
        resultado: 'valido',
        nombreAsistente: nombre,
        codigoQR: codigoQR,
        idEntrada: idEntrada,
        idEvento: idEventoEntrada,
        fechaExpiracion: fechaExpiracion,
        versionQr: versionQr,
      );
    } catch (e) {
      return QrValidationResult(
        resultado: 'invalido',
        nombreAsistente: 'Error al validar',
        codigoQR: codigoQR,
        razon: e.toString(),
      );
    }
  }
}
