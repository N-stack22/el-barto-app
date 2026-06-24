import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'auth_screen.dart';
import 'auth_service.dart';
import 'cart_controller.dart';
import 'sensores_screen.dart';

class TuScreen extends StatelessWidget {
  const TuScreen({super.key});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  Future<void> _abrirLogin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(returnToPrevious: true),
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión? Tu carrito no se perderá.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await AuthService().logout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión cerrada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _nombreUsuario(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    final data = doc.data();
    final nombreCompleto = data?['nombreCompleto']?.toString().trim();
    final nombres = data?['nombres']?.toString().trim();
    final displayName = user.displayName?.trim();

    if (nombreCompleto != null && nombreCompleto.isNotEmpty) {
      return nombreCompleto;
    }

    if (nombres != null && nombres.isNotEmpty) {
      return nombres;
    }

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return user.email?.split('@').first ?? 'Cliente';
  }

  Widget _loginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: amarillo,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, size: 48, color: negro),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tu cuenta',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inicia sesión para ver tus pedidos, favoritos y reseñas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _abrirLogin(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Iniciar sesión o registrarme'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, User user) {
    return FutureBuilder<String>(
      future: _nombreUsuario(user),
      builder: (context, snapshot) {
        final nombre = snapshot.data ?? 'Cliente';
        final email = user.email ?? '';
        final inicial = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'E';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: negro,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: amarillo,
                foregroundColor: negro,
                child: Text(
                  inicial,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hola,',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4BF),
                  borderRadius: BorderRadius.circular(14),
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
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title se puede implementar como siguiente mejora.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return _loginRequired(context);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(context, user),
            const SizedBox(height: 18),
            const Text(
              'Mi actividad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.sensors_rounded,
              title: 'Probar sensores del celular',
              subtitle: 'Ver acelerómetro, giroscopio, magnetómetro y userAccelerometer.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SensoresScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.receipt_long_rounded,
              title: 'Tus pedidos',
              subtitle: 'Consulta el detalle, estado y cancelación de tus pedidos.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TusPedidosScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.favorite_rounded,
              title: 'Tus platos favoritos',
              subtitle: 'Guarda platos para pedirlos más rápido después.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritosScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.star_rate_rounded,
              title: 'Tus reseñas',
              subtitle: 'Reseña pedidos entregados y revisa los pendientes.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResenasScreen()),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Cuenta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.support_agent_rounded,
              title: 'Ayuda y soporte',
              subtitle: 'Contacta al restaurante si tienes dudas con tu pedido.',
              onTap: () => _showComingSoon(context, 'Ayuda y soporte'),
            ),
            const SizedBox(height: 10),
            _option(
              icon: Icons.logout_rounded,
              title: 'Cerrar sesión',
              subtitle: 'Salir de tu cuenta sin borrar el carrito.',
              onTap: () => _cerrarSesion(context),
              trailing: const Icon(Icons.logout_rounded),
            ),
          ],
        );
      },
    );
  }
}

