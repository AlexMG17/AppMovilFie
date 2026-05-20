import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class EventModel {
  final int id;
  final String nombre;
  final String descripcion;
  final DateTime fecha;
  final String lugar;
  final double lat;
  final double lng;
  // Radio en metros para geofencing (configurable, no está en DB)
  static const int radioMetros = 300;

  const EventModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fecha,
    required this.lugar,
    required this.lat,
    required this.lng,
  });

  factory EventModel.fromMap(Map<String, dynamic> map) => EventModel(
        id: map['id_evento'] as int,
        nombre: map['nombre'] ?? 'Evento FIE',
        descripcion: map['descripcion'] ?? '',
        fecha: DateTime.tryParse(map['fecha_evento'].toString()) ??
            DateTime.now().add(const Duration(days: 30)),
        lugar: map['ubicacion'] ?? 'ESPOCH',
        lat: (map['latitud'] as num?)?.toDouble() ?? -1.6489,
        lng: (map['longitud'] as num?)?.toDouble() ?? -78.6480,
      );
}

class EventService {
  EventService._();

  static SupabaseClient get _client => SupabaseService.client;

  /// Retorna el próximo evento activo (fecha_evento >= hoy).
  /// Si no hay futuro, retorna el más reciente.
  static Future<EventModel?> getActiveEvent() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Primero buscamos un evento futuro o de hoy
      var data = await _client
          .from('eventos')
          .select()
          .gte('fecha_evento', today)
          .order('fecha_evento')
          .limit(1)
          .maybeSingle();

      // Si no hay, tomamos el más reciente (el evento pasó pero la app sigue activa)
      data ??= await _client
          .from('eventos')
          .select()
          .order('fecha_evento', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return EventModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Número de entradas no canceladas (aforo actual).
  static Future<int> getAforo(int idEvento) async {
    try {
      final data = await _client
          .from('entradas')
          .select('id_entrada')
          .eq('id_evento', idEvento)
          .neq('estado', 'cancelado');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Capacidad total desde listado_estudiantes.
  static Future<int> getCapacidad() async {
    try {
      final data = await _client
          .from('listado_estudiantes')
          .select('id_detalle');
      return (data as List).length;
    } catch (_) {
      return 350;
    }
  }

  /// id_usuario del usuario autenticado.
  static Future<int?> getCurrentUserId() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('usuarios')
          .select('id_usuario')
          .eq('email', user.email!)
          .single();
      return data['id_usuario'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Crea un nuevo evento en la tabla `eventos`.
  static Future<void> createEvent({
    required String nombre,
    required String descripcion,
    required DateTime fecha,
    required String lugar,
    required double lat,
    required double lng,
  }) async {
    await _client.from('eventos').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha_evento': fecha.toIso8601String().substring(0, 10),
      'ubicacion': lugar,
      'latitud': lat,
      'longitud': lng,
    });
  }

  /// Actualiza los datos de un evento existente.
  static Future<void> updateEvent({
    required int id,
    required String nombre,
    required String descripcion,
    required DateTime fecha,
    required String lugar,
    required double lat,
    required double lng,
  }) async {
    await _client.from('eventos').update({
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha_evento': fecha.toIso8601String().substring(0, 10),
      'ubicacion': lugar,
      'latitud': lat,
      'longitud': lng,
    }).eq('id_evento', id);
  }

  /// Nombre completo del usuario autenticado.
  static Future<String?> getCurrentUserName() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('usuarios')
          .select('nombre')
          .eq('email', user.email!)
          .single();
      return data['nombre'] as String?;
    } catch (_) {
      return user.email;
    }
  }
}
