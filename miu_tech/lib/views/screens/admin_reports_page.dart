import 'package:flutter/material.dart';

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Reports'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Reports & Analytics',
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