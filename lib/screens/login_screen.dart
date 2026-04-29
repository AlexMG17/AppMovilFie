import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // LÓGICA INTACTA
  bool? isStudent;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // GUÍA DE COLORES SENTRY
  static const Color sentryNavy = Color(0xFF0D2B6B);
  static const Color sentryBlue = Color(0xFF1565C0);
  static const Color sentryCyan = Color(0xFF29B6F6);
  static const Color sentryGrey = Color(0xFF8FA3B1);
  static const Color sentryBg = Color(0xFFEDF2F7);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: sentryBg,
      body: Stack(
        children: [
          // =========================================================
          // 1. DISEÑO DE FONDO (Azul con esquinas inferiores redondeadas)
          // =========================================================

          // Fondo azul superior con la curva que pediste
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              color: sentryNavy,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                  60,
                ), // Redondeo de la esquina inferior izquierda
                bottomRight: Radius.circular(
                  60,
                ), // Redondeo de la esquina inferior derecha
              ),
            ),
          ),

          // Círculo grande superpuesto (Esquina superior derecha)
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: sentryBlue,
              ),
            ),
          ),

          // Círculo mediano interior
          Positioned(
            top: -size.width * 0.1,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.45,
              height: size.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sentryCyan.withOpacity(0.2),
              ),
            ),
          ),

          // =========================================================
          // 2. CONTENIDO PRINCIPAL
          // =========================================================
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // LOGO INTACTO
                    Image.asset(
                      'assets/images/logo.png',
                      height: 210,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    /*const Text(
                      'Sentry',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),*/
                    const SizedBox(height: 30),

                    // TARJETA BLANCA
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: sentryNavy.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: isStudent == null
                            ? _buildInitialQuestion()
                            : (isStudent == true
                                  ? _buildStudentLogin()
                                  : _buildNormalLogin()),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PANTALLA 1: Pregunta Inicial
  // =========================================================================
  Widget _buildInitialQuestion() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¡Bienvenido!',
          style: TextStyle(
            fontSize: 28,
            color: sentryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Por favor, selecciona tu perfil de ingreso:',
          style: TextStyle(fontSize: 15, color: sentryGrey),
        ),
        const SizedBox(height: 30),
        _buildRoleButton(
          title: 'Estudiante Politécnico',
          subtitle: 'Acceso con @espoch.edu.ec',
          icon: Icons.school_rounded,
          onTap: () => setState(() => isStudent = true),
        ),
        const SizedBox(height: 16),
        _buildRoleButton(
          title: 'Invitado / Externo',
          subtitle: 'Acceso con Google o correo',
          icon: Icons.person_rounded,
          onTap: () => setState(() => isStudent = false),
        ),
      ],
    );
  }

  // =========================================================================
  // PANTALLA 2: Login Estudiante
  // =========================================================================
  Widget _buildStudentLogin() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: sentryNavy,
                  size: 20,
                ),
                onPressed: () => setState(() => isStudent = null),
              ),
              const Text(
                'Registro Estudiantil',
                style: TextStyle(
                  color: sentryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildEpicTextField(
            controller: _emailController,
            label: 'Correo Institucional',
            hint: 'ejemplo@espoch.edu.ec',
            icon: Icons.alternate_email,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu correo';
              if (!value.endsWith('@espoch.edu.ec')) {
                return 'Debe ser un correo @espoch.edu.ec válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildEpicTextField(
            controller: _passwordController,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 30),
          _buildEpicButton(
            text: 'Validar e Iniciar Sesión',
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Lógica
              }
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PANTALLA 3: Login Normal
  // =========================================================================
  Widget _buildNormalLogin() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: sentryNavy,
                size: 20,
              ),
              onPressed: () => setState(() => isStudent = null),
            ),
            const Text(
              'Iniciar Sesión',
              style: TextStyle(
                color: sentryNavy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildEpicTextField(
          label: 'Correo electrónico',
          hint: 'ejemplo@correo.com',
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 20),
        _buildEpicTextField(
          label: 'Contraseña',
          hint: '••••••••',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: sentryBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildEpicButton(text: 'Iniciar Sesión', onPressed: () {}),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Divider(color: sentryGrey.withOpacity(0.5), thickness: 1),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'o',
                style: TextStyle(
                  color: sentryGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: sentryGrey.withOpacity(0.5), thickness: 1),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: sentryBg,
            foregroundColor: sentryNavy,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: sentryGrey.withOpacity(0.3)),
            ),
          ),
          icon: const Icon(Icons.g_mobiledata, size: 36, color: Colors.red),
          label: const Text(
            'Continuar con Google',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  // =========================================================================
  // WIDGETS REUTILIZABLES
  // =========================================================================

  Widget _buildRoleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sentryBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sentryCyan.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: sentryNavy.withOpacity(0.05), blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                color: sentryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: sentryNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: sentryGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: sentryGrey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildEpicTextField({
    TextEditingController? controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: sentryNavy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(
            color: sentryNavy,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: sentryGrey),
            prefixIcon: Icon(icon, color: sentryGrey),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: sentryGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: sentryBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: sentryCyan, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpicButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: sentryBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [sentryCyan, sentryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
