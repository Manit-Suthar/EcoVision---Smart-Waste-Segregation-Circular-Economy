import 'package:flutter/material.dart';
import '../ai/knowledge_engine.dart';
import '../ai/config_loader.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = AiConfigLoader.labels?.where((l) => l != 'Non_Waste').toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final info = KnowledgeEngine.getWasteInfo(category);
          final disposeIn = info['Dispose In'] ?? '';
          
          Color iconColor = Theme.of(context).colorScheme.primary;
          IconData iconData = Icons.eco;
          
          if (disposeIn.contains('Hazardous')) {
            iconColor = Colors.redAccent;
            iconData = Icons.warning;
          } else if (disposeIn.contains('Blue Bin')) {
            iconColor = Colors.lightBlueAccent;
            iconData = Icons.recycling;
          } else if (disposeIn.contains('Green/Compost')) {
            iconColor = Colors.greenAccent;
            iconData = Icons.compost;
          } else if (disposeIn.contains('Green/Glass')) {
            iconColor = Colors.green;
            iconData = Icons.local_drink;
          } else if (disposeIn.contains('E-Waste')) {
            iconColor = Colors.orangeAccent;
            iconData = Icons.computer;
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(info['Category'] ?? ''),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Dispose In', info['Dispose In'], Colors.greenAccent),
                      _buildInfoRow('Recyclable', info['Recyclable'], Colors.blueAccent),
                      const SizedBox(height: 8),
                      _buildInfoRow('Preparation', info['Preparation Steps'], Colors.orangeAccent),
                      _buildInfoRow('Warnings', info['Disposal Warnings'], Colors.redAccent),
                      _buildInfoRow('Impact', info['Environmental Impact'], Colors.tealAccent),
                      _buildInfoRow('Process', info['Recycling Process'], Colors.purpleAccent),
                      _buildInfoRow('Mistakes', info['Common Mistakes'], Colors.amberAccent),
                      _buildInfoRow('Did you know?', info['Interesting Facts'], Colors.yellowAccent),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, Color labelColor) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.4),
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
