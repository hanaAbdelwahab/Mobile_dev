import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: December 2025',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Acceptance of Terms',
                'By accessing and using MIU Tech Circle, you accept and agree to be bound by the terms and provision of this agreement.',
              ),
              _buildSection(
                '2. User Account',
                'You are responsible for maintaining the confidentiality of your account and password. You must use your official MIU email address to register.',
              ),
              _buildSection(
                '3. User Content',
                'You retain all rights to any content you submit, post or display on the platform. By posting content, you grant us the right to use, modify, and distribute that content.',
              ),
              _buildSection(
                '4. Prohibited Activities',
                'You may not: (a) Use the service for any illegal purposes (b) Harass or harm other users (c) Impersonate others (d) Distribute spam or malware',
              ),
              _buildSection(
                '5. Intellectual Property',
                'All content, features, and functionality are owned by MIU Tech Circle and are protected by international copyright laws.',
              ),
              _buildSection(
                '6. Termination',
                'We reserve the right to terminate or suspend your account at any time for violations of these terms.',
              ),
              _buildSection(
                '7. Changes to Terms',
                'We may modify these terms at any time. Continued use of the service constitutes acceptance of modified terms.',
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For questions about these terms, contact support@miutechcircle.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}