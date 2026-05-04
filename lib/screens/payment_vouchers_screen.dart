import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

// ─── Modelo ────────────────────────────────────────────────────────────────
enum VoucherStatus { pending, approved, rejected }

class PaymentVoucher {
  final String id;
  final String name;
  final String career;
  final String reference;
  final DateTime date;
  VoucherStatus status;
  String? qrData;

  PaymentVoucher({
    required this.id,
    required this.name,
    required this.career,
    required this.reference,
    required this.date,
    this.status = VoucherStatus.pending,
    this.qrData,
  });
}

// ─── Datos simulados ────────────────────────────────────────────────────────
List<PaymentVoucher> _mockVouchers = [
  PaymentVoucher(id: '1', name: 'Carlos Mendoza Rivas', career: 'Ing. Sistemas',     reference: 'TRF-0931', date: DateTime(2026, 6, 14, 10, 32), status: VoucherStatus.pending),
  PaymentVoucher(id: '2', name: 'Ana Torres Guzmán',    career: 'Ing. Electrónica',  reference: 'TRF-0847', date: DateTime(2026, 6, 13, 15, 20), status: VoucherStatus.approved, qrData: 'SENTRY|Ana Torres Guzmán|TRF-0847'),
  PaymentVoucher(id: '3', name: 'Diego Flores Castillo', career: 'Ing. Telecom.',    reference: 'TRF-0799', date: DateTime(2026, 6, 13,  9, 15), status: VoucherStatus.rejected),
  PaymentVoucher(id: '4', name: 'Sofía Ramírez León',   career: 'Ing. Sistemas',     reference: 'TRF-0912', date: DateTime(2026, 6, 14,  8, 44), status: VoucherStatus.pending),
  PaymentVoucher(id: '5', name: 'Luis Cáceres Mora',    career: 'Ing. Electrónica',  reference: 'TRF-0823', date: DateTime(2026, 6, 12, 16,  5), status: VoucherStatus.approved, qrData: 'SENTRY|Luis Cáceres Mora|TRF-0823'),
  PaymentVoucher(id: '6', name: 'María Salinas Cruz',   career: 'Ing. Sistemas',     reference: 'TRF-0888', date: DateTime(2026, 6, 13, 11, 30), status: VoucherStatus.approved, qrData: 'SENTRY|María Salinas Cruz|TRF-0888'),
  PaymentVoucher(id: '7', name: 'Pedro Aguirre Vega',   career: 'Ing. Civil',        reference: 'TRF-0754', date: DateTime(2026, 6, 12,  9,  0), status: VoucherStatus.pending),
];

// ─── Screen ─────────────────────────────────────────────────────────────────
class PaymentVouchersScreen extends StatefulWidget {
  const PaymentVouchersScreen({super.key});
  @override
  State<PaymentVouchersScreen> createState() => _PaymentVouchersScreenState();
}

class _PaymentVouchersScreenState extends State<PaymentVouchersScreen> {
  VoucherStatus? _filter;          // null = Todos
  final _search = TextEditingController();
  String _query = '';

  List<PaymentVoucher> get _filtered {
    return _mockVouchers.where((v) {
      final matchStatus = _filter == null || v.status == _filter;
      final matchSearch = _query.isEmpty ||
          v.name.toLowerCase().contains(_query.toLowerCase()) ||
          v.reference.toLowerCase().contains(_query.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  int _count(VoucherStatus? s) =>
      s == null ? _mockVouchers.length : _mockVouchers.where((v) => v.status == s).length;

  // ── Helpers de texto ──────────────────────────────────────────
  TextStyle _ts(double sz, {FontWeight fw = FontWeight.w400, Color? color}) =>
      GoogleFonts.outfit(fontSize: sz, fontWeight: fw, color: color ?? AppColors.sentryNavy);

  // ── Chip de estado ────────────────────────────────────────────
  Widget _statusChip(VoucherStatus s) {
    final map = {
      VoucherStatus.pending:  (label: 'Pendiente',  bg: const Color(0xFFFFF3E0), fg: const Color(0xFFE65100)),
      VoucherStatus.approved: (label: 'Aprobado',   bg: const Color(0xFFE8F5E9), fg: const Color(0xFF2E7D32)),
      VoucherStatus.rejected: (label: 'Rechazado',  bg: const Color(0xFFFFEBEE), fg: const Color(0xFFC62828)),
    };
    final c = map[s]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(c.label, style: _ts(11, fw: FontWeight.w600, color: c.fg)),
    );
  }

  // ── Diálogo: ver comprobante ──────────────────────────────────
  void _showVoucher(PaymentVoucher v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Comprobante de Pago', style: _ts(18, fw: FontWeight.w700)),
          const SizedBox(height: 16),
          _detailRow('Asistente',  v.name),
          _detailRow('Carrera',    v.career),
          _detailRow('Referencia', '#${v.reference}'),
          _detailRow('Fecha',      '${v.date.day}/${v.date.month}/${v.date.year}  ${_pad(v.date.hour)}:${_pad(v.date.minute)}'),
          _detailRow('Estado',     v.status == VoucherStatus.pending ? 'Pendiente' : v.status == VoucherStatus.approved ? 'Aprobado' : 'Rechazado'),
          const SizedBox(height: 16),
          // imagen simulada del comprobante
          Container(
            width: double.infinity, height: 160,
            decoration: BoxDecoration(
              color: AppColors.sentryBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.image_outlined, size: 48, color: AppColors.sentryGrey),
              const SizedBox(height: 8),
              Text('Imagen del comprobante', style: _ts(12, color: AppColors.sentryGrey)),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: _ts(12, color: AppColors.sentryGrey))),
      Expanded(child: Text(value, style: _ts(13, fw: FontWeight.w600))),
    ]),
  );

