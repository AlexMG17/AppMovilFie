import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/student_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

// ─── Dark palette ─────────────────────────────────────────────────────────────
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

// ─── Color de avatar ──────────────────────────────────────────────────────────
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

// ═════════════════════════════════════════════════════════════════════════════
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key, this.showAppBar = true});
  final bool showAppBar;
  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen>
    with SingleTickerProviderStateMixin {
  List<StudentRecord> _students = [];
  List<String> _careers = ['Todas las carreras'];
  String _query = '';
  String _selectedCareer = 'Todas las carreras';
  bool _loading = true;
  String _userName = '';
  String _eventName = '';

  final _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _total => _students.length;
  int get _conQR => _students.where((s) => s.tieneQR).length;
  int get _aprobados =>
      _students.where((s) => s.status == 'aprobado' || s.status == 'ingresado').length;
  int get _pendientes =>
      _students.where((s) => s.status == 'pendiente' || s.status == 'revision').length;

  // ── Filtered ───────────────────────────────────────────────────────────────
  List<StudentRecord> get _filtered => _students.where((s) {
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
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _load();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) setState(() => _userName = name ?? SupabaseService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final event = await EventService.getActiveEvent();

      final results = await Future.wait([
        StudentService.getStudentsWithStatus(idEvento: event?.id ?? 0),
        StudentService.getCareers(),
      ]);

      final students = results[0] as List<StudentRecord>;
      final careers = ['Todas las carreras', ...(results[1] as List<String>)];

      if (mounted) {
        setState(() {
          _students = students;
          _careers = careers;
          _eventName = event?.nombre ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  TextStyle _ts(double size, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(fontSize: size.sp, fontWeight: fw, color: color ?? _kNavy);

  // ── RF33: Descargar CSV ────────────────────────────────────────────────────
  Future<void> _downloadCsv() async {
    final buf = StringBuffer()
      ..writeln('nombre,correo_electronico,cedula,carrera,estado');
    for (final s in _students) {
      buf.writeln('"${s.nombre}",${s.email},${s.cedula},"${s.carrera}",${s.status}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _kGreen, size: 16),
            const SizedBox(width: 8),
            Text('CSV copiado · ${_students.length} registros', style: _ts(13)),
          ],
        ),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── RF25: Agregar / Editar ─────────────────────────────────────────────────
  Future<void> _showStudentDialog(StudentRecord? existing) async {
    final isEdit = existing != null;
    final nombreCtrl = TextEditingController(text: existing?.nombre);
    final emailCtrl = TextEditingController(text: existing?.email);
    final cedulaCtrl = TextEditingController(text: existing?.cedula);
    String selCareer = existing?.carrera ?? (_careers.length > 1 ? _careers[1] : '');
    bool saving = false;
    bool saved = false;

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
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? 'Editar Estudiante' : 'Agregar Estudiante', style: _ts(18, fw: FontWeight.w800)),
              Text(isEdit ? 'Modificar registro' : 'Nuevo registro', style: _ts(11, color: _kGrey)),
              const SizedBox(height: 20),
              _field('Nombre completo', nombreCtrl, Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _field('Correo electrónico', emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field('Cédula', cedulaCtrl, Icons.badge_outlined, keyboardType: TextInputType.number, maxLength: 10),
              const SizedBox(height: 12),
              if (_careers.length > 1)
                _dropdown<String>(
                  value: selCareer.isEmpty ? _careers[1] : selCareer,
                  items: _careers.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c, style: _ts(13)))).toList(),
                  onChanged: (v) => setModal(() => selCareer = v!),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancelar', style: _ts(14, color: _kGrey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        final nombre = nombreCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final cedula = cedulaCtrl.text.trim();
                        if (nombre.isEmpty || email.isEmpty) return;
                        setModal(() => saving = true);
                        try {
                          if (isEdit && existing.idDetalle != null) {
                            await StudentService.updateStudent(
                              idDetalle: existing.idDetalle!,
                              nombre: nombre, email: email,
                              carrera: selCareer, cedula: cedula,
                            );
                          } else {
                            await StudentService.addStudent(
                              nombre: nombre, email: email,
                              carrera: selCareer, cedula: cedula,
                            );
                          }
                          saved = true;
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setModal(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: _kRed),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPurple, foregroundColor: _kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _kWhite))
                          : Text(isEdit ? 'Guardar' : 'Agregar', style: _ts(14, fw: FontWeight.w700, color: _kWhite)),
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

    // Reload only after the modal is fully dismissed to avoid InheritedWidget
    // dependents assertion (_dependents.isEmpty) triggered by setState during
    // the modal's dismiss animation.
    if (saved) await _load();
  }

  // ── RF25: Eliminar ─────────────────────────────────────────────────────────
  Future<bool> _confirmDelete(StudentRecord s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Eliminar estudiante', style: _ts(16, fw: FontWeight.w700)),
        content: Text(
          '¿Eliminar a ${s.nombre}?\nEsta acción no se puede deshacer.',
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
              backgroundColor: _kRed, foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Eliminar', style: _ts(13, fw: FontWeight.w700, color: _kWhite)),
          ),
        ],
      ),
    );
    if (ok != true || s.idDetalle == null) return false;
    try {
      await StudentService.deleteStudent(s.idDetalle!);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e', style: _ts(13)),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kPurple,
        child: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (widget.showAppBar) _buildAppBar(),
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
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: CircularProgressIndicator(color: AppColors.sentryBlue),
                        ),
                      )
                    else ...[
                      ...list.map(_buildStudentRow),
                      if (list.isEmpty) _buildEmptyState(),
                    ],
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() => SliverAppBar(
    backgroundColor: _kBg,
    elevation: 0,
    pinned: true,
    automaticallyImplyLeading: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel Administrativo', style: _ts(16, fw: FontWeight.w700)),
        if (_eventName.isNotEmpty)
          Text(_eventName, style: _ts(11, color: _kGrey)),
      ],
    ),
    actions: [
      PopupMenuButton<String>(
        offset: const Offset(0, 44),
        onSelected: (value) async {
          if (value == 'logout') {
            final nav = Navigator.of(context);
            await SupabaseService.signOut();
            nav.pushReplacementNamed('/login');
          }
        },
        child: CircleAvatar(
          radius: 16,
          backgroundColor: _kCyan.withValues(alpha: 0.16),
          child: const Icon(Icons.person_rounded, size: 18, color: _kPurple),
        ),
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                Text(
                  SupabaseService.currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
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
      IconButton(
        icon: Icon(Icons.refresh_rounded, color: _kGrey, size: 20),
        onPressed: _load,
      ),
    ],
  );

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Lista de Estudiantes', style: _ts(22, fw: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Gestión y descarga del listado', style: _ts(11, color: _kGrey)),
    ],
  );

  // ── Botones de acción ──────────────────────────────────────────────────────
  Widget _buildActionButtons() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _downloadCsv,
          icon: const Icon(Icons.download_rounded, size: 18, color: _kPurple),
          label: Text('Descargar CSV', style: _ts(12, fw: FontWeight.w600, color: _kPurple), textAlign: TextAlign.center),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kBorder),
            backgroundColor: _kCard,
            foregroundColor: _kPurple,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _showStudentDialog(null),
          icon: const Icon(Icons.add_rounded, size: 20, color: _kWhite),
          label: Text('Agregar', style: _ts(12, fw: FontWeight.w700, color: _kWhite), textAlign: TextAlign.center),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple, foregroundColor: _kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ],
  );

  // ── Stats ──────────────────────────────────────────────────────────────────
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

  // ── Barra de búsqueda ──────────────────────────────────────────────────────
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
              onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
            )
          : null,
      filled: true,
      fillColor: _kCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPurple)),
    ),
  );

  // ── Filtro por carrera ──────────────────────────────────────────────────────
  Widget _buildCareerFilter() => Row(
    children: [
      const Icon(Icons.filter_list_rounded, color: _kGrey, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCareer,
              dropdownColor: _kCard,
              style: _ts(13),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kGrey),
              items: _careers.map((c) => DropdownMenuItem(value: c, child: Text(c, style: _ts(13)))).toList(),
              onChanged: (v) => setState(() => _selectedCareer = v!),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Encabezado de tabla ─────────────────────────────────────────────────────
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

  Widget _colLabel(String t) => Text(t, style: _ts(11, fw: FontWeight.w600, color: _kGrey));

  // ── Fila de estudiante ──────────────────────────────────────────────────────
  Widget _buildStudentRow(StudentRecord s) {
    return Dismissible(
      key: ValueKey(s.idDetalle ?? s.email),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(s),
      onDismissed: (_) {
        if (!mounted) return;
        setState(() => _students.removeWhere((st) => st.idDetalle == s.idDetalle && st.email == s.email));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.nombre} eliminado', style: _ts(13)),
            backgroundColor: _kCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      radius: 20.r,
                      backgroundColor: _avatarColor(s.nombre).withValues(alpha: 0.2),
                      child: Text(
                        s.nombre.isNotEmpty ? s.nombre[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: _avatarColor(s.nombre)),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nombre, style: _ts(13, fw: FontWeight.w700), overflow: TextOverflow.ellipsis),
                          Text(s.email, style: _ts(10, color: _kGrey), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Cédula
              Expanded(
                flex: 5,
                child: Text(s.cedula.isNotEmpty ? s.cedula : '—', style: _ts(11, color: _kGrey), overflow: TextOverflow.ellipsis),
              ),
              // Carrera + status
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.carrera, style: _ts(9, color: _kGrey), overflow: TextOverflow.ellipsis, maxLines: 1),
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

  // ── Estado vacío ───────────────────────────────────────────────────────────
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

  // ── Helpers UI ─────────────────────────────────────────────────────────────
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPurple)),
    ),
  );

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
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

// ─── Tarjeta de estadística ───────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _StatBadge({required this.value, required this.label, required this.color});

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
          Text('$value', style: GoogleFonts.outfit(fontSize: 14.sp, fontWeight: FontWeight.w800, color: color)),
          SizedBox(width: 5.w),
          Text(label, style: GoogleFonts.outfit(fontSize: 12.sp, fontWeight: FontWeight.w500, color: _kNavy)),
        ],
      ),
    );
  }
}

// ─── Chip de estado ───────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ingresado' => ('Ingresado', _kCyan),
      'aprobado'  => ('Aprobado', _kGreen),
      'revision'  => ('En revisión', _kYellow),
      _           => ('Pendiente', _kYellow),
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
        style: GoogleFonts.outfit(fontSize: 9.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
