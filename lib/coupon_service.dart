import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CouponConfig {
  final String id;
  final bool active;
  final String type;
  final String code;
  final int discountPercentage;
  final int requiredPurchases;
  final int shakeSeconds;
  final int limitDays;

  const CouponConfig({
    required this.id,
    required this.active,
    required this.type,
    required this.code,
    required this.discountPercentage,
    required this.requiredPurchases,
    required this.shakeSeconds,
    required this.limitDays,
  });

  factory CouponConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CouponConfig(
      id: doc.id,
      active: data['activo'] == true,
      type: _text(data['tipo']),
      code: _text(data['codigo'], doc.id),
      discountPercentage: _int(data['descuentoPorcentaje']),
      requiredPurchases: _int(data['comprasRequeridas'], 5),
      shakeSeconds: _int(data['segundosAgitar'], 3),
      limitDays: _int(data['limiteDias'], 7),
    );
  }
}

class CustomerCoupon {
  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final String userId;
  final String code;
  final String origin;
  final String title;
  final int discountPercentage;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const CustomerCoupon({
    required this.id,
    required this.reference,
    required this.userId,
    required this.code,
    required this.origin,
    required this.title,
    required this.discountPercentage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isAvailable => status == 'disponible' && !isExpired;

  factory CustomerCoupon.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CustomerCoupon(
      id: doc.id,
      reference: doc.reference,
      userId: _text(data['userId']),
      code: _text(data['codigo']),
      origin: _text(data['origen']),
      title: _text(data['titulo'], 'Cupon'),
      discountPercentage: _int(data['descuentoPorcentaje']),
      status: _text(data['estado'], 'disponible'),
      createdAt: _date(data['creadoEn']),
      expiresAt: _date(data['expiraEn']),
    );
  }
}

class PurchaseCouponStatus {
  final bool active;
  final int deliveredCount;
  final int requiredPurchases;
  final int discountPercentage;
  final int claimableBlock;
  final int nextBlock;

  const PurchaseCouponStatus({
    required this.active,
    required this.deliveredCount,
    required this.requiredPurchases,
    required this.discountPercentage,
    required this.claimableBlock,
    required this.nextBlock,
  });

  bool get canClaim => active && claimableBlock > 0;

  int get remainingPurchases {
    if (canClaim) return 0;
    final target = math.max(1, nextBlock) * requiredPurchases;
    return math.max(0, target - deliveredCount);
  }
}

class ShakeCouponStatus {
  final bool active;
  final int discountPercentage;
  final int shakeSeconds;
  final int limitDays;
  final DateTime? lastClaimAt;

  const ShakeCouponStatus({
    required this.active,
    required this.discountPercentage,
    required this.shakeSeconds,
    required this.limitDays,
    required this.lastClaimAt,
  });

  DateTime? get nextAvailableAt =>
      lastClaimAt == null ? null : lastClaimAt!.add(Duration(days: limitDays));

  bool get canClaim {
    final next = nextAvailableAt;
    return active && (next == null || DateTime.now().isAfter(next));
  }
}

class CouponService {
  CouponService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get configRef =>
      _db.collection('configuracion_cupones');

  static CollectionReference<Map<String, dynamic>> get customerCouponsRef =>
      _db.collection('cupones_clientes');

  static CollectionReference<Map<String, dynamic>> get ordersRef =>
      _db.collection('pedidos_restaurante');

  static Stream<List<CustomerCoupon>> customerCouponsStream(String uid) {
    return customerCouponsRef.where('userId', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final coupons = snapshot.docs
          .map((doc) => CustomerCoupon.fromDoc(doc))
          .toList();
      coupons.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return coupons;
    });
  }

  static Stream<List<CustomerCoupon>> availableCouponsStream(String uid) {
    return customerCouponsStream(
      uid,
    ).map((coupons) => coupons.where((coupon) => coupon.isAvailable).toList());
  }

  static Future<CouponConfig?> loadConfig(String id) async {
    final doc = await configRef.doc(id).get();
    if (!doc.exists) return null;
    return CouponConfig.fromDoc(doc);
  }

  static Future<PurchaseCouponStatus> purchaseStatus(User user) async {
    final config = await loadConfig('compras_5_descuento_30');
    final requiredPurchases = math.max(1, config?.requiredPurchases ?? 5);
    final discount = config?.discountPercentage ?? 30;
    final deliveredCount = await _deliveredOrderCount(user.uid);
    final earnedBlocks = deliveredCount ~/ requiredPurchases;
    final claimedBlocks = await _claimedPurchaseBlocks(user.uid);
    var claimableBlock = 0;

    for (var block = 1; block <= earnedBlocks; block++) {
      if (!claimedBlocks.contains(block)) {
        claimableBlock = block;
        break;
      }
    }

    return PurchaseCouponStatus(
      active: config?.active == true,
      deliveredCount: deliveredCount,
      requiredPurchases: requiredPurchases,
      discountPercentage: discount,
      claimableBlock: claimableBlock,
      nextBlock: claimableBlock > 0 ? claimableBlock : earnedBlocks + 1,
    );
  }

