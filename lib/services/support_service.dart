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
        createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
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
    } catch (_) {
      return [];
    }
  }

  /// Lista de conversaciones para la bandeja del admin,
  /// agrupada por usuario y ordenada por última actividad.
  static Future<List<SupportConversation>> getConversationList() async {
    try {
      final data = await _client
          .from('soporte_mensajes')
          .select()
          .order('created_at', ascending: false)
          .limit(500);

      final Map<String, SupportMessage> latestByCid = {};
      final Map<String, String> studentNameByCid = {};

      for (final row in (data as List)) {
        final msg = SupportMessage.fromMap(row as Map<String, dynamic>);
        final cid = msg.conversacionUsuarioId;
        if (cid.isEmpty) continue;

        if (!latestByCid.containsKey(cid)) {
          latestByCid[cid] = msg;
        }
        if (!msg.esAdmin && !studentNameByCid.containsKey(cid)) {
          studentNameByCid[cid] = msg.nombreUsuario;
        }
      }

      return latestByCid.entries.map((e) {
        final cid = e.key;
        final msg = e.value;
        final name = studentNameByCid[cid] ?? 'Usuario';
        return SupportConversation(
          usuarioId: cid,
          nombreUsuario: name,
          lastMessage: msg.esAdmin ? 'Tú: ${msg.mensaje}' : msg.mensaje,
          lastAt: msg.createdAt,
          lastIsAdmin: msg.esAdmin,
        );
      }).toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    } catch (_) {
      return [];
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
