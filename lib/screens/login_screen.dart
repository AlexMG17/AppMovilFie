import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // â”€â”€ Paleta Sentry (centralizada en AppColors) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const Color sentryNavy = AppColors.sentryNavy;
  static const Color sentryBlue = AppColors.sentryBlue;
  static const Color sentryCyan = AppColors.sentryCyan;
  static const Color sentryGrey = AppColors.sentryGrey;
  static const Color sentryBg   = AppColors.sentryBg;
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor ingresa tu correo y contraseña.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        _showSnackBar('Â¡Bienvenido, ${response.user!.email}!');
        // TODO: Navegar a la pantalla principal
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      _showSnackBar('Error inesperado. Intenta de nuevo.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: isError ? const Color(0xFFD32F2F) : sentryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: sentryBg,
      body: Stack(
        children: [
          // â”€â”€ Fondo con gradiente superior â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [sentryNavy, sentryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // â”€â”€ Círculo decorativo celeste â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sentryCyan.withValues(alpha: 0.15),
              ),
            ),
          ),

          // â”€â”€ Contenido principal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),

                      // Logo Sentry
                      Hero(
                        tag: 'sentry-logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackLogo(),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // â”€â”€ Tarjeta blanca â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: sentryNavy.withValues(alpha: 0.10),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            Text(
                              'Bienvenido',
                              style: GoogleFonts.outfit(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: sentryNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Inicia sesión para continuar',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: sentryGrey,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Email Field
                            _buildLabel('Correo electrónico'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hintText: 'ejemplo@correo.com',
                              icon: Icons.email_outlined,
                              obscureText: false,
                            ),

                            const SizedBox(height: 20),

                            // Password Field
                            _buildLabel('Contraseña'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passController,
                              hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: sentryGrey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Forgot Password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Â¿Olvidaste tu contraseña?',
                                  style: GoogleFonts.outfit(
                                    color: sentryCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [sentryBlue, sentryCyan],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: sentryBlue.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                   onPressed: _isLoading ? null : _handleLogin,
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.transparent,
                                     shadowColor: Colors.transparent,
                                     foregroundColor: Colors.white,
                                     shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(16),
                                     ),
                                   ),
                                   child: _isLoading
                                       ? const SizedBox(
                                           width: 22,
                                           height: 22,
                                           child: CircularProgressIndicator(
                                             color: Colors.white,
                                             strokeWidth: 2.5,
                                           ),
                                         )
                                       : Text(
                                           'Iniciar Sesión',
                                           style: GoogleFonts.outfit(
                                             fontSize: 17,
                                             fontWeight: FontWeight.bold,
                                             letterSpacing: 0.5,
                                           ),
                                         ),
                                 ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(color: Colors.grey.shade200)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'o continúa con',
                                    style: GoogleFonts.outfit(
                                        color: sentryGrey, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: Colors.grey.shade200)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Social Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                    'assets/images/logo.png', 'Google',
                                    fallbackChar: 'G',
                                    fallbackColor: const Color(0xFFDB4437)),
                                const SizedBox(width: 16),
                                _buildSocialButton(
                                    'assets/images/logo.png', 'Microsoft',
                                    fallbackChar: 'M',
                                    fallbackColor: const Color(0xFF00A4EF)),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Sign up row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Â¿No tienes cuenta? ',
                                  style: GoogleFonts.outfit(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: Text(
                                    'Regístrate',
                                    style: GoogleFonts.outfit(
                                      color: sentryBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Footer
                      Text(
                        'Â© 2025 Sentry Â· Acceso Seguro',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: sentryNavy,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.outfit(color: sentryNavy, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
        prefixIcon: Icon(icon, color: sentryGrey, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: sentryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: sentryCyan, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSocialButton(String assetPath, String label,
      {required String fallbackChar, required Color fallbackColor}) {
    return Container(
      width: 120,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          fallbackChar,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: fallbackColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [sentryNavy, sentryCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.shield, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 8),
        Text(
          'SENTRY',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
