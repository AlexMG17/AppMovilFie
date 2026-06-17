import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'qr_unique_service.dart';
import 'supabase_service.dart';

/// Modelo que mapea la tabla `pagos`.
class PagoModel {
  final int id;
  final int idUsuario;
  final int idEvento;
  final String? comprobante; // URL en Storage o referencia de transferencia
  final String estado;       // pendiente | aprobado | rechazado
  final DateTime fechaPago;
  final double? monto;

  const PagoModel({
    required this.id,
    required this.idUsuario,
    required this.idEvento,
    this.comprobante,
    required this.estado,
    required this.fechaPago,
    this.monto,
  });

  factory PagoModel.fromMap(Map<String, dynamic> map) => PagoModel(
        id: map['id_pago'] as int,
        idUsuario: map['id_usuario'] as int,
        idEvento: map['id_evento'] as int,
        comprobante: map['comprobante'] as String?,
        estado: map['estado'] ?? 'pendiente',
        fechaPago: DateTime.tryParse(map['fecha_pago'].toString()) ??
            DateTime.now(),
        monto: (map['monto'] as num?)?.toDouble(),
      );

  bool get isPending => estado == 'pendiente';
  bool get isApproved => estado == 'aprobado';
  bool get isRejected => estado == 'rechazado';
  bool get isPreApproved => estado == 'pre_aprobado';
}

/// Modelo para la vista admin: pago + datos del usuario.
class PagoAdminModel {
  final int id;
  final int idUsuario;
  final int idEvento;
  final String nombreUsuario;
  final String emailUsuario;
  final String? comprobante;
  final String estado;
  final DateTime fechaPago;

  final double? monto;

  const PagoAdminModel({
    required this.id,
    required this.idUsuario,
    required this.idEvento,
    required this.nombreUsuario,
    required this.emailUsuario,
    this.comprobante,
    required this.estado,
    required this.fechaPago,
    this.monto,
  });

  factory PagoAdminModel.fromMap(Map<String, dynamic> map) {
    final u = map['usuarios'];
    return PagoAdminModel(
      id: map['id_pago'] as int,
      idUsuario: map['id_usuario'] as int,
      idEvento: map['id_evento'] as int,
      nombreUsuario: u is Map ? (u['nombre'] ?? 'Sin nombre') : 'Sin nombre',
      emailUsuario: u is Map ? (u['email'] ?? '') : '',
      comprobante: map['comprobante'] as String?,
      estado: map['estado'] ?? 'pendiente',
      fechaPago:
          DateTime.tryParse(map['fecha_pago'].toString()) ?? DateTime.now(),
      monto: (map['monto'] as num?)?.toDouble(),
    );
  }

  bool get isPending => estado == 'pendiente';
  bool get isApproved => estado == 'aprobado';
  bool get isRejected => estado == 'rechazado';
  bool get isPreApproved => estado == 'pre_aprobado';
  bool get comprobanteIsUrl => comprobante?.startsWith('http') == true;
}

class PaymentService {
  PaymentService._();

  static SupabaseClient get _client => SupabaseService.client;
  static const _bucket = 'comprobantes';

