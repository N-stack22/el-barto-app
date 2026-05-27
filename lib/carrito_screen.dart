import 'package:flutter/material.dart';

class CarritoScreen extends StatefulWidget {
  final List<Map<String, dynamic>> carrito;

  const CarritoScreen({
    super.key,
    required this.carrito,
  });

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  double get total {
    double suma = 0;

    for (final producto in widget.carrito) {
      final precio = producto['precio'];

      if (precio is num) {
        suma += precio.toDouble();
      } else {
        suma += double.tryParse(precio.toString()) ?? 0;
      }
    }

    return suma;
  }

  void eliminarProducto(int index) {
    final nombre = widget.carrito[index]['nombre'] ?? 'Producto';

    setState(() {
      widget.carrito.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$nombre eliminado del carrito'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void vaciarCarrito() {
    setState(() {
      widget.carrito.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Carrito vacío'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget imagenCarrito(String imagenUrl) {
    if (imagenUrl.trim().isEmpty) {
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.restaurant_menu_rounded,
          color: Color(0xFF8D5A1B),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imagenUrl,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 62,
            height: 62,
            color: const Color(0xFFFFEBEE),
            child: const Icon(Icons.broken_image, color: Colors.red),
          );
        },
      ),
    );
  }

  String precioTexto(Map<String, dynamic> producto) {
    final precio = producto['precio'];

    final valor = precio is num
        ? precio.toDouble()
        : double.tryParse(precio.toString()) ?? 0.0;

    return 'S/. ${valor.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D3517),
        foregroundColor: Colors.white,
        title: const Text('Mi carrito'),
        actions: [
          if (widget.carrito.isNotEmpty)
            IconButton(
              onPressed: vaciarCarrito,
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Vaciar carrito',
            ),
        ],
      ),
      body: widget.carrito.isEmpty
          ? const Center(
              child: Text(
                'Tu carrito está vacío',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: widget.carrito.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final producto = widget.carrito[index];
                      final imagenUrl = producto['imagenUrl']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            imagenCarrito(imagenUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto['nombre']?.toString() ??
                                        'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    producto['categoria']?.toString() ??
                                        'Sin categoría',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    precioTexto(producto),
                                    style: const TextStyle(
                                      color: Color(0xFFE65100),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => eliminarProducto(index),
                              icon: const Icon(
                                Icons.delete_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total a pagar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'S/. ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pedido registrado para prueba',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Confirmar pedido'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5D3517),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}