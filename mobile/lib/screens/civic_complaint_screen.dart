import 'package:flutter/material.dart';
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
    _locationController.text = "Fetching current location...";
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _locationController.text = "Lat: 28.6139, Lng: 77.2090 (Simulated)";
        });
      }
    });
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
          _ticketId = '#ECO-${Random().nextInt(9000) + 1000}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Civic Issue'),
      ),
      body: _submitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help keep the community clean by reporting unmanaged waste.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: widget.category,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Waste Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                ),
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 100),
            const SizedBox(height: 24),
            const Text(
              'Report Submitted Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Ticket ID: $_ticketId',
              style: const TextStyle(fontSize: 18, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Expected Resolution SLA: 48 hours',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to result screen
              },
              child: const Text('Back to Results'),
            ),
          ],
        ),
      ),
    );
  }
}
