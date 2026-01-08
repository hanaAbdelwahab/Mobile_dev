import 'package:flutter/material.dart';

class ManageOpportunitiesPage extends StatelessWidget {
  const ManageOpportunitiesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Opportunities'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Opportunities Management',
              style: TextStyle(fontSize: 24, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}