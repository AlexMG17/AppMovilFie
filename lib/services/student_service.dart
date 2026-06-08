import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  static SupabaseClient get _client => SupabaseService.client;

  /// Fetches all students merged with their payment/entry status for [idEvento].
  /// Calls the RPC get_students_with_status which does the JOIN server-side.
  static Future<List<StudentRecord>> getStudentsWithStatus({
    required int idEvento,
  }) async {
    final rows = await _client.rpc(
      'get_students_with_status',
      params: {'p_id_evento': idEvento},
    ) as List;

    return rows.map<StudentRecord>((row) {
      return StudentRecord(
        idDetalle: row['id_detalle'] as int?,
        nombre: (row['nombre'] ?? '') as String,
        email: (row['correo_electronico'] ?? '') as String,
        carrera: (row['carrera'] ?? '') as String,
        cedula: (row['cedula'] ?? '') as String,
        status: (row['status'] ?? 'pendiente') as String,
        tieneQR: (row['tiene_qr'] as bool?) ?? false,
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
  /// Returns {'inserted': N, 'skipped': M, 'accounts_created': K,
  ///   'inserted_list': [...], 'skipped_list': [...]} where
  ///   skipped = already existed in listado_estudiantes
  ///   accounts_created = new auth accounts created (and email sent)
  static Future<Map<String, dynamic>> batchUpsert(
      List<Map<String, String>> students) async {
    if (students.isEmpty) return {'inserted': 0, 'skipped': 0, 'accounts_created': 0, 'email_errors': 0, 'email_errors_detail': '', 'inserted_list': [], 'skipped_list': []};

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

    final skippedStudents = students
        .where((s) =>
            existingEmails.contains(
              (s['correo_electronico'] ?? '').toLowerCase(),
            ))
        .toList();

    final skipped = skippedStudents.length;

    if (newStudents.isEmpty) {
      return {
        'inserted': 0,
        'skipped': skipped,
        'accounts_created': 0,
        'email_errors': 0,
        'email_errors_detail': '',
        'inserted_list': <Map<String, String>>[],
        'skipped_list': skippedStudents,
      };
    }

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
      } catch (e) {
        debugPrint('StudentService.importStudents create account: $e');
      }
    }

    return {
      'inserted': newStudents.length,
      'skipped': skipped,
      'accounts_created': accountsCreated,
      'email_errors': emailErrors.length,
      'email_errors_detail': emailErrors.join(' | '),
      'inserted_list': newStudents,
      'skipped_list': skippedStudents,
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

  /// Eliminación completa de un estudiante:
  /// 1. Borra sus datos (entradas, pagos, usuarios) via Edge Function con service role.
  /// 2. Elimina su cuenta de Supabase Auth.
  /// 3. Elimina su fila de listado_estudiantes.
  static Future<void> deleteStudent(int idDetalle, String email) async {
    // Llamar la Edge Function que borra usuarios, entradas, pagos y auth account
    try {
      await _client.functions.invoke(
        'delete-user-account',
        body: {'email': email},
      );
    } catch (e) {
      // Si la Edge Function falla (ej. usuario no tenía cuenta), continuamos
      // para al menos limpiar listado_estudiantes
      debugPrint('delete-user-account edge fn: $e');
    }

    // Siempre borrar de listado_estudiantes independientemente del resultado anterior
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
    } catch (e) {
      debugPrint('StudentService.getUniqueCareers: $e');
      return [];
    }
  }
}
