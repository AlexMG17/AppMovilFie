import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos del QR que se persisten localmente.
class QrCacheData {
  final String codigoQr;
  final String estado;
  final String userName;
  final String userEmail;
  final int eventId;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final int versionQr;

  const QrCacheData({
    required this.codigoQr,
    required this.estado,
    required this.userName,
    required this.userEmail,
    required this.eventId,
    required this.cachedAt,
    this.expiresAt,
    this.versionQr = 1,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toMap() => {
        'codigo_qr': codigoQr,
        'estado': estado,
        'user_name': userName,
        'user_email': userEmail,
        'event_id': eventId,
        'cached_at': cachedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'version_qr': versionQr,
      };

  factory QrCacheData.fromMap(Map<String, dynamic> map) => QrCacheData(
        codigoQr: map['codigo_qr'] as String? ?? '',
        estado: map['estado'] as String? ?? 'activo',
        userName: map['user_name'] as String? ?? '',
        userEmail: map['user_email'] as String? ?? '',
        eventId: map['event_id'] as int? ?? 0,
        cachedAt: DateTime.tryParse(map['cached_at'] as String? ?? '') ??
            DateTime.now(),
        expiresAt: map['expires_at'] != null
            ? DateTime.tryParse(map['expires_at'] as String)
            : null,
        versionQr: map['version_qr'] as int? ?? 1,
      );
}

/// Servicio que guarda y recupera el QR de acceso en almacenamiento local.
/// La clave incluye el userId para que cada usuario tenga su propio caché.
class QrCacheService {
  QrCacheService._();

  static String _key(String userId) => 'sentry_qr_$userId';

  /// Guarda los datos del QR localmente.
  static Future<void> save({
    required String userId,
    required QrCacheData data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(data.toMap()));
  }

  /// Recupera el QR guardado. Retorna null si no hay caché.
  static Future<QrCacheData?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      return QrCacheData.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('QrCacheService.load parse error: $e');
      return null;
    }
  }

  /// Elimina el caché del usuario (ej. al cerrar sesión).
  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
