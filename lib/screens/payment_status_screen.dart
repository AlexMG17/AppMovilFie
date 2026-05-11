import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart' show PaymentService, PagoModel;
import '../theme/app_colors.dart';
import 'my_qr_screen.dart';

class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({super.key});

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  PagoModel? _voucher;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await EventService.getCurrentUserId();
      final event = await EventService.getActiveEvent();
      if (uid == null || event == null) {
        setState(() {
          _loading = false;
          _error = 'No hay evento activo en este momento.';
        });
        return;
      }
      final voucher = await PaymentService.getMyPago(
        idUsuario: uid,
        idEvento: event.id,
      );
      setState(() {
        _voucher = voucher;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.sentryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estado del Pago',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              Text(
                'Seguimiento de tu comprobante',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.sentryBlue),
                )
              else if (_error != null)
                _buildErrorCard(_error!)
              else if (_voucher == null)
                _buildNoVoucherCard()
              else ...[
                _buildStatusBanner(_voucher!),
                const SizedBox(height: 25),
                _buildSectionTitle('Detalles del comprobante'),
                _buildDetailsCard(_voucher!),
                const SizedBox(height: 25),
                _buildSectionTitle('Seguimiento del proceso'),
                _buildTimeline(_voucher!),
                const SizedBox(height: 30),
                if (_voucher!.isApproved) _buildQrButton(context),
                if (_voucher!.isRejected) _buildRejectedActions(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.outfit(color: AppColors.sentryNavy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVoucherCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 56, color: AppColors.sentryGrey),
          const SizedBox(height: 16),
          Text(
            'Sin comprobante',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no has subido ningún comprobante de pago.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(PagoModel v) {
    final Color bg;
    final Color border;
    final Color iconBg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (v.isApproved) {
      bg = AppColors.success.withValues(alpha: 0.1);
      border = AppColors.success.withValues(alpha: 0.3);
      iconBg = AppColors.success;
      icon = Icons.check_rounded;
      title = 'Pago Aprobado';
      subtitle = 'Tu pago fue verificado. Tu código QR está disponible.';
    } else if (v.isRejected) {
      bg = AppColors.error.withValues(alpha: 0.1);
      border = AppColors.error.withValues(alpha: 0.3);
      iconBg = AppColors.error;
      icon = Icons.close_rounded;
      title = 'Pago Rechazado';
      subtitle = 'El administrador rechazó tu comprobante. Vuelve a subir uno.';
    } else {
      bg = AppColors.warning.withValues(alpha: 0.1);
      border = AppColors.warning.withValues(alpha: 0.3);
      iconBg = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
      title = 'En Revisión';
      subtitle = 'Tu comprobante está siendo verificado por el administrador.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconBg,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryGrey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(PagoModel v) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _detailRow('Evento', 'Gala FIE'),
          _detailRow('Monto', '\$5.00'),
          _detailRow('Método', 'Transferencia bancaria'),
          _detailRow(
            'Comprobante',
            v.comprobante != null && v.comprobante!.startsWith('http')
                ? 'Archivo subido ✓'
                : (v.comprobante ?? '—'),
          ),
          _detailRow(
            'Enviado',
            _formatDate(v.fechaPago),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(PagoModel v) {
    final steps = [
      (
        'Comprobante enviado',
        _formatDate(v.fechaPago),
        true,
      ),
      (
        'En revisión por administrador',
        v.isApproved || v.isRejected
            ? _formatDate(v.fechaPago.add(const Duration(minutes: 5)))
            : 'Pendiente',
        v.isApproved || v.isRejected,
      ),
      (
        v.isRejected ? 'Comprobante rechazado' : 'Pago aprobado',
        v.isApproved || v.isRejected
            ? _formatDate(v.fechaPago.add(const Duration(hours: 1)))
            : 'Pendiente',
        v.isApproved || v.isRejected,
      ),
      (
        'QR generado y disponible',
        v.isApproved
            ? _formatDate(v.fechaPago.add(const Duration(hours: 1, seconds: 30)))
            : 'Pendiente',
        v.isApproved,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: steps.asMap().entries.map((e) {
          final isLast = e.key == steps.length - 1;
          final (title, date, done) = e.value;
          return _timelineItem(title, date, done, isLast: isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildQrButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyQrScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(
          'Ver mi código QR',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildRejectedActions() {
    return Column(
      children: [
        Text(
          'Tu comprobante fue rechazado. Por favor sube uno nuevo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppColors.sentryGrey,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
            label: Text(
              'Subir nuevo comprobante',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sentryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );

  Widget _detailRow(String label, String value, {bool isLast = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: AppColors.sentryGrey, fontSize: 14)),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  Widget _timelineItem(String title, String subtitle, bool done,
          {bool isLast = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.success : AppColors.sentryGrey,
                size: 20,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: done
                      ? AppColors.success
                      : AppColors.sentryGrey.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ],
      );

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)} ${d.year}, '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) {
    const names = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return names[m];
  }
}
