import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../ai/knowledge_engine.dart';
import 'result_screen.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    setState(() {
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final allKeys = KnowledgeEngine.getAllWasteKeys();
    final matches = allKeys.where((k) => k.toLowerCase().contains(query.toLowerCase())).take(6).toList();
    setState(() {
      _suggestions = matches;
    });
  }

  void _navigateToResult(String categoryKey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          categoryKey: categoryKey,
          isSearch: true,
        ),
      ),
    );
  }

  Widget _buildPopularItem(String title, String iconPath, Color bgColor, Color iconColor) {
    return GestureDetector(
      onTap: () => _navigateToResult(title),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String title, IconData icon) {
    return GestureDetector(
      onTap: () => _navigateToResult(title), // We let knowledge engine handle it or fallback
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Explore'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search Waste (e.g. Battery, Plastic...)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Popular Searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                alignment: WrapAlignment.start,
                children: [
                  _buildPopularItem('Battery Waste', 'assets/shared/icons/battery.svg', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                  _buildPopularItem('Plastic Waste', 'assets/shared/icons/bottle.svg', const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
                  _buildPopularItem('Paper Waste', 'assets/shared/icons/cardboard.svg', const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
                  _buildPopularItem('Metal Waste', 'assets/shared/icons/can.svg', const Color(0xFFF1F5F9), const Color(0xFF475569)),
                  _buildPopularItem('Organic Waste', 'assets/shared/icons/banana.svg', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildCategoryPill('Plastic Waste', Icons.water_drop_outlined),
                  _buildCategoryPill('Paper Waste', Icons.feed_outlined),
                  _buildCategoryPill('Glass Waste', Icons.wine_bar_outlined),
                  _buildCategoryPill('Metal Waste', Icons.propane_tank_outlined),
                  _buildCategoryPill('Organic Waste', Icons.eco_outlined),
                  _buildCategoryPill('E-waste', Icons.memory_outlined),
                  _buildCategoryPill('Battery Waste', Icons.battery_alert_outlined),
                ],
              ),
            ],
          ),
          
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 0, left: 16, right: 16,
              child: Material(
                color: AppTheme.surfaceColor,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final sug = _suggestions[index];
                    return ListTile(
                      leading: const Icon(Icons.search, color: AppTheme.textSecondary),
                      title: Text(sug),
                      onTap: () {
                        _searchController.clear();
                        setState(() => _suggestions = []);
                        _navigateToResult(sug);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
