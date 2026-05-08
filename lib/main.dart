import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/payment_vouchers_screen.dart';
import 'screens/login_screen.dart';
import 'screens/guard_screen.dart';
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
      home: const LoginScreen(),
      routes: {
        '/login':     (_) => const LoginScreen(),
        '/guard':     (_) => const GuardScreen(),
        '/admin':     (_) => const AdminDashboardScreen(),
        '/vouchers':  (_) => const PaymentVouchersScreen(),
      },
    );
  }
}
