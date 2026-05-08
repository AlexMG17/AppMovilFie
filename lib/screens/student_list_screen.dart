import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

// â”€â”€â”€ Dark palette â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kBg = AppColors.sentryBg;
const _kCard = AppColors.cardBackground;
const _kBorder = AppColors.cardBorder;
const _kPurple = AppColors.sentryBlue;
const _kCyan = AppColors.sentryCyan;
const _kGreen = AppColors.success;
const _kRed = AppColors.error;
const _kYellow = AppColors.warning;
const _kWhite = Colors.white;
const _kGrey = AppColors.sentryGrey;
const _kNavy = AppColors.sentryNavy;

// â”€â”€â”€ Modelo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum StudentStatus { ingresado, aprobado, pendiente }

class Student {
  final String id;
  final String nombre;
  final String email;
  final String cedula;
  final String carrera;
  final StudentStatus status;
  final bool tieneQR;

  const Student({
    required this.id,
    required this.nombre,
    required this.email,
    required this.cedula,
    required this.carrera,
    required this.status,
    required this.tieneQR,
  });

  Student copyWith({
    String? nombre,
    String? email,
    String? cedula,
    String? carrera,
    StudentStatus? status,
    bool? tieneQR,
  }) => Student(
    id: id,
    nombre: nombre ?? this.nombre,
    email: email ?? this.email,
    cedula: cedula ?? this.cedula,
    carrera: carrera ?? this.carrera,
    status: status ?? this.status,
    tieneQR: tieneQR ?? this.tieneQR,
  );
}

// â”€â”€â”€ Mock data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final _mockStudents = <Student>[
  const Student(
    id: '1',
    nombre: 'Ana Torres Guzmán',
    email: 'a.torres@espoch.edu.ec',
    cedula: '0601234567',
    carrera: 'Ing. Electrónica',
    status: StudentStatus.ingresado,
    tieneQR: true,
  ),
  const Student(
    id: '2',
    nombre: 'Carlos Mendoza Rivas',
    email: 'c.mendoza@espoch.edu.ec',
    cedula: '0609876543',
    carrera: 'Ing. Sistemas',
    status: StudentStatus.ingresado,
    tieneQR: true,
  ),
  const Student(
    id: '3',
    nombre: 'Diego Flores Castillo',
    email: 'd.flores@espoch.edu.ec',
    cedula: '0612345678',
    carrera: 'Ing. Telecom.',
    status: StudentStatus.aprobado,
    tieneQR: true,
  ),
  const Student(
    id: '4',
    nombre: 'Sofía Ramírez León',
    email: 's.ramirez@espoch.edu.ec',
    cedula: '0656789012',
    carrera: 'Ing. Sistemas',
    status: StudentStatus.pendiente,
    tieneQR: false,
  ),
  const Student(
    id: '5',
    nombre: 'Luis Cáceres Mora',
    email: 'l.caceres@espoch.edu.ec',
    cedula: '0645678901',
    carrera: 'Ing. Electrónica',
    status: StudentStatus.ingresado,
    tieneQR: true,
  ),
  const Student(
    id: '6',
    nombre: 'María Salinas Cruz',
    email: 'm.salinas@espoch.edu.ec',
    cedula: '0601122334',
    carrera: 'Ing. Sistemas',
    status: StudentStatus.ingresado,
    tieneQR: true,
  ),
  const Student(
    id: '7',
    nombre: 'Pedro Aguirre Vega',
    email: 'p.aguirre@espoch.edu.ec',
    cedula: '0612233445',
    carrera: 'Ing. Civil',
    status: StudentStatus.aprobado,
    tieneQR: true,
  ),
  const Student(
    id: '8',
    nombre: 'Valentina Ríos Ponce',
    email: 'v.rios@espoch.edu.ec',
    cedula: '0623344556',
    carrera: 'Ing. Industrial',
    status: StudentStatus.aprobado,
    tieneQR: true,
  ),
  const Student(
    id: '9',
    nombre: 'Jorge Salas Trujillo',
    email: 'j.salas@espoch.edu.ec',
    cedula: '0634455667',
    carrera: 'Ing. Mecánica',
    status: StudentStatus.pendiente,
    tieneQR: false,
  ),
  const Student(
    id: '10',
    nombre: 'Camila Vera Dávalos',
    email: 'c.vera@espoch.edu.ec',
    cedula: '0645566778',
    carrera: 'Ing. Electrónica',
    status: StudentStatus.ingresado,
    tieneQR: true,
  ),
];

