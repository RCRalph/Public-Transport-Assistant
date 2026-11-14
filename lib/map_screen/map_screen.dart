import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geodesy/geodesy.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:public_transport_assistant/api/city_data.dart';
import 'package:public_transport_assistant/api/model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _cityFilePath = 'city.bin';

  late final Future<CityData> _cityFuture;

  MapLibreMapController? _mapController;

  CityData? _cityData;

  StopGroup? _closestStopGroup;

  bool _styleLoaded = false;
  bool _markersAdded = false;
  bool _closestStopLayerAdded = false;

  // Location following state.
  bool _isFollowingUser = true;
  LatLng? _userLocation;

  LatLng _center = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();

    _cityFuture = CityData.fromFile(_cityFilePath);
  }

  void _onCityLoaded(CityData cityData) {
    if (identical(_cityData, cityData)) return;

    _cityData = cityData;

    final groups = cityData.stopGroups.values.toList();

    if (groups.isNotEmpty) {
      final latitudeMin = groups.map((g) => g.latitude).reduce(min);
      final latitudeMax = groups.map((g) => g.latitude).reduce(max);

      final longitudeMin = groups.map((g) => g.longitude).reduce(min);
      final longitudeMax = groups.map((g) => g.longitude).reduce(max);

      _center = LatLng(
        (latitudeMin + latitudeMax) / 2,
        (longitudeMin + longitudeMax) / 2,
      );
    }

    _addMarkersIfReady();
  }

  void _onMapCreated(MapLibreMapController controller) {
    debugPrint('MAP CREATED');

    _mapController = controller;

    _addMarkersIfReady();
  }

  void _onStyleLoaded() {
    _styleLoaded = true;

    _markersAdded = false;
    _closestStopLayerAdded = false;
    _closestStopGroup = null;

    _addMarkersIfReady();
  }

  Future<void> _addMarkersIfReady() async {
    final controller = _mapController;
    final cityData = _cityData;

    if (controller == null ||
        cityData == null ||
        !_styleLoaded ||
        cityData.stops.isEmpty ||
        _markersAdded) {
      return;
    }

    _markersAdded = true;

    try {
      final geoJson = {
        'type': 'FeatureCollection',
        'features': cityData.stops.entries.map((stop) {
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

      await controller.addSource(
        'stop-groups-source',
        GeojsonSourceProperties(data: geoJson),
      );

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

      // IMPORTANT:
      // Do not animate the camera here.
      // Location tracking controls the camera automatically.
    } catch (e) {
      debugPrint('Failed to render stop groups: $e');
      _markersAdded = false;
    }
  }

  void _onUserLocationUpdated(UserLocation userLocation) {
    final position = userLocation.position;

    debugPrint('GPS UPDATE: ${position.latitude}, ${position.longitude}');

    _userLocation = position;

    final cityData = _cityData;

    if (cityData == null) return;

    StopGroup? closestStopGroup;
    double minDistance = double.infinity;

    for (final group in cityData.stopGroups.values) {
      final distanceSquared = geo.Haversine().distance(
        geo.LatLng(position.latitude, position.longitude),
        geo.LatLng(group.latitude, group.longitude),
      );

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

  // Called when MapLibre stops following the user's location,
  // for example, when the user manually moves the map.
  void _onCameraTrackingDismissed() {
    if (!mounted || !_isFollowingUser) return;

    setState(() {
      _isFollowingUser = false;
    });
  }

  // Keep our UI state synchronized with MapLibre.
  void _onCameraTrackingChanged(MyLocationTrackingMode mode) {
    final isFollowing = mode != MyLocationTrackingMode.none;

    if (!mounted || _isFollowingUser == isFollowing) return;

    setState(() {
      _isFollowingUser = isFollowing;
    });
  }

  // Resume location following when the user presses the button.
  Future<void> _resumeLocationFollowing() async {
    final controller = _mapController;

    if (controller == null) return;

    try {
      await controller.updateMyLocationTrackingMode(
        MyLocationTrackingMode.trackingCompass,
      );

      if (!mounted) return;

      setState(() {
        _isFollowingUser = true;
      });
    } catch (e) {
      debugPrint('Failed to resume location tracking: $e');
    }
  }

  Future<void> _highlightClosestStop(StopGroup stopGroup) async {
    final controller = _mapController;

    if (controller == null || !_styleLoaded || !_markersAdded) {
      return;
    }

    final features = <Object>[];

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

      _closestStopLayerAdded = true;
    } catch (e) {
      debugPrint('Failed to highlight closest stop: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<CityData>(
        future: _cityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  const Text('Failed to load city data'),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry implementation can be added here.
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No city data available'));
          }

          final cityData = snapshot.data!;

          _onCityLoaded(cityData);

          return Stack(
            children: [
              MapLibreMap(
                styleString: 'https://tiles.openfreemap.org/styles/liberty',

                // Fallback position while waiting for GPS.
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: 12,
                ),

                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,

                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.trackingCompass,
                myLocationRenderMode: MyLocationRenderMode.compass,

                onUserLocationUpdated: _onUserLocationUpdated,

                onCameraTrackingDismissed: _onCameraTrackingDismissed,
                onCameraTrackingChanged: _onCameraTrackingChanged,

                locationEnginePlatforms: const LocationEnginePlatforms.android(
                  enableHighAccuracy: true,
                ),
              ),

              // Return-to-location button.
              if (!_isFollowingUser)
                Positioned(
                  right: 16,
                  bottom: 32,
                  child: FloatingActionButton(
                    heroTag: 'follow-location-button',
                    onPressed: _resumeLocationFollowing,
                    tooltip: 'Follow my location',
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.my_location),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
