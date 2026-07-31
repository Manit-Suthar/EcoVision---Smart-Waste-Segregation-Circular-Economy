import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/knowledge_engine.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import 'dart:math';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _history = [];
  int _greenPoints = 0;
  double _carbonOffset = 0.0;

  final List<String> _ecoTips = [
    "Recycling one aluminum can saves enough energy to power a TV for three hours.",
    "Composting at home can reduce household waste by up to 30%.",
    "Properly disposing of one car battery prevents lead and acid from contaminating soil.",
    "E-waste contains valuable metals like gold, silver, and palladium.",
    "Rinse your plastics! Food residue can ruin an entire batch of recyclables."
  ];
  late String _dailyTip;
  late String _greetingMsg;

  @override
  void initState() {
    super.initState();
    _dailyTip = _ecoTips[Random().nextInt(_ecoTips.length)];
    
    final hour = DateTime.now().hour;
    if (hour >= 12 && hour < 17) {
      _greetingMsg = 'Good Afternoon';
    } else if (hour >= 17) {
      _greetingMsg = 'Good Evening';
    } else {
      _greetingMsg = 'Good Morning';
    }
    
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('scan_history');
    final points = await GamificationService.getPoints();
    final offset = await GamificationService.getCarbonOffset();

    if (mounted) {
      setState(() {
        if (historyString != null) {
          final List<dynamic> decoded = jsonDecode(historyString);
          _history = decoded.cast<Map<String, dynamic>>();
        }
        _greenPoints = points;
        _carbonOffset = offset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalScrapValue = 0;
    for (var item in _history) {
      String cat = item['category'] ?? '';
      String cls = item['class_name'] ?? '';
      totalScrapValue += KnowledgeEngine.getScrapValue('$cat $cls');
    }

    return Scaffold(
      
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        'EcoVision',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$_greetingMsg 🌿',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back to EcoVision!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                
                // Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.3,
                  children: [
                    _buildStatCard('Total Scans', '${_history.length}', Icons.document_scanner_outlined, AppTheme.textSecondary),
                    _buildStatCard('Carbon Saved', '${_carbonOffset.toStringAsFixed(1)}kg', Icons.eco, AppTheme.primaryColor),
                    _buildStatCard('Scrap Value', '₹$totalScrapValue', Icons.monetization_on, AppTheme.warningColor),
                    _buildStatCard('Green Score', '$_greenPoints', Icons.star, const Color(0xFF8B5CF6)),
                  ],
                ),

                const SizedBox(height: 24),
                _buildFactCard(),
                
                const SizedBox(height: 32),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 16),
                _buildHistoryList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFF92400E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Did You Know?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF92400E),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _dailyTip,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF92400E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No scans yet. Start recycling!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: min(_history.length, 5), // show last 5 max
      itemBuilder: (context, index) {
        final item = _history[_history.length - 1 - index];
        return GestureDetector(
          onTap: () {
            final category = item['class_name'] ?? item['category'] ?? 'Unknown';
            if (category != 'Unknown') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ResultScreen(predictedClass: category)),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history, color: AppTheme.textSecondary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['class_name'] ?? item['category'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['date'] != null ? DateTime.parse(item['date']).toLocal().toString().split('.')[0] : 'Just now',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '+10 pts',
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
