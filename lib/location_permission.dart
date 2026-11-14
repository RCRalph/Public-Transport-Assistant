import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:public_transport_assistant/map_screen/map_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLoading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;

    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }

    if (!mounted) return;

    debugPrint('Location permission: $status');

    setState(() {
      _permissionGranted = status.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _retryPermission() async {
    setState(() {
      _isLoading = true;
    });

    await _requestLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_permissionGranted) {
      return const MapScreen();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Location permission required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please grant location permission '
                'to use the public transport map.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _retryPermission,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Open app settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
