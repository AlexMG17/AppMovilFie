import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  String? _codigoQr;
  String? _userName;
  String? _userEmail;
  String? _entradaEstado;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final user = SupabaseService.currentUser;
      _userEmail = user?.email ?? '';
      _userName = await EventService.getCurrentUserName() ?? _userEmail;

      final uid = await EventService.getCurrentUserId();
      final event = await EventService.getActiveEvent();

      if (uid == null || event == null) {
        setState(() {
          _loading = false;
          _message = 'No hay evento activo en este momento.';
        });
        return;
      }

      final entry = await PaymentService.getMyEntry(
        idUsuario: uid,
        idEvento: event.id,
      );

      if (entry == null) {
        setState(() {
          _loading = false;
          _message =
              'No tienes una entrada asignada. Verifica el estado de tu pago.';
        });
        return;
      }

      setState(() {
        _codigoQr = entry['codigo_qr'] as String?;
        _entradaEstado = entry['estado'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Error al cargar: ${e.toString()}';
      });
    }
  }

  void _copyCode() {
    if (_codigoQr == null) return;
    Clipboard.setData(ClipboardData(text: _codigoQr!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles'),
        backgroundColor: AppColors.sentryBlue,
        duration: Duration(seconds: 2),
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Código QR',
                        style: GoogleFonts.outfit(
                          color: AppColors.sentryNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        'Entrada al evento',
                        style: GoogleFonts.outfit(
                          color: AppColors.sentryGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  _statusBadge(
                    _codigoQr != null ? 'En línea' : 'Sin entrada',
                    _codigoQr != null ? AppColors.success : AppColors.sentryGrey,
                  ),
                ],
              ),
              const SizedBox(height: 25),

              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.sentryBlue),
                )
              else if (_message != null)
                _buildMessageCard(_message!)
              else ...[
                _buildQrMainCard(),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        'Copiar código',
                        Icons.copy_rounded,
                        AppColors.sentryBlue,
                        _copyCode,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _actionButton(
                        'Actualizar',
                        Icons.refresh_rounded,
                        AppColors.sentryGrey,
                        _load,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildInfoNotice(),
                const SizedBox(height: 25),
                Text(
                  '¿Cómo usarlo?',
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                _stepItem(1, 'Llega al punto de ingreso del evento'),
                _stepItem(2, 'Muestra esta pantalla al guardia'),
                _stepItem(3, 'El guardia escaneará el código con Sentry'),
                _stepItem(4, 'Recibirás confirmación de acceso'),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2_rounded,
              size: 56, color: AppColors.sentryGrey),
          const SizedBox(height: 16),
          Text(
            'QR no disponible',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            msg,
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

  Widget _buildQrMainCard() {
    final isUsed = _entradaEstado == 'usado';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.sentryBlue,
                radius: 22,
                child: Text(
                  _userName?.isNotEmpty == true
                      ? _userName![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'Usuario',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _userEmail ?? '',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(
                isUsed ? 'Usado' : 'Válido',
                isUsed ? AppColors.warning : AppColors.sentryBlue,
              ),
            ],
          ),
          const Divider(height: 30, color: AppColors.divider),

          // QR Code
          if (isUsed)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.sentryBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: AppColors.success),
                  const SizedBox(height: 8),
                  Text(
                    'Entrada utilizada',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Este QR ya fue escaneado en el evento.',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.sentryBg, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: _codigoQr!,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.sentryNavy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.sentryNavy,
                ),
              ),
            ),

          const SizedBox(height: 15),
          if (!isUsed)
            Text(
              'Toca para ampliar',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),

          _qrDataRow(
            'Código único',
            _codigoQr != null
                ? '${_codigoQr!.substring(0, _codigoQr!.length.clamp(0, 16))}...'
                : '—',
          ),
          _qrDataRow('Estado', _entradaEstado ?? '—'),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _qrDataRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: AppColors.sentryGrey, fontSize: 13)),
            Text(
              val,
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _actionButton(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _buildInfoNotice() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.sentryNavy.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: AppColors.sentryNavy.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined,
                color: AppColors.sentryNavy, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este QR es personal e intransferible. El sistema detecta y rechaza usos duplicados automáticamente.',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _stepItem(int num, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.sentryBlue,
              child: Text(
                '$num',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
}
