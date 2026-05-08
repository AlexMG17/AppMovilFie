import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/payment_vouchers_screen.dart';
import 'screens/guard_screen.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // Comentado temporalmente para centrarte en el diseño sin errores de conexión
  // await SupabaseService.initialize();


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
      home: const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/guard': (_) => const GuardScreen(),
        '/admin': (_) => const AdminShellScreen(),
        '/vouchers': (_) => const AdminShellScreen(initialIndex: 4),
        '/attendees': (_) => const AdminShellScreen(initialIndex: 3),
        '/import': (_) => const AdminShellScreen(initialIndex: 2),
        '/students': (_) => const AdminShellScreen(initialIndex: 1),
      },
    );
  }
}