import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/guard_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Conexión con nuestro cerebro de Base de Datos
  final AuthService _authService = AuthService();

  // Estado para mostrar el círculo de carga
  bool _isLoading = false;

  // LÓGICA DE NAVEGACIÓN PRINCIPAL
  bool? isStudent;

  // Lógica para alternar entre Login y Registro
  bool _isStudentLogin = true;
  bool _isExternalLogin = true;

  // Lógica para mostrar los campos del código OTP (Recuperar Contraseña)
  bool _isResetPasswordFlow = false;

  // Lógica para mostrar la verificación de cuenta nueva
  bool _isVerificationFlow = false;

  // Control para nuestra notificación superior
  OverlayEntry? _activeToast;

  StreamSubscription<AuthState>? _authSubscription;
  bool _googleSignInInProgress = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Controladores para la recuperación / verificación OTP
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (!_googleSignInInProgress) return;
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _googleSignInInProgress = false;

        final mustChange = data.session?.user.userMetadata?['must_change_password'] == true;
        if (mustChange && mounted) {
          Navigator.pushReplacementNamed(context, '/change-password');
          return;
        }

        final role = await GuardService.getCurrentUserRole();
        if (!mounted) return;
        switch (role) {
          case 'validador':
            Navigator.pushReplacementNamed(context, '/guard');
          case 'admin':
          case 'administrador':
            Navigator.pushReplacementNamed(context, '/admin');
          default:
            Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _activeToast?.remove();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _otpController.clear();
    _newPasswordController.clear();
  }

  // =========================================================================
  // NOTIFICACIÓN FLOTANTE PERSONALIZADA (SUPERIOR)
  // =========================================================================
  void _showTopToast(String message, {bool isError = false}) {
    _activeToast?.remove();
    _activeToast = null;

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isError ? Colors.redAccent : Colors.green,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isError ? Colors.redAccent : Colors.green)
                        .withAlpha(100),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _activeToast = overlayEntry;
    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (_activeToast == overlayEntry) {
        _activeToast?.remove();
        _activeToast = null;
      }
    });
  }

  // =========================================================================
  // PASO 1: PEDIR EL CÓDIGO (Recuperación de contraseña)
  // =========================================================================
  Future<void> _handleForgotPassword(bool isStudentFlow) async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showTopToast('Por favor, ingresa tu correo primero', isError: true);
      return;
    }

    if (isStudentFlow && !email.endsWith('@espoch.edu.ec')) {
      _showTopToast('Ingresa un correo @espoch.edu.ec válido', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      if (mounted) {
        _showTopToast('Te enviamos un código de recuperación al correo.');
        setState(() {
          _isResetPasswordFlow = true; // Cambiamos la interfaz a "Ingresar Código"
        });
      }
    } on AuthException catch (e) {
      if (mounted) _showTopToast('Error: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) _showTopToast('Error al enviar el correo.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // PASO 2: VERIFICAR CÓDIGO Y CAMBIAR CONTRASEÑA
  // =========================================================================
  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final otpCode = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (otpCode.isEmpty || newPassword.isEmpty) {
      _showTopToast('Por favor completa todos los campos', isError: true);
      return;
    }

    if (newPassword.length < 8) {
      _showTopToast(
        'La contraseña debe tener al menos 8 caracteres',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        token: otpCode,
        email: email,
      );

      if (res.session != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          _showTopToast('¡Contraseña actualizada con éxito! Inicia sesión.');
          setState(() {
            _isResetPasswordFlow = false;
            _clearControllers();
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showTopToast('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) _showTopToast('Ocurrió un error inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // REENVIAR CÓDIGO DE VERIFICACIÓN
  // =========================================================================
  Future<void> _resendVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (mounted) {
        _showTopToast('¡Nuevo código enviado a tu correo!');
      }
    } on AuthException catch (e) {
      if (mounted) _showTopToast('Error: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) _showTopToast('Error al reenviar el código.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // VERIFICAR CUENTA NUEVA CON OTP
  // =========================================================================
  Future<void> _handleVerifySignUp() async {
    final email = _emailController.text.trim();
    final otpCode = _otpController.text.trim();

    if (otpCode.isEmpty) {
      _showTopToast('Por favor, ingresa el código', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Validamos el código de registro (signup)
      final AuthResponse res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        token: otpCode,
        email: email,
      );

      if (res.session != null && mounted) {
        _showTopToast('¡Cuenta verificada exitosamente!');

        final role = await GuardService.getCurrentUserRole();
        if (!mounted) return;

        switch (role) {
          case 'validador':
            Navigator.pushReplacementNamed(context, '/guard');
          case 'admin':
          case 'administrador':
            Navigator.pushReplacementNamed(context, '/admin');
          default:
            Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showTopToast('Error: ${e.message}', isError: true);
    } catch (e) {
      if (mounted) _showTopToast('Ocurrió un error inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // LÓGICA DE AUTENTICACIÓN NORMAL (SUPABASE)
  // =========================================================================
  Future<void> _handleAuth(bool isStudentFlow, bool isLoginFlow) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final nombre = _nameController.text.trim();

      final int idRol = isStudentFlow ? 1 : 2;

      if (isLoginFlow) {
        // ------------------ INICIAR SESIÓN ------------------
        await _authService.signIn(email: email, password: password);

        if (mounted) {
          _showTopToast('¡Inicio de sesión exitoso!');

          // Check if this is an imported student who must change their password
          final mustChange = Supabase.instance.client.auth.currentUser
              ?.userMetadata?['must_change_password'] == true;
          if (mustChange && mounted) {
            Navigator.pushReplacementNamed(context, '/change-password');
            return;
          }

          final role = await GuardService.getCurrentUserRole();
          if (!mounted) return;

          switch (role) {
            case 'validador':
              Navigator.pushReplacementNamed(context, '/guard');
            case 'admin':
            case 'administrador':
              Navigator.pushReplacementNamed(context, '/admin');
            default:
              Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        // ------------------ REGISTRO ------------------
        await _authService.signUp(
          email: email,
          password: password,
          nombre: nombre,
          idRol: idRol,
        );

        if (mounted) {
          _showTopToast(
            '¡Cuenta pre-creada! Hemos enviado un código a tu correo.',
          );
          setState(() {
            _isVerificationFlow = true;
          });
        }
      }
    } on AuthException catch (e) {
      // MEJORA UX: Si el usuario intenta iniciar sesión pero olvidó verificar su correo
      if (e.message.contains("Email not confirmed")) {
        if (mounted) {
          _showTopToast(
            'Debes verificar tu correo. Ingresa el código que te enviamos.',
            isError: true,
          );
          setState(() {
            _isVerificationFlow =
                true; // Lo mandamos automáticamente a verificar
          });
        }
      } else {
        if (mounted) _showTopToast('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showTopToast('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // LÓGICA DE GOOGLE SIGN-IN CON SUPABASE NATIVO
  // =========================================================================
  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _googleSignInInProgress = true);

      final googleSignIn = GoogleSignIn(
        serverClientId:
            '20543870962-g64kl64vhdu5dlthkmlglgq5qfl6ocg0.apps.googleusercontent.com',
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _googleSignInInProgress = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        setState(() => _googleSignInInProgress = false);
        if (mounted) {
          _showTopToast(
            'No se pudo obtener el token de Google.',
            isError: true,
          );
        }
        return;
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (error) {
      setState(() => _googleSignInInProgress = false);
      if (mounted) {
        _showTopToast('Error al conectar con Google.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. DISEÑO DE FONDO
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              color: AppColors.sentryNavy,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(60),
                bottomRight: Radius.circular(60),
              ),
            ),
          ),
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sentryBlue,
              ),
            ),
          ),
          Positioned(
            top: -size.width * 0.1,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.45,
              height: size.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sentryCyan.withAlpha(51),
              ),
            ),
          ),

          // 2. GIF DE LLAMAS FIESTERAS
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/images/Llamasgif.gif',
                  height: 200,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. CONTENIDO PRINCIPAL
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // LOGO
                      Image.asset(
                        'assets/images/logo.png',
                        height: 210,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 30),

                      // TARJETA BLANCA
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sentryNavy.withAlpha(38),
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
                              : (_isResetPasswordFlow
                                    ? _buildResetPasswordForm()
                                    : (_isVerificationFlow
                                          ? _buildVerificationForm()
                                          : (isStudent == true
                                                ? _buildStudentLogin()
                                                : _buildNormalLogin()))),
                        ),
                      ),

                      const SizedBox(height: 200),
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
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Por favor, selecciona tu perfil de ingreso:',
          style: TextStyle(fontSize: 15, color: AppColors.sentryGrey),
        ),
        const SizedBox(height: 30),
        _buildRoleButton(
          title: 'Estudiante Politécnico',
          subtitle: 'Acceso con @espoch.edu.ec',
          icon: Icons.school_rounded,
          onTap: () {
            setState(() {
              isStudent = true;
              _isStudentLogin = true;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildRoleButton(
          title: 'Invitado / Externo',
          subtitle: 'Acceso con Google o correo',
          icon: Icons.person_rounded,
          onTap: () {
            setState(() {
              isStudent = false;
              _isExternalLogin = true;
            });
          },
        ),
      ],
    );
  }

  // =========================================================================
  // PANTALLA: RESTABLECER CONTRASEÑA (OTP NATIVO)
  // =========================================================================
  Widget _buildResetPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey("reset_flow"),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.sentryNavy,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isResetPasswordFlow = false;
                  });
                },
              ),
              const Text(
                'Nueva Contraseña',
                style: TextStyle(
                  color: AppColors.sentryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Revisa tu correo electrónico. Te enviamos un código de recuperación.',
            style: TextStyle(color: AppColors.sentryGrey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildEpicTextField(
            controller: _otpController,
            label: 'Código de recuperación',
            hint: 'Ej: 123456',
            icon: Icons.pin_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa el código';
              return null;
            },
          ),
          const SizedBox(height: 20),

          _buildEpicTextField(
            controller: _newPasswordController,
            label: 'Tu nueva contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu nueva contraseña';
              }
              if (value.length < 8) return 'Mínimo 8 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 30),

          _buildEpicButton(
            text: 'Cambiar Contraseña',
            onPressed: _handleResetPassword,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PANTALLA: VERIFICAR REGISTRO (OTP)
  // =========================================================================
  Widget _buildVerificationForm() {
    return Form(
      child: Column(
        key: const ValueKey("verification_flow"),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.sentryNavy,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isVerificationFlow = false;
                    _clearControllers();
                  });
                },
              ),
              const Text(
                'Verificar Cuenta',
                style: TextStyle(
                  color: AppColors.sentryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enviamos un código de validación al correo:\n${_emailController.text}',
            style: const TextStyle(color: AppColors.sentryGrey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          _buildEpicTextField(
            controller: _otpController,
            label: 'Código de validación',
            hint: 'Ej: 123456',
            icon: Icons.mark_email_read_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa el código';
              return null;
            },
          ),
          const SizedBox(height: 20),

          _buildEpicButton(
            text: 'Completar Registro',
            onPressed: _handleVerifySignUp,
          ),
          const SizedBox(height: 16),

          // BOTÓN DE REENVIAR CÓDIGO
          TextButton(
            onPressed: _isLoading ? null : _resendVerificationCode,
            child: const Text(
              '¿No recibiste el código? Reenviar',
              style: TextStyle(
                color: AppColors.sentryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PANTALLA 2: Login / Registro Estudiante
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
                  color: AppColors.sentryNavy,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    isStudent = null;
                    _clearControllers();
                  });
                },
              ),
              Text(
                _isStudentLogin ? 'Acceso Estudiantil' : 'Registro Estudiantil',
                style: const TextStyle(
                  color: AppColors.sentryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Campo de Nombre (Solo visible en Registro)
          if (!_isStudentLogin) ...[
            _buildEpicTextField(
              controller: _nameController,
              label: 'Nombre Completo',
              hint: 'Ej. Juan Pérez',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          _buildEpicTextField(
            controller: _emailController,
            label: 'Correo Institucional',
            hint: 'ejemplo@espoch.edu.ec',
            icon: Icons.alternate_email,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu correo';
              }
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña';
              }
              // Validaciones estrictas solo aplicables durante el registro
              if (!_isStudentLogin) {
                if (value.length < 8) { return 'Debe tener al menos 8 caracteres'; }
                if (!value.contains(RegExp(r'[A-Z]'))) { return 'Debe contener al menos una mayúscula'; }
                if (!value.contains(RegExp(r'[0-9]'))) { return 'Debe contener al menos un número'; }
                if (!value.contains(RegExp(r'[!@#\$&*~%^().,]'))) { return 'Debe contener un símbolo especial (ej. !@#\$&*)'; }
              }
              return null;
            },
          ),

          // Confirmar Contraseña (Solo visible en Registro)
          if (!_isStudentLogin) ...[
            const SizedBox(height: 20),
            _buildEpicTextField(
              controller: _confirmPasswordController,
              label: 'Confirmar Contraseña',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu contraseña';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
          ],

          // Olvidaste contraseña (Solo visible en Login)
          if (_isStudentLogin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _handleForgotPassword(true),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: AppColors.sentryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 30),
          ],

          _buildEpicButton(
            text: _isStudentLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
            onPressed: () => _handleAuth(true, _isStudentLogin),
          ),
          const SizedBox(height: 24),

          // Botón para alternar entre Login y Registro
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isStudentLogin = !_isStudentLogin;
                  _formKey.currentState?.reset();
                  _clearControllers();
                });
              },
              child: RichText(
                text: TextSpan(
                  text: _isStudentLogin
                      ? '¿No tienes cuenta? '
                      : '¿Ya tienes cuenta? ',
                  style: const TextStyle(color: AppColors.sentryGrey, fontSize: 14),
                  children: [
                    TextSpan(
                      text: _isStudentLogin ? 'Regístrate' : 'Inicia Sesión',
                      style: const TextStyle(
                        color: AppColors.sentryNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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
  // PANTALLA 3: Login / Registro Externo
  // =========================================================================
  Widget _buildNormalLogin() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(3),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.sentryNavy,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    isStudent = null;
                    _clearControllers();
                  });
                },
              ),
              Text(
                _isExternalLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                style: const TextStyle(
                  color: AppColors.sentryNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_isExternalLogin) ...[
            _buildEpicTextField(
              controller: _nameController,
              label: 'Nombre Completo',
              hint: 'Ej. María Gómez',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa tu nombre';
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          _buildEpicTextField(
            controller: _emailController,
            label: 'Correo electrónico',
            hint: 'ejemplo@correo.com',
            icon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa tu correo';
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña';
              }
              if (!_isExternalLogin) {
                if (value.length < 8) { return 'Debe tener al menos 8 caracteres'; }
                if (!value.contains(RegExp(r'[A-Z]'))) { return 'Debe contener al menos una mayúscula'; }
                if (!value.contains(RegExp(r'[0-9]'))) { return 'Debe contener al menos un número'; }
                if (!value.contains(RegExp(r'[!@#\$&*~%^().,]'))) { return 'Debe contener un símbolo especial (ej. !@#\$&*)'; }
              }
              return null;
            },
          ),

          // Confirmar Contraseña (Solo visible en Registro)
          if (!_isExternalLogin) ...[
            const SizedBox(height: 20),
            _buildEpicTextField(
              controller: _confirmPasswordController,
              label: 'Confirmar Contraseña',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu contraseña';
                }
                if (value != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
          ],

          // Olvidaste contraseña (Solo visible en Login)
          if (_isExternalLogin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _handleForgotPassword(false),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: AppColors.sentryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 30),
          ],

          _buildEpicButton(
            text: _isExternalLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
            onPressed: () => _handleAuth(false, _isExternalLogin),
          ),
          const SizedBox(height: 24),

          // Sección de Google siempre visible en usuario externo
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppColors.sentryGrey.withAlpha(128),
                  thickness: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'o continúa con',
                  style: TextStyle(
                    color: AppColors.sentryGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppColors.sentryGrey.withAlpha(128),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sentryBg,
              foregroundColor: AppColors.sentryNavy,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.sentryGrey.withAlpha(77)),
              ),
            ),
            icon: const Icon(Icons.g_mobiledata, size: 36, color: Colors.red),
            label: const Text(
              'Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _handleGoogleSignIn,
          ),
          const SizedBox(height: 24),

          // Botón para alternar entre Login y Registro Externo
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExternalLogin = !_isExternalLogin;
                  _formKey.currentState?.reset();
                  _clearControllers();
                });
              },
              child: RichText(
                text: TextSpan(
                  text: _isExternalLogin
                      ? '¿No tienes cuenta? '
                      : '¿Ya tienes cuenta? ',
                  style: const TextStyle(
                    color: AppColors.sentryGrey,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: _isExternalLogin ? 'Regístrate' : 'Inicia Sesión',
                      style: const TextStyle(
                        color: AppColors.sentryNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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
          color: AppColors.sentryBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.sentryCyan.withAlpha(77),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sentryNavy.withAlpha(13),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.sentryBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.sentryNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.sentryGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.sentryGrey,
              size: 18,
            ),
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
            color: AppColors.sentryNavy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(
            color: AppColors.sentryNavy,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.sentryGrey),
            prefixIcon: Icon(icon, color: AppColors.sentryGrey),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.sentryGrey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.sentryBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.sentryCyan,
                width: 2,
              ),
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
            color: AppColors.sentryBlue.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [AppColors.sentryCyan, AppColors.sentryBlue],
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
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
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