  // ── Diálogo: ver QR ──────────────────────────────────────────
  void _showQr(PaymentVoucher v) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Código QR de Acceso', style: _ts(16, fw: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(v.name, style: _ts(13, color: AppColors.sentryGrey)),
            const SizedBox(height: 20),
            QrImageView(
              data: v.qrData ?? 'SENTRY|${v.name}|${v.reference}',
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(color: AppColors.sentryNavy, eyeShape: QrEyeShape.square),
              dataModuleStyle: const QrDataModuleStyle(color: AppColors.sentryBlue, dataModuleShape: QrDataModuleShape.square),
            ),
            const SizedBox(height: 12),
            Text('#${v.reference}', style: _ts(12, fw: FontWeight.w600, color: AppColors.sentryBlue)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sentryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cerrar', style: _ts(14, fw: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Aprobar ──────────────────────────────────────────────────
  void _approve(PaymentVoucher v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Aprobar comprobante', style: _ts(16, fw: FontWeight.w700)),
        content: Text('¿Confirmas la aprobación del pago de ${v.name}? Se generará un código QR de acceso.', style: _ts(13, color: AppColors.sentryGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: _ts(13, color: AppColors.sentryGrey))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                v.status  = VoucherStatus.approved;
                v.qrData  = 'SENTRY|${v.name}|${v.reference}|GALA-FIE-2026';
              });
              Navigator.pop(context);
              _showQr(v);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Aprobar', style: _ts(13, fw: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Rechazar ──────────────────────────────────────────────────
  void _reject(PaymentVoucher v) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rechazar comprobante', style: _ts(16, fw: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Indica el motivo del rechazo para ${v.name}:', style: _ts(13, color: AppColors.sentryGrey)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            style: _ts(13),
            decoration: InputDecoration(
              hintText: 'Ej. Comprobante ilegible...',
              hintStyle: _ts(13, color: AppColors.sentryGrey),
              filled: true, fillColor: AppColors.sentryBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: _ts(13, color: AppColors.sentryGrey))),
          ElevatedButton(
            onPressed: () { setState(() => v.status = VoucherStatus.rejected); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Rechazar', style: _ts(13, fw: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildSearch(),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                _buildSummaryRow(),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  _buildEmpty()
                else
                  ...list.map((v) => _VoucherCard(
                    voucher: v,
                    onView:    () => _showVoucher(v),
                    onApprove: () => _approve(v),
                    onReject:  () => _reject(v),
                    onQr:      () => _showQr(v),
                    ts: _ts,
                    statusChip: _statusChip(v.status),
                  )),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() => SliverAppBar(
    backgroundColor: AppColors.sentryBg,
    elevation: 0,
    pinned: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.sentryNavy),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Comprobantes de Pago', style: _ts(16, fw: FontWeight.w700)),
      Text('Gala FIE 2026', style: _ts(11, color: AppColors.sentryGrey)),
    ]),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('En vivo', style: _ts(10, fw: FontWeight.w600, color: AppColors.success)),
        ]),
      ),
    ],
  );

  // ── Search ────────────────────────────────────────────────────
  Widget _buildSearch() => TextField(
    controller: _search,
    onChanged: (v) => setState(() => _query = v),
    style: _ts(14),
    decoration: InputDecoration(
      hintText: 'Buscar por nombre o referencia...',
      hintStyle: _ts(14, color: AppColors.sentryGrey),
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.sentryGrey, size: 20),
      suffixIcon: _query.isNotEmpty
          ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.sentryGrey), onPressed: () => setState(() { _query = ''; _search.clear(); }))
          : null,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.sentryCyan, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  // ── Filtros ───────────────────────────────────────────────────
  Widget _buildFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      _filterChip(null,                     'Todos'),
      const SizedBox(width: 8),
      _filterChip(VoucherStatus.pending,    'Pendientes'),
      const SizedBox(width: 8),
      _filterChip(VoucherStatus.approved,   'Aprobados'),
      const SizedBox(width: 8),
      _filterChip(VoucherStatus.rejected,   'Rechazados'),
    ]),
  );

  Widget _filterChip(VoucherStatus? s, String label) {
    final active = _filter == s;
    final count  = _count(s);
    return GestureDetector(
      onTap: () => setState(() => _filter = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.sentryBlue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: active ? AppColors.sentryBlue : AppColors.cardBorder),
          boxShadow: active ? [BoxShadow(color: AppColors.sentryBlue.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(children: [
          Text(label, style: _ts(13, fw: FontWeight.w600, color: active ? Colors.white : AppColors.sentryNavy)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: active ? Colors.white.withValues(alpha: 0.25) : AppColors.sentryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count', style: _ts(11, fw: FontWeight.w700, color: active ? Colors.white : AppColors.sentryBlue)),
          ),
        ]),
      ),
    );
  }

  // ── Fila resumen ──────────────────────────────────────────────
  Widget _buildSummaryRow() => Row(children: [
    _summaryTile('Total',      '${_count(null)}',                          AppColors.sentryBlue),
    const SizedBox(width: 8),
    _summaryTile('Pendientes', '${_count(VoucherStatus.pending)}',         const Color(0xFFE65100)),
    const SizedBox(width: 8),
    _summaryTile('Aprobados',  '${_count(VoucherStatus.approved)}',        const Color(0xFF2E7D32)),
    const SizedBox(width: 8),
    _summaryTile('Rechazados', '${_count(VoucherStatus.rejected)}',        const Color(0xFFC62828)),
  ]);

  Widget _summaryTile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: [
        Text(value, style: _ts(20, fw: FontWeight.w800, color: color)),
        Text(label,  style: _ts(10, color: AppColors.sentryGrey)),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 64, color: AppColors.sentryGrey.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('Sin resultados', style: _ts(16, fw: FontWeight.w600, color: AppColors.sentryGrey)),
      ]),
    ),
  );

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ─── Tarjeta de comprobante ──────────────────────────────────────────────────
class _VoucherCard extends StatelessWidget {
  final PaymentVoucher voucher;
  final VoidCallback onView, onApprove, onReject, onQr;
  final TextStyle Function(double, {Color? color, FontWeight fw}) ts;
  final Widget statusChip;

