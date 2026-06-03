import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_screen.dart';
import 'firebase_options.dart';
import 'restaurante_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RestauranteApp());
}

class RestauranteApp extends StatelessWidget {
  const RestauranteApp({super.key});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  static const Color fondo = Color(0xFFF7F7F7);

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
      home: const RestauranteScreen(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const RestauranteScreen(),
      },
    );
  }
}
