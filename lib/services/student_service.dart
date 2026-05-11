import 'supabase_service.dart';

/// Represents a student from listado_estudiantes merged with
/// their payment/entry status for the current event.
class StudentRecord {
  final int? idDetalle;
  final String nombre;
  final String email;
  final String carrera;
  final String cedula;
  /// 'ingresado' | 'aprobado' | 'pendiente'
  final String status;
  final bool tieneQR;

  const StudentRecord({
    this.idDetalle,
    required this.nombre,
    required this.email,
    required this.carrera,
    this.cedula = '',
    required this.status,
    required this.tieneQR,
  });

  StudentRecord copyWith({
    String? nombre,
    String? email,
    String? carrera,
    String? cedula,
    String? status,
    bool? tieneQR,
  }) => StudentRecord(
    idDetalle: idDetalle,
    nombre: nombre ?? this.nombre,
    email: email ?? this.email,
    carrera: carrera ?? this.carrera,
    cedula: cedula ?? this.cedula,
    status: status ?? this.status,
    tieneQR: tieneQR ?? this.tieneQR,
  );
}

class StudentService {
  StudentService._();

  static dynamic get _client => SupabaseService.client;

  /// Fetches all students from listado_estudiantes, merged with their
  /// payment and entry status for [idEvento].
  static Future<List<StudentRecord>> getStudentsWithStatus({
    required int idEvento,
  }) async {
    // 1. All students in the list
    final studentRows = await _client
        .from('listado_estudiantes')
        .select('id_detalle, nombre, correo_electronico, carrera, cedula')
        .order('nombre') as List;

    // 2. Pagos for this event → build email→estado map
    final pagosRows = await _client
        .from('pagos')
        .select('estado, usuarios(email)')
        .eq('id_evento', idEvento) as List;

    final pagosByEmail = <String, String>{};
    for (final p in pagosRows) {
      final u = p['usuarios'];
      if (u is Map) {
        final email = u['email'] as String?;
        if (email != null) pagosByEmail[email] = p['estado'] ?? 'pendiente';
      }
    }

    // 3. Entradas for this event → build email set
    final entradasRows = await _client
        .from('entradas')
        .select('estado, usuarios(email)')
        .eq('id_evento', idEvento)
        .neq('estado', 'cancelado') as List;

    final entradasByEmail = <String, String>{};
    for (final e in entradasRows) {
      final u = e['usuarios'];
      if (u is Map) {
        final email = u['email'] as String?;
        if (email != null) entradasByEmail[email] = e['estado'] ?? 'activo';
      }
    }

    // 4. Merge
    return studentRows.map<StudentRecord>((row) {
      final email = (row['correo_electronico'] ?? row['email'] ?? '') as String;
      final entradaEstado = entradasByEmail[email];
      final pagoEstado = pagosByEmail[email];

      String status;
      bool tieneQR;

      if (entradaEstado == 'usado') {
        status = 'ingresado';
        tieneQR = true;
      } else if (entradaEstado == 'activo') {
        status = 'aprobado';
        tieneQR = true;
      } else if (pagoEstado == 'aprobado') {
        status = 'aprobado';
        tieneQR = false;
      } else if (pagoEstado == 'pendiente') {
        status = 'revision';
        tieneQR = false;
      } else {
        status = 'pendiente';
        tieneQR = false;
      }

      return StudentRecord(
        idDetalle: row['id_detalle'] as int?,
        nombre: (row['nombre'] ?? '') as String,
        email: email,
        carrera: (row['carrera'] ?? '') as String,
        cedula: (row['cedula'] ?? '') as String,
        status: status,
        tieneQR: tieneQR,
      );
    }).toList();
  }

  /// Adds a student to listado_estudiantes.
  static Future<void> addStudent({
    required String nombre,
    required String email,
    required String carrera,
    String cedula = '',
  }) async {
    await _client.from('listado_estudiantes').insert({
      'nombre': nombre,
      'correo_electronico': email,
      'carrera': carrera,
      if (cedula.isNotEmpty) 'cedula': cedula,
    });
  }

  /// Batch-upserts a list of students (insert or update on email conflict).
  /// Returns the number of rows successfully upserted.
  static Future<int> batchUpsert(List<Map<String, String>> students) async {
    if (students.isEmpty) return 0;
    await _client.from('listado_estudiantes').upsert(
      students,
      onConflict: 'correo_electronico',
    );
    return students.length;
  }

  /// Updates an existing student record.
  static Future<void> updateStudent({
    required int idDetalle,
    required String nombre,
    required String email,
    required String carrera,
    String cedula = '',
  }) async {
    await _client.from('listado_estudiantes').update({
      'nombre': nombre,
      'correo_electronico': email,
      'carrera': carrera,
      if (cedula.isNotEmpty) 'cedula': cedula,
    }).eq('id_detalle', idDetalle);
  }

  /// Deletes a student from listado_estudiantes.
  static Future<void> deleteStudent(int idDetalle) async {
    await _client
        .from('listado_estudiantes')
        .delete()
        .eq('id_detalle', idDetalle);
  }

  /// Returns a sorted, deduplicated list of career names.
  static Future<List<String>> getCareers() async {
    try {
      final rows = await _client
          .from('listado_estudiantes')
          .select('carrera') as List;
      final careers = rows
          .map<String>((r) => (r['carrera'] ?? '') as String)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return careers;
    } catch (_) {
      return [];
    }
  }
}
