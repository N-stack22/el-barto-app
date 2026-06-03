import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RouteInfo {
  final String startAddress;
  final String endAddress;
  final String distanceText;
  final int distanceMeters;
  final String durationText;
  final int durationSeconds;
  final String overviewPolyline;

  const RouteInfo({
    required this.startAddress,
    required this.endAddress,
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationSeconds,
    required this.overviewPolyline,
  });
}

class DirectionsService {
  static String? get _apiKey => dotenv.env['GOOGLE_MAPS_API_KEY'];
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Devuelve información de ruta entre origen y destino.
  ///
  /// Además de distancia/tiempo, retorna `overviewPolyline`, que sirve
  /// para dibujar la ruta en GoogleMap.
  static Future<RouteInfo?> getRouteInfo({
    required String origin,
    required String destination,
    String mode = 'driving',
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'origin': origin,
      'destination': destination,
      'mode': mode,
      'key': apiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return null;
    }

    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;

    final leg = legs.first as Map<String, dynamic>;
    final distance = leg['distance'] as Map<String, dynamic>?;
    final duration = leg['duration'] as Map<String, dynamic>?;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;

    return RouteInfo(
      startAddress: leg['start_address']?.toString() ?? '',
      endAddress: leg['end_address']?.toString() ?? '',
      distanceText: distance?['text']?.toString() ?? '',
      distanceMeters: (distance?['value'] as num?)?.toInt() ?? 0,
      durationText: duration?['text']?.toString() ?? '',
      durationSeconds: (duration?['value'] as num?)?.toInt() ?? 0,
      overviewPolyline: overviewPolyline?['points']?.toString() ?? '',
    );
  }
}
