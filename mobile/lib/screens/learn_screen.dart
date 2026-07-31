import 'package:flutter/material.dart';
import '../ai/knowledge_engine.dart';
import '../ai/config_loader.dart';
import '../widgets/brand_app_bar.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = AiConfigLoader.labels?.where((l) => l != 'Non_Waste').toList() ?? [];

    return Scaffold(
      
      appBar: const BrandAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('MoEFCC Color-Coded Bins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          _buildGovtBinCard(context, 'Green Bin', 'Wet Waste (Organic)', Colors.green, Icons.compost),
          _buildGovtBinCard(context, 'Blue Bin', 'Dry Waste (Recyclable)', Colors.blue, Icons.recycling),
          _buildGovtBinCard(context, 'Red Bin', 'Sanitary Waste', Colors.red, Icons.health_and_safety),
          _buildGovtBinCard(context, 'Black Bin', 'Hazardous & E-Waste', Colors.blueGrey.shade800, Icons.warning),
          const SizedBox(height: 24),
          const Text('Waste Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          ...categories.map((category) {
            final info = KnowledgeEngine.getWasteInfo(category);
            final catLower = category.toLowerCase();
            
            Color iconColor = Theme.of(context).colorScheme.primary;
            IconData iconData = Icons.eco;
            
            if (catLower.contains('plastic')) {
              iconColor = Colors.lightBlue; iconData = Icons.water_drop_outlined;
            } else if (catLower.contains('paper')) {
              iconColor = Colors.orange; iconData = Icons.feed_outlined;
            } else if (catLower.contains('glass')) {
              iconColor = Colors.teal; iconData = Icons.wine_bar_outlined;
            } else if (catLower.contains('metal') || catLower.contains('automobile')) {
              iconColor = Colors.blueGrey; iconData = Icons.propane_tank_outlined;
            } else if (catLower.contains('organic') || catLower.contains('food')) {
              iconColor = Colors.green; iconData = Icons.eco_outlined;
            } else if (catLower.contains('e-waste') || catLower.contains('bulb')) {
              iconColor = Colors.deepOrange; iconData = Icons.memory_outlined;
            } else if (catLower.contains('battery')) {
              iconColor = Colors.red; iconData = Icons.battery_alert_outlined;
            } else if (catLower.contains('sanitary')) {
              iconColor = Colors.redAccent; iconData = Icons.medical_services_outlined;
            }
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: Icon(
                  iconData,
                  color: iconColor,
                  size: 32,
                ),
                title: Text(
                  category.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                subtitle: Text(info['Category'] ?? '', style: const TextStyle(color: Colors.black54)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Dispose In', info['Dispose In'], Colors.green),
                        _buildInfoRow('Recyclable', info['Recyclable'], Colors.blue),
                        const SizedBox(height: 8),
                        _buildInfoRow('Preparation', info['Preparation Steps'], Colors.orange),
                        _buildInfoRow('Warnings', info['Disposal Warnings'], Colors.red),
                        _buildInfoRow('Impact', info['Environmental Impact'], Colors.teal),
                        _buildInfoRow('Process', info['Recycling Process'], Colors.purple),
                        _buildInfoRow('Mistakes', info['Common Mistakes'], Colors.amber),
                        _buildInfoRow('Did you know?', info['Interesting Facts'], Colors.deepOrange),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGovtBinCard(BuildContext context, String title, String subtitle, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.5), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
        onTap: () {
          _showGovtBinDetails(context, title);
        },
      ),
    );
  }

  void _showGovtBinDetails(BuildContext context, String title) {
    String desc = '';
    String examples = '';
    String dest = '';
    
    if (title == 'Green Bin') {
      desc = 'For organic and biodegradable waste.';
      examples = '• Kitchen scraps\n• Vegetable/fruit peels\n• Tea bags\n• Garden leaves';
      dest = 'Sent directly to composting or bio-methanation facilities.';
    } else if (title == 'Blue Bin') {
      desc = 'For non-biodegradable, recyclable materials.';
      examples = '• Plastics\n• Paper & Cardboard\n• Glass bottles\n• Metals';
      dest = 'Transported to Material Recovery Facilities (MRFs) for sorting and recycling.';
    } else if (title == 'Red Bin') {
      desc = 'A new category introduced to isolate highly personal and potentially infectious hygiene products.';
      examples = '• Used diapers\n• Sanitary pads\n• Bandages';
      dest = 'Safely incinerated or deep-buried in secure landfills.';
    } else if (title == 'Black Bin') {
      desc = 'For domestic hazardous materials and e-waste.';
      examples = '• E-waste (batteries, bulbs)\n• Paint cans\n• Chemicals';
      dest = 'Handled by specialized hazardous waste processing facilities.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(desc, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Examples:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            Text(examples, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 12),
            const Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            Text(dest, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, Color labelColor) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.bold, color: labelColor),
            ),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }
}
