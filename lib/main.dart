import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. NUEVO IMPORT
import 'screens/login_screen.dart';

// 2. CAMBIO: Agregamos Future<void> y async
Future<void> main() async {
  // 3. CAMBIO: Obligatorio poner esto antes de inicializar cualquier base de datos en Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 4. CAMBIO: Inicializamos Supabase
  await Supabase.initialize(
    url:
        'https://nnglhmbldffzlsnraryv.supabase.co', // Reemplaza esto con tu URL
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uZ2xobWJsZGZmemxzbnJhcnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4Mjk3MjksImV4cCI6MjA5MTQwNTcyOX0.aIH1G7t7UKty6lQE0RSx0EDxHWjgHAuLBd5GecCP1Gg', // Reemplaza esto con tu Key
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
