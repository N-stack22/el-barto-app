import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritosService {
  FavoritosService._();

  static final FavoritosService instance = FavoritosService._();

  final CollectionReference<Map<String, dynamic>> _favoritosRef =
      FirebaseFirestore.instance.collection('favoritos_restaurante');

  String favoritoId(String uid, String productId) => '${uid}_$productId';

  DocumentReference<Map<String, dynamic>> favoritoRef(String uid, String productId) {
    return _favoritosRef.doc(favoritoId(uid, productId));
  }

  Stream<bool> isFavoriteStream(User? user, String productId) {
    if (user == null || productId.trim().isEmpty) {
      return Stream<bool>.value(false);
    }

    return favoritoRef(user.uid, productId).snapshots().map((doc) => doc.exists);
  }

  Future<bool> toggleFavorite({
    required User user,
    required Map<String, dynamic> producto,
  }) async {
    final productId = producto['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      throw Exception('El producto no tiene id.');
    }

    final ref = favoritoRef(user.uid, productId);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.delete();
      return false;
    }

    await ref.set({
      'userId': user.uid,
      'productId': productId,
      'nombre': producto['nombre']?.toString() ?? 'Producto',
      'categoria': producto['categoria']?.toString() ?? 'Sin categoría',
      'descripcion': producto['descripcion']?.toString() ?? '',
      'imagenUrl': producto['imagenUrl']?.toString() ?? '',
      'precio': producto['precio'] is num
          ? (producto['precio'] as num).toDouble()
          : double.tryParse(producto['precio']?.toString() ?? '') ?? 0.0,
      if (producto['precioFamiliar'] is num)
        'precioFamiliar': (producto['precioFamiliar'] as num).toDouble(),
      'disponible': producto['disponible'] == true,
      'creadoEn': FieldValue.serverTimestamp(),
    });

    return true;
  }
}
