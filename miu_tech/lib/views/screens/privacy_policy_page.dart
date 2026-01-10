import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                'Privacy Policy',
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
                '1. Information We Collect',
                'We collect information you provide directly to us, including:\n• Name and email address\n• Profile information\n• Academic information\n• Content you post',
              ),
              _buildSection(
                '2. How We Use Your Information',
                'We use the information we collect to:\n• Provide and maintain our services\n• Improve user experience\n• Send notifications\n• Ensure platform security',
              ),
              _buildSection(
                '3. Information Sharing',
                'We do not sell your personal information. We may share your information with:\n• Other MIU students (public profile data)\n• Service providers\n• Law enforcement when required',
              ),
              _buildSection(
                '4. Data Security',
                'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, or destruction.',
              ),
              _buildSection(
                '5. Your Rights',
                'You have the right to:\n• Access your personal data\n• Correct inaccurate data\n• Delete your account\n• Opt-out of communications',
              ),
              _buildSection(
                '6. Cookies',
                'We use cookies and similar technologies to enhance your experience and analyze platform usage.',
              ),
              _buildSection(
                '7. Children\'s Privacy',
                'Our service is intended for users 18 years and older. We do not knowingly collect information from children under 18.',
              ),
              _buildSection(
                '8. Changes to Privacy Policy',
                'We may update this policy from time to time. We will notify you of significant changes.',
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your privacy is important to us. For privacy concerns, contact privacy@miutechcircle.com',
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
