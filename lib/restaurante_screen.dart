import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'carrito_screen.dart';

class RestauranteScreen extends StatefulWidget {
  const RestauranteScreen({super.key});

  @override
  State<RestauranteScreen> createState() => _RestauranteScreenState();
}

class _RestauranteScreenState extends State<RestauranteScreen>
    with SingleTickerProviderStateMixin {
  final CollectionReference<Map<String, dynamic>> _productosRef =
      FirebaseFirestore.instance.collection('productos_restaurante');

  final TextEditingController _buscarController = TextEditingController();

  final List<Map<String, dynamic>> carrito = [];

  String _categoriaSeleccionada = 'Todas';
  String _busqueda = '';

  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;

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
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void agregarAlCarrito(Map<String, dynamic> producto) {
    setState(() {
      carrito.add(producto);
    });

    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto['nombre']} añadido al carrito'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void irAlCarrito() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarritoScreen(carrito: carrito),
      ),
    );

    setState(() {});
  }

  bool _pasaFiltros(Map<String, dynamic> data) {
    final nombre = (data['nombre'] ?? '').toString().toLowerCase();
    final categoria = (data['categoria'] ?? '').toString();

    final coincideBusqueda = nombre.contains(_busqueda.toLowerCase());
    final coincideCategoria =
        _categoriaSeleccionada == 'Todas' || categoria == _categoriaSeleccionada;

    return coincideBusqueda && coincideCategoria;
  }

  String _precioTexto(Map<String, dynamic> data) {
    final precio = (data['precio'] is num)
        ? (data['precio'] as num).toDouble()
        : double.tryParse(data['precio'].toString()) ?? 0.0;

    final precioFamiliar = data['precioFamiliar'];

    if (precioFamiliar is num) {
      return 'M: S/. ${precio.toStringAsFixed(2)}  |  F: S/. ${precioFamiliar.toDouble().toStringAsFixed(2)}';
    }

    return 'S/. ${precio.toStringAsFixed(2)}';
  }

  Widget _imagenProducto(String imagenUrl) {
    if (imagenUrl.trim().isEmpty) {
      return Container(
        height: 130,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3E0),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(18),
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu_rounded,
            size: 48,
            color: Color(0xFF8D5A1B),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(18),
      ),
      child: Image.network(
        imagenUrl,
        height: 130,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return const SizedBox(
            height: 130,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 130,
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

  Widget _carritoAction() {
    return Stack(
      children: [
        IconButton(
          tooltip: 'Ver carrito',
          onPressed: irAlCarrito,
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: const Icon(Icons.shopping_cart_rounded),
          ),
        ),
        if (carrito.isNotEmpty)
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
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${carrito.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _productoCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final nombre = data['nombre'] ?? 'Sin nombre';
    final categoria = data['categoria'] ?? 'Sin categoría';
    final descripcion = data['descripcion'] ?? '';
    final imagenUrl = data['imagenUrl'] ?? '';
    final disponible = data['disponible'] == true;
    final destacado = data['destacado'] == true;

    final productoCarrito = {
      'id': doc.id,
      ...data,
    };

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _imagenProducto(imagenUrl.toString()),
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
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Destacado',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _precioTexto(data),
                      style: const TextStyle(
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      categoria.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descripcion.toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: disponible
                            ? () => agregarAlCarrito(productoCarrito)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(
                          disponible ? 'Agregar' : 'No disponible',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D3517),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade400,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtros() {
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
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            setState(() => _busqueda = value.trim());
          },
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
                selectedColor: const Color(0xFFFFCC80),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: seleccionado ? Colors.black : Colors.black87,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: seleccionado
                      ? const Color(0xFFE65100)
                      : Colors.grey.shade300,
                ),
                onSelected: (_) {
                  setState(() => _categoriaSeleccionada = categoria);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listaProductos() {
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
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filtrados = docs.where((doc) => _pasaFiltros(doc.data())).toList();

        if (filtrados.isEmpty) {
          return const Center(
            child: Text(
              'No hay productos para mostrar.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          itemCount: filtrados.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.56,
          ),
          itemBuilder: (context, index) {
            return _productoCard(filtrados[index]);
          },
        );
      },
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF5D3517),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carta del restaurante',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Productos desde Firestore e imágenes desde Cloudinary.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D3517),
        foregroundColor: Colors.white,
        title: const Text('El Bart-o - Carta digital'),
        actions: [
          _carritoAction(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 14),
            _filtros(),
            const SizedBox(height: 8),
            Expanded(
              child: _listaProductos(),
            ),
          ],
        ),
      ),
    );
  }
}