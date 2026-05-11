import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/guard_screen.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '20543870962-g64kl64vhdu5dlthkmlglgq5qfl6ocg0.apps.googleusercontent.com',
  );
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