const _kCareers = [
  'Todas las carreras',
  'Ing. Electrónica',
  'Ing. Sistemas',
  'Ing. Telecom.',
  'Ing. Civil',
  'Ing. Industrial',
  'Ing. Mecánica',
];

const _kAvatarColors = [
  AppColors.sentryNavy,
  AppColors.sentryBlue,
  AppColors.sentryCyan,
  AppColors.success,
  AppColors.warning,
  AppColors.error,
];

Color _avatarColor(String name) =>
    _kAvatarColors[name.codeUnitAt(0) % _kAvatarColors.length];

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen>
    with SingleTickerProviderStateMixin {
  late List<Student> _students;
  String _query = '';
  String _selectedCareer = 'Todas las carreras';

  final _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // â”€â”€ Stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int get _total => _students.length;
  int get _conQR => _students.where((s) => s.tieneQR).length;
  int get _aprobados => _students
      .where(
        (s) =>
            s.status == StudentStatus.aprobado ||
            s.status == StudentStatus.ingresado,
      )
      .length;
  int get _pendientes =>
      _students.where((s) => s.status == StudentStatus.pendiente).length;

  // â”€â”€ Filtered â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Student> get _filtered => _students.where((s) {
    final q = _query.toLowerCase();
    final matchQ =
        q.isEmpty ||
        s.nombre.toLowerCase().contains(q) ||
        s.email.toLowerCase().contains(q) ||
        s.cedula.contains(q);
    final matchCareer =
        _selectedCareer == 'Todas las carreras' || s.carrera == _selectedCareer;
    return matchQ && matchCareer;
  }).toList();

  @override
  void initState() {
    super.initState();
    _students = List.from(_mockStudents);
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
    _searchCtrl.dispose();
    super.dispose();
  }

  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: fw,
        color: color ?? _kNavy,
      );

  // â”€â”€ RF33: Descargar CSV â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _downloadCsv() async {
    final buf = StringBuffer()
      ..writeln('nombre,correo_electronico,cedula,carrera,estado');
    for (final s in _students) {
      final est = switch (s.status) {
        StudentStatus.ingresado => 'Ingresado',
        StudentStatus.aprobado => 'Aprobado',
        StudentStatus.pendiente => 'Pendiente',
      };
      buf.writeln('"${s.nombre}",${s.email},${s.cedula},"${s.carrera}",$est');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _kGreen, size: 16),
            const SizedBox(width: 8),
            Text(
              'CSV copiado Â· ${_students.length} registros',
              style: _ts(13),
            ),
          ],
        ),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // â”€â”€ RF25: Agregar / Editar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _showStudentDialog(Student? existing) async {
    final isEdit = existing != null;
    final nombreCtrl = TextEditingController(text: existing?.nombre);
    final emailCtrl = TextEditingController(text: existing?.email);
    final cedulaCtrl = TextEditingController(text: existing?.cedula);
    String selCareer = existing?.carrera ?? 'Ing. Sistemas';
    StudentStatus selStatus = existing?.status ?? StudentStatus.pendiente;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Editar Estudiante' : 'Agregar Estudiante',
                style: _ts(18, fw: FontWeight.w800),
              ),
              Text(
                isEdit
                    ? 'RF25 â€” Modificar registro'
                    : 'RF25 â€” Nuevo registro',
                style: _ts(11, color: _kGrey),
              ),
              const SizedBox(height: 20),
              _field(
                'Nombre completo',
                nombreCtrl,
                Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _field(
                'Correo electrónico',
                emailCtrl,
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(
                'Cédula',
                cedulaCtrl,
                Icons.badge_outlined,
                keyboardType: TextInputType.number,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                value: selCareer,
                items: _kCareers
                    .skip(1)
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: _ts(13)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModal(() => selCareer = v!),
              ),
              const SizedBox(height: 12),
              _dropdown<StudentStatus>(
                value: selStatus,
                items: StudentStatus.values.map((s) {
                  final label = switch (s) {
                    StudentStatus.ingresado => 'Ingresado',
                    StudentStatus.aprobado => 'Aprobado',
                    StudentStatus.pendiente => 'Pendiente',
                  };
                  return DropdownMenuItem(
                    value: s,
                    child: Text(label, style: _ts(13)),
                  );
                }).toList(),
                onChanged: (v) => setModal(() => selStatus = v!),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Cancelar', style: _ts(14, color: _kGrey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final nombre = nombreCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final cedula = cedulaCtrl.text.trim();
                        if (nombre.isEmpty || email.isEmpty || cedula.isEmpty) {
                          return;
                        }

                        setState(() {
                          if (isEdit) {
                            final idx = _students.indexWhere(
                              (s) => s.id == existing.id,
                            );
                            if (idx >= 0) {
                              _students[idx] = existing.copyWith(
                                nombre: nombre,
                                email: email,
                                cedula: cedula,
                                carrera: selCareer,
                                status: selStatus,
                              );
                            }
                          } else {
                            _students.add(
                              Student(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                nombre: nombre,
                                email: email,
                                cedula: cedula,
                                carrera: selCareer,
                                status: selStatus,
                                tieneQR: false,
                              ),
                            );
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurple,
                        foregroundColor: _kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEdit ? 'Guardar' : 'Agregar',
                        style: _ts(14, fw: FontWeight.w700, color: _kWhite),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    nombreCtrl.dispose();
    emailCtrl.dispose();
    cedulaCtrl.dispose();
  }

  // â”€â”€ RF25: Eliminar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<bool> _confirmDelete(Student s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar estudiante', style: _ts(16, fw: FontWeight.w700)),
        content: Text(
          'Â¿Eliminar a ${s.nombre}?\nEsta acción no se puede deshacer.',
          style: _ts(13, color: _kGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: _ts(13, color: _kGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Eliminar',
              style: _ts(13, fw: FontWeight.w700, color: _kWhite),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
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
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                    const SizedBox(height: 14),
                    _buildStats(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 10),
                    _buildCareerFilter(),
                    const SizedBox(height: 16),
                    _buildColumnHeader(),
                    const SizedBox(height: 6),
                    ...list.map(_buildStudentRow),
                    if (list.isEmpty) _buildEmptyState(),
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
  SliverAppBar _buildAppBar() => SliverAppBar(
    backgroundColor: _kBg,
    elevation: 0,
    pinned: true,
    leading: IconButton(
      icon: const Icon(Icons.menu_rounded, color: _kNavy),
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

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Lista de Estudiantes', style: _ts(22, fw: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(
        'RF25 Â· RF32 Â· RF33 â€” CRUD y descarga del listado',
        style: _ts(11, color: _kGrey),
      ),
    ],
  );

  // â”€â”€ RF33/RF25: Botones de acción â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildActionButtons() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _downloadCsv,
          icon: const Icon(Icons.download_rounded, size: 18, color: _kPurple),
          label: Text(
            'Descargar CSV\n(RF33)',
            style: _ts(12, fw: FontWeight.w600, color: _kPurple),
            textAlign: TextAlign.center,
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kBorder),
            backgroundColor: _kCard,
            foregroundColor: _kPurple,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _showStudentDialog(null),
          icon: const Icon(Icons.add_rounded, size: 20, color: _kWhite),
          label: Text(
            'Agregar\n(RF25)',
            style: _ts(12, fw: FontWeight.w700, color: _kWhite),
            textAlign: TextAlign.center,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple,
            foregroundColor: _kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
    ],
  );

  // â”€â”€ RF23: Stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStats() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _StatBadge(value: _total, label: 'Total', color: _kYellow),
      _StatBadge(value: _conQR, label: 'Con QR', color: _kCyan),
      _StatBadge(value: _aprobados, label: 'Aprobados', color: _kGreen),
      _StatBadge(value: _pendientes, label: 'Pendientes', color: _kYellow),
    ],
  );

  // â”€â”€ RF32: Barra de búsqueda â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSearchBar() => TextField(
    controller: _searchCtrl,
    style: _ts(13),
    cursorColor: _kPurple,
    onChanged: (v) => setState(() => _query = v),
    decoration: InputDecoration(
      hintText: 'Buscar por nombre, email, cédula...',
      hintStyle: _ts(13, color: _kGrey),
      prefixIcon: const Icon(Icons.search_rounded, color: _kGrey, size: 20),
      suffixIcon: _query.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close_rounded, color: _kGrey, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            )
          : null,
      filled: true,
      fillColor: _kCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPurple),
      ),
    ),
  );

  // â”€â”€ Filtro por carrera â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCareerFilter() => Row(
    children: [
      const Icon(Icons.filter_list_rounded, color: _kGrey, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCareer,
              dropdownColor: _kCard,
              style: _ts(13),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _kGrey,
              ),
              items: _kCareers
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: _ts(13)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCareer = v!),
            ),
          ),
        ),
      ),
    ],
  );

  // â”€â”€ Encabezado de tabla â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildColumnHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Expanded(flex: 10, child: _colLabel('Estudiante')),
        Expanded(flex: 5, child: _colLabel('Cédula')),
        Expanded(flex: 4, child: _colLabel('Carrera')),
      ],
    ),
  );

  Widget _colLabel(String t) => Text(
    t,
    style: _ts(11, fw: FontWeight.w600, color: _kGrey),
  );

  // â”€â”€ RF21: Fila de estudiante â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStudentRow(Student s) {
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(s),
      onDismissed: (_) {
        setState(() => _students.removeWhere((st) => st.id == s.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.nombre} eliminado Â· RF25', style: _ts(13)),
            backgroundColor: _kCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kRed.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 22),
      ),
      child: GestureDetector(
        onTap: () => _showStudentDialog(s),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              // Avatar + nombre + email
              Expanded(
                flex: 10,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _avatarColor(
                        s.nombre,
                      ).withValues(alpha: 0.2),
                      child: Text(
                        s.nombre[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _avatarColor(s.nombre),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nombre,
                            style: _ts(13, fw: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            s.email,
                            style: _ts(10, color: _kGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Cédula
              Expanded(
                flex: 5,
                child: Text(
                  s.cedula,
                  style: _ts(11, color: _kGrey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Carrera + status
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.carrera,
                      style: _ts(9, color: _kGrey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(status: s.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Estado vacío â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildEmptyState() => Container(
    padding: const EdgeInsets.all(36),
    alignment: Alignment.center,
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, color: _kGrey, size: 40),
        const SizedBox(height: 12),
        Text('Sin resultados', style: _ts(15, fw: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Prueba otro término o filtro', style: _ts(12, color: _kGrey)),
      ],
    ),
  );

  // â”€â”€ Helpers UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    maxLength: maxLength,
    style: _ts(13),
    cursorColor: _kPurple,
    decoration: InputDecoration(
      counterText: '',
      labelText: label,
      labelStyle: _ts(13, color: _kGrey),
      prefixIcon: Icon(icon, color: _kGrey, size: 18),
      filled: true,
      fillColor: _kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPurple),
      ),
    ),
  );

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        dropdownColor: _kCard,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kGrey),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Widgets auxiliares
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _StatBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _StatBadge({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StudentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StudentStatus.ingresado => ('Ingresado', _kCyan),
      StudentStatus.aprobado => ('Aprobado', _kGreen),
      StudentStatus.pendiente => ('Pendiente', _kYellow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
