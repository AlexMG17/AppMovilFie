import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: _newPasswordCtrl.text.trim(),
          data: {'must_change_password': false},
        ),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'Ocurrió un error. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 32.h),

                // Icon
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.sentryNavy, AppColors.sentryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 40.sp,
                  ),
                ),
                SizedBox(height: 24.h),

                Text(
                  'Crea tu contraseña',
                  style: GoogleFonts.outfit(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sentryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Por seguridad, debes establecer una contraseña personal antes de continuar.',
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    color: AppColors.sentryGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),

                // Form card
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sentryNavy.withAlpha(20),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                          controller: _newPasswordCtrl,
                          label: 'Nueva contraseña',
                          hint: 'Mínimo 8 caracteres',
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu nueva contraseña';
                            }
                            if (v.trim().length < 8) {
                              return 'Mínimo 8 caracteres';
                            }
                            if (!v.contains(RegExp(r'[A-Z]'))) {
                              return 'Debe contener al menos una mayúscula';
                            }
                            if (!v.contains(RegExp(r'[0-9]'))) {
                              return 'Debe contener al menos un número';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),
                        _buildField(
                          controller: _confirmCtrl,
                          label: 'Confirmar contraseña',
                          hint: '••••••••',
                          obscure: _obscureConfirm,
                          onToggle: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                          validator: (v) {
                            if (v != _newPasswordCtrl.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),

                        if (_errorMsg != null) ...[
                          SizedBox(height: 14.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(18),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                  color: Colors.redAccent.withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: Colors.redAccent, size: 16.sp),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.sp,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 24.h),

                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.sentryCyan,
                                AppColors.sentryBlue,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.sentryBlue.withAlpha(70),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding:
                                  EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r)),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Guardar y continuar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Requirements hint
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: AppColors.sentryCyan.withAlpha(20),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                        color: AppColors.sentryCyan.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requisitos de contraseña',
                        style: GoogleFonts.outfit(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sentryNavy,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      ...[
                        'Mínimo 8 caracteres',
                        'Al menos una letra mayúscula',
                        'Al menos un número',
                      ].map(
                        (r) => Padding(
                          padding: EdgeInsets.only(top: 3.h),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 13.sp,
                                  color: AppColors.sentryCyan),
                              SizedBox(width: 6.w),
                              Text(
                                r,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.sp,
                                  color: AppColors.sentryGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.sentryNavy,
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: GoogleFonts.outfit(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: AppColors.sentryGrey),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.sentryGrey),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.sentryGrey,
                size: 20.sp,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.sentryBg,
            contentPadding: EdgeInsets.symmetric(vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(
                  color: AppColors.sentryCyan, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
