import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_service.dart';
import 'supabase_service.dart';

class SupportMessage {
  final int id;
  final String usuarioId;
  final String nombreUsuario;
  final String mensaje;
  final bool esAdmin;
  final String conversacionUsuarioId;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.mensaje,
    required this.esAdmin,
    required this.conversacionUsuarioId,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
        id: map['id'] as int,
        usuarioId: map['usuario_id'] as String? ?? '',
        nombreUsuario: map['nombre_usuario'] as String? ?? 'Usuario',
        mensaje: map['mensaje'] as String? ?? '',
        esAdmin: map['es_admin'] as bool? ?? false,
        conversacionUsuarioId: map['conversacion_usuario_id'] as String? ??
            map['usuario_id'] as String? ??
            '',
        createdAt: (DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now()).toLocal(),
      );
}

/// Representa la última actividad de una conversación (para la bandeja del admin).
class SupportConversation {
  final String usuarioId;
  final String nombreUsuario;
  final String lastMessage;
  final DateTime lastAt;
  final bool lastIsAdmin;

  const SupportConversation({
    required this.usuarioId,
    required this.nombreUsuario,
    required this.lastMessage,
    required this.lastAt,
    required this.lastIsAdmin,
  });
}

class SupportService {
  SupportService._();

  static SupabaseClient get _client => SupabaseService.client;

  /// Mensajes de una conversación específica (filtrado por conversacion_usuario_id).
  static Future<List<SupportMessage>> getConversationMessages(
      String convUserId) async {
    try {
      final data = await _client
          .from('soporte_mensajes')
          .select()
          .eq('conversacion_usuario_id', convUserId)
          .order('created_at', ascending: true)
          .limit(200);
      return (data as List)
          .map((m) => SupportMessage.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupportService.getConversationMessages: $e');
      return [];
    }
  }

  /// Lista de conversaciones para la bandeja del admin,
  /// agrupada por usuario y ordenada por última actividad.
  /// Usa la vista soporte_ultimos_mensajes (DISTINCT ON server-side).
  static Future<List<SupportConversation>> getConversationList() async {
    try {
      final data = await _client
          .from('soporte_ultimos_mensajes')
          .select()
          .order('created_at', ascending: false);

      return (data as List).map((row) {
        final cid = row['conversacion_usuario_id'] as String? ?? '';
        final nombre = row['nombre_usuario'] as String? ?? 'Usuario';
        final mensaje = row['mensaje'] as String? ?? '';
        final esAdmin = row['es_admin'] as bool? ?? false;
        final createdAt =
            (DateTime.tryParse(row['created_at'] as String? ?? '') ??
                    DateTime.now())
                .toLocal();
        return SupportConversation(
          usuarioId: cid,
          nombreUsuario: nombre,
          lastMessage: esAdmin ? 'Tú: $mensaje' : mensaje,
          lastAt: createdAt,
          lastIsAdmin: esAdmin,
        );
      }).toList();
    } catch (e) {
      debugPrint('SupportService.getConversationList: $e');
      return [];
    }
  }

  /// Marca una conversación como leída por el admin actual (upsert en Supabase).
  static Future<void> markConversationRead(String conversacionUsuarioId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      await _client.from('soporte_leidos_admin').upsert({
        'admin_id': user.id,
        'conversacion_usuario_id': conversacionUsuarioId,
        'leido_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'admin_id, conversacion_usuario_id');
    } catch (e) {
      debugPrint('SupportService.markConversationRead: $e');
    }
  }

  /// Devuelve un mapa {conversacionUsuarioId → leidoAt} del admin actual.
  static Future<Map<String, DateTime>> getAdminReadMap() async {
    final user = SupabaseService.currentUser;
    if (user == null) return {};
    try {
      final data = await _client
          .from('soporte_leidos_admin')
          .select('conversacion_usuario_id, leido_at')
          .eq('admin_id', user.id);
      return {
        for (final row in data as List)
          row['conversacion_usuario_id'] as String:
              (DateTime.tryParse(row['leido_at'] as String? ?? '') ??
                      DateTime(0))
                  .toLocal(),
      };
    } catch (e) {
      debugPrint('SupportService.getAdminReadMap: $e');
      return {};
    }
  }

  /// Envía un mensaje. [convUserId] es siempre el UUID del estudiante.
  static Future<void> sendMessage({
    required String mensaje,
    required bool esAdmin,
    required String convUserId,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw Exception('No hay sesión activa');
    final nombre =
        await EventService.getCurrentUserName() ?? user.email ?? 'Usuario';
    await _client.from('soporte_mensajes').insert({
      'usuario_id': user.id,
      'nombre_usuario': nombre,
      'mensaje': mensaje,
      'es_admin': esAdmin,
      'conversacion_usuario_id': convUserId,
    });
  }

  /// Suscripción en tiempo real para una conversación específica.
  static RealtimeChannel subscribeConversation(
      String convUserId, void Function() onUpdate) {
    return _client
        .channel('soporte-chat-$convUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'soporte_mensajes',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  /// Suscripción global para la bandeja del admin.
  static RealtimeChannel subscribeAll(void Function() onUpdate) {
    return _client
        .channel('soporte-admin-inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'soporte_mensajes',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
