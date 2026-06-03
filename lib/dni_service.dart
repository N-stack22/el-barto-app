import 'dart:convert';
import 'package:http/http.dart' as http;

class DniData {
  final String dni;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String estado;
  final String condicion;

  DniData({
    required this.dni,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.estado,
    required this.condicion,
  });

  factory DniData.fromJson(Map<String, dynamic> json) {
    return DniData(
      dni: json['dni'] ?? '',
      nombre: json['nombres'] ?? '',
      apellidoPaterno: json['apellidoPaterno'] ?? '',
      apellidoMaterno: json['apellidoMaterno'] ?? '',
      estado: json['estado'] ?? '',
      condicion: json['condicion'] ?? '',
    );
  }

  String get nombreCompleto =>
      '$apellidoPaterno $apellidoMaterno, $nombre';
}

class DniService {
  static const String _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpmY2M5NTAxMjMwOUBnbWFpbC5jb20ifQ.UaK6eecpbt-mVnF9hI-BYSHtl6QQ5hCLU1MNItWe9P8';
  static const String _baseUrl = 'https://dniruc.apisperu.com/api/v1/dni';

  /// Valida un DNI y retorna los datos del titular
  /// Retorna null si hay error o el DNI no es válido
  static Future<DniData?> validarDni(String dni) async {
    try {
      // Validar formato básico
      if (dni.isEmpty || dni.length != 8) {
        return null;
      }

      // Validar que solo contenga números
      if (!RegExp(r'^[0-9]{8}$').hasMatch(dni)) {
        return null;
      }

      final url = Uri.parse('$_baseUrl/$dni?token=$_token');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Verificar si la respuesta es válida
        if (data.containsKey('dni') && data['dni'] != null) {
          return DniData.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      print('Error al validar DNI: $e');
      return null;
    }
  }

  /// Valida si un DNI tiene el formato correcto
  static bool esDniValido(String dni) {
    return RegExp(r'^[0-9]{8}$').hasMatch(dni);
  }
}
