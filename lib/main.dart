import 'package:flutter/material.dart';
import 'package:public_transport_assistant/map_screen/map_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

Future<void> _requestLocationPermission() async {
  var status = await Permission.location.status;

  if (!status.isGranted) {
    status = await Permission.location.request();
  }

  if (!status.isGranted) {
    debugPrint('Location permission not granted');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    _requestLocationPermission();

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}
