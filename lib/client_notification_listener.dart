import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tu_screen.dart';

class ClientNotificationListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final GlobalKey<NavigatorState> navigatorKey;

  const ClientNotificationListener({
    super.key,
    required this.child,
    required this.scaffoldMessengerKey,
    required this.navigatorKey,
  });

  @override
  State<ClientNotificationListener> createState() =>
      _ClientNotificationListenerState();
}

class _ClientNotificationListenerState
    extends State<ClientNotificationListener> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  final Set<String> _shownNotifications = <String>{};
  String? _currentUid;
  bool _initialSnapshotHandled = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    _authSub = FirebaseAuth.instance.authStateChanges().listen(_handleUser);
    _handleUser(FirebaseAuth.instance.currentUser);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  Future<void> _handleUser(User? user) async {
    if (_currentUid == user?.uid) return;

    _currentUid = user?.uid;
    _initialSnapshotHandled = false;
    _shownNotifications.clear();
    await _ordersSub?.cancel();
    _ordersSub = null;

    if (user == null) return;

    _ordersSub = FirebaseFirestore.instance
        .collection('pedidos_restaurante')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(_handleOrdersSnapshot, onError: _handleOrdersError);
  }

  void _handleOrdersError(Object error) {
    debugPrint('No se pudieron escuchar notificaciones: $error');
  }

  void _handleOrdersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_initialSnapshotHandled) {
      _initialSnapshotHandled = true;

      final pending = snapshot.docs.where((doc) {
        final data = doc.data();
        return _notificationText(data).isNotEmpty &&
            data['notificacionLeida'] != true;
      }).toList();

      pending.sort(
        (a, b) =>
            _notificationDate(b.data()).compareTo(_notificationDate(a.data())),
      );

      if (pending.isNotEmpty) {
        _showNotice(pending.first.id, pending.first.data());
      }
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;

      final data = change.doc.data();
      if (data == null) continue;
      if (_notificationText(data).isEmpty ||
          data['notificacionLeida'] == true) {
        continue;
      }

      _showNotice(change.doc.id, data);
    }
  }

  DateTime _notificationDate(Map<String, dynamic> data) {
    final value =
        data['notificacionCreadaEn'] ??
        data['estadoActualizadoEn'] ??
        data['creadoEn'] ??
        data['fecha'];

    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _notificationText(Map<String, dynamic> data) {
    final direct = data['notificacionCliente']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final cancelReason = data['motivoCancelacion']?.toString().trim() ?? '';
    if (cancelReason.isNotEmpty) {
      return 'Tu pedido fue cancelado. Motivo: $cancelReason';
    }

    final message = data['mensajeCliente']?.toString().trim() ?? '';
    if (message.isNotEmpty) return message;

    return '';
  }

  String _notificationTitle(Map<String, dynamic> data) {
    final type = data['notificacionTipo']?.toString() ?? '';
    final state = data['estado']?.toString() ?? '';

    if (type == 'pedido_cancelado' || state == 'cancelado') {
      return 'Pedido cancelado';
    }
    if (type == 'pedido_editado') return 'Pedido editado';
    if (type == 'pedido_listo') return 'Pedido listo';
    if (type == 'pedido_aceptado') return 'Pedido aceptado';
    return 'Aviso del restaurante';
  }

  String _notificationKey(String orderId, Map<String, dynamic> data) {
    return [
      orderId,
      data['notificacionTipo']?.toString() ?? '',
      _notificationText(data),
    ].join('|');
  }

  void _showNotice(String orderId, Map<String, dynamic> data) {
    final key = _notificationKey(orderId, data);
    if (_shownNotifications.contains(key)) return;
    _shownNotifications.add(key);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = widget.scaffoldMessengerKey.currentState;
      if (messenger == null) return;

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
            backgroundColor: const Color(0xFF050505),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _notificationTitle(data),
                  style: const TextStyle(
                    color: Color(0xFFFFC928),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _notificationText(data),
                  style: const TextStyle(color: Colors.white, height: 1.25),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Ver',
              textColor: const Color(0xFFFFC928),
              onPressed: () {
                widget.navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => const ClienteNotificacionesScreen(),
                  ),
                );
              },
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
