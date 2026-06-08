import 'dart:convert';
import 'package:excel/excel.dart' show Excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/student_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

// ─── Paleta Sentry ────────────────────────────────────────────────────────────
const _kBg     = AppColors.sentryBg;
const _kCard   = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kPurple = AppColors.sentryBlue;
const _kPurp2  = AppColors.sentryNavy;
const _kCyan   = AppColors.sentryCyan;
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kYellow = Color(0xFFF59E0B);
const _kWhite  = Color(0xFFFFFFFF);
const _kGrey   = AppColors.sentryGrey;
const _kNavy   = AppColors.sentryNavy;

const _kRequiredCols = ['nombre', 'correo_electronico', 'carrera'];

const _kCarreras = [
  // ── FIE (primordiales) ──────────────────────────────────────────────────
  'Diseño Gráfico',
  'Electrónica y Automatización',
  'Electrónica, Telecomunicaciones y Redes',
  'Software',
  'Tecnologías de la Información',
  'Telemática',
  'Electricidad',
  // ── Resto de facultades ─────────────────────────────────────────────────
  'Administración de Empresas',
  'Agroindustria',
  'Agronomía',
  'Bioquímica y Farmacia',
  'Contabilidad y Auditoría',
  'Estadística',
  'Finanzas',
  'Física',
  'Gastronomía',
  'Gestión del Transporte',
  'Ingeniería Ambiental',
  'Ingeniería Automotriz',
  'Ingeniería en Recursos Naturales Renovables',
  'Ingeniería Forestal',
  'Ingeniería Industrial',
  'Ingeniería Química',
  'Mantenimiento Industrial',
  'Matemática',
  'Mecánica',
  'Medicina',
  'Mercadotecnia / Marketing',
  'Nutrición y Dietética',
  'Promoción de la Salud',
  'Química',
  'Telecomunicaciones',
  'Turismo',
  'Veterinaria',
  'Zootecnia',
];

// ─── Modelo ───────────────────────────────────────────────────────────────────
class ImportedStudent {
  final String nombre;
  final String correoElectronico;
  final String carrera;
  final String cedula; // opcional
  const ImportedStudent({
    required this.nombre,
    required this.correoElectronico,
    required this.carrera,
    this.cedula = '',
  });
}

// ─── Estados ──────────────────────────────────────────────────────────────────
enum _ImportPhase { idle, loading, preview, importing, done }

