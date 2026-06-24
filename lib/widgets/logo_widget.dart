import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({
    super.key,
    this.size = 120,
    this.assetPath = 'assets/logo.png',
  });

  final double size;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.restaurant_menu_rounded,
          size: size * 0.65,
          color: Colors.white,
        );
      },
    );
  }
}
