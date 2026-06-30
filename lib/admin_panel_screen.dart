import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'seed_restaurante_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  static const Color fondo = Color(0xFFF5F5F2);
  static const double _maxProductPrice = 999.99;
  static final RegExp _pricePattern = RegExp(r'^\d{0,3}(\.\d{0,2})?$');
  static final List<TextInputFormatter> _priceInputFormatters = [
    TextInputFormatter.withFunction((oldValue, newValue) {
      final normalized = newValue.text.replaceAll(',', '.');
      final adjusted = normalized == newValue.text
          ? newValue
          : newValue.copyWith(
              text: normalized,
              selection: TextSelection.collapsed(offset: normalized.length),
            );

      if (normalized.isEmpty || _pricePattern.hasMatch(normalized)) {
        return adjusted;
      }

      return oldValue;
    }),
  ];
  static final List<TextInputFormatter> _orderInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _buscarProductoController =
      TextEditingController();
  final TextEditingController _buscarUsuarioController =
      TextEditingController();

  bool _loadingLogin = false;
  bool _showPassword = false;
  String? _loginError;
  String _busquedaProducto = '';
  String _busquedaUsuario = '';
  String _categoria = 'Todas';
  int _adminSection = 0;
  Timer? _productSearchDebounce;
  final Map<String, Future<String>> _clienteTelefonoCache = {};

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _db.collection(SeedRestauranteService.collectionName);

  CollectionReference<Map<String, dynamic>> get _pedidosRef =>
      _db.collection('pedidos_restaurante');

  CollectionReference<Map<String, dynamic>> get _usuariosRef =>
      _db.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _couponsConfigRef =>
      _db.collection('configuracion_cupones');

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productosStream =
      _productosRef.orderBy('orden').snapshots();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _buscarProductoController.dispose();
    _buscarUsuarioController.dispose();
    _productSearchDebounce?.cancel();
    super.dispose();
  }

  List<String> _roles(Map<String, dynamic>? data) {
    final rol = data?['rol']?.toString().toLowerCase().trim();
    final raw = data?['roles'];
    final roles = raw is List
        ? raw.map((value) => value.toString().toLowerCase().trim()).toSet()
        : <String>{};
    if (rol != null && rol.isNotEmpty) roles.add(rol);
    return roles.toList();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    final roles = _roles(data);
    return roles.contains('admin') || roles.contains('administrador');
  }

  bool _isKitchen(Map<String, dynamic>? data) {
    final roles = _roles(data);
    return roles.contains('cocinero') || roles.contains('cocina');
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = 'Ingresa usuario y contrasena.');
      return;
    }

    setState(() {
      _loadingLogin = true;
      _loginError = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      setState(() => _loginError = _authError(e.code));
    } catch (e) {
      setState(() => _loginError = 'No se pudo iniciar sesion: $e');
    } finally {
      if (mounted) setState(() => _loadingLogin = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no es valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Usuario o contrasena incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta nuevamente mas tarde.';
      default:
        return 'Error de autenticacion: $code';
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
  }

  void _scheduleProductSearch(String value, VoidCallback refresh) {
    _productSearchDebounce?.cancel();
    _productSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _busquedaProducto) return;
      _busquedaProducto = next;
      refresh();
    });
  }

  void _clearProductSearch(VoidCallback refresh) {
    _productSearchDebounce?.cancel();
    _buscarProductoController.clear();
    if (_busquedaProducto.isEmpty) return;
    _busquedaProducto = '';
    refresh();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => 'S/ ${_number(value).toStringAsFixed(2)}';

  DateTime _timestamp(
    Map<String, dynamic> data,
    List<String> fields, {
    DateTime? fallback,
  }) {
    for (final field in fields) {
      final value = data[field];
      if (value is Timestamp) return value.toDate();
    }
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _shortId(String id) {
    return id.substring(0, id.length >= 6 ? 6 : id.length).toUpperCase();
  }

  String _fechaCorta(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'Sin fecha';
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    final hora = date.hour.toString().padLeft(2, '0');
    final minuto = date.minute.toString().padLeft(2, '0');
    return '$dia/$mes $hora:$minuto';
  }

  bool _isToday(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _estadoPedido(dynamic value) {
    final estado = value?.toString().trim().toLowerCase() ?? 'pendiente';
    if (estado == 'pendiente_pago') return 'pendiente';
    if (estado == 'preparacion' ||
        estado == 'en preparacion' ||
        estado == 'en preparacion') {
      return 'en_preparacion';
    }
    if (estado == 'en_preparacion') return 'en_preparacion';
    if (estado == 'problema_cocina' || estado == 'problema cocina') {
      return 'problema_cocina';
    }
    if (estado == 'listo') return 'listo';
    if (estado == 'en_camino_local') return 'en_camino_local';
    if (estado == 'en_camino' || estado == 'camino' || estado == 'en camino') {
      return 'en_camino';
    }
    if (estado == 'entregado') return 'entregado';
    if (estado == 'cancelado' || estado == 'cancelada') return 'cancelado';
    return 'pendiente';
  }

  String _estadoTexto(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return 'En preparacion';
      case 'problema_cocina':
        return 'Problema en cocina';
      case 'listo':
        return 'Listo / por enviar';
      case 'en_camino_local':
        return 'Motorizado hacia local';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Entrante';
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'en_preparacion':
        return Colors.orange.shade700;
      case 'problema_cocina':
        return Colors.red.shade700;
      case 'listo':
        return Colors.green.shade700;
      case 'en_camino_local':
      case 'en_camino':
        return Colors.blue.shade700;
      case 'entregado':
        return Colors.green.shade900;
      case 'cancelado':
        return Colors.red;
      default:
        return amarillo;
    }
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
    return _textField(item, [
          'nombre',
          'producto',
          'productoNombre',
          'nombreProducto',
          'name',
          'title',
        ]).trim().isEmpty
        ? 'Producto'
        : _textField(item, [
            'nombre',
            'producto',
            'productoNombre',
            'nombreProducto',
            'name',
            'title',
          ]);
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

  String _textField(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final text = data[field]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
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

    final uid = _clienteUid(data);
    if (uid.isNotEmpty) {
      try {
        final doc = await _usuariosRef.doc(uid).get();
        final phone = _clienteTelefono(doc.data() ?? const {});
        if (phone.isNotEmpty) return phone;
      } catch (_) {
        // Si las reglas impiden leer el perfil, se muestra el estado sin bloquear el panel.
      }
    }

    final email = _clienteEmail(data);
    if (email.isNotEmpty) {
      try {
        final query = await _usuariosRef
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final phone = _clienteTelefono(query.docs.first.data());
          if (phone.isNotEmpty) return phone;
        }
      } catch (_) {
        // Mismo caso: el pedido sigue visible aunque no se pueda leer el perfil.
      }
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

  Widget _clienteTelefonoLine(
    Map<String, dynamic> data, {
    required double fontSize,
    required double iconSize,
  }) {
    Widget row(String text, {bool muted = false}) {
      return Row(
        children: [
          Icon(
            Icons.phone_rounded,
            size: iconSize,
            color: muted ? Colors.black38 : Colors.black54,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted ? Colors.black38 : Colors.black54,
                fontSize: fontSize,
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

  Widget _orderItemsList(
    Map<String, dynamic> data, {
    required double fontSize,
    bool showHeader = false,
    bool showPrices = false,
  }) {
    final items = _items(data);
    if (items.isEmpty) {
      return Text(
        'Pedido sin productos',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          const Text(
            'Platos del pedido',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
        ],
        for (final item in items) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_itemCantidad(item)} x ${_itemNombre(item)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                    ),
                  ),
                  if (_itemVariante(item).isNotEmpty &&
                      _itemVariante(item) != 'Normal') ...[
                    const SizedBox(height: 3),
                    Text(
                      'Variante: ${_itemVariante(item)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (showPrices) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Subtotal: ${_money(item['subtotal'] ?? item['precioUnitario'])}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Future<void> _seedProducts() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await SeedRestauranteService.cargarProductos();
      messenger.showSnackBar(
        SnackBar(content: Text('Carta base cargada: $count productos.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cargar la carta base: $e')),
      );
    }
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String initialValue = '',
    bool requiredValue = false,
    int maxLines = 3,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (requiredValue && text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String action = 'Confirmar',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _updateProductField(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    String value, {
    bool number = false,
    bool integer = false,
    bool nullableNumber = false,
  }) async {
    final payload = <String, dynamic>{
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    if (nullableNumber && value.trim().isEmpty) {
      payload[field] = FieldValue.delete();
    } else if (integer) {
      final parsed = int.tryParse(value.trim());
      if (parsed == null) throw Exception('Valor entero invalido.');
      payload[field] = parsed;
    } else if (number || nullableNumber) {
      final parsed = double.tryParse(value.trim());
      if (parsed == null) throw Exception('Numero invalido.');
      payload[field] = parsed;
    } else {
      payload[field] = value.trim();
    }

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> _toggleProductField(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String field,
    bool value,
  ) async {
    await doc.reference.set({
      field: value,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final confirmed = await _confirm(
      title: 'Eliminar producto',
      message: 'Se eliminara "${data['nombre'] ?? 'Producto'}".',
      action: 'Eliminar',
      danger: true,
    );

    if (!confirmed) return;

    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Producto eliminado.')));
  }

  List<String> _productCategoryChoices({String? current}) {
    final values =
        SeedRestauranteService.productos
            .map((producto) => producto['categoria']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final currentValue = current?.trim() ?? '';
    if (currentValue.isNotEmpty && !values.contains(currentValue)) {
      values.add(currentValue);
      values.sort();
    }

    return values;
  }

  int _nextProductOrder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var maxOrder = 0;
    for (final doc in docs) {
      final parsed = _productOrderValue(doc.data()['orden']);
      if (parsed != null && parsed > maxOrder) maxOrder = parsed;
    }
    return maxOrder + 1;
  }

  int? _productOrderValue(dynamic value) {
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String? _priceValidationMessage(double? value) {
    if (value == null) return 'Ingresa un precio valido.';
    if (value <= 0) return 'El precio debe ser mayor a 0.';
    if (value > _maxProductPrice) {
      return 'El precio no puede pasar de 3 cifras.';
    }
    return null;
  }

  String? _orderValidationMessage(int? value) {
    if (value == null) return 'Ingresa un orden valido.';
    if (value <= 0) return 'El orden debe ser mayor a 0.';
    return null;
  }

  Future<bool> _productOrderExists(int order, String? currentId) async {
    final snapshot = await _productosRef.get();
    return snapshot.docs.any((doc) {
      if (doc.id == currentId) return false;
      return _productOrderValue(doc.data()['orden']) == order;
    });
  }

  Future<void> _updateProductPrice(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    String value, {
    bool nullable = false,
  }) async {
    final trimmed = value.trim().replaceAll(',', '.');
    if (nullable && trimmed.isEmpty) {
      await _updateProductField(ref, field, trimmed, nullableNumber: true);
      return;
    }

    final parsed = double.tryParse(trimmed);
    final error = _priceValidationMessage(parsed);
    if (error != null) throw Exception(error);

    await _updateProductField(
      ref,
      field,
      parsed!.toStringAsFixed(2),
      number: !nullable,
      nullableNumber: nullable,
    );
  }

  Future<void> _openProductForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    List<QueryDocumentSnapshot<Map<String, dynamic>>> existingDocs = [];
    try {
      existingDocs = (await _productosRef.get()).docs;
    } catch (_) {
      existingDocs = [];
    }

    final currentCategory = data['categoria']?.toString().trim() ?? '';
    final categoryChoices = _productCategoryChoices(current: currentCategory);
    var selectedCategory = currentCategory.isNotEmpty
        ? currentCategory
        : categoryChoices.first;
    final nombreController = TextEditingController(
      text: data['nombre']?.toString() ?? '',
    );
    final descripcionController = TextEditingController(
      text: data['descripcion']?.toString() ?? '',
    );
    final imagenController = TextEditingController(
      text: data['imagenUrl']?.toString() ?? '',
    );
    final precioController = TextEditingController(
      text: data['precio']?.toString() ?? '',
    );
    final precioFamiliarController = TextEditingController(
      text: data['precioFamiliar']?.toString() ?? '',
    );
    final ordenController = TextEditingController(
      text:
          data['orden']?.toString() ??
          _nextProductOrder(existingDocs).toString(),
    );
    var disponible = data['disponible'] != false;
    var destacado = data['destacado'] == true;
    var saving = false;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final nombre = nombreController.text.trim();
              final categoria = selectedCategory.trim();
              final isPizzaProduct = _isPizzaText(nombre, categoria);
              final precioText = precioController.text.trim().replaceAll(
                ',',
                '.',
              );
              final precio = double.tryParse(precioText);
              final precioFamiliarText = isPizzaProduct
                  ? precioFamiliarController.text.trim().replaceAll(',', '.')
                  : '';
              final precioFamiliar = precioFamiliarText.isEmpty
                  ? null
                  : double.tryParse(precioFamiliarText);
              final orden = int.tryParse(ordenController.text.trim());

              if (nombre.isEmpty || categoria.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa nombre y categoria.')),
                );
                return;
              }

              final priceError = _priceValidationMessage(precio);
              if (priceError != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(priceError)));
                return;
              }

              if (precioFamiliarText.isNotEmpty) {
                final familyPriceError = _priceValidationMessage(
                  precioFamiliar,
                );
                if (familyPriceError != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(familyPriceError)));
                  return;
                }
              }

              final orderError = _orderValidationMessage(orden);
              if (orderError != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(orderError)));
                return;
              }

              setSheetState(() => saving = true);

              try {
                final duplicatedOrder = await _productOrderExists(
                  orden!,
                  doc?.id,
                );
                if (duplicatedOrder) {
                  if (context.mounted) {
                    setSheetState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ya existe otro producto con ese orden.'),
                      ),
                    );
                  }
                  return;
                }

                final payload = <String, dynamic>{
                  'nombre': nombre,
                  'categoria': categoria,
                  'descripcion': descripcionController.text.trim(),
                  'imagenUrl': imagenController.text.trim(),
                  'precio': double.parse(precio!.toStringAsFixed(2)),
                  'disponible': disponible,
                  'destacado': destacado,
                  'orden': orden,
                  'actualizadoEn': FieldValue.serverTimestamp(),
                };

                if (!isPizzaProduct || precioFamiliar == null) {
                  if (doc != null) {
                    payload['precioFamiliar'] = FieldValue.delete();
                  }
                } else {
                  payload['precioFamiliar'] = precioFamiliar;
                }

                if (doc == null) {
                  payload['creadoEn'] = FieldValue.serverTimestamp();
                  await _productosRef.add(payload);
                } else {
                  await doc.reference.set(payload, SetOptions(merge: true));
                }

                if (context.mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      doc == null
                          ? 'Producto creado.'
                          : 'Producto actualizado.',
                    ),
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  setSheetState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo guardar el producto: $e'),
                    ),
                  );
                }
              }
            }

            final showFamilyPrice = _isPizzaText('', selectedCategory);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc == null
                                  ? 'Nuevo producto'
                                  : 'Editar producto',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _formField(nombreController, 'Nombre'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: categoryChoices
                            .map(
                              (categoria) => DropdownMenuItem(
                                value: categoria,
                                child: Text(categoria),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setSheetState(() => selectedCategory = value);
                              },
                      ),
                      const SizedBox(height: 10),
                      _formField(
                        descripcionController,
                        'Descripcion',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _formField(imagenController, 'URL de imagen'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(
                              precioController,
                              showFamilyPrice ? 'Mediana' : 'Precio',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: false,
                                  ),
                              inputFormatters: _priceInputFormatters,
                            ),
                          ),
                          if (showFamilyPrice) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _formField(
                                precioFamiliarController,
                                'Familiar',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: false,
                                    ),
                                inputFormatters: _priceInputFormatters,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formField(
                        ordenController,
                        'Orden',
                        keyboardType: TextInputType.number,
                        inputFormatters: _orderInputFormatters,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Disponible'),
                            selected: disponible,
                            selectedColor: amarillo,
                            onSelected: (value) =>
                                setSheetState(() => disponible = value),
                          ),
                          FilterChip(
                            label: const Text('Destacado'),
                            selected: destacado,
                            selectedColor: amarillo,
                            onSelected: (value) =>
                                setSheetState(() => destacado = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : save,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _aceptarPedido(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.set({
      'estado': 'en_preparacion',
      'pagoEstado': 'pendiente',
      'adminAceptadoEn': FieldValue.serverTimestamp(),
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
      'problemaCocina': false,
      'cocinaAceptado': false,
      'cocinaRequiereDecision': true,
      'notificacionCliente': 'Tu pedido fue aceptado y ya paso a cocina.',
      'notificacionTipo': 'pedido_aceptado',
      'notificacionLeida': false,
    }, SetOptions(merge: true));
  }

  Future<void> _aceptarEnCocina(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.set({
      'estado': 'en_preparacion',
      'pagoEstado': 'pendiente',
      'problemaCocina': false,
      'problemaCocinaDetalle': FieldValue.delete(),
      'cocinaAceptado': true,
      'cocinaRequiereDecision': false,
      'cocinaAceptadoEn': FieldValue.serverTimestamp(),
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
      'notificacionCliente': 'Cocina ya esta preparando tu pedido.',
      'notificacionTipo': 'pedido_en_cocina',
      'notificacionLeida': false,
    }, SetOptions(merge: true));
  }

  Future<void> _reportarProblemaCocina(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final motivo = await _promptText(
      title: 'No aceptar pedido #${_shortId(doc.id)}',
      label: 'Motivo interno para administracion',
      requiredValue: true,
    );
    if (motivo == null) return;

    await doc.reference.set({
      'estado': 'problema_cocina',
      'problemaCocina': true,
      'problemaCocinaDetalle': motivo,
      'cocinaRequiereDecision': false,
      'cocinaRechazadoEn': FieldValue.serverTimestamp(),
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _cancelarPedido(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String? reason,
  }) async {
    final motivo =
        reason ??
        await _promptText(
          title: 'Cancelar pedido #${_shortId(doc.id)}',
          label: 'Motivo para el cliente',
          requiredValue: true,
        );
    if (motivo == null) return;

    await doc.reference.set({
      'estado': 'cancelado',
      'pagoEstado': 'cancelado',
      'motivoCancelacion': motivo,
      'canceladoPor': _auth.currentUser?.uid,
      'canceladoEn': FieldValue.serverTimestamp(),
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
      'notificacionCliente': 'Tu pedido fue cancelado. Motivo: $motivo',
      'notificacionTipo': 'pedido_cancelado',
      'notificacionLeida': false,
    }, SetOptions(merge: true));
  }

  Future<void> _marcarListo(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.set({
      'estado': 'listo',
      'problemaCocina': false,
      'cocinaAceptado': true,
      'cocinaRequiereDecision': false,
      'listoEn': FieldValue.serverTimestamp(),
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
      'notificacionCliente':
          'Tu pedido esta listo. En breve se asignara un motorizado.',
      'notificacionTipo': 'pedido_listo',
      'notificacionLeida': false,
    }, SetOptions(merge: true));
  }

  Future<void> _reabrirEnCocina(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.set({
      'estado': 'en_preparacion',
      'problemaCocina': false,
      'problemaCocinaDetalle': FieldValue.delete(),
      'cocinaAceptado': false,
      'cocinaRequiereDecision': true,
      'estadoActualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _openOrderEditor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final productSnapshot = await _productosRef.orderBy('orden').get();
    final productOptions = productSnapshot.docs
        .map((productDoc) => _ProductOption.fromDoc(productDoc))
        .toList();
    final rows = _items(
      data,
    ).map((item) => _OrderEditItem.fromMap(item, productOptions)).toList();
    final deliveryValue = _number(data['delivery']);
    final originalDiscountValue = _number(data['descuento']);
    final messageController = TextEditingController(
      text: data['mensajeCliente']?.toString() ?? '',
    );
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double subtotal() =>
                rows.fold(0, (amount, item) => amount + item.subtotal);
            double delivery() => deliveryValue;
            double discount() => math.min(originalDiscountValue, subtotal());
            double totalBeforeDiscount() => subtotal() + delivery();
            double total() => totalBeforeDiscount() - discount();

            Future<void> save() async {
              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El pedido necesita productos.'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              final message = messageController.text.trim();
              final payload = <String, dynamic>{
                'items': rows.map((row) => row.toMap()).toList(),
                'subtotal': double.parse(subtotal().toStringAsFixed(2)),
                'delivery': double.parse(delivery().toStringAsFixed(2)),
                'descuento': double.parse(discount().toStringAsFixed(2)),
                'totalAntesDescuento': double.parse(
                  totalBeforeDiscount().toStringAsFixed(2),
                ),
                'total': double.parse(total().toStringAsFixed(2)),
                'editadoPorAdmin': true,
                'editadoPorAdminEn': FieldValue.serverTimestamp(),
                'estadoActualizadoEn': FieldValue.serverTimestamp(),
              };

              if (message.isNotEmpty) {
                payload['mensajeCliente'] = message;
                payload['notificacionCliente'] = message;
                payload['notificacionTipo'] = 'pedido_editado';
                payload['notificacionLeida'] = false;
              }

              await doc.reference.set(payload, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Pedido actualizado.')),
              );
            }

            return AlertDialog(
              title: Text('Editar pedido #${_shortId(doc.id)}'),
              content: SizedBox(
                width: math.min(MediaQuery.of(context).size.width * 0.9, 920),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usa esta edicion cuando el cliente acepto el cambio.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...rows.map((row) {
                        final selectedProductId =
                            productOptions.any(
                              (product) => product.id == row.productId,
                            )
                            ? row.productId
                            : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: selectedProductId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Producto',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: productOptions.map((product) {
                                      final priceText = product.hasPizzaVariants
                                          ? 'M ${_money(product.precio)} / F ${_money(product.precioFamiliar)}'
                                          : _money(product.precio);
                                      return DropdownMenuItem(
                                        value: product.id,
                                        child: Text(
                                          '${product.nombre} - $priceText',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (productId) {
                                      _ProductOption? product;
                                      for (final option in productOptions) {
                                        if (option.id == productId) {
                                          product = option;
                                          break;
                                        }
                                      }
                                      if (product == null) return;
                                      final selectedProduct = product;
                                      setDialogState(() {
                                        row.applyProduct(selectedProduct);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      spacing: 12,
                                      runSpacing: 10,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (row.hasPizzaVariants)
                                          SizedBox(
                                            width: 220,
                                            child:
                                                DropdownButtonFormField<String>(
                                                  initialValue: row.variante,
                                                  isExpanded: true,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Tamano de pizza',
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                      ),
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: 'Mediana',
                                                      child: Text('Mediana'),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Familiar',
                                                      child: Text('Familiar'),
                                                    ),
                                                  ],
                                                  onChanged: (value) {
                                                    if (value == null) return;
                                                    setDialogState(() {
                                                      row.variante = value;
                                                    });
                                                  },
                                                ),
                                          ),
                                        SizedBox(
                                          width: 96,
                                          child: TextField(
                                            controller: row.cantidadController,
                                            decoration: const InputDecoration(
                                              labelText: 'Cantidad',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (_) =>
                                                setDialogState(() {}),
                                          ),
                                        ),
                                        _orderReadOnlyValue(
                                          'Precio',
                                          _money(row.precioUnitario),
                                        ),
                                        _orderReadOnlyValue(
                                          'Subtotal',
                                          _money(row.subtotal),
                                          strong: true,
                                        ),
                                        IconButton(
                                          tooltip: 'Quitar del pedido',
                                          onPressed: () {
                                            setDialogState(() {
                                              rows.remove(row);
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_rounded,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: productOptions.isEmpty
                              ? null
                              : () {
                                  setDialogState(() {
                                    rows.add(
                                      _OrderEditItem.fromProduct(
                                        productOptions.first,
                                      ),
                                    );
                                  });
                                },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar producto'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _orderReadOnlyValue(
                            'Delivery',
                            _money(deliveryValue),
                          ),
                          if (discount() > 0) ...[
                            const SizedBox(width: 12),
                            _orderReadOnlyValue(
                              'Descuento',
                              '- ${_money(discount())}',
                            ),
                          ],
                          const Spacer(),
                          Text(
                            'Total: ${_money(total())}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText:
                              'Mensaje para el cliente / notificacion del cambio',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Guardar cambio'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final row in rows) {
      row.dispose();
    }
    messageController.dispose();
  }

  Widget _orderReadOnlyValue(
    String label,
    String value, {
    bool strong = false,
  }) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 16 : 15,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginScreen() {
    return Scaffold(
      backgroundColor: fondo,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/logo.png', height: 88),
                    const SizedBox(height: 18),
                    const Text(
                      'Panel web',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: negro,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Administrador o cocina',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Ocultar' : 'Mostrar',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _loginError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _loadingLogin ? null : _login,
                        icon: _loadingLogin
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notAllowedScreen(User user) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('Panel web'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 54,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Usuario sin permisos para el panel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sesion actual: ${user.email ?? user.uid}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Asigna rol admin o cocinero en usuarios/{uid}.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminShell(User user) {
    final destinations = const [
      _ShellDestination(label: 'Monitor', icon: Icons.dashboard_rounded),
      _ShellDestination(
        label: 'Productos',
        icon: Icons.restaurant_menu_rounded,
      ),
      _ShellDestination(label: 'Usuarios', icon: Icons.group_rounded),
      _ShellDestination(label: 'Cupones', icon: Icons.local_activity_rounded),
      _ShellDestination(label: 'Reportes', icon: Icons.bar_chart_rounded),
      _ShellDestination(label: 'Configuracion', icon: Icons.settings_rounded),
    ];

    final pages = [
      _ordersMonitor(adminMode: true),
      _productsManagement(),
      _usersManagement(),
      _couponsManagement(),
      _reportsView(),
      _configurationView(),
    ];

    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('El Barto Admin'),
        actions: [
          if (_adminSection == 1)
            IconButton(
              tooltip: 'Cargar carta base',
              onPressed: _seedProducts,
              icon: const Icon(Icons.cloud_upload_rounded),
            ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: _adminSection == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Producto'),
              backgroundColor: amarillo,
              foregroundColor: negro,
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;

          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _adminSection,
                  onDestinationSelected: (index) =>
                      setState(() => _adminSection = index),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.icon, color: negro),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[_adminSection]),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: pages[_adminSection]),
              NavigationBar(
                selectedIndex: _adminSection,
                onDestinationSelected: (index) =>
                    setState(() => _adminSection = index),
                destinations: destinations
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kitchenShell(User user) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text('El Barto Cocina'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _kitchenBoard(),
    );
  }

  Widget _pagePadding(Widget child, {double bottom = 24}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: negro,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }

  Widget _ordersMonitor({required bool adminMode}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data!.docs,
        );
        docs.sort((a, b) {
          final ad = _timestamp(a.data(), ['creadoEn', 'fecha']);
          final bd = _timestamp(b.data(), ['creadoEn', 'fecha']);
          return bd.compareTo(ad);
        });

        final incoming = docs
            .where((doc) => _estadoPedido(doc.data()['estado']) == 'pendiente')
            .toList();
        final preparing = docs.where((doc) {
          final estado = _estadoPedido(doc.data()['estado']);
          return estado == 'en_preparacion' || estado == 'problema_cocina';
        }).toList();
        final ready = docs.where((doc) {
          final estado = _estadoPedido(doc.data()['estado']);
          return estado == 'listo' ||
              estado == 'en_camino_local' ||
              estado == 'en_camino';
        }).toList();
        final historyToday = docs.where((doc) {
          final data = doc.data();
          final estado = _estadoPedido(data['estado']);
          final changed = _timestamp(data, [
            'estadoActualizadoEn',
            'entregadoEn',
            'canceladoEn',
            'creadoEn',
          ]);
          return (estado == 'entregado' || estado == 'cancelado') &&
              _isToday(changed);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = [
              _OrderColumnData(
                title: 'Pedidos entrantes',
                subtitle: 'Aceptar o rechazar',
                icon: Icons.notifications_active_rounded,
                docs: incoming,
              ),
              _OrderColumnData(
                title: 'En preparacion',
                subtitle: 'Cocina trabajando',
                icon: Icons.soup_kitchen_rounded,
                docs: preparing,
              ),
              _OrderColumnData(
                title: 'Listos / por enviar',
                subtitle: 'Motorizado y ruta',
                icon: Icons.delivery_dining_rounded,
                docs: ready,
              ),
              _OrderColumnData(
                title: 'Historial de hoy',
                subtitle: 'Entregados y cancelados',
                icon: Icons.history_rounded,
                docs: historyToday,
              ),
            ];
            final columnWidth = math.max(
              280.0,
              (constraints.maxWidth - 72) / 4,
            );

            return _pagePadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    title: 'Monitor de pedidos',
                    subtitle:
                        'Flujo en vivo: entrantes, cocina, delivery e historial del dia.',
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < columns.length;
                            index++
                          ) ...[
                            SizedBox(
                              width: columnWidth,
                              child: _orderColumn(
                                columns[index],
                                adminMode: adminMode,
                              ),
                            ),
                            if (index < columns.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _kitchenBoard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data!.docs,
            ).where((doc) {
              final estado = _estadoPedido(doc.data()['estado']);
              return estado == 'pendiente' || estado == 'en_preparacion';
            }).toList();

        docs.sort((a, b) {
          final aEstado = _estadoPedido(a.data()['estado']);
          final bEstado = _estadoPedido(b.data()['estado']);
          if (aEstado != bEstado) {
            if (aEstado == 'pendiente') return -1;
            if (bEstado == 'pendiente') return 1;
          }
          final ad = _timestamp(a.data(), [
            'adminAceptadoEn',
            'cocinaAceptadoEn',
            'creadoEn',
          ]);
          final bd = _timestamp(b.data(), [
            'adminAceptadoEn',
            'cocinaAceptadoEn',
            'creadoEn',
          ]);
          return ad.compareTo(bd);
        });

        return _pagePadding(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                title: 'Pedidos pendientes y en preparacion',
                subtitle:
                    'Cocina tambien puede aceptar pedidos entrantes. Al aceptar, pasan a preparacion.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('No hay pedidos para cocina.'))
                    : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _orderCard(docs[index], adminMode: false),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderColumn(_OrderColumnData column, {required bool adminMode}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(column.icon, color: negro),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        column.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${column.subtitle} - ${column.docs.length}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (column.docs.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Sin pedidos',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: column.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _orderCard(column.docs[index], adminMode: adminMode),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool adminMode,
  }) {
    final data = doc.data();
    final estado = _estadoPedido(data['estado']);
    final color = _estadoColor(estado);
    final creado = _timestamp(data, ['creadoEn', 'fecha']);
    final problema = data['problemaCocinaDetalle']?.toString().trim() ?? '';
    final cliente = _textField(data, [
      'clienteNombre',
      'nombreCliente',
      'email',
      'clienteEmail',
      'userId',
    ]);
    final descuento = _number(data['descuento']);
    final cocinaAceptado = data['cocinaAceptado'] == true;
    final kitchenMode = !adminMode;
    final titleFont = kitchenMode ? 22.0 : 15.0;
    final metaFont = kitchenMode ? 16.0 : 12.0;
    final itemFont = kitchenMode ? 20.0 : 14.0;
    final totalFont = kitchenMode ? 21.0 : 14.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: estado == 'problema_cocina'
            ? Colors.red.shade50
            : const Color(0xFFFCFCFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: estado == 'problema_cocina'
              ? Colors.red.shade200
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(kitchenMode ? 18 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${_shortId(doc.id)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: titleFont,
                    ),
                  ),
                ),
                _statusPill(_estadoTexto(estado), color, large: kitchenMode),
              ],
            ),
            SizedBox(height: kitchenMode ? 8 : 4),
            Text(
              _fechaCorta(creado),
              style: TextStyle(color: Colors.black54, fontSize: metaFont),
            ),
            if (cliente.isNotEmpty) ...[
              SizedBox(height: kitchenMode ? 6 : 4),
              Text(
                cliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: metaFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(height: kitchenMode ? 6 : 4),
            _clienteTelefonoLine(
              data,
              fontSize: metaFont,
              iconSize: kitchenMode ? 18 : 14,
            ),
            SizedBox(height: kitchenMode ? 14 : 8),
            _orderItemsList(
              data,
              fontSize: itemFont,
              showHeader: kitchenMode,
              showPrices: false,
            ),
            SizedBox(height: kitchenMode ? 10 : 6),
            Text(
              'Total: ${_money(data['total'])}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: totalFont,
              ),
            ),
            if (descuento > 0) ...[
              SizedBox(height: kitchenMode ? 6 : 3),
              Text(
                'Descuento: - ${_money(descuento)}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: metaFont,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            if (problema.isNotEmpty) ...[
              const SizedBox(height: 8),
              _alertBox(Icons.warning_rounded, problema, Colors.red.shade700),
            ],
            if (kitchenMode &&
                (estado == 'pendiente' || estado == 'en_preparacion')) ...[
              const SizedBox(height: 8),
              _alertBox(
                estado == 'pendiente'
                    ? Icons.notifications_active_rounded
                    : cocinaAceptado
                    ? Icons.soup_kitchen_rounded
                    : Icons.help_outline_rounded,
                estado == 'pendiente'
                    ? 'Pedido entrante: cocina puede aceptarlo para pasarlo a preparacion.'
                    : cocinaAceptado
                    ? 'Pedido aceptado por cocina. Marca listo cuando termine.'
                    : 'Revisa el pedido: aceptalo para prepararlo o indica si hay un problema.',
                estado == 'pendiente'
                    ? Colors.orange.shade800
                    : cocinaAceptado
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
            ],
            SizedBox(height: kitchenMode ? 16 : 10),
            _orderActions(doc, estado: estado, adminMode: adminMode),
          ],
        ),
      ),
    );
  }

  Widget _alertBox(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color, {bool large = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 9,
        vertical: large ? 7 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: large ? 15 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _openDeliveryTracking(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final riderName = data['repartidorNombre']?.toString().trim();
    final riderId = data['repartidorId']?.toString().trim();
    final movement =
        data['repartidorMovimiento']?.toString().trim() ?? 'sin_asignar';
    final speed = _number(data['repartidorVelocidadKmh']);
    final lat = data['repartidorLat'];
    final lng = data['repartidorLng'];
    final hasLocation = lat is num && lng is num;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seguimiento #${_shortId(doc.id)}'),
        content: SizedBox(
          width: math.min(MediaQuery.of(context).size.width * 0.9, 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _alertBox(
                Icons.delivery_dining_rounded,
                'El pedido esta en camino. Ya no se puede editar ni cancelar desde administracion.',
                Colors.blue.shade700,
              ),
              const SizedBox(height: 14),
              _trackingLine(
                'Motorizado',
                riderName?.isNotEmpty == true
                    ? riderName!
                    : riderId?.isNotEmpty == true
                    ? riderId!
                    : 'Pendiente',
              ),
              _trackingLine('Movimiento', movement),
              _trackingLine('Velocidad', '${speed.toStringAsFixed(1)} km/h'),
              _trackingLine(
                'Ubicacion',
                hasLocation
                    ? '${(lat).toDouble().toStringAsFixed(6)}, ${(lng).toDouble().toStringAsFixed(6)}'
                    : 'Aun no reportada',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _trackingLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderActions(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String estado,
    required bool adminMode,
  }) {
    final data = doc.data();
    final cocinaAceptado = data['cocinaAceptado'] == true;
    final children = <Widget>[];

    if (adminMode && estado == 'pendiente') {
      children.addAll([
        FilledButton.icon(
          onPressed: () => _aceptarPedido(doc),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aceptar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _cancelarPedido(doc),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Rechazar'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ]);
    }

    if (!adminMode && (estado == 'pendiente' || estado == 'en_preparacion')) {
      if (estado == 'en_preparacion' && cocinaAceptado) {
        children.addAll([
          FilledButton.icon(
            onPressed: () => _marcarListo(doc),
            icon: const Icon(Icons.done_rounded),
            label: const Text('Marcar listo'),
          ),
          OutlinedButton.icon(
            onPressed: () => _reportarProblemaCocina(doc),
            icon: const Icon(Icons.warning_rounded),
            label: const Text('Problema'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ]);
      } else {
        final isPending = estado == 'pendiente';
        children.addAll([
          FilledButton.icon(
            onPressed: () => _aceptarEnCocina(doc),
            icon: const Icon(Icons.check_rounded),
            label: Text(isPending ? 'Aceptar y preparar' : 'Aceptar'),
          ),
          OutlinedButton.icon(
            onPressed: () => _reportarProblemaCocina(doc),
            icon: const Icon(Icons.close_rounded),
            label: const Text('No aceptar'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ]);
      }
    }

    if (adminMode && estado == 'problema_cocina') {
      children.addAll([
        OutlinedButton.icon(
          onPressed: () => _openOrderEditor(doc),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _reabrirEnCocina(doc),
          icon: const Icon(Icons.restaurant_rounded),
          label: const Text('Volver a cocina'),
        ),
        OutlinedButton.icon(
          onPressed: () => _cancelarPedido(doc),
          icon: const Icon(Icons.cancel_rounded),
          label: const Text('Cancelar'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ]);
    }

    if (adminMode && estado == 'problema_cocina') {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }

    if (adminMode && (estado == 'en_preparacion' || estado == 'listo')) {
      children.addAll([
        OutlinedButton.icon(
          onPressed: () => _openOrderEditor(doc),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _cancelarPedido(doc),
          icon: const Icon(Icons.cancel_rounded),
          label: const Text('Cancelar'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      ]);
    }

    if (adminMode && (estado == 'en_camino' || estado == 'en_camino_local')) {
      children.add(
        FilledButton.icon(
          onPressed: () => _openDeliveryTracking(doc),
          icon: const Icon(Icons.delivery_dining_rounded),
          label: const Text('Ver motorizado'),
        ),
      );
    }

    if (adminMode && children.isEmpty) {
      children.add(
        TextButton.icon(
          onPressed: null,
          icon: const Icon(Icons.visibility_rounded),
          label: Text(_estadoTexto(estado)),
        ),
      );
    }

    if (children.isEmpty) {
      children.add(
        TextButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_clock_rounded),
          label: Text(_estadoTexto(estado)),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  Widget _productsManagement() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productosStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final categorias = _categorias(docs);

        return StatefulBuilder(
          builder: (context, setProductsState) {
            final selectedCategory = categorias.contains(_categoria)
                ? _categoria
                : 'Todas';
            final filtered = docs.where((doc) {
              return _matchesProduct(doc.data(), selectedCategory);
            }).toList();
            final regularProducts = filtered
                .where((doc) => !_isPizzaProduct(doc.data()))
                .toList();
            final pizzas = filtered
                .where((doc) => _isPizzaProduct(doc.data()))
                .toList();

            return _pagePadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                    title: 'Gestion de productos',
                    subtitle:
                        'La tabla ocupa el ancho del panel. Edita cada dato directamente.',
                    actions: [
                      FilledButton.icon(
                        onPressed: () => _openProductForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuevo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _productFilters(
                    categorias,
                    selectedCategory,
                    onSearchChanged: (value) => _scheduleProductSearch(
                      value,
                      () => setProductsState(() {}),
                    ),
                    onClearSearch: () =>
                        _clearProductSearch(() => setProductsState(() {})),
                    onCategorySelected: (value) {
                      _categoria = value ?? 'Todas';
                      setProductsState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No hay productos para mostrar.'),
                          )
                        : ListView(
                            children: [
                              if (regularProducts.isNotEmpty)
                                _productTableSection(
                                  title: 'Productos',
                                  subtitle: 'Platos sin variante familiar.',
                                  child: _productsTable(
                                    regularProducts,
                                    includeFamiliar: false,
                                    categoryChoices: _productCategoryChoices(),
                                  ),
                                ),
                              if (regularProducts.isNotEmpty &&
                                  pizzas.isNotEmpty)
                                const SizedBox(height: 20),
                              if (pizzas.isNotEmpty)
                                _productTableSection(
                                  title: 'Pizzas',
                                  subtitle:
                                      'Solo pizzas: precio mediana y familiar.',
                                  child: _productsTable(
                                    pizzas,
                                    includeFamiliar: true,
                                    categoryChoices: _productCategoryChoices(),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              bottom: 90,
            );
          },
        );
      },
    );
  }

  bool _matchesProduct(Map<String, dynamic> data, String selectedCategory) {
    final query = _busquedaProducto.toLowerCase();
    final nombre = data['nombre']?.toString().toLowerCase() ?? '';
    final categoria = data['categoria']?.toString().toLowerCase() ?? '';
    final descripcion = data['descripcion']?.toString().toLowerCase() ?? '';

    if (selectedCategory != 'Todas' &&
        data['categoria']?.toString() != selectedCategory) {
      return false;
    }

    return query.isEmpty ||
        nombre.contains(query) ||
        categoria.contains(query) ||
        descripcion.contains(query);
  }

  List<String> _categorias(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final categorias =
        docs
            .map((doc) => doc.data()['categoria']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['Todas', ...categorias];
  }

  bool _isPizzaProduct(Map<String, dynamic> data) {
    return _isPizzaText(
      data['nombre']?.toString() ?? '',
      data['categoria']?.toString() ?? '',
    );
  }

  Widget _productTableSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _productFilters(
    List<String> categorias,
    String selectedCategory, {
    required ValueChanged<String> onSearchChanged,
    required VoidCallback onClearSearch,
    required ValueChanged<String?> onCategorySelected,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 340,
          child: TextField(
            controller: _buscarProductoController,
            decoration: InputDecoration(
              hintText: 'Buscar producto',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _busquedaProducto.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        DropdownButton<String>(
          value: selectedCategory,
          items: categorias
              .map(
                (categoria) =>
                    DropdownMenuItem(value: categoria, child: Text(categoria)),
              )
              .toList(),
          onChanged: onCategorySelected,
        ),
      ],
    );
  }

  Widget _productsTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool includeFamiliar,
    required List<String> categoryChoices,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = math.max(
          constraints.maxWidth,
          includeFamiliar ? 1540.0 : 1420.0,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 14,
                      headingRowHeight: 48,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 78,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFFFF3C4),
                      ),
                      columns: [
                        const DataColumn(label: Text('Orden')),
                        const DataColumn(label: Text('Producto')),
                        const DataColumn(label: Text('Categoria')),
                        const DataColumn(label: Text('Descripcion')),
                        DataColumn(
                          label: Text(includeFamiliar ? 'Mediana' : 'Precio'),
                        ),
                        if (includeFamiliar)
                          const DataColumn(label: Text('Familiar')),
                        const DataColumn(label: Text('Disponible')),
                        const DataColumn(label: Text('Destacado')),
                        const DataColumn(label: Text('Acciones')),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();
                        final nombre = data['nombre']?.toString() ?? 'Producto';
                        final categoria = data['categoria']?.toString() ?? '';
                        final rowCategoryChoices = [...categoryChoices];
                        if (categoria.isNotEmpty &&
                            !rowCategoryChoices.contains(categoria)) {
                          rowCategoryChoices.add(categoria);
                          rowCategoryChoices.sort();
                        }

                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 76,
                                child: Text(
                                  data['orden']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              _InlineTextCell(
                                value: nombre,
                                width: 230,
                                onSave: (value) => _updateProductField(
                                  doc.reference,
                                  'nombre',
                                  value,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 210,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Cambiar categoria',
                                  initialValue: categoria.isEmpty
                                      ? null
                                      : categoria,
                                  onSelected: (value) async {
                                    try {
                                      await _updateProductField(
                                        doc.reference,
                                        'categoria',
                                        value,
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No se pudo guardar: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => rowCategoryChoices
                                      .map(
                                        (value) => PopupMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          categoria,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.edit_rounded, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              _InlineTextCell(
                                value: data['descripcion']?.toString() ?? '',
                                width: 300,
                                maxLines: 2,
                                onSave: (value) => _updateProductField(
                                  doc.reference,
                                  'descripcion',
                                  value,
                                ),
                              ),
                            ),
                            DataCell(
                              _InlineTextCell(
                                value: _number(
                                  data['precio'],
                                ).toStringAsFixed(2),
                                width: 96,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: false,
                                    ),
                                inputFormatters: _priceInputFormatters,
                                onSave: (value) => _updateProductPrice(
                                  doc.reference,
                                  'precio',
                                  value,
                                ),
                              ),
                            ),
                            if (includeFamiliar)
                              DataCell(
                                _InlineTextCell(
                                  value: data['precioFamiliar'] == null
                                      ? ''
                                      : _number(
                                          data['precioFamiliar'],
                                        ).toStringAsFixed(2),
                                  width: 96,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: false,
                                      ),
                                  inputFormatters: _priceInputFormatters,
                                  onSave: (value) => _updateProductPrice(
                                    doc.reference,
                                    'precioFamiliar',
                                    value,
                                    nullable: true,
                                  ),
                                ),
                              ),
                            DataCell(
                              Switch(
                                value: data['disponible'] == true,
                                onChanged: (value) => _toggleProductField(
                                  doc,
                                  'disponible',
                                  value,
                                ),
                              ),
                            ),
                            DataCell(
                              Switch(
                                value: data['destacado'] == true,
                                onChanged: (value) => _toggleProductField(
                                  doc,
                                  'destacado',
                                  value,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Eliminar',
                                    onPressed: () => _deleteProduct(doc),
                                    icon: const Icon(
                                      Icons.delete_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _usersManagement() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usuariosRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data!.docs,
        );
        docs.sort((a, b) {
          final ae = a.data()['email']?.toString() ?? '';
          final be = b.data()['email']?.toString() ?? '';
          return ae.compareTo(be);
        });

        final query = _busquedaUsuario.toLowerCase();
        final filtered = docs.where((doc) {
          final data = doc.data();
          final text = [
            data['email'],
            data['nombreCompleto'],
            data['nombres'],
            data['dni'],
            data['rol'],
          ].whereType<Object>().join(' ').toLowerCase();
          return query.isEmpty || text.contains(query);
        }).toList();

        return _pagePadding(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                title: 'Gestion de usuarios',
                subtitle:
                    'Asigna roles para cliente, administrador, cocina o motorizado.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _buscarUsuarioController,
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _busquedaUsuario.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _buscarUsuarioController.clear();
                              setState(() => _busquedaUsuario = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _busquedaUsuario = value.trim()),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No hay usuarios para mostrar.'))
                    : _usersTable(filtered),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _usersTable(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = math.max(constraints.maxWidth, 1080.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 18,
                      horizontalMargin: 14,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFFFF3C4),
                      ),
                      columns: const [
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Correo')),
                        DataColumn(label: Text('DNI')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data();
                        final rawRol = data['rol']?.toString() ?? 'cliente';
                        final rol = rawRol == 'repartidor'
                            ? 'motociclista'
                            : rawRol;
                        final activo = data['activo'] != false;

                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(
                                  data['nombreCompleto']?.toString() ??
                                      data['nombres']?.toString() ??
                                      'Sin nombre',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 260,
                                child: Text(
                                  data['email']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(data['dni']?.toString() ?? '-')),
                            DataCell(
                              DropdownButton<String>(
                                value: _roleOptions.contains(rol)
                                    ? rol
                                    : 'cliente',
                                underline: const SizedBox.shrink(),
                                items: _roleOptions
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  _updateUserRole(doc, value);
                                },
                              ),
                            ),
                            DataCell(
                              _statusPill(
                                activo ? 'Activo' : 'Bloqueado',
                                activo ? Colors.green : Colors.red,
                              ),
                            ),
                            DataCell(
                              Switch(
                                value: activo,
                                onChanged: (value) => doc.reference.set({
                                  'activo': value,
                                  'actualizadoEn': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _couponsManagement() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _couponsConfigRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = {
          for (final doc
              in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            doc.id: doc.data(),
        };

        return _pagePadding(
          ListView(
            children: [
              _sectionHeader(
                title: 'Cupones',
                subtitle: 'Activa promociones automaticas para clientes.',
              ),
              const SizedBox(height: 14),
              _couponCard(
                id: 'compras_5_descuento_30',
                data: docs['compras_5_descuento_30'],
                icon: Icons.shopping_bag_rounded,
                title: '5 compras - 30% en el proximo pedido',
                description:
                    'Cuando el cliente complete 5 pedidos entregados, podra recibir un cupon de 30% para su siguiente pedido.',
                payload: {
                  'tipo': 'compras_entregadas',
                  'comprasRequeridas': 5,
                  'descuentoPorcentaje': 30,
                  'aplicaEn': 'proximo_pedido',
                  'codigo': 'BARTO5',
                },
              ),
              const SizedBox(height: 12),
              _couponCard(
                id: 'shake_20_semanal',
                data: docs['shake_20_semanal'],
                icon: Icons.vibration_rounded,
                title: 'Agitar celular - 20% semanal',
                description:
                    'El cliente puede obtener 20% agitando el celular por 3 segundos. Disponible una vez por semana cuando esta activo.',
                payload: {
                  'tipo': 'agitar_celular',
                  'descuentoPorcentaje': 20,
                  'segundosAgitar': 3,
                  'limiteDias': 7,
                  'codigo': 'SHAKE20',
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _couponCard({
    required String id,
    required Map<String, dynamic>? data,
    required IconData icon,
    required String title,
    required String description,
    required Map<String, dynamic> payload,
  }) {
    final active = data?['activo'] == true;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: active ? amarillo : Colors.grey.shade200,
              foregroundColor: negro,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusPill(
                        active ? 'Activo' : 'Inactivo',
                        active ? Colors.green : Colors.grey,
                      ),
                      _statusPill(
                        '${payload['descuentoPorcentaje']}% descuento',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: active,
              onChanged: (value) => _setCouponActive(id, value, payload),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setCouponActive(
    String id,
    bool active,
    Map<String, dynamic> payload,
  ) async {
    await _couponsConfigRef.doc(id).set({
      ...payload,
      'activo': active,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget _reportsView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pedidosRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final todayDocs = docs.where((doc) {
          final created = _timestamp(doc.data(), ['creadoEn', 'fecha']);
          return _isToday(created);
        }).toList();
        final deliveredToday = todayDocs.where((doc) {
          return _estadoPedido(doc.data()['estado']) == 'entregado';
        }).toList();
        final canceledToday = todayDocs.where((doc) {
          return _estadoPedido(doc.data()['estado']) == 'cancelado';
        }).toList();
        final income = deliveredToday.fold<double>(
          0,
          (amount, doc) => amount + _number(doc.data()['total']),
        );
        final active = docs.where((doc) {
          final estado = _estadoPedido(doc.data()['estado']);
          return estado != 'entregado' && estado != 'cancelado';
        }).length;

        final productCount = <String, int>{};
        for (final doc in deliveredToday) {
          for (final item in _items(doc.data())) {
            final name = item['nombre']?.toString() ?? 'Producto';
            final qty = item['cantidad'] is num
                ? (item['cantidad'] as num).round()
                : int.tryParse(item['cantidad']?.toString() ?? '') ?? 1;
            productCount[name] = (productCount[name] ?? 0) + qty;
          }
        }
        final topProducts = productCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _pagePadding(
          ListView(
            children: [
              _sectionHeader(
                title: 'Reportes',
                subtitle: 'Resumen operativo de pedidos y ventas del dia.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard('Pedidos hoy', todayDocs.length.toString()),
                  _metricCard('Entregados', deliveredToday.length.toString()),
                  _metricCard('Cancelados', canceledToday.length.toString()),
                  _metricCard('Activos', active.toString()),
                  _metricCard('Ventas entregadas', _money(income)),
                ],
              ),
              const SizedBox(height: 18),
              _panelCard(
                title: 'Cantidad vendida por plato hoy',
                child: topProducts.isEmpty
                    ? const Text('Aun no hay platos vendidos hoy.')
                    : Column(
                        children: topProducts.take(8).map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: amarillo.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${entry.value} vendido(s)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _configurationView() {
    final configRef = _db
        .collection('configuracion_restaurante')
        .doc('principal');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: configRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};

        return _pagePadding(
          ListView(
            children: [
              _sectionHeader(
                title: 'Configuracion',
                subtitle:
                    'Ajustes principales del restaurante, ubicacion y delivery.',
              ),
              const SizedBox(height: 14),
              _panelCard(
                title: 'Delivery',
                child: Column(
                  children: [
                    _configRow(
                      configRef,
                      data,
                      field: 'restauranteLat',
                      label: 'Latitud del restaurante',
                      fallback: -12.039447,
                    ),
                    _configRow(
                      configRef,
                      data,
                      field: 'restauranteLng',
                      label: 'Longitud del restaurante',
                      fallback: -75.227225,
                    ),
                    _configRow(
                      configRef,
                      data,
                      field: 'costoBaseDelivery',
                      label: 'Costo base delivery',
                      fallback: 3.00,
                    ),
                    _configRow(
                      configRef,
                      data,
                      field: 'costoPorKmDelivery',
                      label: 'Costo por km',
                      fallback: 1.50,
                    ),
                    _configRow(
                      configRef,
                      data,
                      field: 'radioDeliveryKm',
                      label: 'Radio de delivery km',
                      fallback: 10.00,
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

  Widget _metricCard(String label, String value) {
    return SizedBox(
      width: 190,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: negro,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelCard({required String title, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _configRow(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, {
    required String field,
    required String label,
    required double fallback,
  }) {
    final value = _number(data[field] ?? fallback);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(field),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: () => _editConfigNumber(
              ref,
              field: field,
              label: label,
              currentValue: value,
            ),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _editConfigNumber(
    DocumentReference<Map<String, dynamic>> ref, {
    required String field,
    required String label,
    required double currentValue,
  }) async {
    final value = await _promptText(
      title: label,
      label: 'Nuevo valor',
      initialValue: currentValue.toStringAsFixed(2),
      requiredValue: true,
      maxLines: 1,
    );
    if (value == null) return;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un numero valido.')),
      );
      return;
    }

    await ref.set({
      field: parsed,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static const List<String> _roleOptions = [
    'cliente',
    'admin',
    'cocinero',
    'motociclista',
  ];

  Future<void> _updateUserRole(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String role,
  ) async {
    final normalizedRole = role == 'repartidor' ? 'motociclista' : role;
    await doc.reference.set({
      'rol': normalizedRole,
      'roles': [normalizedRole],
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) return _loginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _usuariosRef.doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userSnapshot.data?.data();
            if (_isAdmin(data)) return _adminShell(user);
            if (_isKitchen(data)) return _kitchenShell(user);
            return _notAllowedScreen(user);
          },
        );
      },
    );
  }
}

class _ShellDestination {
  final String label;
  final IconData icon;

  const _ShellDestination({required this.label, required this.icon});
}

class _OrderColumnData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _OrderColumnData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.docs,
  });
}

bool _isPizzaText(String nombre, String categoria) {
  final text = '$nombre $categoria'.toLowerCase();
  return text.contains('pizza');
}

String _normalizeVariant(String value, {required bool isPizza}) {
  if (!isPizza) return 'Normal';

  final normalized = value.trim().toLowerCase();
  if (normalized == 'grande' || normalized == 'familiar') return 'Familiar';
  return 'Mediana';
}

String _normalizeProductName(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ã±': 'n',
    'Ã±': 'n',
    'Ã¡': 'a',
    'Ã©': 'e',
    'Ã­': 'i',
    'Ã³': 'o',
    'Ãº': 'u',
  };

  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class _ProductOption {
  final String id;
  final String nombre;
  final String categoria;
  final String descripcion;
  final String imagenUrl;
  final double precio;
  final double? precioFamiliar;

  const _ProductOption({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.imagenUrl,
    required this.precio,
    required this.precioFamiliar,
  });

  bool get hasPizzaVariants =>
      _isPizzaText(nombre, categoria) && precioFamiliar != null;

  factory _ProductOption.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    final data = doc.data();
    return _ProductOption(
      id: doc.id,
      nombre: data['nombre']?.toString() ?? 'Producto',
      categoria: data['categoria']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      imagenUrl: data['imagenUrl']?.toString() ?? '',
      precio: number(data['precio']),
      precioFamiliar: data['precioFamiliar'] == null
          ? null
          : number(data['precioFamiliar']),
    );
  }
}

class _OrderEditItem {
  String productId;
  String nombre;
  String categoria;
  String descripcion;
  String imagenUrl;
  String lineId;
  double precioMediana;
  double? precioFamiliar;
  String variante;
  final TextEditingController cantidadController;

  _OrderEditItem({
    required this.productId,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.imagenUrl,
    required this.lineId,
    required String variante,
    required int cantidad,
    required this.precioMediana,
    required this.precioFamiliar,
  }) : variante = _normalizeVariant(
         variante,
         isPizza: _isPizzaText(nombre, categoria) && precioFamiliar != null,
       ),
       cantidadController = TextEditingController(text: cantidad.toString());

  factory _OrderEditItem.fromMap(
    Map<String, dynamic> item,
    List<_ProductOption> productOptions,
  ) {
    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int intNumber(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 1;
    }

    final productId = item['productId']?.toString() ?? '';
    final itemName = item['nombre']?.toString() ?? 'Producto';
    _ProductOption? selectedProduct;

    for (final product in productOptions) {
      if (product.id == productId) {
        selectedProduct = product;
        break;
      }
    }

    if (selectedProduct == null) {
      final normalizedItemName = _normalizeProductName(itemName);
      for (final product in productOptions) {
        if (_normalizeProductName(product.nombre) == normalizedItemName) {
          selectedProduct = product;
          break;
        }
      }
    }

    if (selectedProduct != null) {
      return _OrderEditItem.fromProduct(
        selectedProduct,
        cantidad: math.max(1, intNumber(item['cantidad'])),
        variante: item['variante']?.toString() ?? 'Normal',
        lineId: item['lineId']?.toString() ?? '',
      );
    }

    final categoria = item['categoria']?.toString() ?? '';
    final precio = number(item['precioUnitario']);
    return _OrderEditItem(
      productId: productId,
      nombre: itemName,
      categoria: categoria,
      descripcion: item['descripcion']?.toString() ?? '',
      imagenUrl: item['imagenUrl']?.toString() ?? '',
      lineId: item['lineId']?.toString() ?? '',
      variante: item['variante']?.toString() ?? 'Normal',
      cantidad: math.max(1, intNumber(item['cantidad'])),
      precioMediana: precio,
      precioFamiliar: null,
    );
  }

  factory _OrderEditItem.fromProduct(
    _ProductOption product, {
    int cantidad = 1,
    String variante = 'Normal',
    String lineId = '',
  }) {
    return _OrderEditItem(
      productId: product.id,
      nombre: product.nombre,
      categoria: product.categoria,
      descripcion: product.descripcion,
      imagenUrl: product.imagenUrl,
      lineId: lineId,
      variante: variante,
      cantidad: cantidad,
      precioMediana: product.precio,
      precioFamiliar: product.precioFamiliar,
    );
  }

  void applyProduct(_ProductOption product) {
    productId = product.id;
    nombre = product.nombre;
    categoria = product.categoria;
    descripcion = product.descripcion;
    imagenUrl = product.imagenUrl;
    precioMediana = product.precio;
    precioFamiliar = product.precioFamiliar;
    variante = product.hasPizzaVariants ? 'Mediana' : 'Normal';
    lineId = '';
  }

  bool get hasPizzaVariants =>
      _isPizzaText(nombre, categoria) && precioFamiliar != null;

  int get cantidad =>
      math.max(1, int.tryParse(cantidadController.text.trim()) ?? 1);

  double get precioUnitario {
    if (hasPizzaVariants && variante == 'Familiar') {
      return precioFamiliar ?? precioMediana;
    }
    return precioMediana;
  }

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toMap() {
    final savedVariant = _normalizeVariant(variante, isPizza: hasPizzaVariants);
    return {
      'lineId': '$productId|$savedVariant',
      'productId': productId,
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': descripcion,
      'imagenUrl': imagenUrl,
      'variante': savedVariant,
      'precioUnitario': double.parse(precioUnitario.toStringAsFixed(2)),
      'cantidad': cantidad,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
    };
  }

  void dispose() {
    cantidadController.dispose();
  }
}

class _InlineTextCell extends StatefulWidget {
  final String value;
  final double width;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Future<void> Function(String value) onSave;

  const _InlineTextCell({
    required this.value,
    required this.width,
    required this.onSave,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  State<_InlineTextCell> createState() => _InlineTextCellState();
}

class _InlineTextCellState extends State<_InlineTextCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _lastValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _InlineTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _lastValue) {
      _lastValue = widget.value;
      _controller.text = widget.value;
    }
  }

  Future<void> _commit() async {
    final value = _controller.text.trim();
    if (value == _lastValue || _saving) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(value);
      _lastValue = value;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
      _controller.text = _lastValue;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          suffixIcon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.edit_rounded, size: 16),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
        ),
      ),
    );
  }
}
