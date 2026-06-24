import 'package:flutter/foundation.dart';

class CartItem {
  final String lineId;
  final String productId;
  final String nombre;
  final String categoria;
  final String descripcion;
  final String imagenUrl;
  final String variante;
  final double precioUnitario;
  int cantidad;

  CartItem({
    required this.lineId,
    required this.productId,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.imagenUrl,
    required this.variante,
    required this.precioUnitario,
    this.cantidad = 1,
  });

  double get subtotal => precioUnitario * cantidad;

  Map<String, dynamic> toMap() {
    return {
      'lineId': lineId,
      'productId': productId,
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': descripcion,
      'imagenUrl': imagenUrl,
      'variante': variante,
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
      'subtotal': subtotal,
    };
  }
}

class CartController extends ChangeNotifier {
  CartController._();

  static final CartController instance = CartController._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCantidad => _items.fold(0, (sum, item) => sum + item.cantidad);

  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  static String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void addProduct(
    Map<String, dynamic> product, {
    String variante = 'Normal',
    double? precio,
  }) {
    final productId = _text(product['id'], _text(product['nombre'], 'producto'));
    final lineId = '$productId|$variante';
    final existingIndex = _items.indexWhere((item) => item.lineId == lineId);

    if (existingIndex >= 0) {
      _items[existingIndex].cantidad++;
      notifyListeners();
      return;
    }

    _items.add(
      CartItem(
        lineId: lineId,
        productId: productId,
        nombre: _text(product['nombre'], 'Producto'),
        categoria: _text(product['categoria'], 'Sin categoría'),
        descripcion: _text(product['descripcion']),
        imagenUrl: _text(product['imagenUrl']),
        variante: variante,
        precioUnitario: precio ?? _number(product['precio']),
      ),
    );

    notifyListeners();
  }

  void increase(String lineId) {
    final index = _items.indexWhere((item) => item.lineId == lineId);
    if (index < 0) return;
    _items[index].cantidad++;
    notifyListeners();
  }

  void decrease(String lineId) {
    final index = _items.indexWhere((item) => item.lineId == lineId);
    if (index < 0) return;

    if (_items[index].cantidad <= 1) {
      _items.removeAt(index);
    } else {
      _items[index].cantidad--;
    }

    notifyListeners();
  }

  void remove(String lineId) {
    _items.removeWhere((item) => item.lineId == lineId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
