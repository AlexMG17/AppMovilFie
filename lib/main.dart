import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        // Aplicando la fuente Outfit de Google Fonts
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),

      // Mantenemos HomeScreen como principal para que analices el diseño directamente
      home: const HomeScreen(),

      // Definimos las rutas para que la navegabilidad de los botones funcione
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}