class _ImportResult {
  final int imported;
  final int duplicates;     // duplicados dentro del archivo
  final int existingInDb;   // ya existían en la base de datos
  final int errors;
  final int accountsCreated;
  final List<Map<String, String>> importedList;
  final List<Map<String, String>> existingList;
  const _ImportResult({
    required this.imported,
    required this.duplicates,
    required this.existingInDb,
    required this.errors,
    required this.accountsCreated,
    this.importedList = const [],
    this.existingList = const [],
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
class ImportStudentsScreen extends StatefulWidget {
  const ImportStudentsScreen({super.key});
  @override
  State<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends State<ImportStudentsScreen>
    with SingleTickerProviderStateMixin {
  _ImportPhase _phase = _ImportPhase.idle;
  String? _fileName;
  String? _errorMsg;
  List<ImportedStudent> _parsed = [];
  _ImportResult? _result;
  bool _isManualEntry = false;

  // Estado para la descarga de plantilla
  bool _isDownloadingTemplate = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) setState(() => _userName = name ?? SupabaseService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size.sp,
        fontWeight: fw,
        color: color ?? _kNavy,
      );

  // ── Descargar plantilla desde assets ─────────────────────────────────────
  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);

    try {
      // 1. Leer el archivo desde assets
      final ByteData data = await rootBundle.load(
        'assets/templates/PLANTILLA_CSV_SENTRY.xlsx',
      );
      final List<int> bytes = data.buffer.asUint8List();

      // 2. Abrir selector de carpeta para guardar
      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Guardar plantilla',
        fileName: 'plantilla_estudiantes_sentry.xlsx',
        bytes: Uint8List.fromList(bytes),
      );

      if (!mounted) return;

      if (outputPath != null) {
        // Éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: _kWhite, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plantilla guardada correctamente',
                    style: GoogleFonts.outfit(fontSize: 13, color: _kWhite),
                  ),
                ),
              ],
            ),
            backgroundColor: _kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _kWhite, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error al descargar: ${e.toString().replaceFirst("Exception: ", "")}',
                  style: GoogleFonts.outfit(fontSize: 13, color: _kWhite),
                ),
              ),
            ],
          ),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  // ── Seleccionar archivo ───────────────────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() {
      _phase = _ImportPhase.idle;
      _errorMsg = null;
      _parsed = [];
      _result = null;
    });

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _phase = _ImportPhase.loading;
      _fileName = file.name;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final ext = file.extension?.toLowerCase() ?? '';
      List<ImportedStudent> students;

      if (ext == 'csv') {
        students = _parseCsv(utf8.decode(file.bytes!));
      } else if (ext == 'xlsx' || ext == 'xls') {
        students = _parseExcel(file.bytes!);
      } else {
        throw Exception('Formato no soportado');
      }

      if (students.isEmpty) {
        throw Exception('El archivo no contiene datos válidos');
      }

      setState(() {
        _parsed = students;
        _phase = _ImportPhase.preview;
      });
    } catch (e) {
      setState(() {
        _phase = _ImportPhase.idle;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Parsear CSV ───────────────────────────────────────────────────────────
  List<ImportedStudent> _parseCsv(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) throw Exception('Archivo vacío');

    final firstLine = lines[0];
    final delimiter = firstLine.contains(';') ? ';' : ',';

    final headers = firstLine
        .split(delimiter)
        .map((h) => h.trim().toLowerCase().replaceAll('"', ''))
        .toList();

    _validateHeaders(headers);

    final result = <ImportedStudent>[];
    for (int i = 1; i < lines.length; i++) {
      final values = lines[i]
          .split(delimiter)
          .map((v) => v.trim().replaceAll('"', ''))
          .toList();

      if (values.length < 3) continue;

      final row = <String, String>{};
      for (int j = 0; j < headers.length && j < values.length; j++) {
        row[headers[j]] = values[j];
      }

      final nombre = row['nombre'] ?? '';
      final email = row['correo_electronico'] ?? '';
      final carrera = row['carrera'] ?? '';
      final cedula = row['cedula'] ?? '';

      if (nombre.isEmpty || email.isEmpty) continue;

      result.add(ImportedStudent(
        nombre: nombre,
        correoElectronico: email,
        carrera: carrera,
        cedula: cedula,
      ));
    }
    return result;
  }

  // ── Parsear Excel ─────────────────────────────────────────────────────────
  List<ImportedStudent> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null) throw Exception('No se encontró hoja de cálculo');

    final rows = sheet.rows;
    if (rows.isEmpty) throw Exception('Archivo vacío');

    final headers = rows[0]
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    _validateHeaders(headers);

    final result = <ImportedStudent>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every(
        (c) => c?.value == null || c!.value.toString().trim().isEmpty,
      )) {
        continue;
      }

      final data = <String, String>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        data[headers[j]] = row[j]?.value?.toString().trim() ?? '';
      }

      final nombre = data['nombre'] ?? '';
      final email = data['correo_electronico'] ?? '';
      final carrera = data['carrera'] ?? '';
      final cedula = data['cedula'] ?? '';

      if (nombre.isEmpty || email.isEmpty) continue;

      result.add(ImportedStudent(
        nombre: nombre,
        correoElectronico: email,
        carrera: carrera,
        cedula: cedula,
      ));
    }
    return result;
  }

  // ── Validar columnas requeridas ───────────────────────────────────────────
  void _validateHeaders(List<String> headers) {
    final missing = _kRequiredCols.where((c) => !headers.contains(c)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Columnas faltantes: ${missing.join(', ')}');
    }
  }

  // ── Procesar e importar ───────────────────────────────────────────────────
  Future<void> _doImport() async {
    setState(() => _phase = _ImportPhase.importing);

    final seen = <String>{};
    final unique = <Map<String, String>>[];
    int duplicates = 0;

    for (final s in _parsed) {
      final key = s.correoElectronico.toLowerCase();
      if (seen.contains(key)) {
        duplicates++;
        continue;
      }
      seen.add(key);
      unique.add({
        'nombre': s.nombre,
        'correo_electronico': s.correoElectronico,
        'carrera': s.carrera,
        'cedula': s.cedula,
      });
    }

    int imported = 0;
    int existingInDb = 0;
    int errors = 0;
    int accountsCreated = 0;
    List<Map<String, String>> importedList = [];
    List<Map<String, String>> existingList = [];

    try {
      final result = await StudentService.batchUpsert(unique);
      imported = result['inserted'] ?? 0;
      existingInDb = result['skipped'] ?? 0;
      accountsCreated = result['accounts_created'] ?? 0;
      importedList = List<Map<String, String>>.from(
        (result['inserted_list'] as List? ?? []).map((e) => Map<String, String>.from(e as Map)),
      );
      existingList = List<Map<String, String>>.from(
        (result['skipped_list'] as List? ?? []).map((e) => Map<String, String>.from(e as Map)),
      );
    } catch (e) {
      debugPrint('ERROR IMPORT: $e');
      errors = unique.length;
    }

    setState(() {
      _result = _ImportResult(
        imported: imported,
        duplicates: duplicates,
        existingInDb: existingInDb,
        errors: errors,
        accountsCreated: accountsCreated,
        importedList: importedList,
        existingList: existingList,
      );
      _phase = _ImportPhase.done;
    });
  }

  void _reset() {
    setState(() {
      _phase = _ImportPhase.idle;
      _fileName = null;
      _errorMsg = null;
      _parsed = [];
      _result = null;
      _isManualEntry = false;
    });
  }

  // ── Agregar estudiante manualmente ────────────────────────────────────────
  Future<void> _showAddStudentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    String? selectedCarrera;

    final student = await showModalBottomSheet<ImportedStudent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Agregar estudiante',
                            style: _ts(17, fw: FontWeight.w800)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded,
                            color: _kGrey, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(nombreCtrl, 'Nombre completo *',
                      'Ej: Juan Pérez', TextInputType.name, true),
                  const SizedBox(height: 12),
                  _buildFormField(emailCtrl, 'Correo electrónico *',
                      'Ej: j.perez@espoch.edu.ec',
                      TextInputType.emailAddress, true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCarrera,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Carrera *',
                      labelStyle: _ts(12, color: _kGrey),
                      filled: true,
                      fillColor: _kBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _kPurple, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _kRed),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _kRed, width: 1.5),
                      ),
                    ),
                    style: _ts(13),
                    hint: Text('Selecciona una carrera',
                        style: _ts(12,
                            color: _kGrey.withValues(alpha: 0.6))),
                    items: [
                      const DropdownMenuItem(
                        enabled: false,
                        value: '__divider_fie__',
                        child: Text('── Facultad FIE ──',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic)),
                      ),
                      ..._kCarreras
                          .take(7)
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: _ts(13,
                                      fw: FontWeight.w600,
                                      color: _kNavy)))),
                      const DropdownMenuItem(
                        enabled: false,
                        value: '__divider_other__',
                        child: Text('── Otras facultades ──',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic)),
                      ),
                      ..._kCarreras
                          .skip(7)
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: _ts(13)))),
                    ],
                    onChanged: (v) =>
                        setModalState(() => selectedCarrera = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(cedulaCtrl, 'Cédula (opcional)',
                      'Ej: 0601234567', TextInputType.number, false),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(
                            ctx,
                            ImportedStudent(
                              nombre: nombreCtrl.text.trim(),
                              correoElectronico: emailCtrl.text.trim(),
                              carrera: selectedCarrera!,
                              cedula: cedulaCtrl.text.trim(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_add_rounded,
                          color: _kWhite, size: 18),
                      label: Text('Agregar estudiante',
                          style:
                              _ts(14, fw: FontWeight.w700, color: _kWhite)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurple,
                        foregroundColor: _kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (student != null && mounted) {
      setState(() {
        _parsed.add(student);
        _isManualEntry = true;
        _phase = _ImportPhase.preview;
        _fileName = 'Entrada manual';
      });
    }
  }

  Widget _buildFormField(
    TextEditingController ctrl,
    String label,
    String hint,
    TextInputType type,
    bool required,
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: _ts(13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _ts(12, color: _kGrey),
        hintText: hint,
        hintStyle: _ts(12, color: _kGrey.withValues(alpha: 0.6)),
        filled: true,
        fillColor: _kBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kRed, width: 1.5),
        ),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildRequirementsCard(),
                    const SizedBox(height: 16),
                    // ── Tarjeta de plantilla descargable ──────────────────
                    _buildTemplateCard(),
                    const SizedBox(height: 16),
                    _buildContent(),
                    SizedBox(height: 120.h),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _kBg,
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panel Administrativo', style: _ts(16, fw: FontWeight.w700)),
          Text('Gala FIE 2026', style: _ts(11, color: _kGrey)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text('En línea',
                  style: _ts(10, color: _kGreen, fw: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          offset: const Offset(0, 44),
          onSelected: (value) async {
            if (value == 'logout') {
              await SupabaseService.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x221565C0),
            child: Icon(Icons.person_rounded, size: 18, color: _kPurple),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87)),
                  Text(SupabaseService.currentUser?.email ?? '',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cerrar sesión',
                      style: TextStyle(color: Colors.red, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Importar Estudiantes', style: _ts(22, fw: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Carga masiva de estudiantes habilitados',
            style: _ts(11, color: _kGrey)),
      ],
    );
  }

  // ── Tarjeta de requisitos ─────────────────────────────────────────────────
  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: _kCyan, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Requisitos del archivo',
                    style: _ts(13, fw: FontWeight.w700, color: _kCyan)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: _ts(12, color: _kGrey),
              children: [
                const TextSpan(
                    text:
                        'El archivo debe ser CSV o Excel (.xlsx) y contener las columnas: '),
                TextSpan(text: 'nombre', style: _ts(12, fw: FontWeight.w700)),
                const TextSpan(text: ', '),
                TextSpan(
                    text: 'correo_electronico',
                    style: _ts(12, fw: FontWeight.w700)),
                const TextSpan(text: ', '),
                TextSpan(text: 'carrera', style: _ts(12, fw: FontWeight.w700)),
                const TextSpan(text: ', '),
                TextSpan(text: 'cedula', style: _ts(12, fw: FontWeight.w700)),
                const TextSpan(text: ' (opcional).'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.0),
                1: FlexColumnWidth(1.6),
                2: FlexColumnWidth(0.9),
                3: FlexColumnWidth(0.9),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _kNavy),
                  children: [
                    _tableCell('nombre', isHeader: true),
                    _tableCell('correo_electronico', isHeader: true),
                    _tableCell('carrera', isHeader: true),
                    _tableCell('cedula', isHeader: true),
                  ],
                ),
                TableRow(
                  decoration:
                      BoxDecoration(color: _kCard.withValues(alpha: 0.6)),
                  children: [
                    _tableCell('Juan\nPérez'),
                    _tableCell('j.perez@espoch.edu.ec'),
                    _tableCell('Ing.\nSistemas'),
                    _tableCell('0601234567'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          text,
          style: _ts(
            11,
            fw: isHeader ? FontWeight.w700 : FontWeight.w400,
            color: isHeader ? _kWhite : _kGrey,
          ),
        ),
      );

  // ── Tarjeta de descarga de plantilla ─────────────────────────────────────
  Widget _buildTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Fondo con gradiente sutil verde
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16A34A).withValues(alpha: 0.07),
            const Color(0xFF22C55E).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Icono Excel
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              color: _kGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plantilla oficial',
                  style: _ts(13, fw: FontWeight.w700, color: _kGreen),
                ),
                const SizedBox(height: 3),
                Text(
                  'Descarga el formato correcto con las 4 columnas requeridas para evitar errores al importar.',
                  style: _ts(11, color: _kGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Botón de descarga
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _isDownloadingTemplate ? null : _downloadTemplate,
              icon: _isDownloadingTemplate
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(_kWhite),
                      ),
                    )
                  : const Icon(Icons.download_rounded,
                      color: _kWhite, size: 16),
              label: Text(
                _isDownloadingTemplate ? 'Guardando...' : 'Descargar',
                style: _ts(12, fw: FontWeight.w600, color: _kWhite),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                disabledBackgroundColor: _kGreen.withValues(alpha: 0.6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contenido dinámico ────────────────────────────────────────────────────
  Widget _buildContent() {
    return switch (_phase) {
      _ImportPhase.idle => _buildFilePicker(),
      _ImportPhase.loading => _buildFilePicker(),
      _ImportPhase.preview => _buildPreview(),
      _ImportPhase.importing => _buildImporting(),
      _ImportPhase.done => _buildResult(),
    };
  }

  // ── Selector de archivo ───────────────────────────────────────────────────
  Widget _buildFilePicker() {
    final isLoading = _phase == _ImportPhase.loading;
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : _pickFile,
          child: CustomPaint(
            painter: _DashedBorderPainter(
                color: _kPurple.withValues(alpha: 0.45)),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPurp2, _kPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(_kWhite),
                            ),
                          )
                        : const Icon(Icons.description_outlined,
                            color: _kWhite, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isLoading
                        ? 'Procesando archivo...'
                        : 'Seleccionar archivo CSV o Excel',
                    style: _ts(15, fw: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoading
                        ? (_fileName ?? '')
                        : 'Arrastra o haz clic para cargar',
                    style: _ts(11, color: _kGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['.CSV', '.XLSX', '.XLS']
                        .map((ext) => Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kBorder,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(ext,
                                  style: _ts(11,
                                      fw: FontWeight.w600, color: _kGrey)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _errorMsg!),
        ],
        if (!isLoading) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: _kBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o', style: _ts(12, color: _kGrey)),
              ),
              const Expanded(child: Divider(color: _kBorder)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddStudentDialog,
              icon: const Icon(Icons.person_add_rounded,
                  color: _kPurple, size: 18),
              label: Text('Agregar Estudiante',
                  style: _ts(14, fw: FontWeight.w600, color: _kPurple)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPurple),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Vista previa ──────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final preview = _isManualEntry ? _parsed : _parsed.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: _kGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isManualEntry
                          ? 'Entrada manual'
                          : (_fileName ?? ''),
                      style: _ts(13, fw: FontWeight.w600, color: _kGreen),
                    ),
                    Text(
                      '${_parsed.length} ${_isManualEntry ? 'estudiante(s) agregado(s)' : 'registros encontrados · columnas validadas'}',
                      style: _ts(11, color: _kGrey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _reset,
                child: const Icon(Icons.close_rounded,
                    color: _kGrey, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              _isManualEntry ? 'Estudiantes agregados' : 'Vista previa',
              style: _ts(13, fw: FontWeight.w700),
            ),
            const Spacer(),
            if (_isManualEntry)
              GestureDetector(
                onTap: _showAddStudentDialog,
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        color: _kPurple, size: 16),
                    const SizedBox(width: 4),
                    Text('Agregar otro',
                        style: _ts(12,
                            fw: FontWeight.w600, color: _kPurple)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  color: _kNavy,
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('Nombre',
                              style: _ts(11,
                                  fw: FontWeight.w700, color: _kWhite))),
                      Expanded(
                          child: Text('Correo',
                              style: _ts(11,
                                  fw: FontWeight.w700, color: _kWhite))),
                      Expanded(
                          child: Text('Carrera',
                              style: _ts(11,
                                  fw: FontWeight.w700, color: _kWhite))),
                      Expanded(
                          child: Text('Cédula',
                              style: _ts(11,
                                  fw: FontWeight.w700, color: _kWhite))),
                      if (_isManualEntry) const SizedBox(width: 28),
                    ],
                  ),
                ),
                ...preview.asMap().entries.map(
                  (e) => Column(
                    children: [
                      if (e.key > 0)
                        Divider(
                            height: 1,
                            color: _kBorder,
                            thickness: 0.5),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(e.value.nombre,
                                    style: _ts(11, color: _kGrey),
                                    overflow: TextOverflow.ellipsis)),
                            Expanded(
                                child: Text(e.value.correoElectronico,
                                    style: _ts(10, color: _kGrey),
                                    overflow: TextOverflow.ellipsis)),
                            Expanded(
                                child: Text(e.value.carrera,
                                    style: _ts(11, color: _kGrey),
                                    overflow: TextOverflow.ellipsis)),
                            Expanded(
                                child: Text(
                                    e.value.cedula.isEmpty
                                        ? '—'
                                        : e.value.cedula,
                                    style: _ts(11, color: _kGrey),
                                    overflow: TextOverflow.ellipsis)),
                            if (_isManualEntry)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _parsed.removeAt(e.key);
                                  if (_parsed.isEmpty) _reset();
                                }),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: _kRed,
                                    size: 18),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isManualEntry && _parsed.length > 5) ...[
                  Divider(height: 1, color: _kBorder, thickness: 0.5),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '... y ${_parsed.length - 5} registros más',
                      style: _ts(11, color: _kGrey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _doImport,
            icon: const Icon(Icons.upload_rounded, color: _kWhite),
            label: Text(
              'Importar ${_parsed.length} estudiante${_parsed.length == 1 ? '' : 's'}',
              style: _ts(14, fw: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: _kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Importando ────────────────────────────────────────────────────────────
  Widget _buildImporting() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_kPurple),
            ),
          ),
          const SizedBox(height: 16),
          Text('Importando estudiantes...',
              style: _ts(15, fw: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Procesando y verificando duplicados...',
              style: _ts(11, color: _kGrey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Resultado ─────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Importación completada',
                      style: _ts(15, fw: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _StatChip(
                          value: '${r.imported}',
                          label: 'Importados',
                          color: _kGreen)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatChip(
                          value: '${r.accountsCreated}',
                          label: 'Cuentas creadas',
                          color: _kPurple)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _StatChip(
                          value: '${r.existingInDb}',
                          label: 'Ya existían',
                          color: _kYellow)),
                ],
              ),
              if (r.duplicates > 0) ...[
                const SizedBox(height: 8),
                _StatChip(
                    value: '${r.duplicates}',
                    label: 'Duplicados en archivo',
                    color: _kYellow),
              ],
              if (r.errors > 0) ...[
                const SizedBox(height: 8),
                _StatChip(
                    value: '${r.errors}',
                    label: 'Errores',
                    color: _kRed),
              ],
              if (r.accountsCreated > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kPurple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_rounded,
                          color: _kPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se enviaron ${r.accountsCreated} correos con credenciales temporales al Outlook de cada estudiante.',
                          style: _ts(11, color: _kPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (r.importedList.isNotEmpty || r.existingList.isNotEmpty) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _showImportDetail(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kNavy.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt_rounded, color: _kNavy, size: 16),
                        const SizedBox(width: 8),
                        Text('Ver detalle completo',
                            style: _ts(12, fw: FontWeight.w600, color: _kNavy)),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: _kNavy, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.upload_file_rounded, color: _kPurple),
            label: Text('Importar otro archivo',
                style: _ts(14, fw: FontWeight.w600, color: _kPurple)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kPurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Modal de detalle de importación ──────────────────────────────────────
  void _showImportDetail(_ImportResult r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Detalle de importación', style: _ts(17, fw: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: _kGrey, size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${r.imported} importados · ${r.existingInDb} ya existían · ${r.duplicates} duplicados en archivo',
                  style: _ts(11, color: _kGrey),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    if (r.importedList.isNotEmpty) ...[
                      _detailSectionHeader(
                        '✅ Importados (${r.importedList.length})', _kGreen),
                      const SizedBox(height: 8),
                      ...r.importedList.map((s) => _detailRow(
                        s['nombre'] ?? '',
                        s['correo_electronico'] ?? '',
                        _kGreen,
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (r.existingList.isNotEmpty) ...[
                      _detailSectionHeader(
                        '⚠️ Ya existían (${r.existingList.length})', _kYellow),
                      const SizedBox(height: 8),
                      ...r.existingList.map((s) => _detailRow(
                        s['nombre'] ?? '',
                        s['correo_electronico'] ?? '',
                        _kYellow,
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSectionHeader(String title, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: _ts(13, fw: FontWeight.w700, color: color)),
  );

  Widget _detailRow(String nombre, String email, Color accent) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
            style: _ts(11, fw: FontWeight.w700, color: accent),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: _ts(12, fw: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text(email, style: _ts(10, color: _kGrey),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares
// ═══════════════════════════════════════════════════════════════════════════════

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const radius = Radius.circular(16);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      radius,
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    GoogleFonts.outfit(fontSize: 12, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.outfit(fontSize: 10, color: _kGrey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
