import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_screen.dart';
import 'firebase_options.dart';
import 'role_gate_screen.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RestauranteApp());
}

class RestauranteApp extends StatefulWidget {
  const RestauranteApp({super.key});

  @override
  State<RestauranteApp> createState() => _RestauranteAppState();
}

class _RestauranteAppState extends State<RestauranteApp>
    with WidgetsBindingObserver {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  static const Color fondo = Color(0xFFF7F7F7);

  Timer? _inactivityTimer;

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () async {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _inactivityTimer?.cancel();
      if (FirebaseAuth.instance.currentUser != null) {
        FirebaseAuth.instance.signOut();
      }
    }
  }

  void _markUserActivity() {
    _startInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Barto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: amarillo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: fondo,
        appBarTheme: const AppBarTheme(
          backgroundColor: negro,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: negro,
          indicatorColor: amarillo,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? amarillo : Colors.white70,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? negro : Colors.white70,
            );
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: amarillo,
            foregroundColor: negro,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _markUserActivity(),
          onPointerMove: (_) => _markUserActivity(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const RoleGateScreen(),
      },
    );
  }
}
