import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class MapScreen extends StatefulWidget {
  final String category;
  const MapScreen({super.key, required this.category});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LatLng _userLocation = const LatLng(28.6139, 77.2090); // Simulated user location
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _generateSimulatedCenters();
  }

  void _generateSimulatedCenters() {
    _markers.add(
      Marker(
        point: _userLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 40),
      ),
    );

    final random = Random();
    for (int i = 0; i < 4; i++) {
      double latOffset = (random.nextDouble() - 0.5) * 0.05;
      double lngOffset = (random.nextDouble() - 0.5) * 0.05;
      
      _markers.add(
        Marker(
          point: LatLng(_userLocation.latitude + latOffset, _userLocation.longitude + lngOffset),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.greenAccent, size: 40),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby ${widget.category} Centers'),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _userLocation,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ecovision',
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}
