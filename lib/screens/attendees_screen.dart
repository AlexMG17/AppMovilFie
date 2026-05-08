import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

// â”€â”€â”€ Modelo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum AttendeeStatus { registered, entered, pending }

class Attendee {
  final String id;
  final String name;
  final String email;
  final String career;
  final AttendeeStatus status;
  final String? qrData;

  const Attendee({
    required this.id,
    required this.name,
    required this.email,
    required this.career,
    required this.status,
    this.qrData,
  });
}

// â”€â”€â”€ Datos simulados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final List<Attendee> _mockAttendees = [
  Attendee(
    id: '1',
    name: 'Ana Torres Guzmán',
    email: 'a.torres@espoch.edu.ec',
    career: 'Ing. Electrónica',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|Ana Torres Guzmán|TRF-0847',
  ),
  Attendee(
    id: '2',
    name: 'Carlos Mendoza Rivas',
    email: 'c.mendoza@espoch.edu.ec',
    career: 'Ing. Sistemas',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|Carlos Mendoza Rivas|TRF-0931',
  ),
  Attendee(
    id: '3',
    name: 'Diego Flores Castillo',
    email: 'd.flores@espoch.edu.ec',
    career: 'Ing. Telecom.',
    status: AttendeeStatus.registered,
    qrData: 'SENTRY|Diego Flores Castillo|TRF-0799',
  ),
  Attendee(
    id: '4',
    name: 'Sofía Ramírez León',
    email: 's.ramirez@espoch.edu.ec',
    career: 'Ing. Sistemas',
    status: AttendeeStatus.pending,
  ),
  Attendee(
    id: '5',
    name: 'Luis Cáceres Mora',
    email: 'l.caceres@espoch.edu.ec',
    career: 'Ing. Electrónica',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|Luis Cáceres Mora|TRF-0823',
  ),
  Attendee(
    id: '6',
    name: 'María Salinas Cruz',
    email: 'm.salinas@espoch.edu.ec',
    career: 'Ing. Sistemas',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|María Salinas Cruz|TRF-0888',
  ),
  Attendee(
    id: '7',
    name: 'Pedro Aguirre Vega',
    email: 'p.aguirre@espoch.edu.ec',
    career: 'Ing. Civil',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|Pedro Aguirre Vega|TRF-0754',
  ),
  Attendee(
    id: '8',
    name: 'Valentina Ríos Ponce',
    email: 'v.rios@espoch.edu.ec',
    career: 'Ing. Industrial',
    status: AttendeeStatus.registered,
    qrData: 'SENTRY|Valentina Ríos Ponce|TRF-0902',
  ),
  Attendee(
    id: '9',
    name: 'Jorge Salas Trujillo',
    email: 'j.salas@espoch.edu.ec',
    career: 'Ing. Mecánica',
    status: AttendeeStatus.pending,
  ),
  Attendee(
    id: '10',
    name: 'Camila Vera Dávalos',
    email: 'c.vera@espoch.edu.ec',
    career: 'Ing. Electrónica',
    status: AttendeeStatus.entered,
    qrData: 'SENTRY|Camila Vera Dávalos|TRF-0915',
  ),
];

// â”€â”€â”€ Color de avatar según inicial â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const List<Color> _avatarPalette = [
  AppColors.sentryBlue,
  AppColors.sentryCyan,
  AppColors.sentryNavy,
  Color(0xFF9C6FE4),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
];
Color _avatarColor(String name) =>
    _avatarPalette[name.codeUnitAt(0) % _avatarPalette.length];

