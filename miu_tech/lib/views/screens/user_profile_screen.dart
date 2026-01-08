import 'package:flutter/material.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Profile')),
      body: Center(
        child: Text(
          'User Profile for ID: $userId\n\nTODO: Integrate with actual profile screen',
        ),
      ),
    );
  }
}
