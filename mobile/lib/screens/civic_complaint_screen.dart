import 'package:flutter/material.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';

class CivicComplaintScreen extends StatefulWidget {
  final String category;
  
  const CivicComplaintScreen({super.key, required this.category});

  @override
  State<CivicComplaintScreen> createState() => _CivicComplaintScreenState();
}

class _CivicComplaintScreenState extends State<CivicComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  
  bool _isSubmitting = false;
  bool _submitted = false;
  String _ticketId = '';
  String? _selectedCategory;

  final List<String> _reportCategories = [
    'Garbage Dump Overflow',
    'Dead Animal',
    'Street Sweeping Required',
    'Hazardous Waste Spilled',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category.isNotEmpty && widget.category != 'Non_Waste' ? widget.category : _reportCategories[0];
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationController.text = "Fetching current location...";
    });
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationController.text = "Location services disabled");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationController.text = "Location permission denied");
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationController.text = "Location permanently denied");
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _locationController.text = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationController.text = "Failed to get location");
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // Simulate network request
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
          _ticketId = '#EV-${Random().nextInt(9000) + 1000}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: const BrandAppBar(),
      body: _submitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.errorColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Help keep the community clean by reporting unmanaged waste. This will generate a municipal ticket.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _reportCategories.contains(_selectedCategory) ? _selectedCategory : _reportCategories[0],
              decoration: const InputDecoration(
                labelText: 'Issue Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _reportCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: _isSubmitting 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: AppTheme.primaryColor, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              'Report Submitted!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                'Ticket ID: $_ticketId',
                style: const TextStyle(fontSize: 18, color: AppTheme.warningColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Expected Resolution SLA: 48 hours',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _submitted = false;
                      _descController.clear();
                    });
                  }
                },
                child: const Text('Back / Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