  const _VoucherCard({
    required this.voucher,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onQr,
    required this.ts,
    required this.statusChip,
  });

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: AppColors.sentryNavy.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Fila superior ─────────────────────────────────────
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.sentryBlue.withValues(alpha: 0.12),
            child: Text(v.name[0], style: ts(16, fw: FontWeight.w700, color: AppColors.sentryBlue)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name,   style: ts(14, fw: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text(v.career, style: ts(11, color: AppColors.sentryGrey)),
          ])),
          statusChip,
        ]),

        const SizedBox(height: 12),
        Divider(color: AppColors.cardBorder, height: 1),
        const SizedBox(height: 12),

        // ── Fila de datos ─────────────────────────────────────
        Row(children: [
          _info(Icons.tag_rounded,            '#${v.reference}'),
          const SizedBox(width: 20),
          _info(Icons.calendar_today_outlined, '${v.date.day}/${v.date.month}/${v.date.year}'),
          const SizedBox(width: 20),
          _info(Icons.access_time_rounded,    '${v.date.hour.toString().padLeft(2,'0')}:${v.date.minute.toString().padLeft(2,'0')}'),
        ]),

        const SizedBox(height: 14),

        // ── Acciones ──────────────────────────────────────────
        Row(children: [
          // Ver comprobante
          _iconBtn(Icons.visibility_outlined, AppColors.sentryBlue, onView, 'Ver'),
          const SizedBox(width: 8),
          if (v.status == VoucherStatus.pending) ...[
            Expanded(child: _actionBtn('Aprobar',  const Color(0xFF2E7D32), Icons.check_rounded, onApprove)),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn('Rechazar', const Color(0xFFC62828), Icons.close_rounded,  onReject)),
          ] else if (v.status == VoucherStatus.approved)
            _iconBtn(Icons.qr_code_2_rounded, AppColors.sentryNavy, onQr, 'QR')
          else
            Text('Sin acciones disponibles', style: ts(11, color: AppColors.sentryGrey)),
        ]),
      ]),
    );
  }

  Widget _info(IconData icon, String text) => Row(children: [
    Icon(icon, size: 13, color: AppColors.sentryGrey),
    const SizedBox(width: 4),
    Text(text, style: ts(12, color: AppColors.sentryGrey)),
  ]);

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, String tooltip) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    ),
  );

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ),
  );
}
