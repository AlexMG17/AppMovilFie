import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase antes de arrancar la app
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.sentryBlue),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const AdminShellScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/admin': (_) => const AdminShellScreen(),
        '/vouchers': (_) => const AdminShellScreen(initialIndex: 4),
        '/attendees': (_) => const AdminShellScreen(initialIndex: 3),
        '/import': (_) => const AdminShellScreen(initialIndex: 2),
        '/students': (_) => const AdminShellScreen(initialIndex: 1),
      },
    );
  }
}
