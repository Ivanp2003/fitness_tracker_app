import 'package:flutter/material.dart' hide Route;
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/datasources/gps_datasource.dart';
import '../../domain/entities/location_point.dart';

class RouteMapWidget extends StatefulWidget {
  const RouteMapWidget({super.key});

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final GpsDataSource _dataSource = GpsDataSourceImpl();
  final Route _route = Route();
  final MapController _mapController = MapController();

  StreamSubscription<LocationPoint>? _subscription;
  bool _isTracking = false;
  String _statusMessage = 'Presiona Iniciar';
  LocationPoint? _currentLocation;

  @override
  void dispose() {
    _subscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _stopTracking();
    } else {
      await _startTracking();
    }
  }

  Future<void> _startTracking() async {
    final hasPermission = await _dataSource.requestPermissions();
    if (!hasPermission) {
      setState(() {
        _statusMessage = 'Permisos denegados';
      });
      return;
    }

    final gpsEnabled = await _dataSource.isGpsEnabled();
    if (!gpsEnabled) {
      setState(() {
        _statusMessage = 'Activa el GPS';
      });
      return;
    }

    _subscription = _dataSource.locationStream.listen(
      (point) {
        _currentLocation = point;

        if (_route.points.isEmpty) {
          setState(() {
            _route.addPoint(point);
            _statusMessage = 'Tracking - ${_route.points.length} puntos';
          });
          _mapController.move(
            LatLng(point.latitude, point.longitude),
            16,
          );
        } else {
          final lastPoint = _route.points.last;
          final distance = lastPoint.distanceTo(point);

          if (distance >= 1) {
            setState(() {
              _route.addPoint(point);
              _statusMessage = 'Tracking - ${_route.points.length} puntos';
            });
            _mapController.move(
              LatLng(point.latitude, point.longitude),
              16,
            );
          }
        }
      },
      onError: (error) {
        setState(() {
          _statusMessage = 'Error: $error';
        });
      },
    );

    setState(() {
      _isTracking = true;
    });
  }

  void _stopTracking() {
    _subscription?.cancel();
    _route.finish();

    if (_route.points.length >= 2) {
      _fitRouteBounds();
    }

    setState(() {
      _isTracking = false;
      _statusMessage = 'Ruta finalizada';
    });
  }

  void _fitRouteBounds() {
    if (_route.points.isEmpty) return;

    double minLat = _route.points.first.latitude;
    double maxLat = _route.points.first.latitude;
    double minLon = _route.points.first.longitude;
    double maxLon = _route.points.first.longitude;

    for (final p in _route.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLon),
          LatLng(maxLat, maxLon),
        ),
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final routePoints = _route.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final markers = <Marker>[];
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.my_location, size: 14, color: Colors.blue),
            ),
          ),
        ),
      );
    }
    if (_route.points.isNotEmpty) {
      markers.add(
        Marker(
          point: LatLng(_route.points.first.latitude, _route.points.first.longitude),
          width: 20,
          height: 20,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.flag, size: 12, color: Colors.white),
            ),
          ),
        ),
      );
    }
    if (_route.points.length > 1) {
      markers.add(
        Marker(
          point: LatLng(_route.points.last.latitude, _route.points.last.longitude),
          width: 20,
          height: 20,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.flag, size: 12, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF0A8BFF).withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(color: const Color(0xFF0A8BFF).withValues(alpha: 0.3), width: 3),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A8BFF).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.navigation, color: Color(0xFF0A8BFF), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Ruta GPS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _toggleTracking,
                        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow, size: 20),
                        label: Text(_isTracking ? 'Detener' : 'Iniciar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red : const Color(0xFF69F06A),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: _isTracking
                              ? Colors.red.withValues(alpha: 0.4)
                              : const Color(0xFF69F06A).withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isTracking ? const Color(0xFF69F06A) : onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
            ),

            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(-0.22985, -78.52495),
                  initialZoom: 5,
                  minZoom: 3,
                  maxZoom: 20,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tuinstituto.fitness_tracker',
                  ),
                  if (routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: const Color(0xFF0A8BFF),
                          strokeWidth: 4,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                  if (markers.isNotEmpty)
                    MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetric(
                  icon: Icons.straighten,
                  value: _route.totalDistance < 1000
                      ? '${_route.totalDistance.toStringAsFixed(0)} m'
                      : '${_route.distanceKm.toStringAsFixed(2)} km',
                  label: 'Distancia',
                ),
                _buildMetric(
                  icon: Icons.timer,
                  value: _formatDuration(_route.duration),
                  label: 'Tiempo',
                ),
                _buildMetric(
                  icon: Icons.speed,
                  value: '${_route.averageSpeed.toStringAsFixed(1)} km/h',
                  label: 'Velocidad',
                ),
                _buildMetric(
                  icon: Icons.local_fire_department,
                  value: _route.estimatedCalories.toStringAsFixed(0),
                  label: 'Calorías',
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0A8BFF)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