class TusPedidosScreen extends StatelessWidget {
  const TusPedidosScreen({super.key});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return 'S/ ${number.toStringAsFixed(2)}';
  }

  String _estadoNormalizado(dynamic value) {
    final estado = value?.toString().trim().toLowerCase() ?? 'pendiente';

    if (estado == 'pendiente_pago') return 'pendiente';
    if (estado == 'preparacion') return 'en_preparacion';
    if (estado == 'en preparación') return 'en_preparacion';
    if (estado == 'en_preparacion') return 'en_preparacion';
    if (estado == 'listo') return 'listo';
    if (estado == 'en_camino' || estado == 'en_camino_local' || estado == 'camino' || estado == 'en camino') return 'en_camino';
    if (estado == 'entregado') return 'entregado';
    if (estado == 'cancelado') return 'cancelado';
    if (estado == 'cancelada') return 'cancelado';

    return 'pendiente';
  }

  String _estadoTexto(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Pendiente';
    }
  }

  int _estadoIndex(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return 1;
      case 'listo':
        return 2;
      case 'en_camino':
        return 3;
      case 'entregado':
        return 4;
      default:
        return 0;
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return Colors.orange;
      case 'listo':
        return Colors.green;
      case 'en_camino':
        return Colors.blue;
      case 'entregado':
        return Colors.green.shade700;
      case 'cancelado':
        return Colors.red;
      default:
        return amarillo;
    }
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['creadoEn'] ?? data['fecha'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fechaTexto(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Fecha pendiente';
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    final hora = date.hour.toString().padLeft(2, '0');
    final minuto = date.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${date.year} · $hora:$minuto';
  }

  Widget _statusStepper(String estado) {
    if (estado == 'cancelado') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Este pedido fue cancelado.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    final current = _estadoIndex(estado);
    final colorActual = _estadoColor(estado);
    final labels = ['Pendiente', 'En\npreparación', 'Listo', 'En\ncamino', 'Entregado'];

    return Column(
      children: [
        SizedBox(
          height: 30,
          child: Row(
            children: List.generate(labels.length * 2 - 1, (pos) {
              if (pos.isOdd) {
                final leftIndex = (pos - 1) ~/ 2;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: leftIndex < current ? colorActual : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }

              final index = pos ~/ 2;
              final active = index <= current;
              return SizedBox(
                width: 34,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active ? colorActual : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      index >= 2 ? Icons.check_rounded : Icons.circle,
                      size: index >= 2 ? 18 : 9,
                      color: active ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (index) {
            final active = index <= current;
            return Expanded(
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.05,
                  color: active ? negro : Colors.black45,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _totalChip(dynamic total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: negro,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'Total: ${_money(total)}',
        style: const TextStyle(
          color: amarillo,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _pedidoCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final estado = _estadoNormalizado(data['estado']);
    final rawItems = (data['items'] as List?) ?? (data['productos'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final fecha = _createdAt(data);
    final distanciaTexto = data['distanciaTexto']?.toString() ?? '';
    final duracionTexto = data['duracionTexto']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PedidoDetalleScreen(pedidoId: doc.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${doc.id.substring(0, doc.id.length >= 6 ? 6 : doc.id.length).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _estadoColor(estado).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _estadoColor(estado)),
                    ),
                    child: Text(
                      _estadoTexto(estado),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _fechaTexto(fecha),
                style: const TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _statusStepper(estado),
              const Divider(height: 24),
              if (items.isEmpty)
                const Text(
                  'Sin detalle de productos.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...items.take(3).map((item) {
                  final cantidad = item['cantidad'] ?? 1;
                  final nombre = item['nombre']?.toString() ?? 'Producto';
                  final subtotal = item['subtotal'] ?? item['precioUnitario'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$cantidad x $nombre',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          _money(subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                }),
              if (items.length > 3)
                Text(
                  '+ ${items.length - 3} producto(s) más',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              const SizedBox(height: 10),
              if (distanciaTexto.isNotEmpty || duracionTexto.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, size: 18, color: negro),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [distanciaTexto, duracionTexto].where((e) => e.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delivery: ${_money(data['delivery'])}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  _totalChip(data['total']),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tus pedidos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inicia sesión para ver tus pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(returnToPrevious: true),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tus pedidos')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_restaurante')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar tus pedidos:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          );
          docs.sort((a, b) => _createdAt(b.data()).compareTo(_createdAt(a.data())));

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: amarillo, shape: BoxShape.circle),
                      child: const Icon(Icons.receipt_long_outlined, size: 44, color: negro),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aún no tienes pedidos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cuando confirmes uno, aparecerá aquí con su estado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _pedidoCard(context, docs[index]),
          );
        },
      ),
    );
  }
}

class PedidoDetalleScreen extends StatelessWidget {
  final String pedidoId;

  const PedidoDetalleScreen({super.key, required this.pedidoId});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return 'S/. ${number.toStringAsFixed(2)}';
  }

  String _estadoNormalizado(dynamic value) {
    final estado = value?.toString().trim().toLowerCase() ?? 'pendiente';
    if (estado == 'pendiente_pago') return 'pendiente';
    if (estado == 'preparacion') return 'en_preparacion';
    if (estado == 'en preparación') return 'en_preparacion';
    if (estado == 'en_preparacion') return 'en_preparacion';
    if (estado == 'listo') return 'listo';
    if (estado == 'en_camino' || estado == 'en_camino_local' || estado == 'camino' || estado == 'en camino') return 'en_camino';
    if (estado == 'entregado') return 'entregado';
    if (estado == 'cancelado' || estado == 'cancelada') return 'cancelado';
    return 'pendiente';
  }

  String _estadoTexto(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Pendiente';
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return Colors.orange;
      case 'listo':
        return Colors.green;
      case 'en_camino':
        return Colors.blue;
      case 'entregado':
        return Colors.green.shade700;
      case 'cancelado':
        return Colors.red;
      default:
        return amarillo;
    }
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['creadoEn'] ?? data['fecha'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fechaTexto(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Fecha pendiente';
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    final hora = date.hour.toString().padLeft(2, '0');
    final minuto = date.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${date.year} · $hora:$minuto';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  double? _coord(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Widget _statusBox(String estado) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _estadoColor(estado).withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _estadoColor(estado)),
      ),
      child: Row(
        children: [
          Icon(
            estado == 'cancelado'
                ? Icons.cancel_rounded
                : estado == 'entregado'
                    ? Icons.done_all_rounded
                    : estado == 'en_camino'
                        ? Icons.delivery_dining_rounded
                        : estado == 'listo'
                            ? Icons.check_circle_rounded
                            : estado == 'en_preparacion'
                                ? Icons.restaurant_rounded
                                : Icons.hourglass_bottom_rounded,
            color: estado == 'pendiente' ? negro : _estadoColor(estado),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _estadoTexto(estado),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  estado == 'pendiente'
                      ? 'Tu pedido fue recibido. Puedes cancelarlo mientras siga pendiente.'
                      : estado == 'en_preparacion'
                          ? 'El restaurante ya empezó a preparar tu pedido.'
                          : estado == 'listo'
                              ? 'Tu pedido está listo para entrega o recojo.'
                              : estado == 'en_camino'
                                  ? 'El repartidor está llevando tu pedido hacia la ubicación indicada.'
                                  : estado == 'entregado'
                                      ? 'Tu pedido fue entregado. Ya puedes dejar una reseña.'
                                      : 'El pedido ya no continuará.',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapaPedido(Map<String, dynamic> data) {
    final restauranteMap = _asMap(data['restauranteUbicacion']);
    final clienteMap = _asMap(data['ubicacionCliente']);

    final restLat = _coord(restauranteMap, 'lat') ?? -12.039447;
    final restLng = _coord(restauranteMap, 'lng') ?? -75.227225;
    final clienteLat = _coord(clienteMap, 'lat');
    final clienteLng = _coord(clienteMap, 'lng');

    if (clienteLat == null || clienteLng == null) {
      return const SizedBox.shrink();
    }

    final restaurante = LatLng(restLat, restLng);
    final cliente = LatLng(clienteLat, clienteLng);
    final encoded = data['rutaPolyline']?.toString() ?? '';
    final decodedPoints = encoded.isNotEmpty ? _decodePolyline(encoded) : <LatLng>[];
    final points = decodedPoints.isNotEmpty ? decodedPoints : <LatLng>[restaurante, cliente];
    final center = LatLng(
      (restaurante.latitude + cliente.latitude) / 2,
      (restaurante.longitude + cliente.longitude) / 2,
    );

    final repartidorLat = data['repartidorLat'] is num ? (data['repartidorLat'] as num).toDouble() : null;
    final repartidorLng = data['repartidorLng'] is num ? (data['repartidorLng'] as num).toDouble() : null;
    final repartidor = repartidorLat != null && repartidorLng != null ? LatLng(repartidorLat, repartidorLng) : null;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('restaurante'),
        position: restaurante,
        infoWindow: const InfoWindow(title: 'El Barto'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
      Marker(
        markerId: const MarkerId('cliente'),
        position: cliente,
        infoWindow: const InfoWindow(title: 'Entrega'),
      ),
    };

    final movimiento = data['repartidorMovimiento']?.toString() ?? 'detenido';
    final rumbo = data['repartidorRumbo'] is num
        ? (data['repartidorRumbo'] as num).toDouble()
        : 0.0;

    if (repartidor != null && movimiento != 'detenido') {
      markers.add(
        Marker(
          markerId: const MarkerId('repartidor'),
          position: repartidor,
          flat: true,
          rotation: rumbo,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'Repartidor en movimiento'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 13.5),
          markers: markers,
          circles: {
            if (repartidor != null && movimiento == 'detenido')
              Circle(
                circleId: const CircleId('repartidor_detenido'),
                center: repartidor,
                radius: 18,
                strokeWidth: 3,
                strokeColor: Colors.blue,
                fillColor: Colors.blueAccent.withOpacity(0.20),
              ),
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId('ruta_pedido'),
              points: points,
              width: 6,
              color: negro,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _repartidorCard(Map<String, dynamic> data) {
    final asignado = data['repartidorAsignado'] == true;
    final nombre = data['repartidorNombre']?.toString().trim();
    final movimiento = data['repartidorMovimiento']?.toString().trim() ?? 'sin_asignar';
    final velocidadValue = data['repartidorVelocidadKmh'];
    final velocidad = velocidadValue is num ? velocidadValue.toDouble() : double.tryParse(velocidadValue?.toString() ?? '') ?? 0.0;
    final lat = data['repartidorLat'];
    final lng = data['repartidorLng'];
    final tieneUbicacion = lat is num && lng is num;

    String movimientoTexto;
    switch (movimiento) {
      case 'en_movimiento':
        movimientoTexto = 'En movimiento';
        break;
      case 'detenido':
        movimientoTexto = 'Detenido';
        break;
      case 'movimiento_fuerte':
        movimientoTexto = 'Movimiento fuerte';
        break;
      default:
        movimientoTexto = 'Sin asignar';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: asignado ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: asignado ? Colors.blue.shade200 : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            asignado ? Icons.delivery_dining_rounded : Icons.person_search_rounded,
            color: asignado ? Colors.blue.shade700 : Colors.black45,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asignado ? 'Repartidor asignado' : 'Repartidor aún no asignado',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                if (asignado && nombre != null && nombre.isNotEmpty)
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (asignado) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Velocidad: ${velocidad.toStringAsFixed(1)} km/h · $movimientoTexto',
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tieneUbicacion ? 'Ubicación del repartidor disponible en el mapa.' : 'Ubicación del repartidor pendiente.',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ] else
                  const Text(
                    'Cuando el restaurante asigne un repartidor, aquí aparecerá su velocidad, movimiento y ubicación.',
                    style: TextStyle(color: Colors.black54, fontSize: 12.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productoItem(Map<String, dynamic> item) {
    final imagenUrl = item['imagenUrl']?.toString() ?? '';
    final cantidad = item['cantidad'] ?? 1;
    final nombre = item['nombre']?.toString() ?? 'Producto';
    final variante = item['variante']?.toString() ?? 'Normal';
    final precioUnitario = item['precioUnitario'];
    final subtotal = item['subtotal'] ?? precioUnitario;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imagenUrl.trim().isEmpty
                ? Container(
                    width: 58,
                    height: 58,
                    color: const Color(0xFFFFF4BF),
                    child: const Icon(Icons.restaurant_menu_rounded, color: negro),
                  )
                : Image.network(
                    imagenUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFFFFEBEE),
                      child: const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cantidad x $nombre',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  variante == 'Normal' ? 'Precio unitario: ${_money(precioUnitario)}' : '$variante · ${_money(precioUnitario)} c/u',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(subtotal),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, dynamic value, {bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: big ? negro : Colors.black54,
            fontWeight: big ? FontWeight.w900 : FontWeight.w700,
            fontSize: big ? 18 : 14,
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: big ? 20 : 15,
          ),
        ),
      ],
    );
  }

  Future<void> _cancelarPedido(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final estado = _estadoNormalizado(data?['estado']);
    final user = AuthService().currentUser;

    if (data == null || user == null || data['userId'] != user.uid) return;

    if (estado != 'pendiente') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se puede cancelar un pedido mientras está pendiente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Seguro que deseas cancelar este pedido? Esta acción cambiará su estado a cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await doc.reference.update({
        'estado': 'cancelado',
        'pagoEstado': 'cancelado',
        'estadoActualizadoEn': FieldValue.serverTimestamp(),
        'canceladoEn': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido cancelado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cancelar el pedido: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del pedido')),
        body: const Center(child: Text('Inicia sesión para ver este pedido.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_restaurante')
            .doc(pedidoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el pedido:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data;
          final data = doc?.data();

          if (doc == null || data == null || !doc.exists || data['userId'] != user.uid) {
            return const Center(child: Text('Pedido no encontrado.'));
          }

          final estado = _estadoNormalizado(data['estado']);
          final rawItems = (data['items'] as List?) ?? (data['productos'] as List?) ?? const [];
          final items = rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          final fecha = _createdAt(data);
          final distanciaTexto = data['distanciaTexto']?.toString() ?? '';
          final duracionTexto = data['duracionTexto']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${pedidoId.substring(0, pedidoId.length >= 6 ? 6 : pedidoId.length).toUpperCase()}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _estadoColor(estado).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _estadoColor(estado)),
                    ),
                    child: Text(
                      _estadoTexto(estado),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _fechaTexto(fecha),
                style: const TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _statusBox(estado),
              const SizedBox(height: 18),
              const Text(
                'Ruta de entrega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _mapaPedido(data),
              if (distanciaTexto.isNotEmpty || duracionTexto.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  [distanciaTexto, duracionTexto].where((e) => e.isNotEmpty).join(' · '),
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 14),
              _repartidorCard(data),
              const SizedBox(height: 18),
              const Text(
                'Detalle de productos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Text(
                  'Este pedido no tiene productos registrados.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _productoItem(item),
                    )),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _totalRow('Subtotal', data['subtotal']),
                    const SizedBox(height: 8),
                    _totalRow('Delivery', data['delivery']),
                    const Divider(height: 24),
                    _totalRow('Total', data['total'], big: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (estado == 'pendiente')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelarPedido(context, doc),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar pedido'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    estado == 'cancelado'
                        ? 'Este pedido ya fue cancelado.'
                        : 'Este pedido ya no puede cancelarse desde la app.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) => 'S/. ${_number(value).toStringAsFixed(2)}';

  DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['creadoEn'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _quitarFavorito(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.delete();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plato quitado de favoritos.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _agregarAlCarrito(BuildContext context, Map<String, dynamic> data) {
    final producto = {
      'id': data['productId']?.toString() ?? data['id']?.toString() ?? '',
      'nombre': data['nombre']?.toString() ?? 'Producto',
      'categoria': data['categoria']?.toString() ?? 'Sin categoría',
      'descripcion': data['descripcion']?.toString() ?? '',
      'imagenUrl': data['imagenUrl']?.toString() ?? '',
      'precio': _number(data['precio']),
    };

    CartController.instance.addProduct(
      producto,
      precio: _number(data['precio']),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto['nombre']} agregado al carrito'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _imagen(String url) {
    if (url.trim().isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4BF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.restaurant_menu_rounded, color: negro),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: const Color(0xFFFFEBEE),
          child: const Icon(Icons.broken_image, color: Colors.red),
        ),
      ),
    );
  }

  Widget _favoritoCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final nombre = data['nombre']?.toString() ?? 'Producto';
    final categoria = data['categoria']?.toString() ?? 'Sin categoría';
    final imagenUrl = data['imagenUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _imagen(imagenUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  categoria,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(data['precio']),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton.filled(
                onPressed: () => _agregarAlCarrito(context, data),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: amarillo,
                  foregroundColor: negro,
                ),
              ),
              IconButton(
                onPressed: () => _quitarFavorito(context, doc),
                icon: const Icon(Icons.favorite_rounded, color: Colors.red),
                tooltip: 'Quitar de favoritos',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tus favoritos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inicia sesión para ver tus platos favoritos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(returnToPrevious: true),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tus favoritos')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('favoritos_restaurante')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar tus favoritos:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          );
          docs.sort((a, b) => _createdAt(b.data()).compareTo(_createdAt(a.data())));

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes platos favoritos. Toca el corazón de un plato para guardarlo aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _favoritoCard(context, docs[index]),
          );
        },
      ),
    );
  }
}

class ResenasScreen extends StatelessWidget {
  const ResenasScreen({super.key});

  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) => 'S/. ${_number(value).toStringAsFixed(2)}';

  String _estadoNormalizado(dynamic value) {
    final estado = value?.toString().trim().toLowerCase() ?? '';
    if (estado == 'entregado') return 'entregado';
    if (estado == 'listo') return 'listo';
    return estado;
  }

  DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['creadoEn'] ?? data['fecha'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fechaTexto(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Fecha pendiente';
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    return '$dia/$mes/${date.year}';
  }

  String _pedidoTitulo(String pedidoId) {
    return 'Pedido #${pedidoId.substring(0, pedidoId.length >= 6 ? 6 : pedidoId.length).toUpperCase()}';
  }

  String _productosResumen(Map<String, dynamic> data) {
    final rawItems = (data['items'] as List?) ?? (data['productos'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (items.isEmpty) return 'Sin detalle de productos';

    final nombres = items
        .take(3)
        .map((item) => '${item['cantidad'] ?? 1} x ${item['nombre'] ?? 'Producto'}')
        .join(', ');

    if (items.length <= 3) return nombres;
    return '$nombres y ${items.length - 3} más';
  }

  Future<void> _abrirDialogoResena(
    BuildContext context,
    User user,
    QueryDocumentSnapshot<Map<String, dynamic>> pedidoDoc, {
    Map<String, dynamic>? resenaExistente,
  }) async {
    final pedido = pedidoDoc.data();
    final controller = TextEditingController(
      text: resenaExistente?['comentario']?.toString() ?? '',
    );
    var calificacion = resenaExistente?['calificacion'] is num
        ? (resenaExistente?['calificacion'] as num).toInt()
        : 5;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(resenaExistente == null ? 'Dejar reseña' : 'Editar reseña'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pedidoTitulo(pedidoDoc.id),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _productosResumen(pedido),
                    style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Calificación',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      final selected = index < calificacion;
                      return IconButton(
                        onPressed: () => setDialogState(() => calificacion = index + 1),
                        icon: Icon(
                          selected ? Icons.star_rounded : Icons.star_border_rounded,
                          color: selected ? amarillo : Colors.black38,
                          size: 31,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      hintText: 'Cuenta cómo llegó tu pedido...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (guardar != true) return;

    final comentario = controller.text.trim();
    final rawItems = (pedido['items'] as List?) ?? (pedido['productos'] as List?) ?? const [];

    try {
      await FirebaseFirestore.instance
          .collection('resenas_restaurante')
          .doc(pedidoDoc.id)
          .set({
        'userId': user.uid,
        'email': user.email ?? '',
        'pedidoId': pedidoDoc.id,
        'calificacion': calificacion,
        'comentario': comentario,
        'productosResumen': _productosResumen(pedido),
        'items': rawItems,
        'total': _number(pedido['total']),
        'estadoPedido': pedido['estado']?.toString() ?? 'entregado',
        'creadoEn': resenaExistente == null
            ? FieldValue.serverTimestamp()
            : resenaExistente['creadoEn'] ?? FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reseña guardada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la reseña: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4BF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.w900, color: negro),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: amarillo,
          size: 20,
        );
      }),
    );
  }

  Widget _pedidoResenaCard(
    BuildContext context,
    User user,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? resena,
  ) {
    final data = doc.data();
    final reviewed = resena != null;
    final rating = resena?['calificacion'] is num
        ? (resena?['calificacion'] as num).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _pedidoTitulo(doc.id),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: reviewed ? Colors.green.shade50 : const Color(0xFFFFF4BF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reviewed ? 'Reseñado' : 'Falta reseñar',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_fechaTexto(_createdAt(data))} · Total ${_money(data['total'])}',
            style: const TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Text(
            _productosResumen(data),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (reviewed) ...[
            const SizedBox(height: 10),
            _stars(rating),
            if ((resena['comentario']?.toString().trim() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                resena['comentario'].toString(),
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: reviewed
                ? OutlinedButton.icon(
                    onPressed: () => _abrirDialogoResena(
                      context,
                      user,
                      doc,
                      resenaExistente: resena,
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar reseña'),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _abrirDialogoResena(context, user, doc),
                    icon: const Icon(Icons.star_rate_rounded),
                    label: const Text('Reseñar pedido'),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tus reseñas')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inicia sesión para ver tus reseñas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(returnToPrevious: true),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tus reseñas')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pedidos_restaurante')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, pedidosSnapshot) {
          if (pedidosSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar tus pedidos:\n${pedidosSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
              ),
            );
          }

          if (pedidosSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pedidos = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            pedidosSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )
              .where((doc) => _estadoNormalizado(doc.data()['estado']) == 'entregado')
              .toList();
          pedidos.sort((a, b) => _createdAt(b.data()).compareTo(_createdAt(a.data())));

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('resenas_restaurante')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, resenasSnapshot) {
              if (resenasSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar tus reseñas:\n${resenasSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }

              if (resenasSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final resenas = <String, Map<String, dynamic>>{};
              for (final doc in resenasSnapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                final data = doc.data();
                final pedidoId = data['pedidoId']?.toString() ?? doc.id;
                resenas[pedidoId] = data;
              }

              final pendientes = pedidos.where((doc) => !resenas.containsKey(doc.id)).toList();
              final resenados = pedidos.where((doc) => resenas.containsKey(doc.id)).toList();

              if (pedidos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Cuando tengas pedidos entregados, aparecerán aquí para reseñarlos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _sectionTitle('Falta reseñar', pendientes.length),
                  if (pendientes.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No tienes pedidos pendientes de reseña.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    ...pendientes.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _pedidoResenaCard(context, user, doc, null),
                      ),
                    ),
                  _sectionTitle('Reseñados', resenados.length),
                  if (resenados.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Aún no has reseñado pedidos.',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    ...resenados.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _pedidoResenaCard(context, user, doc, resenas[doc.id]),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
