import 'package:flutter/foundation.dart';
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

  static EventModel? _cachedEvent;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 30);

  static void clearEventCache() {
    _cachedEvent = null;
    _cacheTime = null;
  }

  /// Retorna el próximo evento activo (fecha_evento >= hoy).
  /// Si no hay futuro, retorna el más reciente.
  /// Resultado cacheado 30 s para evitar múltiples consultas simultáneas.
  static Future<EventModel?> getActiveEvent() async {
    if (_cachedEvent != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedEvent;
    }
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

      _cachedEvent = data != null ? EventModel.fromMap(data) : null;
      _cacheTime = DateTime.now();
      return _cachedEvent;
    } catch (e) {
      debugPrint('EventService.getActiveEvent: $e');
      return _cachedEvent; // Devuelve caché obsoleto antes de reportar null
    }
  }

  /// Número de entradas no canceladas (aforo actual).
  static Future<int> getAforo(int idEvento) async {
    try {
      return await _client
          .from('entradas')
          .count(CountOption.exact)
          .eq('id_evento', idEvento)
          .neq('estado', 'cancelado');
    } catch (e) {
      debugPrint('EventService.getAforo: $e');
      return 0;
    }
  }

  /// Capacidad total desde listado_estudiantes.
  static Future<int> getCapacidad() async {
    try {
      return await _client
          .from('listado_estudiantes')
          .count(CountOption.exact);
    } catch (e) {
      debugPrint('EventService.getCapacidad: $e');
      return 350;
    }
  }

  /// id_usuario del usuario autenticado.
  /// Si no existe fila en `usuarios` (trigger falló), la crea automáticamente.
  static Future<int?> getCurrentUserId() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('usuarios')
          .select('id_usuario')
          .eq('email', user.email!)
          .maybeSingle();

      if (data != null) return data['id_usuario'] as int?;

      // Registro faltante: reconstruir desde metadatos de auth
      final meta = user.userMetadata ?? {};
      final nombre =
          meta['nombre'] as String? ?? user.email ?? 'Usuario';
      final idRol = (meta['id_rol'] as num?)?.toInt() ?? 1;

      final inserted = await _client
          .from('usuarios')
          .insert({'email': user.email, 'nombre': nombre, 'id_rol': idRol})
          .select('id_usuario')
          .single();

      return inserted['id_usuario'] as int?;
    } catch (e) {
      debugPrint('EventService.getCurrentUserId: $e');
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
      'fecha_evento': fecha.toIso8601String(),
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
      'fecha_evento': fecha.toIso8601String(),
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
    } catch (e) {
      debugPrint('EventService.getCurrentUserName: $e');
      return user.email;
    }
  }
}
