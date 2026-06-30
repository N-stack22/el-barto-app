import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'admin_panel_screen.dart';
import 'app_settings_controller.dart';
import 'auth_screen.dart';
import 'client_notification_listener.dart';
import 'firebase_options.dart';
import 'role_gate_screen.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _inactivityTimer;

  void _startInactivityTimer() {
    if (kIsWeb) return;
    _inactivityTimer?.cancel();
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
    if (kIsWeb) return;

    if (state == AppLifecycleState.resumed) {
      _startInactivityTimer();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _inactivityTimer?.cancel();
    }
  }

  void _markUserActivity() {
    if (kIsWeb) return;
    _startInactivityTimer();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsController.darkMode,
      builder: (context, darkMode, _) {
        return MaterialApp(
          title: 'El Barto',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          builder: (context, child) {
            final trackedChild = Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _markUserActivity(),
              onPointerMove: (_) => _markUserActivity(),
              child: child ?? const SizedBox.shrink(),
            );

            if (kIsWeb) return trackedChild;

            return ClientNotificationListener(
              scaffoldMessengerKey: _scaffoldMessengerKey,
              navigatorKey: _navigatorKey,
              child: trackedChild,
            );
          },
          home: kIsWeb ? const AdminPanelScreen() : const SplashScreen(),
          routes: {
            '/admin': (context) => const AdminPanelScreen(),
            '/auth': (context) => const AuthScreen(),
            '/home': (context) => const RoleGateScreen(),
          },
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: amarillo,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF111111) : fondo,
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
          return IconThemeData(color: selected ? negro : Colors.white70);
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
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1D1D1D) : Colors.white,
      ),
    );
  }
}
