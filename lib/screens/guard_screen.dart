import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/event_service.dart';
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
  // ── Paleta Sentry ───────────────────────────────────────────
  static const Color sentryDarkBg = AppColors.sentryBg; // Fondo claro
  static const Color sentryDarkCard = Color(0xFFFFFFFF); // Tarjeta blanca
  static const Color sentrySuccess = Color(0xFF00E676);
  static const Color sentryError = Color(0xFFFF5252);
  static const Color sentryWarning = Color(0xFFFFCA28);
  // ────────────────────────────────────────────────────────────

  final TextEditingController _manualCodeController = TextEditingController();
  MobileScannerController? _scannerController;

  int? _guardId;
  int? _eventoId;
  bool _isInitializing = true;
  final bool _isCameraActive = true;
  bool _isProcessingScan = false;
  String _userName = '';

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
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await EventService.getCurrentUserName();
    if (mounted) {
      setState(
        () => _userName = name ?? SupabaseService.currentUser?.email ?? '',
      );
    }
  }

  Future<void> _initializeGuard() async {
    try {
      final results = await Future.wait([
        GuardService.getCurrentGuardId(),
        EventService.getActiveEvent(),
      ]);
      final guardId = results[0] as int?;
      final event = results[1] as dynamic;
      if (guardId != null) {
        _guardId = guardId;
        await _refreshData();
      }
      if (event != null) _eventoId = event.id as int?;
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
    if (_isProcessingScan || _lastScanResult != null) return;

    setState(() => _isProcessingScan = true);

    final result = await GuardService.validateQR(
      codigoQR: code,
      idGuardia: _guardId,
      idEvento: _eventoId,
    );

    // Vibración según resultado y ACTUALIZACIÓN A SUPABASE
    if (result.resultado == 'valido') {
      HapticFeedback.heavyImpact();

      // 🔥 LA MAGIA EN TIEMPO REAL 🔥
      // Le decimos a Supabase que este código ha sido USADO exitosamente
      // Esto disparará la señal al celular del estudiante para ocultar su QR
      try {
        await SupabaseService.client
            .from('entradas')
            .update({'estado': 'usado'})
            .eq('codigo_qr', code);
      } catch (e) {
        debugPrint("Error actualizando estado a usado en BD: $e");
      }
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

  Future<void> _confirmUndoScan(ScanResult scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Deshacer entrada?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se revertirá el ingreso de ${scan.nombreAsistente}. '
          'El asistente ya no quedará marcado como dentro del evento.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sentryWarning),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Deshacer',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && scan.codigoQR != null && mounted) {
      final ok = await GuardService.undoEntry(codigoQR: scan.codigoQR!);

      if (ok) {
        // 🔥 MAGIA INVERSA 🔥
        // Si el guardia deshace la entrada, el QR vuelve a estar "activo"
        // para que al estudiante le reaparezca en su celular.
        try {
          await SupabaseService.client
              .from('entradas')
              .update({'estado': 'activo'})
              .eq('codigo_qr', scan.codigoQR!);
        } catch (e) {
          debugPrint("Error revirtiendo estado a activo en BD: $e");
        }
      }

      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Entrada de ${scan.nombreAsistente} revertida.'
                  : 'No se pudo revertir. Intenta de nuevo.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: ok ? sentryWarning : sentryError,
          ),
        );
      }
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
              SizedBox(height: 16.h),
              Text(
                'Inicializando validador...',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey,
                  fontSize: 14.sp,
                ),
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
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    SizedBox(height: 12.h),
                    _buildCameraSection(),
                    SizedBox(height: 16.h),
                    _buildManualInput(),
                    SizedBox(height: 20.h),
                    _buildRecentScans(),
                    SizedBox(height: 20.h),
                    _buildStatsSection(),
                    SizedBox(height: 24.h),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: sentryDarkCard,
        border: Border(
          bottom: BorderSide(
            color: AppColors.sentryCyan.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40.w,
            height: 40.w,
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
          SizedBox(width: 10.w),
          // Título
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Sentry',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryNavy,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sentryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Validador',
                      style: GoogleFonts.outfit(
                        color: AppColors.sentryCyan,
                        fontSize: 11.sp,
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
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: sentrySuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: sentrySuccess.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.w,
                  height: 7.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: sentrySuccess,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(
                  'Activo',
                  style: GoogleFonts.outfit(
                    color: sentrySuccess,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await SupabaseService.signOut();
                } catch (_) {}
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.sentryCyan,
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      SupabaseService.currentUser?.email ?? '',
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey),
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
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sección de cámara / QR Scanner ────────────────────────────

  Widget _buildCameraSection() {
    return Container(
      width: double.infinity,
      height: 280.h,
      decoration: BoxDecoration(
        color: sentryDarkCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.sentryCyan.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Apunta la cámara al QR del asistente',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12.sp,
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
              color: AppColors.sentryGrey.withValues(alpha: 0.5),
              size: 48.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Cámara no disponible',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Usa el ingreso manual',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey.withValues(alpha: 0.6),
                fontSize: 11.sp,
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
          width: 180.w,
          height: 180.w,
          child: CustomPaint(
            painter: _ScanFramePainter(color: AppColors.sentryCyan),
          ),
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
        bgColor = sentrySuccess.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.check_circle;
        title = 'ACCESO PERMITIDO';
        break;
      case 'ya_adentro':
        bgColor = sentryWarning.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.person_pin_circle_rounded;
        title = 'YA ESTÁ ADENTRO';
        break;
      case 'expirado':
        bgColor = sentryWarning.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.timer_off_rounded;
        title = 'QR EXPIRADO';
        break;
      case 'evento_incorrecto':
        bgColor = sentryError.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.event_busy_rounded;
        title = 'EVENTO INCORRECTO';
        break;
      default:
        bgColor = sentryError.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.cancel;
        title = 'ACCESO DENEGADO';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (mounted) {
          setState(() => _lastScanResult = null);
        }
      },
      child: ScaleTransition(
        scale: _resultScaleAnim,
        child: Container(
          color: bgColor,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 64.sp),
                SizedBox(height: 12.h),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  result.nombreAsistente,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16.sp,
                  ),
                ),
                if (result.razon != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    result.razon!,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
                if (result.resultado == 'valido' &&
                    result.codigoQR != null) ...[
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: () async {
                      await GuardService.undoEntry(codigoQR: result.codigoQR!);

                      // Magia inversa: Al deshacer, vuelve a estado activo
                      try {
                        await SupabaseService.client
                            .from('entradas')
                            .update({'estado': 'activo'})
                            .eq('codigo_qr', result.codigoQR!);
                      } catch (e) {
                        debugPrint("Error revirtiendo: $e");
                      }

                      await _refreshData();
                      if (mounted) setState(() => _lastScanResult = null);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.undo_rounded,
                            color: Colors.white70,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Deshacer entrada',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            'Ingreso manual del código',
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: sentryDarkCard,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.sentryCyan.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _manualCodeController,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontSize: 14.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pegar o escribir código QR...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppColors.sentryGrey.withValues(alpha: 0.5),
                      fontSize: 13.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                  onSubmitted: (_) => _handleManualCode(),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            GestureDetector(
              onTap: _handleManualCode,
              child: Container(
                height: 48.h,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.sentryBlue, AppColors.sentryCyan],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sentryCyan.withValues(alpha: 0.3),
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
                      fontSize: 14.sp,
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
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text(
            'Escaneos recientes',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_recentScans.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              color: sentryDarkCard,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.sentryCyan.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'Aún no hay escaneos registrados',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey,
                  fontSize: 13.sp,
                ),
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
      case 'expirado':
        statusColor = sentryWarning;
        statusIcon = Icons.timer_off_rounded;
        break;
      case 'evento_incorrecto':
        statusColor = sentryError;
        statusIcon = Icons.event_busy_rounded;
        break;
      default:
        statusColor = sentryError;
        statusIcon = Icons.cancel;
    }

    final timeStr =
        '${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: sentryDarkCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icono de estado
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.nombreAsistente,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontSize: 14.sp,
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
                      color: AppColors.sentryGrey.withValues(alpha: 0.6),
                      fontSize: 11.sp,
                    ),
                  ),
              ],
            ),
          ),
          // Hora
          Text(
            timeStr,
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 12.sp,
            ),
          ),
          if (scan.resultado == 'valido' && scan.codigoQR != null) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => _confirmUndoScan(scan),
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: sentryWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.undo_rounded,
                  color: sentryWarning,
                  size: 16.sp,
                ),
              ),
            ),
          ],
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
        SizedBox(width: 10.w),
        _buildStatCard(
          value: _stats.invalidos.toString(),
          label: 'Inválidos',
          color: sentryError,
          icon: Icons.block_rounded,
        ),
        SizedBox(width: 10.w),
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
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: sentryDarkCard,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 11.sp,
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
