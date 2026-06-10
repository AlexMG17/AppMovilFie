import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/admin_shell_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/guard_screen.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/guard_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

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

    if (user.userMetadata?['must_change_password'] == true) {
      Navigator.pushReplacementNamed(context, '/change-password');
      return;
    }

    final cached = await GuardService.getCachedRole();

    // Navigate exactly once: fresh role within 3 s, otherwise fall back to cache.
    final fresh = await GuardService.getCurrentUserRole()
        .timeout(const Duration(seconds: 3), onTimeout: () => cached);

    NotificationService.initialize();

    if (!mounted) return;
    _navigateByRole(fresh ?? cached);
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
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await SupabaseService.initialize();
  runApp(const SentryApp());
}

class SentryApp extends StatefulWidget {
  const SentryApp({super.key});

  @override
  State<SentryApp> createState() => _SentryAppState();
}

class _SentryAppState extends State<SentryApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'Sentry',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', 'US'),
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
          '/import': (_) => const AdminShellScreen(initialIndex: 2),
        },
      ),
    );
  }
}