  static Future<ShakeCouponStatus> shakeStatus(User user) async {
    final config = await loadConfig('shake_20_semanal');
    final limitDays = math.max(1, config?.limitDays ?? 7);
    final lastClaimAt = await _lastShakeClaim(user.uid);

    return ShakeCouponStatus(
      active: config?.active == true,
      discountPercentage: config?.discountPercentage ?? 20,
      shakeSeconds: math.max(1, config?.shakeSeconds ?? 3),
      limitDays: limitDays,
      lastClaimAt: lastClaimAt,
    );
  }

  static Future<String> claimPurchaseCoupon(User user) async {
    final status = await purchaseStatus(user);
    if (!status.active) {
      throw Exception('El cupon por compras todavia no esta activo.');
    }
    if (!status.canClaim) {
      throw Exception(
        'Te faltan ${status.remainingPurchases} compra(s) entregadas.',
      );
    }

    final docId = '${user.uid}_BARTO5_${status.claimableBlock}';
    await customerCouponsRef.doc(docId).set({
      'userId': user.uid,
      'email': user.email ?? '',
      'codigo': 'BARTO5',
      'origen': 'compras_5_descuento_30',
      'titulo': '${status.discountPercentage}% por 5 compras',
      'descuentoPorcentaje': status.discountPercentage,
      'estado': 'disponible',
      'bloqueCompras': status.claimableBlock,
      'comprasContadas': status.deliveredCount,
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return 'Cupon BARTO5 activado.';
  }

  static Future<String> claimShakeCoupon(User user) async {
    final status = await shakeStatus(user);
    if (!status.active) {
      throw Exception('El cupon por agitar todavia no esta activo.');
    }
    if (!status.canClaim) {
      final next = status.nextAvailableAt;
      final suffix = next == null
          ? ''
          : ' Disponible desde ${_shortDate(next)}.';
      throw Exception('Ya obtuviste este cupon esta semana.$suffix');
    }

    final now = DateTime.now();
    await customerCouponsRef
        .doc('${user.uid}_SHAKE20_${now.millisecondsSinceEpoch}')
        .set({
          'userId': user.uid,
          'email': user.email ?? '',
          'codigo': 'SHAKE20',
          'origen': 'shake_20_semanal',
          'titulo': '${status.discountPercentage}% por agitar',
          'descuentoPorcentaje': status.discountPercentage,
          'estado': 'disponible',
          'creadoEn': FieldValue.serverTimestamp(),
          'expiraEn': Timestamp.fromDate(
            now.add(Duration(days: status.limitDays)),
          ),
          'actualizadoEn': FieldValue.serverTimestamp(),
        });

    return 'Cupon SHAKE20 activado.';
  }

  static double discountAmount(CustomerCoupon? coupon, double subtotal) {
    if (coupon == null || !coupon.isAvailable || subtotal <= 0) return 0;
    final amount = subtotal * coupon.discountPercentage / 100;
    return double.parse(math.min(subtotal, amount).toStringAsFixed(2));
  }

  static void markCouponUsedInBatch(
    WriteBatch batch,
    CustomerCoupon coupon,
    String orderId,
  ) {
    batch.set(coupon.reference, {
      'estado': 'usado',
      'pedidoId': orderId,
      'usadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<int> _deliveredOrderCount(String uid) async {
    final snapshot = await ordersRef.where('userId', isEqualTo: uid).get();
    return snapshot.docs.where((doc) {
      final state = _state(doc.data()['estado']);
      return state == 'entregado';
    }).length;
  }

  static Future<Set<int>> _claimedPurchaseBlocks(String uid) async {
    final snapshot = await customerCouponsRef
        .where('userId', isEqualTo: uid)
        .get();

    return snapshot.docs
        .map((doc) => doc.data())
        .where((data) => _text(data['origen']) == 'compras_5_descuento_30')
        .map((data) => _int(data['bloqueCompras']))
        .where((block) => block > 0)
        .toSet();
  }

  static Future<DateTime?> _lastShakeClaim(String uid) async {
    final snapshot = await customerCouponsRef
        .where('userId', isEqualTo: uid)
        .get();

    DateTime? latest;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (_text(data['origen']) != 'shake_20_semanal') continue;
      final createdAt = _date(data['creadoEn']);
      if (createdAt == null) continue;
      if (latest == null || createdAt.isAfter(latest)) latest = createdAt;
    }
    return latest;
  }
}

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _state(dynamic value) {
  final text = _text(value).toLowerCase().trim().replaceAll(' ', '_');
  if (text == 'entregado' || text == 'delivery_entregado') return 'entregado';
  return text;
}

String _shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