  /// Sube el archivo a Supabase Storage y retorna la URL pública.
  static Future<String> uploadVoucher({
    required String filePath,
    required String fileName,
    required int userId,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final ext = fileName.split('.').last.toLowerCase();
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: _mimeType(ext), upsert: true),
        );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  /// Crea o actualiza el pago en la tabla `pagos`.
  /// [comprobante] puede ser la URL de Storage o una referencia manual.
  static Future<void> submitPago({
    required int idUsuario,
    required int idEvento,
    required String comprobante,
  }) async {
    final existing = await _client
        .from('pagos')
        .select('id_pago')
        .eq('id_usuario', idUsuario)
        .eq('id_evento', idEvento)
        .maybeSingle();

    if (existing != null) {
      await _client.from('pagos').update({
        'comprobante': comprobante,
        'estado': 'pendiente',
        'fecha_pago': DateTime.now().toIso8601String(),
      }).eq('id_pago', existing['id_pago']);
    } else {
      await _client.from('pagos').insert({
        'id_usuario': idUsuario,
        'id_evento': idEvento,
        'comprobante': comprobante,
        'estado': 'pendiente',
        'fecha_pago': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Retorna el pago más reciente del estudiante para el evento.
  static Future<PagoModel?> getMyPago({
    required int idUsuario,
    required int idEvento,
  }) async {
    try {
      final data = await _client
          .from('pagos')
          .select()
          .eq('id_usuario', idUsuario)
          .eq('id_evento', idEvento)
          .order('fecha_pago', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return PagoModel.fromMap(data);
    } catch (e) {
      debugPrint('PaymentService.getMyPago: $e');
      return null;
    }
  }

  /// Retorna todos los pagos del evento con el nombre del usuario (admin).
  static Future<List<PagoAdminModel>> getAllPagos({
    required int idEvento,
  }) async {
    final data = await _client
        .from('pagos')
        .select('*, usuarios(nombre, email)')
        .eq('id_evento', idEvento)
        .order('fecha_pago', ascending: false);
    return (data as List).map((e) => PagoAdminModel.fromMap(e)).toList();
  }

  /// Busca la entrada existente para el usuario+evento y crea/renueva el QR.
  /// Usado tanto al aprobar manualmente como al activar desde el Excel.
  static Future<String> generateEntryQr({
    required int idUsuario,
    required int idEvento,
  }) async {
    final existing = await _client
        .from('entradas')
        .select('id_entrada')
        .eq('id_usuario', idUsuario)
        .eq('id_evento', idEvento)
        .maybeSingle();

    return QrUniqueService.createOrRenewEntry(
      idUsuario: idUsuario,
      idEvento: idEvento,
      existingEntradaId: existing?['id_entrada'] as int?,
    );
  }

  /// Aprueba el pago y genera (o renueva) la entrada con QR único (UUID v4).
  /// Retorna el código QR generado.
  static Future<String> approvePago({
    required int idPago,
    required int idUsuario,
    required int idEvento,
    required double monto,
  }) async {
    await _client
        .from('pagos')
        .update({'estado': 'aprobado', 'monto': monto})
        .eq('id_pago', idPago);

    final qr = await generateEntryQr(idUsuario: idUsuario, idEvento: idEvento);

    NotificationService.sendToUser(
      idUsuario: idUsuario,
      title: 'Pago aprobado',
      body: 'Tu comprobante fue aprobado. Tu código QR de acceso está listo.',
    ).ignore();

    return qr;
  }

  /// Actualiza el monto de un pago ya aprobado sin cambiar su estado.
  static Future<void> updateMonto({
    required int idPago,
    required double monto,
  }) async {
    await _client
        .from('pagos')
        .update({'monto': monto})
        .eq('id_pago', idPago);
  }

  /// Rechaza el pago.
  static Future<void> rejectPago({
    required int idPago,
    required int idUsuario,
  }) async {
    await _client
        .from('pagos')
        .update({'estado': 'rechazado'})
        .eq('id_pago', idPago);

    NotificationService.sendToUser(
      idUsuario: idUsuario,
      title: 'Pago rechazado',
      body: 'Tu comprobante fue rechazado. Puedes subir uno nuevo.',
    ).ignore();
  }

  /// Revierte una aprobación: vuelve el pago a 'pendiente' y cancela la entrada QR.
  static Future<void> revertApproval({
    required int idPago,
    required int idUsuario,
    required int idEvento,
  }) async {
    await _client
        .from('pagos')
        .update({'estado': 'pendiente'})
        .eq('id_pago', idPago);

    await _client
        .from('entradas')
        .update({'estado': 'cancelado'})
        .eq('id_usuario', idUsuario)
        .eq('id_evento', idEvento);
  }

  /// Estadísticas para el dashboard del admin.
  static Future<Map<String, dynamic>> getDashboardStats({
    required int idEvento,
  }) async {
    final results = await Future.wait([
      _client.from('pagos').select('estado, monto').eq('id_evento', idEvento),
      _client.from('entradas').select('estado').eq('id_evento', idEvento),
      _client.from('usuarios').count(CountOption.exact),
    ]);

    final pagosList = results[0] as List;
    final entradasList = results[1] as List;
    final totalUsuarios = results[2] as int;

    final totalRecaudado = pagosList
        .where((p) => p['estado'] == 'aprobado' && p['monto'] != null)
        .fold<double>(0, (sum, p) => sum + (p['monto'] as num).toDouble());

    return {
      'pendientes': pagosList.where((p) => p['estado'] == 'pendiente').length,
      'aprobados': pagosList.where((p) => p['estado'] == 'aprobado').length,
      'rechazados': pagosList.where((p) => p['estado'] == 'rechazado').length,
      'ingresaron': entradasList.where((e) => e['estado'] == 'usado').length,
      'qr_generados': entradasList.where((e) => e['estado'] != 'cancelado').length,
      'total_usuarios': totalUsuarios,
      'total': pagosList.length,
      'total_recaudado': totalRecaudado,
    };
  }

  /// Retorna la entrada (QR) del estudiante para el evento.
  static Future<Map<String, dynamic>?> getMyEntry({
    required int idUsuario,
    required int idEvento,
  }) async {
    try {
      final data = await _client
          .from('entradas')
          .select('id_entrada, codigo_qr, estado, dentro_evento, fecha_generacion, fecha_expiracion, version_qr')
          .eq('id_usuario', idUsuario)
          .eq('id_evento', idEvento)
          .neq('estado', 'cancelado')
          .order('fecha_generacion', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('PaymentService.getMyEntry: $e');
      return null;
    }
  }
}
