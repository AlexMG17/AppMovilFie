import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart';
import '../services/qr_cache_service.dart';
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
  DateTime? _expiresAt;
  int _versionQr = 1;

  bool _loading = true;
  bool _isOffline = false;
  bool _syncing = false;
  String? _message;
  DateTime? _cachedAt;

  bool get _isExpired =>
      _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  @override
  void initState() {
    super.initState();
    _loadWithCache();
  }

  Future<void> _loadWithCache() async {
    setState(() {
      _loading = true;
      _message = null;
      _isOffline = false;
    });

    final userId = SupabaseService.currentUser?.id ?? '';

    // ── Paso 1: mostrar caché inmediatamente ──────────────────────────────
    final cached = await QrCacheService.load(userId);
    if (cached != null && cached.codigoQr.isNotEmpty) {
      setState(() {
        _codigoQr = cached.codigoQr;
        _entradaEstado = cached.estado;
        _userName = cached.userName;
        _userEmail = cached.userEmail;
        _cachedAt = cached.cachedAt;
        _expiresAt = cached.expiresAt;
        _versionQr = cached.versionQr;
        _loading = false;
        _isOffline = true;
        _syncing = true;
      });
    }

    // ── Paso 2: intentar sincronizar con Supabase ─────────────────────────
    try {
      final user = SupabaseService.currentUser;
      final freshEmail = user?.email ?? '';
      final freshName =
          await EventService.getCurrentUserName() ?? freshEmail;
      final uid = await EventService.getCurrentUserId();
      final event = await EventService.getActiveEvent();

      if (uid == null || event == null) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _loading = false;
          if (_codigoQr == null) {
            _message = 'No hay evento activo en este momento.';
          }
        });
        return;
      }

      final entry = await PaymentService.getMyEntry(
        idUsuario: uid,
        idEvento: event.id,
      );

      if (entry == null) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _loading = false;
          if (_codigoQr == null) {
            _message =
                'No tienes una entrada asignada.\nVerifica el estado de tu pago.';
          }
        });
        return;
      }

      final newQr = entry['codigo_qr'] as String? ?? '';
      final newEstado = entry['estado'] as String? ?? 'activo';
      final newExpiresAt = entry['fecha_expiracion'] != null
          ? DateTime.tryParse(entry['fecha_expiracion'].toString())
          : null;
      final newVersion = entry['version_qr'] as int? ?? 1;
      final now = DateTime.now();

      await QrCacheService.save(
        userId: userId,
        data: QrCacheData(
          codigoQr: newQr,
          estado: newEstado,
          userName: freshName,
          userEmail: freshEmail,
          eventId: event.id,
          cachedAt: now,
          expiresAt: newExpiresAt,
          versionQr: newVersion,
        ),
      );

      if (!mounted) return;
      setState(() {
        _codigoQr = newQr;
        _entradaEstado = newEstado;
        _expiresAt = newExpiresAt;
        _versionQr = newVersion;
        _userName = freshName;
        _userEmail = freshEmail;
        _cachedAt = now;
        _loading = false;
        _isOffline = false;
        _syncing = false;
      });
    } catch (_) {
      // Sin red — si ya teníamos caché lo seguimos mostrando
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _loading = false;
        if (_codigoQr == null) {
          _message =
              'Sin conexión a internet y no hay QR guardado en este dispositivo.';
        }
        // _isOffline ya es true desde que cargamos caché
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: RefreshIndicator(
        onRefresh: _loadWithCache,
        color: AppColors.sentryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
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
                  _statusBadge(),
                ],
              ),

              // ── Banner offline ────────────────────────────────────────
              if (_isOffline && _codigoQr != null) ...[
                const SizedBox(height: 14),
                _offlineBanner(),
              ],

              const SizedBox(height: 25),

              // ── Contenido principal ───────────────────────────────────
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(
                        color: AppColors.sentryBlue),
                  ),
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
                        _syncing ? 'Sincronizando…' : 'Actualizar',
                        _syncing
                            ? Icons.sync_rounded
                            : Icons.refresh_rounded,
                        AppColors.sentryGrey,
                        _syncing ? () {} : _loadWithCache,
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

  // ── Banner de modo offline ──────────────────────────────────────────────

  Widget _offlineBanner() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo sin conexión',
                    style: GoogleFonts.outfit(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (_cachedAt != null)
                    Text(
                      'Guardado ${_timeAgo(_cachedAt!)} · desliza para intentar actualizar',
                      style: GoogleFonts.outfit(
                        color: AppColors.warning.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (_syncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
      );

  // ── Badge de estado superior ────────────────────────────────────────────

  Widget _statusBadge() {
    if (_isOffline && _codigoQr != null) {
      return _badge('Sin conexión', AppColors.warning);
    }
    if (_codigoQr != null) return _badge('En línea', AppColors.success);
    return _badge('Sin entrada', AppColors.sentryGrey);
  }

  Widget _badge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // ── Tarjeta principal del QR ────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
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
          // Info del usuario
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
              _entradaStatusChip(isUsed),
            ],
          ),

          const Divider(height: 30, color: AppColors.divider),

          // QR, expirado o ya usado
          if (isUsed)
            _buildStatusCard(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              title: 'Entrada utilizada',
              subtitle: 'Este QR ya fue escaneado en el evento.',
            )
          else if (_isExpired)
            _buildStatusCard(
              icon: Icons.timer_off_rounded,
              color: AppColors.warning,
              title: 'QR Expirado',
              subtitle: _expiresAt != null
                  ? 'Venció el ${_formatDate(_expiresAt!)}. Contacta al administrador.'
                  : 'Este QR ya no es válido.',
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
          if (!isUsed && !_isExpired)
            Text(
              'Muestra este código al entrar al evento',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),

          _qrDataRow(
            'Código',
            _codigoQr != null
                ? '${_codigoQr!.substring(0, _codigoQr!.length.clamp(0, 16))}…'
                : '—',
          ),
          _qrDataRow('Estado', _entradaEstado ?? '—'),
          _qrDataRow('Versión', 'v$_versionQr'),
          if (_expiresAt != null)
            _qrDataRow('Expira', _formatDate(_expiresAt!)),
          if (_cachedAt != null)
            _qrDataRow('Última sync', _timeAgo(_cachedAt!)),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _entradaStatusChip(bool isUsed) {
    final Color color;
    final String label;
    if (isUsed) {
      color = AppColors.warning;
      label = 'Usado';
    } else if (_isExpired) {
      color = AppColors.warning;
      label = 'Expirado';
    } else {
      color = AppColors.sentryBlue;
      label = 'Válido';
    }
    return Container(
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
  }

  // ── Tarjeta de mensaje (sin QR) ─────────────────────────────────────────

  Widget _buildMessageCard(String msg) => Container(
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadWithCache,
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                'Reintentar',
                style:
                    GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sentryBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );

  // ── Helpers ─────────────────────────────────────────────────────────────

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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
