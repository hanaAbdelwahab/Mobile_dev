import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings_page.dart';
import 'account_settings_page.dart';
import 'change_password_page.dart';
import 'notification_preferences_page.dart';
import 'submit_feedback_page.dart';
import 'report_problem_page.dart';
import 'about_page.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('email', user.email!)
          .single();

      setState(() {
        _userProfile = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // User Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: _userProfile?['profile_image'] != null
                              ? NetworkImage(_userProfile!['profile_image'])
                              : null,
                          child: _userProfile?['profile_image'] == null
                              ? Text(
                                  (_userProfile?['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userProfile?['name'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userProfile?['email'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _userProfile?['role'] ?? 'Student',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Settings Sections
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Account'),
                        _buildSettingsCard([
                          _buildSettingTile(
                            'App Settings',
                            'Customize your app experience',
                            Icons.settings_outlined,
                            Colors.blue,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppSettingsPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Account Settings',
                            'Manage your account information',
                            Icons.person_outline,
                            Colors.green,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountSettingsPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Change Password',
                            'Update your password',
                            Icons.lock_outline,
                            Colors.orange,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Notification Preferences',
                            'Manage notification settings',
                            Icons.notifications_outlined,
                            Colors.purple,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationPreferencesPage(),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        _buildSectionTitle('Support'),
                        _buildSettingsCard([
                          _buildSettingTile(
                            'Submit Feedback',
                            'Share your thoughts with us',
                            Icons.feedback_outlined,
                            Colors.teal,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SubmitFeedbackPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Report a Problem',
                            'Let us know about issues',
                            Icons.bug_report_outlined,
                            Colors.red,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportProblemPage(),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        _buildSectionTitle('Legal'),
                        _buildSettingsCard([
                          _buildSettingTile(
                            'About',
                            'App version and information',
                            Icons.info_outline,
                            Colors.indigo,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Terms & Conditions',
                            'Read our terms of service',
                            Icons.description_outlined,
                            Colors.blueGrey,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TermsConditionsPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildSettingTile(
                            'Privacy Policy',
                            'How we handle your data',
                            Icons.privacy_tip_outlined,
                            Colors.cyan,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage(),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
    );
  }
}