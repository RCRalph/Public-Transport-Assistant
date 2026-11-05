import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'generated/city_city_generated.dart' as city_fb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class StopLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const StopLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _mapController;

  List<StopLocation> _stops = [];

  bool _styleLoaded = false;
  bool _markersAdded = false;

  LatLng _center = const LatLng(50.0647, 19.9450);

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    try {
      // Load city.bin from Flutter assets.
      final data = await rootBundle.load('city.bin');

      // Copy bytes so the FlatBuffers buffer starts at offset zero.
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      // Decode the FlatBuffers root object.
      final city = city_fb.City(bytes);

      final stops = <StopLocation>[];

      for (final group in city.stopGroups ?? <city_fb.StopGroup>[]) {
        final center = group.center;

        if (center == null) continue;

        stops.add(
          StopLocation(
            id: group.name ?? '',
            name: group.name ?? '',
            latitude: center.latitude,
            longitude: center.longitude,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _stops = stops;

        if (stops.isNotEmpty) {
          // Calculate the average coordinates of all stops.
          final latitude =
              stops.map((stop) => stop.latitude).reduce((a, b) => a + b) /
              stops.length;

          final longitude =
              stops.map((stop) => stop.longitude).reduce((a, b) => a + b) /
              stops.length;

          _center = LatLng(latitude, longitude);
        }
      });

      _addMarkersIfReady();
    } catch (e) {
      debugPrint('Failed to load city.bin: $e');
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _addMarkersIfReady();
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _addMarkersIfReady();
  }

  Future<void> _addMarkersIfReady() async {
    final controller = _mapController;

    if (controller == null ||
        !_styleLoaded ||
        _stops.isEmpty ||
        _markersAdded) {
      return;
    }

    _markersAdded = true;

    try {
      final geoJson = {
        'type': 'FeatureCollection',
        'features': _stops.map((stop) {
          return {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [stop.longitude, stop.latitude],
            },
            'properties': {'id': stop.id, 'name': stop.name},
          };
        }).toList(),
      };

      // Add all stop groups in a single GeoJSON source.
      await controller.addSource(
        'stop-groups-source',
        GeojsonSourceProperties(data: geoJson),
      );

      // Render all stop groups using one native circle layer.
      await controller.addCircleLayer(
        'stop-groups-source',
        'stop-groups-layer',
        const CircleLayerProperties(
          circleRadius: 4,
          circleColor: '#1976D2',
          circleOpacity: 0.85,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1,
        ),
      );

      await controller.animateCamera(CameraUpdate.newLatLngZoom(_center, 12));
    } catch (e) {
      debugPrint('Failed to render stop groups: $e');
      _markersAdded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: 'https://tiles.openfreemap.org/styles/liberty',
            initialCameraPosition: CameraPosition(target: _center, zoom: 12),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
          ),

          if (_stops.isEmpty) const Center(child: CircularProgressIndicator()),

          if (_stops.isNotEmpty)
            Positioned(
              top: 48,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Stops: ${_stops.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
