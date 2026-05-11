import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

// ── Modelo ────────────────────────────────────────────────────────────────────
enum AttendeeStatus { registered, entered }

class Attendee {
  final String name;
  final String email;
  final AttendeeStatus status;
  final String? qrData;

  const Attendee({
    required this.name,
    required this.email,
    required this.status,
    this.qrData,
  });

  factory Attendee.fromMap(Map<String, dynamic> map) {
    final u = map['usuarios'];
    final nombre = u is Map ? (u['nombre'] ?? 'Sin nombre') : 'Sin nombre';
    final email = u is Map ? (u['email'] ?? '') : '';
    final estado = map['estado'] as String? ?? 'activo';
    return Attendee(
      name: nombre,
      email: email,
      status: estado == 'usado' ? AttendeeStatus.entered : AttendeeStatus.registered,
      qrData: map['codigo_qr'] as String?,
    );
  }
}

// ── Color de avatar según inicial ─────────────────────────────────────────────
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

// ── Screen ────────────────────────────────────────────────────────────────────
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
  bool _loading = true;

  List<Attendee> _attendees = [];
  int? _eventId;
  RealtimeChannel? _channel;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Estadísticas ──
  int get _total => _attendees.length;
  int get _entered =>
      _attendees.where((a) => a.status == AttendeeStatus.entered).length;
  int get _registered =>
      _attendees.where((a) => a.status == AttendeeStatus.registered).length;

  List<Attendee> get _filtered => _attendees.where((a) {
    final matchStatus = !_showOnlyEntered || a.status == AttendeeStatus.entered;
    final q = _query.toLowerCase();
    final matchQ =
        q.isEmpty ||
        a.name.toLowerCase().contains(q) ||
        a.email.toLowerCase().contains(q);
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
    _load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final event = await EventService.getActiveEvent();
      if (event == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _eventId = event.id;
      await _fetch();
      _subscribeRealtime(event.id);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetch() async {
    if (_eventId == null) return;
    try {
      final rows = await SupabaseService.client
          .from('entradas')
          .select('codigo_qr, estado, usuarios(nombre, email)')
          .eq('id_evento', _eventId!)
          .neq('estado', 'cancelado')
          .order('estado'); // 'activo' antes que 'usado'

      final list = (rows as List).map((r) => Attendee.fromMap(r)).toList();
      if (mounted) setState(() { _attendees = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime(int idEvento) {
    _channel = SupabaseService.client
        .channel('attendees-$idEvento')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'entradas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_evento',
            value: idEvento,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  TextStyle _ts(double sz, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(
        fontSize: sz,
        fontWeight: fw,
        color: color ?? AppColors.sentryNavy,
      );

  // ── Modal QR ──────────────────────────────────────────────────────────────
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _avatarColor(a.name).withValues(alpha: 0.15),
                    child: Text(
                      a.name[0],
                      style: _ts(15, fw: FontWeight.w700, color: _avatarColor(a.name)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: _ts(13, fw: FontWeight.w700)),
                        Text(a.email, style: _ts(11, color: AppColors.sentryGrey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.sentryGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Código QR de Acceso',
                style: _ts(12, fw: FontWeight.w600, color: AppColors.sentryGrey),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: a.status == AttendeeStatus.entered
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.sentryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: a.status == AttendeeStatus.entered
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.sentryBlue.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      a.status == AttendeeStatus.entered
                          ? Icons.verified_rounded
                          : Icons.qr_code_rounded,
                      size: 14,
                      color: a.status == AttendeeStatus.entered
                          ? AppColors.success
                          : AppColors.sentryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      a.status == AttendeeStatus.entered ? 'Acceso verificado' : 'Acceso pendiente',
                      style: _ts(
                        12,
                        fw: FontWeight.w600,
                        color: a.status == AttendeeStatus.entered
                            ? AppColors.success
                            : AppColors.sentryBlue,
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

  // ══════════════════════════════════════════════════════════════════════════
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
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: CircularProgressIndicator(color: AppColors.sentryBlue),
                        ),
                      )
                    else if (list.isEmpty)
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

  // ── AppBar ─────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() => SliverAppBar(
    backgroundColor: AppColors.sentryBg,
    elevation: 0,
    pinned: true,
    leading: IconButton(
      icon: const Icon(Icons.menu_rounded, color: AppColors.sentryNavy, size: 22),
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
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text('En vivo', style: _ts(10, fw: FontWeight.w600, color: AppColors.success)),
          ],
        ),
      ),
    ],
  );

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asistentes', style: _ts(24, fw: FontWeight.w800)),
            Text(
              'Lista de asistentes en tiempo real',
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
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
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

  // ── Estadísticas ────────────────────────────────────────────────────────────
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
        icon: Icons.people_alt_rounded,
        color: AppColors.sentryNavy,
        value: '$_total',
        label: 'Total\nentradas',
        ts: _ts,
      ),
    ],
  );

  // ── Filtros ─────────────────────────────────────────────────────────────────
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

  // ── Búsqueda ────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => TextField(
    controller: _searchCtrl,
    onChanged: (v) => setState(() => _query = v),
    style: _ts(14),
    decoration: InputDecoration(
      hintText: 'Buscar asistente...',
      hintStyle: _ts(14, color: AppColors.sentryGrey),
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.sentryGrey, size: 20),
      suffixIcon: _query.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.sentryGrey),
              onPressed: () => setState(() { _query = ''; _searchCtrl.clear(); }),
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

  // ── Encabezado de tabla ─────────────────────────────────────────────────────
  Widget _buildTableHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Expanded(
          child: Text('Asistente', style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey)),
        ),
        SizedBox(
          width: 84,
          child: Text('Email', style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey)),
        ),
        SizedBox(
          width: 40,
          child: Text('QR', textAlign: TextAlign.center, style: _ts(11, fw: FontWeight.w600, color: AppColors.sentryGrey)),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: AppColors.sentryGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _eventId == null ? 'No hay evento activo' : 'Sin resultados',
            style: _ts(16, fw: FontWeight.w600, color: AppColors.sentryGrey),
          ),
        ],
      ),
    ),
  );
}

// ── Tarjeta de estadística ────────────────────────────────────────────────────
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
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: ts(10, color: AppColors.sentryGrey)),
        ],
      ),
    ),
  );
}

// ── Tab de filtro ─────────────────────────────────────────────────────────────
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
            ? [BoxShadow(color: AppColors.sentryBlue.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
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
              color: active ? Colors.white.withValues(alpha: 0.25) : AppColors.sentryBg,
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

// ── Fila de asistente ─────────────────────────────────────────────────────────
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
    final accent = a.status == AttendeeStatus.entered ? AppColors.success : AppColors.sentryBlue;

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar + nombre + estado
            Expanded(
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: aColor.withValues(alpha: 0.15),
                        child: Text(
                          a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                          style: ts(13, fw: FontWeight.w700, color: aColor),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: ts(13, fw: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          a.status == AttendeeStatus.entered ? 'Ingresó' : 'Registrado',
                          style: ts(10, color: accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Email abreviado
            SizedBox(
              width: 84,
              child: Text(
                a.email.split('@').first,
                style: ts(11, color: AppColors.sentryGrey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Botón QR
            SizedBox(
              width: 40,
              child: Center(
                child: onQr != null
                    ? GestureDetector(
                        onTap: onQr,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.sentryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.qr_code_rounded, size: 16, color: AppColors.sentryBlue),
                        ),
                      )
                    : Icon(Icons.remove, size: 14, color: AppColors.sentryGrey.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
