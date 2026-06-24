import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'delivery_service.dart';
import 'directions_service.dart';

class MapaEntregaScreen extends StatefulWidget {
  const MapaEntregaScreen({super.key});

  @override
  State<MapaEntregaScreen> createState() => _MapaEntregaScreenState();
}

class _MapaEntregaScreenState extends State<MapaEntregaScreen> {
  static const Color negro = Color(0xFF050505);
  static const Color amarillo = Color(0xFFFFC928);

  GoogleMapController? _mapController;
  LatLng? _clienteSeleccionado;
  LatLng? _restaurante;
  RouteInfo? _rutaPreview;
  bool _loading = true;
  bool _loadingRoute = false;
  String? _error;
  Set<Polyline> _polylines = {};
  int _routeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _cargarUbicacionInicial();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cargarUbicacionInicial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = await DeliveryService.loadConfig();
      final position = await DeliveryService.obtenerUbicacionActual();

      final cliente = LatLng(position.latitude, position.longitude);
      final restaurante = LatLng(config.restaurantLat, config.restaurantLng);

      if (!mounted) return;
      setState(() {
        _clienteSeleccionado = cliente;
        _restaurante = restaurante;
        _loading = false;
      });

      await _calcularRutaPreview(cliente);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _actualizarUbicacion(LatLng ubicacion) {
    setState(() {
      _clienteSeleccionado = ubicacion;
      _rutaPreview = null;
      _polylines = {};
    });
    _calcularRutaPreview(ubicacion);
  }

  Future<void> _calcularRutaPreview(LatLng cliente) async {
    final restaurante = _restaurante;
    if (restaurante == null) return;

    final requestId = ++_routeRequestId;
    setState(() => _loadingRoute = true);

    try {
      final route = await DirectionsService.getRouteInfo(
        origin: '${restaurante.latitude},${restaurante.longitude}',
        destination: '${cliente.latitude},${cliente.longitude}',
        mode: 'driving',
      );

      if (!mounted || requestId != _routeRequestId) return;

      final points = route != null && route.overviewPolyline.isNotEmpty
          ? _decodePolyline(route.overviewPolyline)
          : <LatLng>[restaurante, cliente];

      setState(() {
        _rutaPreview = route;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta_entrega'),
            points: points,
            width: 6,
            color: negro,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
        _loadingRoute = false;
      });
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _rutaPreview = null;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta_aproximada'),
            points: [restaurante, cliente],
            width: 5,
            color: negro.withOpacity(0.75),
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
        _loadingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};

    final restaurante = _restaurante;
    if (restaurante != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurante'),
          position: restaurante,
          infoWindow: const InfoWindow(title: 'El Barto'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
      );
    }

    final cliente = _clienteSeleccionado;
    if (cliente != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('cliente'),
          position: cliente,
          draggable: true,
          infoWindow: const InfoWindow(title: 'Tu punto de entrega'),
          onDragEnd: _actualizarUbicacion,
        ),
      );
    }

    return markers;
  }

  Future<void> _centrarEnMiUbicacion() async {
    try {
      final position = await DeliveryService.obtenerUbicacionActual();
      final nuevaUbicacion = LatLng(position.latitude, position.longitude);
      _actualizarUbicacion(nuevaUbicacion);
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: nuevaUbicacion, zoom: 17),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmarUbicacion() {
    final ubicacion = _clienteSeleccionado;
    if (ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una ubicación de entrega.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context, ubicacion);
  }

  Widget _loadingView() {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Buscando tu ubicación...',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación de entrega')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: const BoxDecoration(
                  color: amarillo,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, size: 42, color: negro),
              ),
              const SizedBox(height: 18),
              const Text(
                'No se pudo abrir tu ubicación',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Revisa los permisos de ubicación.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _cargarUbicacionInicial,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Intentar de nuevo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rutaInfoCard(LatLng cliente) {
    final ruta = _rutaPreview;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Punto seleccionado',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Lat: ${cliente.latitude.toStringAsFixed(6)}  ·  Lng: ${cliente.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.black54, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            if (_loadingRoute)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Calculando ruta de entrega...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )
            else if (ruta != null)
              Row(
                children: [
                  const Icon(Icons.route_rounded, size: 20, color: negro),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ruta: ${ruta.distanceText} · ${ruta.durationText}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: Colors.black54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se pudo mostrar la ruta exacta. Se usará una distancia aproximada.',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _confirmarUbicacion,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Confirmar ubicación'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_error != null || _clienteSeleccionado == null) return _errorView();

    final cliente = _clienteSeleccionado!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de entrega'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cliente,
              zoom: 17,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: _actualizarUbicacion,
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.touch_app_rounded, color: negro),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirma el punto detectado o toca otra zona del mapa. La línea muestra la ruta de entrega.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 174,
            child: FloatingActionButton(
              heroTag: 'mi_ubicacion_entrega',
              backgroundColor: Colors.white,
              foregroundColor: negro,
              onPressed: _centrarEnMiUbicacion,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _rutaInfoCard(cliente),
          ),
        ],
      ),
    );
  }
}
