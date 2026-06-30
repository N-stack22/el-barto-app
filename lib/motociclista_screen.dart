import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'auth_service.dart';
import 'delivery_service.dart';

class MotociclistaScreen extends StatefulWidget {
  const MotociclistaScreen({super.key});

  @override
  State<MotociclistaScreen> createState() => _MotociclistaScreenState();
}

class _MotociclistaScreenState extends State<MotociclistaScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  final Map<String, Future<String>> _clienteTelefonoCache = {};

  User? get _user => FirebaseAuth.instance.currentUser;

  double _moneyNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) =>
      'S/ ${_moneyNumber(value).toStringAsFixed(2)}';

  String _textField(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final text = data[field]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  dynamic _firstValue(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      if (data.containsKey(field) && data[field] != null) return data[field];
    }
    return null;
  }

  List<Map<String, dynamic>> _itemsFrom(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    if (raw is Map) {
      return raw.values.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final raw = _firstValue(data, [
      'items',
      'productos',
      'platos',
      'detalleItems',
      'productosPedido',
    ]);
    final direct = _itemsFrom(raw);
    if (direct.isNotEmpty) return direct;

    for (final parentKey in ['pedido', 'detalle', 'orden', 'carrito']) {
      final parent = _asMap(data[parentKey]);
      if (parent == null) continue;
      final nested = _itemsFrom(
        _firstValue(parent, ['items', 'productos', 'platos', 'lineas']),
      );
      if (nested.isNotEmpty) return nested;
    }
    return const [];
  }

  String _itemNombre(Map<String, dynamic> item) {
    final text = _textField(item, [
      'nombre',
      'producto',
      'productoNombre',
      'nombreProducto',
      'name',
      'title',
    ]);
    return text.isEmpty ? 'Producto' : text;
  }

  String _itemCantidad(Map<String, dynamic> item) {
    final value = _firstValue(item, [
      'cantidad',
      'qty',
      'quantity',
      'unidades',
    ]);
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '1' : text;
  }

  String _itemVariante(Map<String, dynamic> item) {
    return _textField(item, [
      'variante',
      'tamano',
      'tamanio',
      'size',
      'presentacion',
    ]);
  }

  String _clienteTelefono(Map<String, dynamic> data) {
    final direct = _textField(data, [
      'clienteTelefono',
      'telefonoCliente',
      'clienteCelular',
      'celularCliente',
      'telefonoUsuario',
      'numeroTelefono',
      'numeroCelular',
      'telefono',
      'celular',
      'phone',
      'whatsapp',
      'clienteWhatsapp',
    ]);
    if (direct.isNotEmpty) return direct;

    for (final parentKey in [
      'cliente',
      'usuario',
      'perfilCliente',
      'customer',
      'datosCliente',
      'contacto',
      'direccion',
    ]) {
      final parent = _asMap(data[parentKey]);
      if (parent == null) continue;
      final nested = _clienteTelefono(parent);
      if (nested.isNotEmpty) return nested;
    }

    return '';
  }

  String _clienteEmail(Map<String, dynamic> data) {
    return _textField(data, ['clienteEmail', 'email', 'correo', 'userEmail']);
  }

  String _clienteUid(Map<String, dynamic> data) {
    return _textField(data, [
      'userId',
      'clienteId',
      'clienteUid',
      'usuarioId',
      'uid',
    ]);
  }

  Future<String> _loadClienteTelefono(Map<String, dynamic> data) async {
    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return direct;

    final users = FirebaseFirestore.instance.collection('usuarios');
    final uid = _clienteUid(data);
    if (uid.isNotEmpty) {
      try {
        final doc = await users.doc(uid).get();
        final phone = _clienteTelefono(doc.data() ?? const {});
        if (phone.isNotEmpty) return phone;
      } catch (_) {}
    }

    final email = _clienteEmail(data);
    if (email.isNotEmpty) {
      try {
        final query = await users
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final phone = _clienteTelefono(query.docs.first.data());
          if (phone.isNotEmpty) return phone;
        }
      } catch (_) {}
    }

    return '';
  }

  Future<String> _clienteTelefonoFuture(Map<String, dynamic> data) {
    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return Future.value(direct);
    final uid = _clienteUid(data);
    final email = _clienteEmail(data);
    final cacheKey = uid.isNotEmpty
        ? 'uid:$uid'
        : email.isNotEmpty
        ? 'email:$email'
        : data.hashCode.toString();
    return _clienteTelefonoCache.putIfAbsent(
      cacheKey,
      () => _loadClienteTelefono(data),
    );
  }

  Widget _clienteTelefonoLine(Map<String, dynamic> data) {
    Widget row(String text, {bool muted = false}) {
      return Row(
        children: [
          Icon(
            Icons.phone_rounded,
            size: 18,
            color: muted ? Colors.black38 : negro,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: muted ? Colors.black38 : Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return row(direct);

    return FutureBuilder<String>(
      future: _clienteTelefonoFuture(data),
      builder: (context, snapshot) {
        final phone = snapshot.data?.trim() ?? '';
        if (phone.isNotEmpty) return row(phone);
        if (snapshot.connectionState != ConnectionState.done) {
          return row('Buscando celular...', muted: true);
        }
        return row('Celular no registrado', muted: true);
      },
    );
  }

  Widget _pedidoItemsList(Map<String, dynamic> data) {
    final items = _items(data);
    if (items.isEmpty) {
      return const Text(
        'Pedido sin detalle',
        style: TextStyle(fontWeight: FontWeight.w800),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text(
            '${_itemCantidad(item)} x ${_itemNombre(item)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (_itemVariante(item).isNotEmpty && _itemVariante(item) != 'Normal')
            Text(
              _itemVariante(item),
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  double _ganancia(Map<String, dynamic> data) {
    final ganancia = data['gananciaRepartidor'];
    if (ganancia is num) return ganancia.toDouble();
    final delivery = _moneyNumber(data['delivery']);
    return double.parse(math.max(3.0, delivery * 0.70).toStringAsFixed(2));
  }

  String _rutaResumen(Map<String, dynamic> data) {
    final distancia = data['distanciaTexto']?.toString() ?? '';
    final duracion = data['duracionTexto']?.toString() ?? '';
    final partes = [distancia, duracion].where((e) => e.isNotEmpty).toList();
    return partes.isEmpty
        ? 'Ruta local → cliente por calcular'
        : partes.join(' · ');
  }

  Widget _topResumen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: negro,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: amarillo,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              size: 30,
              color: negro,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo motociclista',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Toca un pedido para ver el mapa, revisar la ruta y aceptar o rechazar.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async => AuthService().logout(),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }

  Widget _pedidoDisponibleCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ganancia = _ganancia(data);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MotociclistaMapaScreen(pedidoId: doc.id),
        ),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 7),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: amarillo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ganas ${_money(ganancia)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _pedidoItemsList(data),
            const SizedBox(height: 8),
            _clienteTelefonoLine(data),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18, color: negro),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Local → Cliente · ${_rutaResumen(data)}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MotociclistaMapaScreen(pedidoId: doc.id),
                  ),
                ),
                icon: const Icon(Icons.map_rounded),
                label: const Text('Ver en mapa y decidir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pedidoActivoCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final estado = data['estado']?.toString() ?? 'en_camino_local';
    final ganancia = _ganancia(data);
    final label = estado == 'en_camino_local'
        ? 'Aceptado · ve al local'
        : estado == 'en_camino'
        ? 'En ruta al cliente'
        : 'Pedido activo';
    final statusLabel = estado == 'en_preparacion'
        ? 'Asignado - esperando cocina'
        : estado == 'listo'
        ? 'Listo - recoge en local'
        : label;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MotociclistaMapaScreen(pedidoId: doc.id),
        ),
      ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4BF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: amarillo),
        ),
        child: Row(
          children: [
            const Icon(Icons.navigation_rounded, size: 30, color: negro),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido #${doc.id.substring(0, doc.id.length >= 6 ? 6 : doc.id.length).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ganancia ${_money(ganancia)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 32),
          ],
        ),
      ),
    );
  }

  Widget _activeOrderSection(User user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pedidos_restaurante')
          .where('repartidorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final estado = doc.data()['estado']?.toString();
          return estado == 'en_preparacion' ||
              estado == 'listo' ||
              estado == 'en_camino_local' ||
              estado == 'en_camino';
        }).toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Pedido actual',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _pedidoActivoCard(docs.first),
          ],
        );
      },
    );
  }

  Widget _availableOrders(User user) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pedidos_restaurante')
          .where('estado', whereIn: ['en_preparacion', 'listo'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Error al cargar pedidos: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();
          final asignado = data['repartidorAsignado'] == true;
          final rechazados =
              (data['rechazadosPor'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{};
          return !asignado && !rechazados.contains(user.uid);
        }).toList();

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'No hay pedidos disponibles por ahora. Cuando cocina marque un pedido como listo, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Column(
          children: docs
              .map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _pedidoDisponibleCard(doc),
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión como motociclista.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('El Barto Delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _topResumen(),
          _activeOrderSection(user),
          const SizedBox(height: 16),
          const Text(
            'Pedidos para enviar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _availableOrders(user),
        ],
      ),
    );
  }
}

