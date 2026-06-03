import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'directions_service.dart';

class DeliveryConfig {
  final double restaurantLat;
  final double restaurantLng;
  final double costoBase;
  final double costoPorKm;
  final double costoMinimo;
  final double radioDeliveryKm;

  const DeliveryConfig({
    required this.restaurantLat,
    required this.restaurantLng,
    required this.costoBase,
    required this.costoPorKm,
    required this.costoMinimo,
    required this.radioDeliveryKm,
  });

  factory DeliveryConfig.fromMap(Map<String, dynamic>? data) {
    double number(String key, double fallback) {
      final value = data?[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DeliveryConfig(
      restaurantLat: number('restauranteLat', -12.039447),
      restaurantLng: number('restauranteLng', -75.227225),
      costoBase: number('costoBaseDelivery', 3.00),
      costoPorKm: number('costoPorKmDelivery', 1.50),
      costoMinimo: number('deliveryMinimo', 3.00),
      radioDeliveryKm: number('radioDeliveryKm', 10.00),
    );
  }
}

class DeliveryEstimate {
  final double clienteLat;
  final double clienteLng;
  final double distanciaKm;
  final String distanciaTexto;
  final String duracionTexto;
  final double costoDelivery;
  final bool dentroZona;
  final String origen;
  final String destino;
  final String rutaPolyline;

  const DeliveryEstimate({
    required this.clienteLat,
    required this.clienteLng,
    required this.distanciaKm,
    required this.distanciaTexto,
    required this.duracionTexto,
    required this.costoDelivery,
    required this.dentroZona,
    required this.origen,
    required this.destino,
    required this.rutaPolyline,
  });

  Map<String, dynamic> toMap() {
    return {
      'clienteLat': clienteLat,
      'clienteLng': clienteLng,
      'distanciaKm': distanciaKm,
      'distanciaTexto': distanciaTexto,
      'duracionTexto': duracionTexto,
      'costoDelivery': costoDelivery,
      'dentroZona': dentroZona,
      'origen': origen,
      'destino': destino,
      'rutaPolyline': rutaPolyline,
    };
  }
}

class DeliveryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<DeliveryConfig> loadConfig() async {
    final doc = await _db
        .collection('configuracion_restaurante')
        .doc('principal')
        .get();

    return DeliveryConfig.fromMap(doc.data());
  }

  static Future<Position> obtenerUbicacionActual() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Activa el GPS para calcular el delivery.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Se necesita permiso de ubicación para calcular el delivery.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso de ubicación está bloqueado. Actívalo desde ajustes del teléfono.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<DeliveryEstimate> calcularConGps() async {
    final position = await obtenerUbicacionActual();
    return calcularConCoordenadas(
      clienteLat: position.latitude,
      clienteLng: position.longitude,
    );
  }

  static Future<DeliveryEstimate> calcularConCoordenadas({
    required double clienteLat,
    required double clienteLng,
  }) async {
    final config = await loadConfig();
    final origin = '${config.restaurantLat},${config.restaurantLng}';
    final destination = '$clienteLat,$clienteLng';

    final route = await DirectionsService.getRouteInfo(
      origin: origin,
      destination: destination,
      mode: 'driving',
    );

    final meters = route?.distanceMeters ??
        Geolocator.distanceBetween(
          config.restaurantLat,
          config.restaurantLng,
          clienteLat,
          clienteLng,
        ).round();

    final km = meters / 1000.0;
    final roundedKm = double.parse(km.toStringAsFixed(2));
    final costoCalculado = config.costoBase + (roundedKm * config.costoPorKm);
    final costo = math.max(config.costoMinimo, costoCalculado);
    final dentroZona = roundedKm <= config.radioDeliveryKm;

    return DeliveryEstimate(
      clienteLat: clienteLat,
      clienteLng: clienteLng,
      distanciaKm: roundedKm,
      distanciaTexto: route?.distanceText ?? '${roundedKm.toStringAsFixed(2)} km aprox.',
      duracionTexto: route?.durationText ?? 'Duración no disponible',
      costoDelivery: double.parse(costo.toStringAsFixed(2)),
      dentroZona: dentroZona,
      origen: route?.startAddress ?? origin,
      destino: route?.endAddress ?? destination,
      rutaPolyline: route?.overviewPolyline ?? '',
    );
  }
}
