import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/guard_screen.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/guard_service.dart';
import 'services/supabase_service.dart';

class _AppRouter extends StatefulWidget {
  const _AppRouter();
  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final user = SupabaseService.currentUser;
    if (!mounted) return;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Imported students must change their temporary password before anything else.
    if (user.userMetadata?['must_change_password'] == true) {
      Navigator.pushReplacementNamed(context, '/change-password');
      return;
    }

    // Navigate immediately using cached role (no network needed).
    final cached = await GuardService.getCachedRole();
    if (!mounted) return;
    _navigateByRole(cached);

    // Refresh role in background and re-navigate only if it changed.
    GuardService.getCurrentUserRole().then((fresh) {
      if (!mounted || fresh == null || fresh == cached) return;
      _navigateByRole(fresh);
    });
  }

  void _navigateByRole(String? role) {
    if (role == 'admin' || role == 'administrador') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (role == 'validador') {
      Navigator.pushReplacementNamed(context, '/guard');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.sentryBg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.sentryBlue),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const SentryApp());
}

class SentryApp extends StatelessWidget {
  const SentryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentry',
      debugShowCheckedModeBanner: false,
      // CONFIGURACIÓN DE IDIOMA AL ESPAÑOL POR DEFECTO
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.sentryBlue),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const _AppRouter(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),
        '/home': (_) => const HomeScreen(),
        '/guard': (_) => const GuardScreen(),
        '/admin': (_) => const AdminShellScreen(),
        '/vouchers': (_) => const AdminShellScreen(initialIndex: 1),
        '/import': (_) => const AdminShellScreen(initialIndex: 2),
        '/attendees': (_) => const AdminShellScreen(initialIndex: 3),
        '/students': (_) => const AdminShellScreen(initialIndex: 1),
      },
    );
  }
}
