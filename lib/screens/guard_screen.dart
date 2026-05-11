import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/guard_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class GuardScreen extends StatefulWidget {
  const GuardScreen({super.key});

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen>
    with TickerProviderStateMixin {
  // ── Paleta Sentry (extendida para tema oscuro) ──────────────
  static const Color sentryDarkBg = Color(0xFF0A1628);
  static const Color sentryDarkCard = Color(0xFF122240);
  static const Color sentrySuccess = Color(0xFF00E676);
  static const Color sentryError = Color(0xFFFF5252);
  static const Color sentryWarning = Color(0xFFFFCA28);
  // ────────────────────────────────────────────────────────────

  final TextEditingController _manualCodeController = TextEditingController();
  MobileScannerController? _scannerController;

  int? _guardId;
  bool _isInitializing = true;
  final bool _isCameraActive = true;
  bool _isProcessingScan = false;

  // Estado del último escaneo
  ScanResult? _lastScanResult;

  // Historial y estadísticas
  List<ScanResult> _recentScans = [];
  ScanStats _stats = ScanStats(ingresados: 0, invalidos: 0, usados: 0);

  // Animaciones
  late AnimationController _resultAnimController;
  late Animation<double> _resultScaleAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultScaleAnim = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.elasticOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeGuard();
  }

  Future<void> _initializeGuard() async {
    try {
      final guardId = await GuardService.getCurrentGuardId();
      if (guardId != null) {
        _guardId = guardId;
        await _refreshData();
      }
    } catch (_) {
      // Sin conexión Supabase — modo demo activo
    }
    if (mounted) {
      setState(() => _isInitializing = false);
      _initCamera();
    }
  }

  void _initCamera() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  Future<void> _refreshData() async {
    if (_guardId == null) return;
    final scans = await GuardService.getRecentScans(idGuardia: _guardId!);
    final stats = await GuardService.getStats(idGuardia: _guardId!);
    if (mounted) {
      setState(() {
        _recentScans = scans;
        _stats = stats;
      });
    }
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    _pulseController.dispose();
    _manualCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── Manejar escaneo de QR ───────────────────────────────────

  Future<void> _handleScan(String code) async {
    if (_isProcessingScan) return;

    setState(() => _isProcessingScan = true);

    final result = await GuardService.validateQR(
      codigoQR: code,
      idGuardia: _guardId,
    );

    // Vibración según resultado
    if (result.resultado == 'valido') {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _lastScanResult = result;
      _isProcessingScan = false;
    });

    _resultAnimController.reset();
    _resultAnimController.forward();

    // Refrescar datos
    await _refreshData();

    // Limpiar resultado después de 4 segundos
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(() => _lastScanResult = null);
    }
  }

  void _handleManualCode() {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) return;
    _manualCodeController.clear();
    FocusScope.of(context).unfocus();
    _handleScan(code);
  }

  // ── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: sentryDarkBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.sentryCyan),
              const SizedBox(height: 16),
              Text(
                'Inicializando validador...',
                style: GoogleFonts.outfit(color: AppColors.sentryGrey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: sentryDarkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildCameraSection(),
                    const SizedBox(height: 16),
                    _buildManualInput(),
                    const SizedBox(height: 20),
                    _buildRecentScans(),
                    const SizedBox(height: 20),
                    _buildStatsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: sentryDarkCard,
        border: Border(
          bottom: BorderSide(color: AppColors.sentryCyan.withValues(alpha:0.15), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          // Título
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Sentry',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sentryCyan.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Validador',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Indicador de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sentrySuccess.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sentrySuccess.withValues(alpha:0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: sentrySuccess,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Activo',
                  style: GoogleFonts.outfit(
                    color: sentrySuccess,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Botón de cerrar sesión
          IconButton(
            onPressed: () async {
              try {
                await SupabaseService.signOut();
              } catch (_) {}
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: sentryError,
              size: 24,
            ),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }

  // ── Sección de cámara / QR Scanner ────────────────────────────

  Widget _buildCameraSection() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: sentryDarkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sentryCyan.withValues(alpha:0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Cámara/Scanner
            if (_isCameraActive && _scannerController != null)
              MobileScanner(
                controller: _scannerController!,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _handleScan(barcode.rawValue!);
                      break;
                    }
                  }
                },
                errorBuilder: (context, error) {
                  return _buildCameraFallback();
                },
              )
            else
              _buildCameraFallback(),

            // Marco de escaneo animado
            if (_lastScanResult == null) _buildScanFrame(),

            // Overlay de resultado
            if (_lastScanResult != null) _buildResultOverlay(),

            // Texto inferior
            if (_lastScanResult == null)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Apunta la cámara al QR del asistente',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

            // Loading overlay
            if (_isProcessingScan)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.sentryCyan),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFallback() {
    return Container(
      color: sentryDarkBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: AppColors.sentryGrey.withValues(alpha:0.5),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'Cámara no disponible',
              style: GoogleFonts.outfit(color: AppColors.sentryGrey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Usa el ingreso manual',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey.withValues(alpha:0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnim.value, child: child);
        },
        child: SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: _ScanFramePainter(color: AppColors.sentryCyan)),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final result = _lastScanResult!;
    Color bgColor;
    Color iconColor;
    IconData icon;
    String title;

    switch (result.resultado) {
      case 'valido':
        bgColor = sentrySuccess.withValues(alpha:0.9);
        iconColor = Colors.white;
        icon = Icons.check_circle;
        title = 'ACCESO PERMITIDO';
        break;
      case 'usado':
        bgColor = sentryWarning.withValues(alpha:0.9);
        iconColor = Colors.white;
        icon = Icons.warning_rounded;
        title = 'YA UTILIZADO';
        break;
      default:
        bgColor = sentryError.withValues(alpha:0.9);
        iconColor = Colors.white;
        icon = Icons.cancel;
        title = 'ACCESO DENEGADO';
    }

    return ScaleTransition(
      scale: _resultScaleAnim,
      child: Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 64),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.nombreAsistente,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha:0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ingreso manual ────────────────────────────────────────────

  Widget _buildManualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Ingreso manual del código',
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: sentryDarkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.sentryCyan.withValues(alpha:0.15),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _manualCodeController,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Pegar o escribir código QR...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppColors.sentryGrey.withValues(alpha:0.5),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _handleManualCode(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _handleManualCode,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.sentryBlue, AppColors.sentryCyan],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sentryCyan.withValues(alpha:0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Validar',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Escaneos recientes ────────────────────────────────────────

  Widget _buildRecentScans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Escaneos recientes',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_recentScans.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: sentryDarkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sentryCyan.withValues(alpha:0.08), width: 1),
            ),
            child: Center(
              child: Text(
                'Aún no hay escaneos registrados',
                style: GoogleFonts.outfit(color: AppColors.sentryGrey, fontSize: 13),
              ),
            ),
          )
        else
          ...(_recentScans.take(5).map((scan) => _buildScanTile(scan))),
      ],
    );
  }

  Widget _buildScanTile(ScanResult scan) {
    Color statusColor;
    IconData statusIcon;

    switch (scan.resultado) {
      case 'valido':
        statusColor = sentrySuccess;
        statusIcon = Icons.check_circle;
        break;
      case 'usado':
        statusColor = sentryWarning;
        statusIcon = Icons.warning_rounded;
        break;
      default:
        statusColor = sentryError;
        statusIcon = Icons.cancel;
    }

    final timeStr =
        '${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sentryDarkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha:0.15), width: 1),
      ),
      child: Row(
        children: [
          // Icono de estado
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha:0.15),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.nombreAsistente,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (scan.codigoQR != null)
                  Text(
                    scan.codigoQR!.length > 20
                        ? '${scan.codigoQR!.substring(0, 20)}...'
                        : scan.codigoQR!,
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryGrey.withValues(alpha:0.6),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Hora
          Text(
            timeStr,
            style: GoogleFonts.outfit(color: AppColors.sentryGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Estadísticas ──────────────────────────────────────────────

  Widget _buildStatsSection() {
    return Row(
      children: [
        _buildStatCard(
          value: _stats.ingresados.toString(),
          label: 'Ingresaron',
          color: sentrySuccess,
          icon: Icons.login_rounded,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          value: _stats.invalidos.toString(),
          label: 'Inválidos',
          color: sentryError,
          icon: Icons.block_rounded,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          value: _stats.usados.toString(),
          label: 'Usados',
          color: sentryWarning,
          icon: Icons.replay_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sentryDarkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha:0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom painter para el marco de escaneo ─────────────────────

class _ScanFramePainter extends CustomPainter {
  final Color color;
  _ScanFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    const radius = 12.0;

    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(cornerLength, size.height),
      paint,
    );

    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - radius,
        )
        ..lineTo(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
