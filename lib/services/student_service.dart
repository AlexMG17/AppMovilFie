import 'payment_service.dart';
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

  /// Batch-inserts students skipping emails already in listado_estudiantes.
  /// For each truly new student, also creates a Supabase auth account and sends
  /// a welcome email with temporary credentials via the Edge Function.
  /// Returns {'inserted': N, 'skipped': M, 'accounts_created': K} where
  ///   skipped = already existed in listado_estudiantes
  ///   accounts_created = new auth accounts created (and email sent)
  static Future<Map<String, dynamic>> batchUpsert(
      List<Map<String, String>> students) async {
    if (students.isEmpty) return {'inserted': 0, 'skipped': 0, 'accounts_created': 0, 'email_errors': 0, 'email_errors_detail': ''};

    // 1. Detect which emails already exist in the DB
    final incomingEmails = students
        .map((s) => s['correo_electronico'] ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    final existingRows = await _client
        .from('listado_estudiantes')
        .select('correo_electronico')
        .inFilter('correo_electronico', incomingEmails) as List;

    final existingEmails = existingRows
        .map((r) => (r['correo_electronico'] as String).toLowerCase())
        .toSet();

    final newStudents = students
        .where((s) =>
            !existingEmails.contains(
              (s['correo_electronico'] ?? '').toLowerCase(),
            ))
        .toList();

    final skipped = students.length - newStudents.length;

    if (newStudents.isEmpty) return {'inserted': 0, 'skipped': skipped, 'accounts_created': 0, 'email_errors': 0, 'email_errors_detail': ''};

    // 2. Create parent record in 'listados'
    final listadoResponse = await _client
        .from('listados')
        .insert({
          'nombre_archivo':
              'importacion_${DateTime.now().millisecondsSinceEpoch}',
          'cargado_por': SupabaseService.currentUser?.email ?? 'admin',
        })
        .select('id_listado')
        .single();

    final idListado = listadoResponse['id_listado'] as int;

    // 3. Insert only new students into listado_estudiantes
    final rows = newStudents
        .map((s) => {
              'id_listado': idListado,
              'nombre': s['nombre'],
              'correo_electronico': s['correo_electronico'],
              'carrera': s['carrera'],
              'procesado': false,
              if ((s['cedula'] ?? '').isNotEmpty) 'cedula': s['cedula'],
            })
        .toList();

    await _client.from('listado_estudiantes').insert(rows);

    // 4. Create auth accounts + send emails via Edge Function (best-effort)
    int accountsCreated = 0;
    final emailErrors = <String>[];
    for (final s in newStudents) {
      try {
        final response = await _client.functions.invoke(
          'create-student-account',
          body: {
            'nombre': s['nombre'] ?? '',
            'email': s['correo_electronico'] ?? '',
            'carrera': s['carrera'] ?? '',
            'cedula': s['cedula'] ?? '',
          },
        );
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['success'] == true && data['already_exists'] != true) {
          accountsCreated++;
          if (data['email_error'] != null) {
            emailErrors.add('${s['correo_electronico']}: ${data['email_error']}');
          }
        }
      } catch (_) {
        // Account creation failures don't block the import
      }
    }

    return {
      'inserted': newStudents.length,
      'skipped': skipped,
      'accounts_created': accountsCreated,
      'email_errors': emailErrors.length,
      'email_errors_detail': emailErrors.join(' | '),
    };
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

  /// Si el correo está en listado_estudiantes (vino del Excel) y aún no tiene
  /// pago para el evento activo, crea uno con estado 'pre_aprobado' y genera
  /// su entrada con QR automáticamente. Es idempotente: no crea duplicados.
  static Future<void> checkAndActivateIfPreApproved({
    required String email,
    required int idUsuario,
    required int idEvento,
  }) async {
    try {
      final inList = await _client
          .from('listado_estudiantes')
          .select('id_detalle')
          .eq('correo_electronico', email)
          .limit(1)
          .maybeSingle();

      if (inList == null) return;

      final existingPago = await _client
          .from('pagos')
          .select('id_pago')
          .eq('id_usuario', idUsuario)
          .eq('id_evento', idEvento)
          .maybeSingle();

      if (existingPago == null) {
        await _client.from('pagos').insert({
          'id_usuario': idUsuario,
          'id_evento': idEvento,
          'comprobante': null,
          'estado': 'aprobado',
          'fecha_pago': DateTime.now().toIso8601String(),
        });
      }

      // Siempre verificar que la entrada exista (puede faltar si generateEntryQr falló antes)
      final existingEntry = await _client
          .from('entradas')
          .select('id_entrada')
          .eq('id_usuario', idUsuario)
          .eq('id_evento', idEvento)
          .maybeSingle();

      if (existingEntry == null) {
        await PaymentService.generateEntryQr(
          idUsuario: idUsuario,
          idEvento: idEvento,
        );
      }
    } catch (_) {
      rethrow;
    }
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
