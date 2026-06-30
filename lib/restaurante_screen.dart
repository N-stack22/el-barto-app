import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'auth_service.dart';
import 'carrito_screen.dart';
import 'cart_controller.dart';
import 'favoritos_service.dart';
import 'tu_screen.dart';
import 'widgets/custom_app_bar.dart';

class RestauranteScreen extends StatefulWidget {
  const RestauranteScreen({super.key});

  @override
  State<RestauranteScreen> createState() => _RestauranteScreenState();
}

class _RestauranteScreenState extends State<RestauranteScreen>
    with SingleTickerProviderStateMixin {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);
  static const Color fondo = Color(0xFFF7F7F7);

  final CollectionReference<Map<String, dynamic>> _productosRef =
      FirebaseFirestore.instance.collection('productos_restaurante');

  final TextEditingController _buscarController = TextEditingController();
  final CartController _cart = CartController.instance;

  int _selectedIndex = 0;
  String _categoriaSeleccionada = 'Todas';
  String _busqueda = '';

  late final AnimationController _iconAnimationController;
  late final Animation<double> _scaleAnimation;

  final List<String> _categorias = const [
    'Todas',
    'Bife y lomo al kamado',
    'Pollo',
    'Hamburguesas y salchipapas',
    'Pastas y pasta con carne',
    'Pizzas artesanales',
    'Bebidas',
  ];

  @override
  void initState() {
    super.initState();

    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  double _precio(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(double value) => 'S/. ${value.toStringAsFixed(2)}';

  String _precioTexto(Map<String, dynamic> data) {
    final precio = _precio(data['precio']);
    final precioFamiliar = data['precioFamiliar'];

    if (precioFamiliar is num) {
      return 'M: ${_money(precio)} / F: ${_money(precioFamiliar.toDouble())}';
    }

    return _money(precio);
  }

  String _precioCardTexto(Map<String, dynamic> data) {
    final precio = _precio(data['precio']);
    final precioFamiliar = data['precioFamiliar'];

    if (precioFamiliar is num) {
      return 'Desde S/ ${precio.toStringAsFixed(2)}';
    }

    return 'S/ ${precio.toStringAsFixed(2)}';
  }

  bool _pasaBusqueda(Map<String, dynamic> data) {
    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
    final categoria = (data['categoria'] ?? '').toString().toLowerCase();
    final descripcion = (data['descripcion'] ?? '').toString().toLowerCase();
    final query = _busqueda.toLowerCase();

    if (query.isEmpty) return true;
    return nombre.contains(query) ||
        categoria.contains(query) ||
        descripcion.contains(query);
  }

  bool _pasaCategoria(Map<String, dynamic> data, String categoria) {
    return categoria == 'Todas' || data['categoria']?.toString() == categoria;
  }

  void _agregarAlCarrito(
    Map<String, dynamic> producto, {
    String variante = 'Normal',
    double? precio,
  }) {
    _cart.addProduct(producto, variante: variante, precio: precio);

    _iconAnimationController.forward().then((_) {
      if (mounted) _iconAnimationController.reverse();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto['nombre'] ?? 'Producto'} añadido al carrito'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 88, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _toggleFavorito(Map<String, dynamic> producto) async {
    var user = AuthService().currentUser;

    if (user == null) {
      await _abrirLogin();
      user = AuthService().currentUser;
      if (user == null) return;
    }

    try {
      final added = await FavoritosService.instance.toggleFavorite(
        user: user,
        producto: producto,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '${producto['nombre'] ?? 'Producto'} agregado a favoritos'
                : '${producto['nombre'] ?? 'Producto'} quitado de favoritos',
          ),
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 88, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar favoritos: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _favoritoButton(Map<String, dynamic> producto) {
    final productId = producto['id']?.toString() ?? '';

    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        return StreamBuilder<bool>(
          stream: FavoritosService.instance.isFavoriteStream(user, productId),
          builder: (context, favSnapshot) {
            final isFavorite = favSnapshot.data == true;

            return Material(
              color: Colors.white.withOpacity(0.92),
              elevation: 2,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _toggleFavorito(producto),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red : negro,
                    size: 23,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión? El carrito no se perderá.'),
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

    if (shouldLogout == true) {
      await AuthService().logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada. Puedes seguir viendo la carta.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    }
  }

  Future<void> _abrirLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(returnToPrevious: true),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _imagenProducto(String imagenUrl, {double height = 132}) {
    if (imagenUrl.trim().isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF4BF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: const Center(
          child: Icon(Icons.restaurant_menu_rounded, size: 48, color: negro),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Image.network(
        imagenUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: double.infinity,
            color: const Color(0xFFFFEBEE),
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                size: 45,
                color: Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarDetalleProducto(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = {'id': doc.id, ...doc.data()};
    final nombre = data['nombre']?.toString() ?? 'Producto';
    final categoria = data['categoria']?.toString() ?? 'Sin categoría';
    final descripcion = data['descripcion']?.toString() ?? 'Sin descripción';
    final imagenUrl = data['imagenUrl']?.toString() ?? '';
    final disponible = data['disponible'] == true;
    final precio = _precio(data['precio']);
    final precioFamiliar = data['precioFamiliar'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _imagenProducto(imagenUrl, height: 210),
                ),
                const SizedBox(height: 18),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: negro,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: amarillo.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    categoria,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 18),
                Text(
                  _precioTexto(data),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: negro,
                  ),
                ),
                const SizedBox(height: 16),
                if (!disponible)
                  const SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: null,
                      child: Text('No disponible'),
                    ),
                  )
                else if (precioFamiliar is num)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _agregarAlCarrito(
                              data,
                              variante: 'Mediana',
                              precio: precio,
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Mediana'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _agregarAlCarrito(
                              data,
                              variante: 'Familiar',
                              precio: precioFamiliar.toDouble(),
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.local_pizza_rounded),
                          label: const Text('Familiar'),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _agregarAlCarrito(data, precio: precio);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Agregar al carrito'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _productoCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = {'id': doc.id, ...doc.data()};
    final nombre = data['nombre'] ?? 'Sin nombre';
    final imagenUrl = data['imagenUrl'] ?? '';
    final disponible = data['disponible'] == true;
    final destacado = data['destacado'] == true;
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 1.5,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarDetalleProducto(doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _imagenProducto(imagenUrl.toString(), height: 132),
                if (destacado)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: amarillo,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Destacado',
                        style: TextStyle(
                          color: negro,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                Positioned(top: 8, right: 8, child: _favoritoButton(data)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        nombre.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.4,
                          height: 1.05,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 104,
                              maxWidth: 136,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: negro,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                _precioCardTexto(data),
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: amarillo,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: disponible ? amarillo : Colors.grey.shade300,
                        shape: const CircleBorder(),
                        elevation: disponible ? 2 : 0,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: disponible
                              ? () => _agregarAlCarrito(
                                  data,
                                  precio: _precio(data['precio']),
                                )
                              : null,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.add_rounded, color: negro),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productosStream({
    required Widget Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    )
    builder,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productosRef.orderBy('orden').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Error al cargar productos:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Todavía no hay productos. Carga la colección productos_restaurante.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }

        return builder(docs);
      },
    );
  }

  Widget _gridProductos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const Center(child: Text('No hay productos para mostrar.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxWidth < 380 ? 236.0 : 248.0;

        return GridView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) => _productoCard(docs[index]),
        );
      },
    );
  }

  Widget _imagenCircularCategoria(String imagenUrl, {double size = 88}) {
    final url = imagenUrl.trim();

    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFF1B8),
        ),
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: negro,
          size: size * 0.42,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF1B8),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFEBEE),
          ),
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.red,
            size: size * 0.36,
          ),
        ),
      ),
    );
  }

  Widget _productoCategoriaTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    double imageSize = 88,
  }) {
    final data = {'id': doc.id, ...doc.data()};
    final nombre = data['nombre']?.toString() ?? 'Producto';
    final imagenUrl = data['imagenUrl']?.toString() ?? '';
    final disponible = data['disponible'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _mostrarDetalleProducto(doc),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _imagenCircularCategoria(imagenUrl, size: imageSize),
                if (disponible)
                  Positioned(
                    right: -4,
                    bottom: 2,
                    child: Material(
                      color: amarillo,
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _agregarAlCarrito(
                          data,
                          precio: _precio(data['precio']),
                        ),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.add_rounded,
                            size: 23,
                            color: negro,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!disponible)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.62),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.block_rounded,
                          color: Colors.black54,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  nombre,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: negro,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: amarillo.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _precioTexto(data),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: negro,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridProductosCategoria(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No hay productos en esta categoría.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth < 300 ? 76.0 : 88.0;
        final itemHeight = constraints.maxWidth < 300 ? 198.0 : 218.0;

        return GridView.builder(
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 28,
            right: 10,
            left: 8,
          ),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            mainAxisExtent: itemHeight,
          ),
          itemBuilder: (context, index) =>
              _productoCategoriaTile(docs[index], imageSize: imageSize),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: negro,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Carta digital',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Carnes · Pastas · Pizzas',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _filtrosInicio() {
    return Column(
      children: [
        TextField(
          controller: _buscarController,
          decoration: InputDecoration(
            hintText: 'Buscar plato...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _busqueda.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _buscarController.clear();
                      setState(() => _busqueda = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _busqueda = value.trim()),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categorias.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final categoria = _categorias[index];
              final seleccionado = categoria == _categoriaSeleccionada;

              return ChoiceChip(
                label: Text(categoria),
                selected: seleccionado,
                selectedColor: amarillo,
                backgroundColor: Theme.of(context).colorScheme.surface,
                labelStyle: TextStyle(
                  color: seleccionado
                      ? negro
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: seleccionado ? FontWeight.w900 : FontWeight.w600,
                ),
                side: BorderSide(
                  color: seleccionado
                      ? negro
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                onSelected: (_) =>
                    setState(() => _categoriaSeleccionada = categoria),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inicioPage() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _header(),
          const SizedBox(height: 14),
          _filtrosInicio(),
          const SizedBox(height: 4),
          Expanded(
            child: _productosStream(
              builder: (docs) {
                final filtrados = docs.where((doc) {
                  final data = doc.data();
                  return _pasaBusqueda(data) &&
                      _pasaCategoria(data, _categoriaSeleccionada);
                }).toList();
                final destacados = filtrados
                    .where((doc) => doc.data()['destacado'] == true)
                    .toList();
                final normales = filtrados
                    .where((doc) => doc.data()['destacado'] != true)
                    .toList();

                return _gridProductos([...destacados, ...normales]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriasPage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 116,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            border: Border(
              right: BorderSide(color: Colors.black.withOpacity(0.07)),
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: _categorias.length,
            itemBuilder: (context, index) {
              final categoria = _categorias[index];
              final selected = categoria == _categoriaSeleccionada;

              return Material(
                color: selected ? Colors.white : Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      setState(() => _categoriaSeleccionada = categoria),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 4,
                          color: selected ? amarillo : Colors.transparent,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 13,
                            ),
                            child: Text(
                              categoria,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.08,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: selected ? negro : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comprar por categoría',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: negro,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _categoriaSeleccionada,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _productosStream(
                      builder: (docs) {
                        final filtrados = docs
                            .where(
                              (doc) => _pasaCategoria(
                                doc.data(),
                                _categoriaSeleccionada,
                              ),
                            )
                            .toList();
                        return _gridProductosCategoria(filtrados);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _authAction() {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final logged = snapshot.data != null;
        return IconButton(
          tooltip: logged ? 'Cerrar sesión' : 'Iniciar sesión',
          onPressed: logged ? _handleLogout : _abrirLogin,
          icon: Icon(logged ? Icons.logout_rounded : Icons.person_rounded),
        );
      },
    );
  }

  Widget _cartAction() {
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        return Stack(
          children: [
            IconButton(
              tooltip: 'Ver carrito',
              onPressed: () => setState(() => _selectedIndex = 2),
              icon: ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(Icons.shopping_cart_rounded),
              ),
            ),
            if (_cart.totalCantidad > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: amarillo,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_cart.totalCantidad}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: negro,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _inicioPage(),
      const CarritoView(showTitle: false),
      const TuScreen(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(actions: [_authAction()]),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: AnimatedBuilder(
        animation: _cart,
        builder: (context, _) {
          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Badge.count(
                  count: _cart.totalCantidad,
                  isLabelVisible: _cart.totalCantidad > 0,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge.count(
                  count: _cart.totalCantidad,
                  isLabelVisible: _cart.totalCantidad > 0,
                  child: const Icon(Icons.shopping_cart_rounded),
                ),
                label: 'Carrito',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Tú',
              ),
            ],
          );
        },
      ),
    );
  }
}
