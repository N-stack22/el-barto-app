import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'auth_screen.dart';
import 'auth_service.dart';
import 'coupon_service.dart';

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key});

  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  StreamSubscription? _sensorSub;
  Future<PurchaseCouponStatus>? _purchaseFuture;
  Future<ShakeCouponStatus>? _shakeFuture;
  String? _futureUserId;
  DateTime? _shakeStartedAt;
  DateTime? _lastShakePulseAt;
  bool _claimingPurchase = false;
  bool _claimingShake = false;
  double _shakeProgress = 0;

  @override
  void initState() {
    super.initState();
    _startShakeSensor();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  void _startShakeSensor() {
    if (kIsWeb) return;

    _sensorSub = SensorsPlatform.instance.userAccelerometerEventStream().listen(
      (event) {
        if (!mounted || _claimingShake) return;

        final user = AuthService().currentUser;
        if (user == null) return;

        final force = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        final now = DateTime.now();
        final lastPulse = _lastShakePulseAt;

        if (force >= 8.0) {
          if (_shakeStartedAt == null ||
              (lastPulse != null &&
                  now.difference(lastPulse) >
                      const Duration(milliseconds: 750))) {
            _shakeStartedAt = now;
          }

          _lastShakePulseAt = now;
          final elapsed = now.difference(_shakeStartedAt!).inMilliseconds;
          final progress = (elapsed / 3000).clamp(0.0, 1.0);
          if (progress != _shakeProgress) {
            setState(() => _shakeProgress = progress);
          }

          if (progress >= 1) {
            _claimShake(user);
          }
          return;
        }

        if (lastPulse != null &&
            now.difference(lastPulse) > const Duration(milliseconds: 900) &&
            _shakeProgress > 0) {
          setState(() {
            _shakeProgress = 0;
            _shakeStartedAt = null;
            _lastShakePulseAt = null;
          });
        }
      },
    );
  }

  void _ensureFutures(User user) {
    if (_futureUserId == user.uid &&
        _purchaseFuture != null &&
        _shakeFuture != null) {
      return;
    }

    _futureUserId = user.uid;
    _purchaseFuture = CouponService.purchaseStatus(user);
    _shakeFuture = CouponService.shakeStatus(user);
  }

  void _reload(User user) {
    setState(() {
      _futureUserId = user.uid;
      _purchaseFuture = CouponService.purchaseStatus(user);
      _shakeFuture = CouponService.shakeStatus(user);
    });
  }

  Future<void> _claimPurchase(User user) async {
    if (_claimingPurchase) return;

    setState(() => _claimingPurchase = true);
    try {
      final message = await CouponService.claimPurchaseCoupon(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      _reload(user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingPurchase = false);
    }
  }

  Future<void> _claimShake(User user) async {
    if (_claimingShake) return;

    setState(() => _claimingShake = true);
    try {
      final message = await CouponService.claimShakeCoupon(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      _reload(user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _claimingShake = false;
          _shakeProgress = 0;
          _shakeStartedAt = null;
          _lastShakePulseAt = null;
        });
      }
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AuthScreen(returnToPrevious: true),
      ),
    );
  }

  Widget _loginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_activity_rounded, size: 70, color: negro),
            const SizedBox(height: 14),
            const Text(
              'Inicia sesion para ver tus cupones.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Iniciar sesion'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: negro,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_activity_rounded, color: amarillo, size: 34),
          SizedBox(height: 12),
          Text(
            'Cupones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Reclama beneficios activos y usalos en tu siguiente pedido.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _purchaseRule(User user) {
    return FutureBuilder<PurchaseCouponStatus>(
      future: _purchaseFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final active = status?.active == true;
        final canClaim = status?.canClaim == true;
        final delivered = status?.deliveredCount ?? 0;
        final required = status?.requiredPurchases ?? 5;
        final missing = status?.remainingPurchases ?? required;

        return _ruleCard(
          icon: Icons.shopping_bag_rounded,
          title: '5 compras',
          subtitle: active
              ? 'Llevas $delivered compra(s) entregadas. Necesitas $required para reclamar 30%.'
              : 'Esta promocion aun no esta activa.',
          status: active
              ? canClaim
                    ? 'Listo para reclamar'
                    : 'Faltan $missing compra(s)'
              : 'Inactivo',
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading || !canClaim || _claimingPurchase
                  ? null
                  : () => _claimPurchase(user),
              icon: _claimingPurchase
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard_rounded),
              label: const Text('Reclamar 30%'),
            ),
          ),
        );
      },
    );
  }

  Widget _shakeRule(User user) {
    return FutureBuilder<ShakeCouponStatus>(
      future: _shakeFuture,
      builder: (context, snapshot) {
        final colors = Theme.of(context).colorScheme;
        final status = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final active = status?.active == true;
        final canClaim = status?.canClaim == true;
        final seconds = status?.shakeSeconds ?? 3;
        final next = status?.nextAvailableAt;

        var subtitle =
            'Agita tu celular por $seconds segundos para obtener 20%.';
        if (!active) subtitle = 'Esta promocion aun no esta activa.';
        if (active && !canClaim && next != null) {
          subtitle =
              'Ya lo reclamaste esta semana. Vuelve el ${_dateText(next)}.';
        }

        return _ruleCard(
          icon: Icons.vibration_rounded,
          title: 'Agitar celular',
          subtitle: subtitle,
          status: active
              ? canClaim
                    ? 'Agita ahora'
                    : 'Una vez por semana'
              : 'Inactivo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: loading || !active || !canClaim ? 0 : _shakeProgress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'Disponible en el celular.'
                    : _claimingShake
                    ? 'Activando cupon...'
                    : 'Progreso: ${(_shakeProgress * 100).round()}%',
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ruleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xFF1D1D1D) : Colors.white;
    final borderColor = dark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: amarillo,
                foregroundColor: negro,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.68),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _couponList(User user) {
    return StreamBuilder<List<CustomerCoupon>>(
      stream: CouponService.customerCouponsStream(user.uid),
      builder: (context, snapshot) {
        final coupons = snapshot.data ?? const <CustomerCoupon>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (coupons.isEmpty) {
          final colors = Theme.of(context).colorScheme;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavia no tienes cupones.',
              style: TextStyle(
                color: colors.onSurface.withOpacity(0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Column(
          children: coupons
              .map(
                (coupon) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _couponTile(coupon),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _couponTile(CustomerCoupon coupon) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final available = coupon.isAvailable;
    final label = available
        ? 'Disponible'
        : coupon.isExpired
        ? 'Vencido'
        : 'Usado';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: available
            ? dark
                  ? const Color(0xFF2B2616)
                  : const Color(0xFFFFFAE5)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: available
              ? amarillo
              : dark
              ? Colors.white.withOpacity(0.10)
              : Colors.black.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.confirmation_number_rounded,
            color: dark ? amarillo : negro,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${coupon.code} - ${coupon.discountPercentage}%',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coupon.title,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.68),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: available
                  ? Colors.green.withOpacity(dark ? 0.18 : 0.10)
                  : colors.onSurface.withOpacity(dark ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: available
                    ? (dark ? Colors.green.shade200 : Colors.green.shade800)
                    : colors.onSurface.withOpacity(0.72),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateText(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Cupones')),
          body: user == null
              ? _loginRequired()
              : Builder(
                  builder: (context) {
                    _ensureFutures(user);
                    return RefreshIndicator(
                      onRefresh: () async => _reload(user),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _header(),
                          const SizedBox(height: 14),
                          _purchaseRule(user),
                          const SizedBox(height: 12),
                          _shakeRule(user),
                          const SizedBox(height: 20),
                          const Text(
                            'Tus cupones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _couponList(user),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
