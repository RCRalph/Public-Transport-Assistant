import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import "package:public_transport_assistant/map_screen/model.dart";
import 'package:public_transport_assistant/generated/city_city_generated.dart'
    as city_fb;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _mapController;

  Map<int, StopGroup> _stopGroups = {};
  Map<String, Stop> _stops = {};
  StopGroup? _closestStopGroup;

  bool _styleLoaded = false;
  bool _markersAdded = false;
  bool _closestStopLayerAdded = false;

  LatLng _center = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<city_fb.City> _loadCityData() async {
    final data = await rootBundle.load('city.bin');

    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );

    return city_fb.City(bytes);
  }

  Future<void> _loadCity() async {
    try {
      final city = await _loadCityData();

      final stops = <String, Stop>{};
      final stopGroups = <int, StopGroup>{};

      (city.stopGroups ?? <city_fb.StopGroup>[]).asMap().forEach((id, item) {
        final stopsInGroup = <Stop>[];

        for (final stop in item.stops ?? <city_fb.StopInfo>[]) {
          stopsInGroup.add(
            Stop(
              id: stop.id ?? "",
              name: stop.name ?? "",
              latitude: stop.location?.latitude ?? 0,
              longitude: stop.location?.longitude ?? 0,
            ),
          );
        }

        final stopGroup = StopGroup(
          id: id,
          name: item.name ?? "",
          latitude: item.center?.latitude ?? 0,
          longitude: item.center?.longitude ?? 0,
          stops: stopsInGroup,
        );

        stopGroups[stopGroup.id] = stopGroup;

        for (final stop in stopsInGroup) {
          stops[stop.id] = stop;
        }
      });

      if (!mounted) return;

      setState(() {
        _stops = stops;
        _stopGroups = stopGroups;

        if (stops.isNotEmpty) {
          // Calculate the average coordinates of all stops.
          final latitudeMin = stopGroups.values
              .map((stop) => stop.latitude)
              .reduce(min);

          final latitudeMax = stopGroups.values
              .map((stop) => stop.latitude)
              .reduce(max);

          final longitudeMin = stopGroups.values
              .map((stop) => stop.longitude)
              .reduce(min);

          final longitudeMax = stopGroups.values
              .map((stop) => stop.longitude)
              .reduce(max);

          _center = LatLng(
            (latitudeMin + latitudeMax) / 2,
            (longitudeMin + longitudeMax) / 2,
          );
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
        'features': _stops.entries.map((stop) {
          return {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [stop.value.longitude, stop.value.latitude],
            },
            'properties': {'id': stop.key, 'name': stop.value.name},
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

  void _onUserLocationUpdated(UserLocation userLocation) {
    if (_stops.isEmpty || !_styleLoaded) return;

    final userLatLng = userLocation.position;

    // Find the closest stop using squared Euclidean distance
    StopGroup? closestStopGroup;
    double minDistance = double.infinity;

    for (final group in _stopGroups.values) {
      final dx = group.latitude - userLatLng.latitude;
      final dy = group.longitude - userLatLng.longitude;
      final distanceSquared = dx * dx + dy * dy;

      if (distanceSquared < minDistance) {
        minDistance = distanceSquared;
        closestStopGroup = group;
      }
    }

    if (closestStopGroup != null &&
        _closestStopGroup?.id != closestStopGroup.id) {
      _closestStopGroup = closestStopGroup;
      _highlightClosestStop(closestStopGroup);
    }
  }

  Future<void> _highlightClosestStop(StopGroup stopGroup) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;

    final List<Object> features = [];

    for (final stop in stopGroup.stops) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [stop.longitude, stop.latitude],
        },
        'properties': {'id': stop.id, 'name': stop.name},
      });
    }

    final geoJson = {'type': 'FeatureCollection', 'features': features};

    try {
      if (_closestStopLayerAdded) {
        await controller.setGeoJsonSource('closest-stop-source', geoJson);
        return;
      }

      _closestStopLayerAdded = true;

      await controller.addSource(
        'closest-stop-source',
        GeojsonSourceProperties(data: geoJson),
      );

      await controller.addCircleLayer(
        'closest-stop-source',
        'closest-stop-layer',
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#FF5722',
          circleOpacity: 1.0,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ),
      );
    } catch (e) {
      debugPrint('Failed to highlight closest stop: $e');
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
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.trackingCompass,
            myLocationRenderMode: MyLocationRenderMode.compass,
            onUserLocationUpdated: _onUserLocationUpdated,
          ),
        ],
      ),
    );
  }
}
