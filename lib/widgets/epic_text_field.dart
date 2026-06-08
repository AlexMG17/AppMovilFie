import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';

class EpicTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;

  const EpicTextField({
    super.key,
    this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.validator,
  });

  @override
  State<EpicTextField> createState() => _EpicTextFieldState();
}

class _EpicTextFieldState extends State<EpicTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: Text(
            widget.label,
            style: TextStyle(
              color: AppColors.sentryNavy,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          style: const TextStyle(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: AppColors.sentryGrey.withAlpha(150)),
            prefixIcon: Icon(
              widget.icon,
              color: AppColors.sentryNavy.withAlpha(150),
              size: 22,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.sentryNavy.withAlpha(150),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.sentryBg.withAlpha(150),
            contentPadding: EdgeInsets.symmetric(
              vertical: 18.h,
              horizontal: 20.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.r),
              borderSide: const BorderSide(
                color: AppColors.sentryCyan,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.r),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.r),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