// â”€â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AttendeesScreen extends StatefulWidget {
  const AttendeesScreen({super.key});
  @override
  State<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen>
    with SingleTickerProviderStateMixin {
  bool _showOnlyEntered = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Timer _timer;
  int _tick = 0;

  // â”€â”€ Estadísticas â”€â”€
  int get _total => _mockAttendees.length;
  int get _entered =>
      _mockAttendees.where((a) => a.status == AttendeeStatus.entered).length;
  int get _registered =>
      _mockAttendees.where((a) => a.status == AttendeeStatus.registered).length;
  int get _pending =>
      _mockAttendees.where((a) => a.status == AttendeeStatus.pending).length;

  List<Attendee> get _filtered => _mockAttendees.where((a) {
    final matchStatus = !_showOnlyEntered || a.status == AttendeeStatus.entered;
    final q = _query.toLowerCase();
    final matchQ =
        q.isEmpty ||
        a.name.toLowerCase().contains(q) ||
        a.email.toLowerCase().contains(q) ||
        a.career.toLowerCase().contains(q);
    return matchStatus && matchQ;
  }).toList();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _timer.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  TextStyle _ts(double sz, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: sz,
        fontWeight: fw,
        color: color ?? AppColors.sentryNavy,
      );

  // â”€â”€ Modal QR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showQr(Attendee a) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _avatarColor(
                      a.name,
                    ).withValues(alpha: 0.15),
                    child: Text(
                      a.name[0],
                      style: _ts(
                        15,
                        fw: FontWeight.w700,
                        color: _avatarColor(a.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: _ts(13, fw: FontWeight.w700)),
                        Text(
                          a.career,
                          style: _ts(11, color: AppColors.sentryGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.sentryGrey,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Código QR de Acceso',
                style: _ts(
                  12,
                  fw: FontWeight.w600,
                  color: AppColors.sentryGrey,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sentryBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: QrImageView(
                  data: a.qrData ?? 'SENTRY|${a.name}',
                  version: QrVersions.auto,
                  size: 180,
                  eyeStyle: const QrEyeStyle(
                    color: AppColors.sentryNavy,
                    eyeShape: QrEyeShape.square,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    color: AppColors.sentryBlue,
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Acceso verificado',
                      style: _ts(
                        12,
                        fw: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(a.email, style: _ts(11, color: AppColors.sentryGrey)),
            ],
          ),
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 4),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 20),
                    _buildFilterTabs(),
                    const SizedBox(height: 14),
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildTableHeader(),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      _buildEmpty()
                    else
                      ...list.map(
                        (a) => _AttendeeRow(
                          attendee: a,
                          onQr: a.qrData != null ? () => _showQr(a) : null,
                          ts: _ts,
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  SliverAppBar _buildAppBar() => SliverAppBar(
    backgroundColor: AppColors.sentryBg,
    elevation: 0,
    pinned: true,
    leading: IconButton(
      icon: const Icon(
        Icons.menu_rounded,
        color: AppColors.sentryNavy,
        size: 22,
      ),
      onPressed: () {},
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel Administrativo', style: _ts(15, fw: FontWeight.w700)),
        Text('Gala FIE 2026', style: _ts(10, color: AppColors.sentryGrey)),
      ],
    ),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'En vivo',
              style: _ts(10, fw: FontWeight.w600, color: AppColors.success),
            ),
          ],
        ),
      ),
    ],
  );

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asistentes', style: _ts(24, fw: FontWeight.w800)),
            Text(
              'RF21 Â· RF22 â€” Lista de asistentes en tiempo real',
              style: _ts(11, color: AppColors.sentryGrey),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '$_entered ingresaron',
              style: _ts(13, fw: FontWeight.w700, color: AppColors.success),
            ),
          ],
        ),
      ),
    ],
  );

  // â”€â”€ Estadísticas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStatsRow() => Row(
    children: [
      _StatTile(
        icon: Icons.login_rounded,
        color: AppColors.success,
        value: '$_entered',
        label: 'Ingresaron',
        ts: _ts,
      ),
      const SizedBox(width: 10),
      _StatTile(
        icon: Icons.how_to_reg_rounded,
        color: AppColors.sentryBlue,
        value: '$_registered',
        label: 'Registrados',
        ts: _ts,
      ),
      const SizedBox(width: 10),
      _StatTile(
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        value: '$_pending',
        label: 'Pendiente\npago',
        ts: _ts,
      ),
    ],
  );

  // â”€â”€ Filtros â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilterTabs() => Row(
    children: [
      _FilterTab(
        label: 'Todos',
        count: _total,
        active: !_showOnlyEntered,
        onTap: () => setState(() => _showOnlyEntered = false),
      ),
      const SizedBox(width: 10),
      _FilterTab(
        label: 'Ingresaron',
        count: _entered,
        active: _showOnlyEntered,
        onTap: () => setState(() => _showOnlyEntered = true),
      ),
    ],
  );

  // â”€â”€ Búsqueda â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSearchBar() => TextField(
    controller: _searchCtrl,
    onChanged: (v) => setState(() => _query = v),
    style: _ts(14),
    decoration: InputDecoration(
      hintText: 'Buscar asistente...',
      hintStyle: _ts(14, color: AppColors.sentryGrey),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.sentryGrey,
        size: 20,
      ),
      suffixIcon: _query.isNotEmpty
          ? IconButton(
              icon: const Icon(
                Icons.clear_rounded,
                size: 18,
                color: AppColors.sentryGrey,
              ),
              onPressed: () => setState(() {
                _query = '';
                _searchCtrl.clear();
              }),
            )
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sentryCyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  // â”€â”€ Encabezado de tabla â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTableHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Asistente',
            style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey),
          ),
        ),
        SizedBox(
          width: 84,
          child: Text(
            'Carrera',
            style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            'QR',
            textAlign: TextAlign.center,
            style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: AppColors.sentryGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: _ts(16, fw: FontWeight.w600, color: AppColors.sentryGrey),
          ),
        ],
      ),
    ),
  );
}

// â”€â”€â”€ Tarjeta de estadística â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final TextStyle Function(double, {Color? color, FontWeight fw}) ts;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryNavy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: ts(10, color: AppColors.sentryGrey),
          ),
        ],
      ),
    ),
  );
}

// â”€â”€â”€ Tab de filtro â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.sentryBlue : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active ? AppColors.sentryBlue : AppColors.cardBorder,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.sentryBlue.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.sentryNavy,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.sentryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.sentryBlue,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// â”€â”€â”€ Fila de asistente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AttendeeRow extends StatelessWidget {
  final Attendee attendee;
  final VoidCallback? onQr;
  final TextStyle Function(double, {Color? color, FontWeight fw}) ts;

  const _AttendeeRow({
    required this.attendee,
    required this.onQr,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) {
    final a = attendee;
    final aColor = _avatarColor(a.name);

    Color accent;
    switch (a.status) {
      case AttendeeStatus.entered:
        accent = AppColors.success;
        break;
      case AttendeeStatus.registered:
        accent = AppColors.sentryBlue;
        break;
      case AttendeeStatus.pending:
        accent = AppColors.warning;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryNavy.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barra lateral de estado
              Container(width: 4, color: accent),
              // Contenido
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: aColor.withValues(alpha: 0.15),
                        child: Text(
                          a.name[0],
                          style: ts(15, fw: FontWeight.w700, color: aColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nombre + email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: ts(13, fw: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.email,
                              style: ts(10, color: AppColors.sentryGrey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Carrera
                      SizedBox(
                        width: 72,
                        child: Text(
                          a.career,
                          style: ts(10, color: AppColors.sentryGrey),
                        ),
                      ),
                      // Botón QR
                      SizedBox(
                        width: 36,
                        child: a.qrData != null
                            ? GestureDetector(
                                onTap: onQr,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.sentryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: AppColors.sentryBlue.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 18,
                                    color: AppColors.sentryBlue,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'â€”',
                                  style: ts(14, color: AppColors.sentryGrey),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
