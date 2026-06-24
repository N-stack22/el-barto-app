import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensoresScreen extends StatefulWidget {
  const SensoresScreen({super.key});

  @override
  State<SensoresScreen> createState() => _SensoresScreenState();
}

class _SensoresScreenState extends State<SensoresScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  final List<StreamSubscription<dynamic>> _subs = [];

  String acelerometro = 'Esperando datos...';
  String giroscopio = 'Esperando datos...';
  String magnetometro = 'Esperando datos...';
  String userAccel = 'Esperando datos...';
  String estadoMovimiento = 'Quieto';
  double fuerzaUsuario = 0;

  @override
  void initState() {
    super.initState();
    _subs.add(
      SensorsPlatform.instance.accelerometerEventStream().listen((e) {
        if (!mounted) return;
        setState(() {
          acelerometro =
              'X: ${e.x.toStringAsFixed(2)}   Y: ${e.y.toStringAsFixed(2)}   Z: ${e.z.toStringAsFixed(2)}';
        });
      }),
    );
    _subs.add(
      SensorsPlatform.instance.gyroscopeEventStream().listen((e) {
        if (!mounted) return;
        setState(() {
          giroscopio =
              'X: ${e.x.toStringAsFixed(2)}   Y: ${e.y.toStringAsFixed(2)}   Z: ${e.z.toStringAsFixed(2)}';
        });
      }),
    );
    _subs.add(
      SensorsPlatform.instance.magnetometerEventStream().listen((e) {
        if (!mounted) return;
        setState(() {
          magnetometro =
              'X: ${e.x.toStringAsFixed(2)}   Y: ${e.y.toStringAsFixed(2)}   Z: ${e.z.toStringAsFixed(2)}';
        });
      }),
    );
    _subs.add(
      SensorsPlatform.instance.userAccelerometerEventStream().listen((e) {
        final fuerza = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (!mounted) return;
        setState(() {
          fuerzaUsuario = fuerza;
          userAccel =
              'X: ${e.x.toStringAsFixed(2)}   Y: ${e.y.toStringAsFixed(2)}   Z: ${e.z.toStringAsFixed(2)}';
          if (fuerza < 0.45) {
            estadoMovimiento = 'Quieto';
          } else if (fuerza < 2.4) {
            estadoMovimiento = 'En movimiento';
          } else {
            estadoMovimiento = 'Movimiento fuerte';
          }
        });
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  Widget _sensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4BF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: negro),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensores del celular')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: negro,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prueba de sensores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Esta pantalla muestra datos en tiempo real del acelerómetro, giroscopio, magnetómetro y userAccelerometer.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: amarillo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$estadoMovimiento · fuerza ${fuerzaUsuario.toStringAsFixed(2)}',
                    style: const TextStyle(color: negro, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sensorCard(
            icon: Icons.screen_rotation_alt_rounded,
            title: 'Acelerómetro',
            value: acelerometro,
            subtitle: 'Mide aceleración del dispositivo incluyendo gravedad.',
          ),
          const SizedBox(height: 10),
          _sensorCard(
            icon: Icons.rotate_90_degrees_ccw_rounded,
            title: 'Giroscopio',
            value: giroscopio,
            subtitle: 'Mide rotación del celular en sus ejes.',
          ),
          const SizedBox(height: 10),
          _sensorCard(
            icon: Icons.explore_rounded,
            title: 'Magnetómetro',
            value: magnetometro,
            subtitle: 'Detecta campo magnético, útil para brújula/orientación.',
          ),
          const SizedBox(height: 10),
          _sensorCard(
            icon: Icons.delivery_dining_rounded,
            title: 'UserAccelerometer',
            value: userAccel,
            subtitle: 'Mide movimiento del usuario sin contar tanto la gravedad. En el modo motociclista ayuda a indicar si el repartidor está detenido o en movimiento.',
          ),
        ],
      ),
    );
  }
}
