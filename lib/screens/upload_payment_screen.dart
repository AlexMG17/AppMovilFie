import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/event_service.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class UploadPaymentScreen extends StatefulWidget {
  const UploadPaymentScreen({super.key});

  @override
  State<UploadPaymentScreen> createState() => _UploadPaymentScreenState();
}

class _UploadPaymentScreenState extends State<UploadPaymentScreen> {
  PlatformFile? _pickedFile;
  bool _isUploading = false;
  bool _isLoadingData = true;
  bool _alreadySubmitted = false;
  PagoModel? _pago;
  bool _hasActiveEntry = false;
  bool _isExcelPending = false;
  final _referenceController = TextEditingController();

  bool get _isPreApproved =>
      _hasActiveEntry ||
      _pago?.isPreApproved == true ||
      _pago?.isApproved == true;

  int? _userId;
  int? _eventId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = await EventService.getCurrentUserId();
    final event = await EventService.getActiveEvent();
    if (!mounted) return;

    setState(() {
      _userId = uid;
      _eventId = event?.id;
    });

    if (uid != null && event != null) {
      final results = await Future.wait([
        PaymentService.getMyPago(idUsuario: uid, idEvento: event.id),
        PaymentService.getMyEntry(idUsuario: uid, idEvento: event.id),
      ]);
      if (!mounted) return;
      final pago = results[0] as PagoModel?;
      final entry = results[1] as Map<String, dynamic>?;

      bool excelPending = false;
      if (pago == null && entry == null) {
        final email = SupabaseService.currentUser?.email;
        if (email != null) {
          final inList = await SupabaseService.client
              .from('listado_estudiantes')
              .select('id_detalle')
              .eq('correo_electronico', email)
              .limit(1)
              .maybeSingle();
          if (!mounted) return;
          excelPending = inList != null;
        }
      }

      setState(() {
        _hasActiveEntry = entry != null;
        _isExcelPending = excelPending;
        _isLoadingData = false;
        if (pago != null) {
          _pago = pago;
          if (pago.isPending) _alreadySubmitted = true;
        }
      });
    } else {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _handleSubmit() async {
    if (_pickedFile == null) {
      _showSnack('Selecciona un comprobante primero.', isError: true);
      return;
    }
    if (_referenceController.text.trim().isEmpty) {
      _showSnack('Ingresa el número de referencia.', isError: true);
      return;
    }
    if (_userId == null || _eventId == null) {
      _showSnack('No hay evento activo en este momento.', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Intentar subir el archivo a Supabase Storage
      String comprobante = _referenceController.text.trim();
      final path = _pickedFile?.path;
      if (path != null) {
        final url = await PaymentService.uploadVoucher(
          filePath: path,
          fileName: _pickedFile!.name,
          userId: _userId!,
        );
        comprobante = url;
      }

      await PaymentService.submitPago(
        idUsuario: _userId!,
        idEvento: _eventId!,
        comprobante: comprobante,
      );

      if (mounted) {
        setState(() => _alreadySubmitted = true);
        _showSnack('¡Comprobante enviado! Recibirás una notificación.');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cargar Comprobante',
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontWeight: FontWeight.w800,
                fontSize: 24.sp,
              ),
            ),
            Text(
              'Sube tu comprobante de pago',
              style: GoogleFonts.outfit(
                color: AppColors.sentryGrey,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 25.h),

            if (_isLoadingData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: CircularProgressIndicator(color: AppColors.sentryBlue),
                ),
              )

            // Estudiante viene del Excel → entrada ya generada
            else if (_isPreApproved) ...[
              _buildPreApprovedBanner(),
              const SizedBox(height: 100),
            ]

            // Estudiante del Excel que aún no fue a "Mi QR"
            else if (_isExcelPending) ...[
              _buildExcelPendingBanner(),
              const SizedBox(height: 100),
            ]

            // Sin evento activo
            else if (_eventId == null) ...[
              Container(
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
                        'No hay evento activo en este momento.',
                        style: GoogleFonts.outfit(color: AppColors.sentryNavy),
                      ),
                    ),
                  ],
                ),
              ),
            ]

            // Flujo normal de comprobante
            else ...[
              if (_alreadySubmitted) _buildAlreadySubmittedBanner(),
              if (!_alreadySubmitted) ...[
                _buildInfoCard(),
                const SizedBox(height: 20),
              ],
              _buildBankDetails(),
              const SizedBox(height: 20),
              _buildUploadArea(),
              if (_pickedFile != null) ...[
                const SizedBox(height: 16),
                _buildFilePreview(),
              ],
              const SizedBox(height: 16),
              _buildReferenceField(),
              const SizedBox(height: 30),
              if (!_alreadySubmitted) _buildSubmitButton(),
              if (_alreadySubmitted) _buildResubmitButton(),
              const SizedBox(height: 100),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreApprovedBanner() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48.sp),
          SizedBox(height: 14.h),
          Text(
            'Tu entrada fue generada automáticamente',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Tu pago fue registrado por secretaría al momento de pagar tu matrícula. No necesitas subir ningún comprobante.',
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 13.sp,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Ve a "Mi QR" para ver tu código de entrada',
                  style: GoogleFonts.outfit(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
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

  Widget _buildExcelPendingBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8F00).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8F00).withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_rounded,
              color: Color(0xFFFF8F00), size: 48),
          const SizedBox(height: 14),
          Text(
            'Estás en la lista oficial de invitados',
            style: GoogleFonts.outfit(
              color: AppColors.sentryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tu acceso fue pre-aprobado. No necesitas subir ningún comprobante.',
            style: GoogleFonts.outfit(
              color: AppColors.sentryGrey,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_rounded,
                    color: Color(0xFFFF8F00), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Ve a "Mi QR" para generar tu código de acceso',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF8F00),
                    fontWeight: FontWeight.w600,
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

  Widget _buildAlreadySubmittedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ya tienes un comprobante en revisión. Puedes reenviar uno nuevo si hubo un error.',
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sentryCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sentryCyan.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.sentryCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Realiza tu depósito o transferencia de \$5.00 a la cuenta de la FIE y sube aquí el comprobante para verificación.',
              style: GoogleFonts.outfit(
                color: AppColors.sentryNavy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: AppColors.sentryBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Datos para transferencia',
                style: GoogleFonts.outfit(
                  color: AppColors.sentryNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.divider),
          _bankRow('Banco', 'Banco Pichincha'),
          _bankRow('Tipo', 'Cuenta de Ahorros'),
          _bankRow('Número', '2208154670'),
          _bankRow('Beneficiario', 'FIE ESPOCH'),
          _bankRow('Monto', '\$5.00', highlight: true),
        ],
      ),
    );
  }

  Widget _bankRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  color: AppColors.sentryGrey, fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: highlight ? AppColors.sentryBlue : AppColors.sentryNavy,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    final picked = _pickedFile != null;
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        height: 140.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: picked
                ? AppColors.success
                : AppColors.sentryGrey.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: picked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _pickedFile!.name,
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Toca para cambiar',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.sentryGrey.withValues(alpha: 0.7),
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Seleccionar imagen o PDF',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'JPG, PNG o PDF · Max. 5 MB',
                    style: GoogleFonts.outfit(
                      color: AppColors.sentryGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.sentryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_rounded,
                color: AppColors.sentryBlue, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedFile!.name,
                  style: GoogleFonts.outfit(
                    color: AppColors.sentryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB · Listo para enviar',
                  style: GoogleFonts.outfit(
                    color: AppColors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.sentryGrey, size: 20),
            onPressed: () => setState(() => _pickedFile = null),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Número de referencia',
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _referenceController,
          style: GoogleFonts.outfit(color: AppColors.sentryNavy),
          decoration: InputDecoration(
            hintText: 'Ej. TRF-20260614-0931',
            hintStyle: GoogleFonts.outfit(color: AppColors.sentryGrey),
            prefixIcon:
                const Icon(Icons.tag_rounded, color: AppColors.sentryGrey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.sentryCyan, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return _gradientButton(
      label: _isUploading ? 'Enviando...' : 'Enviar Comprobante',
      icon: _isUploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.send_rounded, color: Colors.white),
      onPressed: _isUploading ? null : _handleSubmit,
    );
  }

  Widget _buildResubmitButton() {
    return _gradientButton(
      label: 'Reenviar comprobante',
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      onPressed: () => setState(() => _alreadySubmitted = false),
    );
  }

  Widget _gradientButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.sentryCyan, AppColors.sentryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sentryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 18.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
