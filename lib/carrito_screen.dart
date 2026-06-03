import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'auth_screen.dart';
import 'auth_service.dart';
import 'cart_controller.dart';
import 'delivery_service.dart';
import 'mapa_entrega_screen.dart';
import 'tu_screen.dart';

class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi carrito')),
      body: const CarritoView(),
    );
  }
}

class CarritoView extends StatefulWidget {
  final bool showTitle;

  const CarritoView({
    super.key,
    this.showTitle = true,
  });

  @override
  State<CarritoView> createState() => _CarritoViewState();
}

class _CarritoViewState extends State<CarritoView> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  final CartController _cart = CartController.instance;

  DeliveryEstimate? _delivery;
  bool _loadingDelivery = false;
  bool _savingOrder = false;
  String? _deliveryError;


  double get _total => _cart.subtotal + (_delivery?.costoDelivery ?? 0);

  String _money(double value) => 'S/. ${value.toStringAsFixed(2)}';

  Widget _image(String imagenUrl) {
    if (imagenUrl.trim().isEmpty) {
      return Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4BF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.restaurant_menu_rounded, color: negro),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imagenUrl,
        width: 66,
        height: 66,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 66,
          height: 66,
          color: const Color(0xFFFFEBEE),
          child: const Icon(Icons.broken_image, color: Colors.red),
        ),
      ),
    );
  }


  Future<void> _confirmarQuitar(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar producto'),
        content: Text('¿Deseas quitar "${item.nombre}" del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _cart.remove(item.lineId);

    if (_cart.isEmpty && mounted) {
      setState(() => _delivery = null);
    }
  }


  Future<void> _abrirMapaEntrega() async {
    final ubicacion = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapaEntregaScreen(),
      ),
    );

    if (ubicacion == null) return;

    await _calcularManual(ubicacion.latitude, ubicacion.longitude);
  }

  Future<void> _calcularManual(double lat, double lng) async {
    setState(() {
      _loadingDelivery = true;
      _deliveryError = null;
    });

    try {
      final estimate = await DeliveryService.calcularConCoordenadas(
        clienteLat: lat,
        clienteLng: lng,
      );
      if (!mounted) return;
      setState(() {
        _delivery = estimate;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deliveryError = 'No se pudo calcular el delivery: $e');
    } finally {
      if (mounted) setState(() => _loadingDelivery = false);
    }
  }

  Future<bool> _asegurarLogin() async {
    if (AuthService().currentUser != null) return true;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(returnToPrevious: true),
      ),
    );

    return result == true || AuthService().currentUser != null;
  }

  Future<void> _confirmarPedido() async {
    if (_cart.isEmpty || _savingOrder) return;

    if (_delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero elige y confirma tu ubicación de entrega en el mapa.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_delivery?.dentroZona == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ubicación está fuera de la zona de delivery configurada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final logged = await _asegurarLogin();
    if (!logged) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _savingOrder = true);

    try {
      final delivery = _delivery!;
      final config = await DeliveryService.loadConfig();
      final orderRef = await FirebaseFirestore.instance.collection('pedidos_restaurante').add({
        'userId': user.uid,
        'email': user.email,
        'items': _cart.items.map((item) => item.toMap()).toList(),
        'subtotal': _cart.subtotal,
        'delivery': delivery.costoDelivery,
        'total': _total,
        'restauranteUbicacion': {
          'lat': config.restaurantLat,
          'lng': config.restaurantLng,
        },
        'ubicacionCliente': {
          'lat': delivery.clienteLat,
          'lng': delivery.clienteLng,
        },
        'distanciaKm': delivery.distanciaKm,
        'distanciaTexto': delivery.distanciaTexto,
        'duracionTexto': delivery.duracionTexto,
        'rutaPolyline': delivery.rutaPolyline,
        'estado': 'pendiente',
        'pagoEstado': 'pendiente',
        'metodoPago': 'pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
        'estadoActualizadoEn': FieldValue.serverTimestamp(),
      });

      _cart.clear();
      if (!mounted) return;
      setState(() => _delivery = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido registrado. Puedes revisar su detalle y cancelarlo si aún está pendiente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PedidoDetalleScreen(pedidoId: orderRef.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el pedido: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Widget _emptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: amarillo,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 48, color: negro),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega platos desde Inicio o Categorías.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartItem(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _image(item.imagenUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  item.variante == 'Normal'
                      ? item.categoria
                      : '${item.categoria} · ${item.variante}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(item.precioUnitario)} c/u',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: negro),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyButton(Icons.remove_rounded, () => _cart.decrease(item.lineId)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.cantidad}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _qtyButton(Icons.add_rounded, () => _cart.increase(item.lineId)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _money(item.subtotal),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              TextButton.icon(
                onPressed: () => _confirmarQuitar(item),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Quitar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: amarillo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 18, color: negro),
      ),
    );
  }

  Widget _deliveryBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delivery_dining_rounded, color: negro),
              SizedBox(width: 8),
              Text(
                'Delivery en Huancayo',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Primero confirma tu punto de entrega en el mapa. La app abrirá tu ubicación detectada y podrás mover el marcador si el GPS no es exacto.',
            style: TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingDelivery ? null : _abrirMapaEntrega,
              icon: _loadingDelivery
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.map_rounded),
              label: Text(
                _delivery == null
                    ? 'Elegir ubicación en el mapa'
                    : 'Cambiar ubicación de entrega',
              ),
            ),
          ),
          if (_deliveryError != null) ...[
            const SizedBox(height: 10),
            Text(
              _deliveryError!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ],
          if (_delivery != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _delivery!.dentroZona ? const Color(0xFFFFFAE5) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distancia: ${_delivery!.distanciaTexto}'),
                  Text('Tiempo aprox.: ${_delivery!.duracionTexto}'),
                  Text('Delivery: ${_money(_delivery!.costoDelivery)}'),
                  if (!_delivery!.dentroZona)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Fuera de la zona configurada para delivery.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _totalRow('Subtotal', _cart.subtotal),
            const SizedBox(height: 8),
            _totalRow('Delivery', _delivery?.costoDelivery ?? 0),
            const Divider(height: 24),
            _totalRow('Total', _total, big: true),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _savingOrder ? null : _confirmarPedido,
                icon: _savingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Confirmar pedido'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'La pasarela de pago aún no se implementa. El pedido queda como pendiente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 18 : 14,
            fontWeight: big ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: big ? 22 : 15,
            fontWeight: FontWeight.w900,
            color: negro,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        if (_cart.isEmpty) return _emptyCart();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _cart.items.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Row(
                      children: [
                        if (widget.showTitle)
                          const Expanded(
                            child: Text(
                              'Mi carrito',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          )
                        else
                          const Expanded(
                            child: Text(
                              'Revisa tu pedido',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _cart.clear,
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Vaciar'),
                        ),
                      ],
                    );
                  }

                  if (index == _cart.items.length + 1) {
                    return _deliveryBox();
                  }

                  return _cartItem(_cart.items[index - 1]);
                },
              ),
            ),
            _summary(),
          ],
        );
      },
    );
  }
}