class MotociclistaMapaScreen extends StatefulWidget {
  final String pedidoId;

  const MotociclistaMapaScreen({super.key, required this.pedidoId});

  @override
  State<MotociclistaMapaScreen> createState() => _MotociclistaMapaScreenState();
}

class _MotociclistaMapaScreenState extends State<MotociclistaMapaScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pedidoSub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _sensorSub;

  Map<String, dynamic>? _pedidoData;
  Position? _posicionActual;
  LatLng? _ultimaUbicacion;
  double _velocidadKmh = 0;
  double _rumbo = 0;
  double _fuerza = 0;
  String _movimiento = 'detenido';
  String? _error;
  int _ultimoSetStateSensorMs = 0;
  int _ultimoEnvioFirestoreMs = 0;
  GoogleMapController? _mapController;
  final Map<String, Future<String>> _clienteTelefonoCache = {};

  User? get _user => FirebaseAuth.instance.currentUser;

  String _textField(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final text = data[field]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  dynamic _firstValue(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      if (data.containsKey(field) && data[field] != null) return data[field];
    }
    return null;
  }

  List<Map<String, dynamic>> _itemsFrom(dynamic raw) {
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    if (raw is Map) {
      return raw.values.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final raw = _firstValue(data, [
      'items',
      'productos',
      'platos',
      'detalleItems',
      'productosPedido',
    ]);
    final direct = _itemsFrom(raw);
    if (direct.isNotEmpty) return direct;

    for (final parentKey in ['pedido', 'detalle', 'orden', 'carrito']) {
      final parent = _asMap(data[parentKey]);
      if (parent == null) continue;
      final nested = _itemsFrom(
        _firstValue(parent, ['items', 'productos', 'platos', 'lineas']),
      );
      if (nested.isNotEmpty) return nested;
    }
    return const [];
  }

  String _itemNombre(Map<String, dynamic> item) {
    final text = _textField(item, [
      'nombre',
      'producto',
      'productoNombre',
      'nombreProducto',
      'name',
      'title',
    ]);
    return text.isEmpty ? 'Producto' : text;
  }

  String _itemCantidad(Map<String, dynamic> item) {
    final value = _firstValue(item, [
      'cantidad',
      'qty',
      'quantity',
      'unidades',
    ]);
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '1' : text;
  }

  String _itemVariante(Map<String, dynamic> item) {
    return _textField(item, [
      'variante',
      'tamano',
      'tamanio',
      'size',
      'presentacion',
    ]);
  }

  String _clienteTelefono(Map<String, dynamic> data) {
    final direct = _textField(data, [
      'clienteTelefono',
      'telefonoCliente',
      'clienteCelular',
      'celularCliente',
      'telefonoUsuario',
      'numeroTelefono',
      'numeroCelular',
      'telefono',
      'celular',
      'phone',
      'whatsapp',
      'clienteWhatsapp',
    ]);
    if (direct.isNotEmpty) return direct;

    for (final parentKey in [
      'cliente',
      'usuario',
      'perfilCliente',
      'customer',
      'datosCliente',
      'contacto',
      'direccion',
    ]) {
      final parent = _asMap(data[parentKey]);
      if (parent == null) continue;
      final nested = _clienteTelefono(parent);
      if (nested.isNotEmpty) return nested;
    }

    return '';
  }

  String _clienteEmail(Map<String, dynamic> data) {
    return _textField(data, ['clienteEmail', 'email', 'correo', 'userEmail']);
  }

  String _clienteUid(Map<String, dynamic> data) {
    return _textField(data, [
      'userId',
      'clienteId',
      'clienteUid',
      'usuarioId',
      'uid',
    ]);
  }

  Future<String> _loadClienteTelefono(Map<String, dynamic> data) async {
    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return direct;

    final users = FirebaseFirestore.instance.collection('usuarios');
    final uid = _clienteUid(data);
    if (uid.isNotEmpty) {
      try {
        final doc = await users.doc(uid).get();
        final phone = _clienteTelefono(doc.data() ?? const {});
        if (phone.isNotEmpty) return phone;
      } catch (_) {}
    }

    final email = _clienteEmail(data);
    if (email.isNotEmpty) {
      try {
        final query = await users
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final phone = _clienteTelefono(query.docs.first.data());
          if (phone.isNotEmpty) return phone;
        }
      } catch (_) {}
    }

    return '';
  }

  Future<String> _clienteTelefonoFuture(Map<String, dynamic> data) {
    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return Future.value(direct);
    final uid = _clienteUid(data);
    final email = _clienteEmail(data);
    final cacheKey = uid.isNotEmpty
        ? 'uid:$uid'
        : email.isNotEmpty
        ? 'email:$email'
        : data.hashCode.toString();
    return _clienteTelefonoCache.putIfAbsent(
      cacheKey,
      () => _loadClienteTelefono(data),
    );
  }

  Widget _clienteTelefonoLine(Map<String, dynamic> data) {
    Widget row(String text, {bool muted = false}) {
      return Row(
        children: [
          Icon(
            Icons.phone_rounded,
            size: 18,
            color: muted ? Colors.black38 : negro,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: muted ? Colors.black38 : Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    final direct = _clienteTelefono(data);
    if (direct.isNotEmpty) return row(direct);

    return FutureBuilder<String>(
      future: _clienteTelefonoFuture(data),
      builder: (context, snapshot) {
        final phone = snapshot.data?.trim() ?? '';
        if (phone.isNotEmpty) return row(phone);
        if (snapshot.connectionState != ConnectionState.done) {
          return row('Buscando celular...', muted: true);
        }
        return row('Celular no registrado', muted: true);
      },
    );
  }

  Widget _pedidoItemsList(Map<String, dynamic> data) {
    final items = _items(data);
    if (items.isEmpty) {
      return const Text(
        'Pedido sin detalle',
        style: TextStyle(fontWeight: FontWeight.w800),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text(
            '${_itemCantidad(item)} x ${_itemNombre(item)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (_itemVariante(item).isNotEmpty && _itemVariante(item) != 'Normal')
            Text(
              _itemVariante(item),
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _escucharPedido();
    _iniciarUbicacion();
    _iniciarSensores();
  }

  @override
  void dispose() {
    _pedidoSub?.cancel();
    _positionSub?.cancel();
    _sensorSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _escucharPedido() {
    _pedidoSub = FirebaseFirestore.instance
        .collection('pedidos_restaurante')
        .doc(widget.pedidoId)
        .snapshots()
        .listen(
          (doc) {
            final data = doc.data();
            if (data == null) {
              if (mounted) setState(() => _error = 'Pedido no encontrado.');
              return;
            }

            if (_pedidoData == null ||
                _hayCambioImportante(_pedidoData!, data)) {
              if (mounted) setState(() => _pedidoData = data);
            }
          },
          onError: (e) {
            if (mounted)
              setState(() => _error = 'No se pudo cargar el pedido: $e');
          },
        );
  }

  bool _hayCambioImportante(
    Map<String, dynamic> anterior,
    Map<String, dynamic> actual,
  ) {
    const keys = [
      'estado',
      'repartidorAsignado',
      'repartidorId',
      'repartidorNombre',
      'gananciaRepartidor',
      'items',
      'delivery',
      'total',
      'distanciaTexto',
      'duracionTexto',
      'rutaPolyline',
      'ubicacionCliente',
      'restauranteUbicacion',
      'rechazadosPor',
    ];
    for (final key in keys) {
      if (anterior[key].toString() != actual[key].toString()) return true;
    }
    return false;
  }

  Future<void> _iniciarUbicacion() async {
    try {
      await DeliveryService.obtenerUbicacionActual();
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _onPosition(current, enviarFirestore: false);

      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      );
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (pos) => _onPosition(pos),
            onError: (e) {
              if (mounted)
                setState(() => _error = 'Activa el GPS para seguimiento: $e');
            },
          );
    } catch (e) {
      if (mounted)
        setState(() => _error = 'Activa ubicación para usar el mapa: $e');
    }
  }

  void _iniciarSensores() {
    _sensorSub = SensorsPlatform.instance.userAccelerometerEventStream().listen(
      (e) {
        final fuerza = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        final gpsRapido = _velocidadKmh >= 5;
        final nuevoMovimiento = gpsRapido || fuerza > 0.60
            ? (fuerza > 3.2 ? 'movimiento_fuerte' : 'en_movimiento')
            : 'detenido';

        final cambio = nuevoMovimiento != _movimiento;
        _fuerza = fuerza;
        _movimiento = nuevoMovimiento;

        final ahora = DateTime.now().millisecondsSinceEpoch;
        if (mounted && (cambio || ahora - _ultimoSetStateSensorMs > 1800)) {
          setState(() => _ultimoSetStateSensorMs = ahora);
        }
      },
    );
  }

  double _bearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _onPosition(Position position, {bool enviarFirestore = true}) {
    final actual = LatLng(position.latitude, position.longitude);
    final anterior = _ultimaUbicacion;
    final velocidad = math.max(0.0, position.speed * 3.6);
    final rumbo = anterior == null ? _rumbo : _bearing(anterior, actual);

    if (!mounted) return;
    setState(() {
      _posicionActual = position;
      _velocidadKmh = velocidad;
      _rumbo = velocidad >= 2 ? rumbo : _rumbo;
      _ultimaUbicacion = actual;
      if (velocidad >= 5) _movimiento = 'en_movimiento';
      if (velocidad < 2 && _fuerza < 0.60) _movimiento = 'detenido';
    });

    if (enviarFirestore) _guardarUbicacionRepartidor();
  }

  Future<String> _nombreRepartidor() async {
    final user = _user;
    if (user == null) return 'Motociclista';
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();
    final data = doc.data();
    final nombreCompleto = data?['nombreCompleto']?.toString().trim();
    final nombres = data?['nombres']?.toString().trim();
    if (nombreCompleto != null && nombreCompleto.isNotEmpty)
      return nombreCompleto;
    if (nombres != null && nombres.isNotEmpty) return nombres;
    return user.email?.split('@').first ?? 'Motociclista';
  }

  Future<void> _guardarUbicacionRepartidor({bool forzar = false}) async {
    final user = _user;
    final pos = _posicionActual;
    final data = _pedidoData;
    if (user == null || pos == null || data == null) return;

    final estado = data['estado']?.toString() ?? '';
    final asignadoAMi = data['repartidorId']?.toString() == user.uid;
    if (!asignadoAMi || !(estado == 'en_camino_local' || estado == 'en_camino'))
      return;

    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (!forzar && ahora - _ultimoEnvioFirestoreMs < 3500) return;
    _ultimoEnvioFirestoreMs = ahora;

    final tracking = {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'velocidadKmh': double.parse(_velocidadKmh.toStringAsFixed(1)),
      'rumbo': double.parse(_rumbo.toStringAsFixed(1)),
      'movimiento': _movimiento,
      'fuerzaSensor': double.parse(_fuerza.toStringAsFixed(2)),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('repartidores')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'email': user.email,
          'activo': true,
          ...tracking,
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('pedidos_restaurante')
        .doc(widget.pedidoId)
        .set({
          'repartidorLat': pos.latitude,
          'repartidorLng': pos.longitude,
          'repartidorVelocidadKmh': tracking['velocidadKmh'],
          'repartidorMovimiento': _movimiento,
          'repartidorRumbo': tracking['rumbo'],
          'repartidorActualizadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  double _moneyNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(dynamic value) =>
      'S/ ${_moneyNumber(value).toStringAsFixed(2)}';

  double _ganancia(Map<String, dynamic> data) {
    final ganancia = data['gananciaRepartidor'];
    if (ganancia is num) return ganancia.toDouble();
    final delivery = _moneyNumber(data['delivery']);
    return double.parse(math.max(3.0, delivery * 0.70).toStringAsFixed(2));
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

  Future<void> _aceptarPedido() async {
    final user = _user;
    final data = _pedidoData;
    if (user == null || data == null) return;
    final pos = _posicionActual;
    final nombre = await _nombreRepartidor();
    final ganancia = _ganancia(data);

    try {
      final ref = FirebaseFirestore.instance
          .collection('pedidos_restaurante')
          .doc(widget.pedidoId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final fresh = await transaction.get(ref);
        final freshData = fresh.data();
        if (freshData == null) throw Exception('Pedido no encontrado');
        final estadoActual = freshData['estado']?.toString() ?? '';
        if (estadoActual != 'en_preparacion' && estadoActual != 'listo') {
          throw Exception(
            'El pedido todavia no fue aceptado por administracion',
          );
        }
        final asignado = freshData['repartidorAsignado'] == true;
        final repartidorActual = freshData['repartidorId']?.toString();
        if (asignado && repartidorActual != user.uid) {
          throw Exception('Este pedido ya fue tomado por otro repartidor');
        }
        transaction.update(ref, {
          'estado': estadoActual == 'listo' ? 'en_camino_local' : estadoActual,
          'seguimientoActivo': true,
          'repartidorAsignado': true,
          'repartidorId': user.uid,
          'repartidorNombre': nombre,
          'repartidorEmail': user.email,
          'repartidorLat': pos?.latitude,
          'repartidorLng': pos?.longitude,
          'repartidorVelocidadKmh': double.parse(
            _velocidadKmh.toStringAsFixed(1),
          ),
          'repartidorMovimiento': _movimiento,
          'repartidorRumbo': double.parse(_rumbo.toStringAsFixed(1)),
          'gananciaRepartidor': ganancia,
          'aceptadoEn': FieldValue.serverTimestamp(),
          'estadoActualizadoEn': FieldValue.serverTimestamp(),
          'repartidorActualizadoEn': FieldValue.serverTimestamp(),
        });
      });
      await _guardarUbicacionRepartidor(forzar: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido aceptado. Ve al restaurante a recogerlo.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo aceptar: $e')));
    }
  }

  Future<void> _rechazarPedido() async {
    final user = _user;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('pedidos_restaurante')
        .doc(widget.pedidoId)
        .set({
          'rechazadosPor': FieldValue.arrayUnion([user.uid]),
          'ultimoRechazoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pedido rechazado. Se libera para otro repartidor.'),
      ),
    );
  }

  Future<void> _cambiarEstado(String estado) async {
    await FirebaseFirestore.instance
        .collection('pedidos_restaurante')
        .doc(widget.pedidoId)
        .set({
          'estado': estado,
          'estadoActualizadoEn': FieldValue.serverTimestamp(),
          if (estado == 'en_camino') 'recogidoEn': FieldValue.serverTimestamp(),
          if (estado == 'entregado')
            'entregadoEn': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await _guardarUbicacionRepartidor(forzar: true);
  }

  LatLng _restaurante(Map<String, dynamic> data) {
    final restauranteMap = _asMap(data['restauranteUbicacion']);
    final restLat = _coord(restauranteMap, 'lat') ?? -12.039447;
    final restLng = _coord(restauranteMap, 'lng') ?? -75.227225;
    return LatLng(restLat, restLng);
  }

  LatLng? _cliente(Map<String, dynamic> data) {
    final clienteMap = _asMap(data['ubicacionCliente']);
    final clienteLat = _coord(clienteMap, 'lat');
    final clienteLng = _coord(clienteMap, 'lng');
    return clienteLat != null && clienteLng != null
        ? LatLng(clienteLat, clienteLng)
        : null;
  }

  Widget _mapa(Map<String, dynamic> data) {
    final restaurante = _restaurante(data);
    final cliente = _cliente(data);
    final rider = _posicionActual == null
        ? null
        : LatLng(_posicionActual!.latitude, _posicionActual!.longitude);
    final center = cliente == null
        ? restaurante
        : LatLng(
            (restaurante.latitude + cliente.latitude) / 2,
            (restaurante.longitude + cliente.longitude) / 2,
          );
    final polyline = data['rutaPolyline']?.toString() ?? '';
    final routePoints = polyline.isNotEmpty
        ? _decodePolyline(polyline)
        : <LatLng>[restaurante, if (cliente != null) cliente];
    final detenido = _movimiento == 'detenido' || _velocidadKmh < 2;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13.2),
      onMapCreated: (controller) => _mapController = controller,
      markers: {
        Marker(
          markerId: const MarkerId('restaurante'),
          position: restaurante,
          infoWindow: const InfoWindow(title: 'A: El Barto'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
        if (cliente != null)
          Marker(
            markerId: const MarkerId('cliente'),
            position: cliente,
            infoWindow: const InfoWindow(title: 'B: Cliente'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        if (rider != null && !detenido)
          Marker(
            markerId: const MarkerId('repartidor'),
            position: rider,
            flat: true,
            rotation: _rumbo,
            anchor: const Offset(0.5, 0.5),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: const InfoWindow(title: 'Tu ubicación'),
          ),
      },
      circles: {
        if (rider != null && detenido)
          Circle(
            circleId: const CircleId('repartidor_detenido'),
            center: rider,
            radius: 18,
            strokeWidth: 3,
            strokeColor: Colors.blue,
            fillColor: Colors.blue.withOpacity(0.20),
          ),
      },
      polylines: {
        if (routePoints.length >= 2)
          Polyline(
            polylineId: const PolylineId('ruta_local_cliente'),
            points: routePoints,
            color: negro,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  Widget _bottomPanel(Map<String, dynamic> data) {
    final user = _user;
    final estado = data['estado']?.toString() ?? 'pendiente';
    final asignado = data['repartidorAsignado'] == true;
    final asignadoAMi =
        user != null && data['repartidorId']?.toString() == user.uid;
    final ganancia = _ganancia(data);
    final distancia = data['distanciaTexto']?.toString() ?? '';
    final duracion = data['duracionTexto']?.toString() ?? '';

    Widget primaryButton;
    Widget? secondaryButton;

    if (!asignado && (estado == 'en_preparacion' || estado == 'listo')) {
      primaryButton = ElevatedButton.icon(
        onPressed: _aceptarPedido,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Aceptar pedido'),
      );
      secondaryButton = OutlinedButton.icon(
        onPressed: _rechazarPedido,
        icon: const Icon(Icons.close_rounded),
        label: const Text('Rechazar'),
      );
    } else if (asignadoAMi && estado == 'en_preparacion') {
      primaryButton = ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.restaurant_rounded),
        label: const Text('Esperando cocina'),
      );
    } else if (asignadoAMi &&
        (estado == 'listo' || estado == 'en_camino_local')) {
      primaryButton = ElevatedButton.icon(
        onPressed: () => _cambiarEstado('en_camino'),
        icon: const Icon(Icons.delivery_dining_rounded),
        label: const Text('Pedido recogido / iniciar ruta'),
      );
    } else if (asignadoAMi && estado == 'en_camino') {
      primaryButton = ElevatedButton.icon(
        onPressed: () => _cambiarEstado('entregado'),
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Marcar entregado'),
      );
    } else if (estado == 'entregado') {
      primaryButton = ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.done_all_rounded),
        label: const Text('Pedido entregado'),
      );
    } else if (asignado && !asignadoAMi) {
      primaryButton = ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_rounded),
        label: const Text('Pedido tomado por otro repartidor'),
      );
    } else {
      primaryButton = ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_bottom_rounded),
        label: Text('Estado: $estado'),
      );
    }

    final movimientoTexto = _movimiento == 'detenido'
        ? 'Detenido'
        : _movimiento == 'movimiento_fuerte'
        ? 'Movimiento fuerte'
        : 'En movimiento';

    return Positioned(
      left: 14,
      right: 14,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Local → Cliente',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: amarillo,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ganas ${_money(ganancia)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _pedidoItemsList(data),
              const SizedBox(height: 6),
              _clienteTelefonoLine(data),
              const SizedBox(height: 6),
              Text(
                '${distancia.isEmpty ? 'Distancia no disponible' : distancia} · ${duracion.isEmpty ? 'Tiempo no disponible' : duracion}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${_velocidadKmh.toStringAsFixed(1)} km/h · $movimientoTexto',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (secondaryButton != null)
                Row(
                  children: [
                    Expanded(child: secondaryButton),
                    const SizedBox(width: 10),
                    Expanded(child: primaryButton),
                  ],
                )
              else
                SizedBox(width: double.infinity, child: primaryButton),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _pedidoData;
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa del pedido')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : data == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [_mapa(data), _bottomPanel(data)]),
    );
  }
}
