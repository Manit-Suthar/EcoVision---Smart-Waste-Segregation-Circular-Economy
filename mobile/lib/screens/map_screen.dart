import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatelessWidget {
  final String category;
  const MapScreen({super.key, required this.category});

  Future<void> _launchGoogleMaps() async {
    String q = "recycling";
    final lower = category.toLowerCase();
    if (lower.contains('e-waste')) q = "e-waste";
    if (lower.contains('plastic')) q = "plastic recycling";
    if (lower.contains('garbage')) q = "dumpster";
    if (lower.contains('metal')) q = "scrap metal yard";
    if (lower.contains('paper')) q = "paper recycling";
    
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$q near me')}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Facilities for $category')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Search by Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Find the nearest recycling or disposal centers for this waste type using Google Maps.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _launchGoogleMaps,
                    icon: const Icon(Icons.map),
                    label: const Text('Open Google Maps'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Partner Centers in Ahmedabad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFacilityCard('AMC West Zone Ward 9 Collection', 'Navrangpura, Ahmedabad', 'General & Dry Waste'),
          _buildFacilityCard('E-Waste Recyclers India', 'GIDC Vatva, Ahmedabad', 'E-Waste & Batteries'),
          _buildFacilityCard('GreenEarth Scrap & Metal', 'Sarkhej, Ahmedabad', 'Metal & Plastics'),
          _buildFacilityCard('Local Kabadiwala (Ramesh)', 'Satellite, Ahmedabad', 'Paper & Cardboard'),
        ],
      ),
    );
  }

  Widget _buildFacilityCard(String name, String address, String accepts) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.recycling, color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address),
            Text('Accepts: $accepts', style: const TextStyle(color: Colors.green)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
