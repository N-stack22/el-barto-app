import 'dart:async';

import 'package:flutter/material.dart';

import 'role_gate_screen.dart';
import 'widgets/logo_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: negro,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                LogoWidget(size: 170),
                SizedBox(height: 18),
                Text(
                  'El Barto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Carnes · Pastas · Pizzas',
                  style: TextStyle(
                    color: amarillo,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
