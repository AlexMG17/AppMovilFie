import 'dart:convert';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

// Paleta Sentry para mantener el admin conectado al home.
const _kBg = AppColors.sentryBg;
const _kCard = AppColors.cardBackground;
const _kBorder = AppColors.cardBorder;
const _kPurple = AppColors.sentryBlue;
const _kPurp2 = AppColors.sentryNavy;
const _kCyan = AppColors.sentryCyan;
const _kGreen = AppColors.success;
const _kRed = AppColors.error;
const _kYellow = AppColors.warning;
const _kWhite = Colors.white;
const _kGrey = AppColors.sentryGrey;
const _kNavy = AppColors.sentryNavy;

const _kRequiredCols = ['nombre', 'correo_electronico', 'carrera'];

// â”€â”€â”€ Modelo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class ImportedStudent {
  final String nombre;
  final String correoElectronico;
  final String carrera;
  const ImportedStudent({
    required this.nombre,
    required this.correoElectronico,
    required this.carrera,
  });
}

// â”€â”€â”€ Estados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum _ImportPhase { idle, loading, preview, importing, done }

class _ImportResult {
  final int imported;
  final int duplicates;
  final int errors;
  const _ImportResult({
    required this.imported,
    required this.duplicates,
    required this.errors,
  });
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: fw,
        color: color ?? _kNavy,
      );

  // â”€â”€ RF24/RF26: Seleccionar archivo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ RF26/RF27: Parsear CSV â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

      if (nombre.isEmpty || email.isEmpty) continue;

      result.add(
        ImportedStudent(
          nombre: nombre,
          correoElectronico: email,
          carrera: carrera,
        ),
      );
    }
    return result;
  }

  // â”€â”€ RF26/RF27: Parsear Excel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

      if (nombre.isEmpty || email.isEmpty) continue;

      result.add(
        ImportedStudent(
          nombre: nombre,
          correoElectronico: email,
          carrera: carrera,
        ),
      );
    }
    return result;
  }

  // â”€â”€ RF27: Validar columnas requeridas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _validateHeaders(List<String> headers) {
    final missing = _kRequiredCols.where((c) => !headers.contains(c)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Columnas faltantes: ${missing.join(', ')}');
    }
  }

  // â”€â”€ RF28/RF29: Procesar e importar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _doImport() async {
    setState(() => _phase = _ImportPhase.importing);

    await Future.delayed(const Duration(seconds: 2));

    // RF29: detectar duplicados por correo
    final seen = <String>{};
    int imported = 0;
    int duplicates = 0;
    int errors = 0;

    for (final s in _parsed) {
      final key = s.correoElectronico.toLowerCase();
      if (seen.contains(key)) {
        duplicates++;
        continue;
      }
      seen.add(key);

      try {
        // TODO: conectar Supabase
        // await SupabaseService.client
        //     .from('estudiantes_habilitados')
        //     .upsert({'nombre': s.nombre, 'correo': s.correoElectronico, 'carrera': s.carrera});
        imported++;
      } catch (_) {
        errors++;
      }
    }

    setState(() {
      _result = _ImportResult(
        imported: imported,
        duplicates: duplicates,
        errors: errors,
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
    });
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                    _buildContent(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _kBg,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: _kWhite),
        onPressed: () {},
      ),
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
              Text(
                'En línea',
                style: _ts(10, color: _kGreen, fw: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 16,
          backgroundColor: _kCyan.withValues(alpha: 0.16),
          child: const Icon(Icons.person_rounded, size: 18, color: _kPurple),
        ),
        IconButton(
          icon: Icon(Icons.logout_rounded, color: _kGrey, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Importar Estudiantes', style: _ts(22, fw: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'RF24 Â· RF26â€“RF32 â€” Carga masiva de estudiantes habilitados',
          style: _ts(11, color: _kGrey),
        ),
      ],
    );
  }

  // â”€â”€ RF26/RF27: Tarjeta de requisitos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _kCyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Requisitos del archivo (RF26 Â· RF27)',
                  style: _ts(13, fw: FontWeight.w700, color: _kCyan),
                ),
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
                      'El archivo debe ser CSV o Excel (.xlsx) y contener las columnas: ',
                ),
                TextSpan(
                  text: 'nombre',
                  style: _ts(12, fw: FontWeight.w700),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: 'correo_electronico',
                  style: _ts(12, fw: FontWeight.w700),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: 'carrera',
                  style: _ts(12, fw: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _kNavy),
                  children: [
                    _tableCell('nombre', isHeader: true),
                    _tableCell('correo_electronico', isHeader: true),
                    _tableCell('carrera', isHeader: true),
                  ],
                ),
                TableRow(
                  decoration: BoxDecoration(
                    color: _kCard.withValues(alpha: 0.6),
                  ),
                  children: [
                    _tableCell('Juan\nPérez'),
                    _tableCell('j.perez@espoch.edu.ec'),
                    _tableCell('Ing.\nSistemas'),
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

  // â”€â”€ Contenido dinámico â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildContent() {
    return switch (_phase) {
      _ImportPhase.idle => _buildFilePicker(),
      _ImportPhase.loading => _buildFilePicker(),
      _ImportPhase.preview => _buildPreview(),
      _ImportPhase.importing => _buildImporting(),
      _ImportPhase.done => _buildResult(),
    };
  }

  // â”€â”€ RF24: Selector de archivo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilePicker() {
    final isLoading = _phase == _ImportPhase.loading;
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : _pickFile,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _kPurple.withValues(alpha: 0.45),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                        : const Icon(
                            Icons.description_outlined,
                            color: _kWhite,
                            size: 28,
                          ),
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
                        : 'RF24 Â· RF26 â€” Arrastra o haz clic para cargar',
                    style: _ts(11, color: _kGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['.CSV', '.XLSX', '.XLS']
                        .map(
                          (ext) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _kBorder,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              ext,
                              style: _ts(
                                11,
                                fw: FontWeight.w600,
                                color: _kGrey,
                              ),
                            ),
                          ),
                        )
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
      ],
    );
  }

  // â”€â”€ RF27/RF30: Vista previa â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPreview() {
    final preview = _parsed.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Archivo validado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? '',
                      style: _ts(13, fw: FontWeight.w600, color: _kGreen),
                    ),
                    Text(
                      '${_parsed.length} registros encontrados Â· RF27 validado',
                      style: _ts(11, color: _kGrey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _reset,
                child: const Icon(Icons.close_rounded, color: _kGrey, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Vista previa Â· RF30', style: _ts(13, fw: FontWeight.w700)),
        const SizedBox(height: 10),
        // Tabla previa
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: _kNavy,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nombre',
                          style: _ts(11, fw: FontWeight.w700, color: _kWhite),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Correo',
                          style: _ts(11, fw: FontWeight.w700, color: _kWhite),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Carrera',
                          style: _ts(11, fw: FontWeight.w700, color: _kWhite),
                        ),
                      ),
                    ],
                  ),
                ),
                ...preview.asMap().entries.map(
                  (e) => Column(
                    children: [
                      if (e.key > 0)
                        Divider(height: 1, color: _kBorder, thickness: 0.5),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value.nombre,
                                style: _ts(11, color: _kGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value.correoElectronico,
                                style: _ts(10, color: _kGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value.carrera,
                                style: _ts(11, color: _kGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_parsed.length > 5) ...[
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
        // RF28: Botón importar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _doImport,
            icon: const Icon(Icons.upload_rounded, color: _kWhite),
            label: Text(
              'Importar ${_parsed.length} estudiantes',
              style: _ts(14, fw: FontWeight.w700, color: _kWhite),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: _kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ RF28: Importando â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          Text(
            'Importando estudiantes...',
            style: _ts(15, fw: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'RF28 Â· RF29 â€” Procesando y verificando duplicados',
            style: _ts(11, color: _kGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // â”€â”€ RF30: Resultado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: _kGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Importación completada Â· RF30',
                    style: _ts(15, fw: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      value: '${r.imported}',
                      label: 'Importados',
                      color: _kGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      value: '${r.duplicates}',
                      label: 'Duplicados omitidos',
                      color: _kYellow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatChip(
                      value: '${r.errors}',
                      label: 'Errores',
                      color: _kRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.upload_file_rounded, color: _kPurple),
            label: Text(
              'Importar otro archivo',
              style: _ts(14, fw: FontWeight.w600, color: _kPurple),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kPurple),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Widgets auxiliares
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error),
            ),
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
  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
  });

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
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10, color: _kGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
