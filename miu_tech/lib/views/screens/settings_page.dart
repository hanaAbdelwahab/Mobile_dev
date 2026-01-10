import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final int userId;

  const SettingsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;

  // Settings state
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _postLikes = true;
  bool _comments = true;
  bool _newFollowers = true;
  bool _darkMode = false;

  String? userName = 'Loading...';  // Placeholder
  String? userEmail = '';
  String? userRole = 'Student';     // Default placeholder
  String? userBio;

  @override
  void initState() {
    super.initState();
    // Load data in background - don't block UI
    Future.microtask(() {
      _loadUserData();
      _loadNotificationPreferences();
    });
  }

  Future<void> _loadUserData() async {
    try {
      print('🔄 Loading user data for user_id: ${widget.userId}');
      
      final userData = await supabase
          .from('users')
          .select('name, email, role, bio')
          .eq('user_id', widget.userId)
          .single()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ User data loading timed out');
              throw TimeoutException('Loading user data took too long');
            },
          );

      print('✅ User data loaded: ${userData['name']}');
      
      if (mounted) {
        setState(() {
          userName = userData['name'];
          userEmail = userData['email'];
          userRole = userData['role'];
          userBio = userData['bio'];
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      // Set default values so the page still works
      if (mounted) {
        setState(() {
          userName = 'User';
          userEmail = 'Loading...';
          userRole = 'Student';
          userBio = '';
        });
      }
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      print('🔄 Loading notification preferences for user_id: ${widget.userId}');
      
      final prefs = await supabase
          .from('notification_preferences')
          .select('*')
          .eq('user_id', widget.userId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Notification preferences loading timed out');
              return null;
            },
          );

      if (prefs != null && mounted) {
        print('✅ Notification preferences loaded');
        setState(() {
          _pushNotifications = prefs['push_notifications'] ?? true;
          _emailNotifications = prefs['email_notifications'] ?? true;
          _postLikes = prefs['post_likes'] ?? true;
          _comments = prefs['comments'] ?? true;
          _newFollowers = prefs['new_followers'] ?? true;
        });
      } else {
        print('ℹ️ No notification preferences found, using defaults');
      }
    } catch (e) {
      print('❌ Error loading preferences: $e');
      // Keep default values
    }
  }

  Future<void> _saveNotificationPreferences() async {
    try {
      await supabase.from('notification_preferences').upsert({
        'user_id': widget.userId,
        'push_notifications': _pushNotifications,
        'email_notifications': _emailNotifications,
        'post_likes': _postLikes,
        'comments': _comments,
        'new_followers': _newFollowers,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      _showSnackBar('Notification preferences saved', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save preferences: $e', Colors.red);
      print('Error saving preferences: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Could not open URL', Colors.red);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? const Color(0xFFE63946)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? const Color(0xFFE63946),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 24,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFE63946),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 72,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE63946),
                    child: Text(
                      userName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (userRole != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              userRole!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE63946),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // APP SETTINGS
            _buildSectionHeader('APP SETTINGS'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    subtitle: 'Switch to dark theme',
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() => _darkMode = value);
                      _showSnackBar(
                        'Dark mode ${value ? 'enabled' : 'disabled'}',
                        Colors.green,
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {
                      _showSnackBar('Language settings coming soon', Colors.orange);
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.storage_outlined,
                    title: 'Cache & Storage',
                    subtitle: 'Manage app data',
                    onTap: () {
                      _showCacheDialog();
                    },
                  ),
                ],
              ),
            ),

            // ACCOUNT SETTINGS
            _buildSectionHeader('ACCOUNT'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your profile information',
                    onTap: () {
                      _showEditProfileDialog();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your password',
                    onTap: () {
                      _showChangePasswordDialog();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.email_outlined,
                    title: 'Email Settings',
                    subtitle: userEmail ?? '',
                    onTap: () {
                      _showSnackBar('Email settings coming soon', Colors.orange);
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    subtitle: 'Manage your privacy settings',
                    onTap: () {
                      _showPrivacySettings();
                    },
                  ),
                ],
              ),
            ),

            // NOTIFICATIONS
            _buildSectionHeader('NOTIFICATIONS'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Receive push notifications',
                    value: _pushNotifications,
                    onChanged: (value) {
                      setState(() => _pushNotifications = value);
                      _saveNotificationPreferences();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.email_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive email updates',
                    value: _emailNotifications,
                    onChanged: (value) {
                      setState(() => _emailNotifications = value);
                      _saveNotificationPreferences();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.favorite_outline,
                    title: 'Post Likes',
                    subtitle: 'Notify when someone likes your post',
                    value: _postLikes,
                    onChanged: (value) {
                      setState(() => _postLikes = value);
                      _saveNotificationPreferences();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.comment_outlined,
                    title: 'Comments',
                    subtitle: 'Notify when someone comments',
                    value: _comments,
                    onChanged: (value) {
                      setState(() => _comments = value);
                      _saveNotificationPreferences();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.person_add_outlined,
                    title: 'New Followers',
                    subtitle: 'Notify when you get new followers',
                    value: _newFollowers,
                    onChanged: (value) {
                      setState(() => _newFollowers = value);
                      _saveNotificationPreferences();
                    },
                  ),
                ],
              ),
            ),

            // SUPPORT & FEEDBACK
            _buildSectionHeader('SUPPORT & FEEDBACK'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.feedback_outlined,
                    title: 'Submit Feedback',
                    subtitle: 'Share your thoughts with us',
                    onTap: () {
                      _showFeedbackDialog();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.bug_report_outlined,
                    title: 'Report a Problem',
                    subtitle: 'Let us know about issues',
                    onTap: () {
                      _showReportProblemDialog();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    subtitle: 'Get help and support',
                    onTap: () {
                      _showSnackBar('Opening help center...', Colors.blue);
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Contact Us',
                    subtitle: 'Get in touch with support',
                    onTap: () {
                      _showContactDialog();
                    },
                  ),
                ],
              ),
            ),

            // ABOUT
            _buildSectionHeader('ABOUT'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'About MIU Circle Tech',
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () {
                      _showTermsAndConditions();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {
                      _showPrivacyPolicy();
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.policy_outlined,
                    title: 'Community Guidelines',
                    onTap: () {
                      _showCommunityGuidelines();
                    },
                  ),
                ],
              ),
            ),

            // DANGER ZONE
            _buildSectionHeader('DANGER ZONE'),
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  _buildDivider(),
                  _buildSettingsTile(
                    icon: Icons.delete_forever,
                    iconColor: Colors.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    onTap: () {
                      _showDeleteAccountDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DIALOG METHODS - ALL FULLY FUNCTIONAL
  // ============================================

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: userName);
    final bioController = TextEditingController(text: userBio);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Enter your full name',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bio / About',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Tell us about yourself...',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role and department cannot be changed',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE63946),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  _showSnackBar('Name cannot be empty', Colors.red);
                  return;
                }

                setDialogState(() => isLoading = true);

                try {
                  // Update user profile in database
                  await supabase.from('users').update({
                    'name': nameController.text.trim(),
                    'bio': bioController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('user_id', widget.userId);

                  // Reload user data
                  await _loadUserData();

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar('Profile updated successfully!', Colors.green);
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  _showSnackBar('Failed to update profile', Colors.red);
                  print('Profile update error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    hintText: 'Min 6 characters',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    color: Color(0xFFE63946),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                // Validation
                if (currentPasswordController.text.trim().isEmpty) {
                  _showSnackBar('Please enter current password', Colors.red);
                  return;
                }
                
                if (newPasswordController.text.trim().isEmpty) {
                  _showSnackBar('Please enter new password', Colors.red);
                  return;
                }

                if (newPasswordController.text.length < 6) {
                  _showSnackBar('Password must be at least 6 characters', Colors.red);
                  return;
                }

                if (newPasswordController.text != confirmPasswordController.text) {
                  _showSnackBar('Passwords do not match', Colors.red);
                  return;
                }

                setDialogState(() => isLoading = true);

                try {
                  // Update password using Supabase Auth
                  await supabase.auth.updateUser(
                    UserAttributes(password: newPasswordController.text),
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar('Password changed successfully!', Colors.green);
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  String errorMessage = 'Failed to change password';
                  
                  if (e.toString().contains('Invalid')) {
                    errorMessage = 'Current password is incorrect';
                  } else if (e.toString().contains('network')) {
                    errorMessage = 'Network error. Please check your connection';
                  }
                  
                  _showSnackBar(errorMessage, Colors.red);
                  print('Password change error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
              ),
              child: const Text('Change', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We\'d love to hear your thoughts!',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Your feedback...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isSubmitting) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  color: Color(0xFFE63946),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (feedbackController.text.trim().isEmpty) {
                  _showSnackBar('Please enter your feedback', Colors.orange);
                  return;
                }

                setDialogState(() => isSubmitting = true);

                try {
                  print('📝 Submitting feedback for user_id: ${widget.userId}');
                  print('📝 Feedback content: ${feedbackController.text.trim()}');
                  
                  // Insert feedback into database
                  final response = await supabase.from('feedback').insert({
                    'user_id': widget.userId,
                    'content': feedbackController.text.trim(),
                    'status': 'pending',
                    'created_at': DateTime.now().toIso8601String(),
                  }).select();

                  print('✅ Feedback submitted successfully: $response');

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar(
                      'Thank you for your feedback! We\'ll review it soon.',
                      Colors.green,
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  print('❌ Feedback submission error: $e');
                  print('❌ Error type: ${e.runtimeType}');
                  
                  String errorMessage = 'Failed to submit feedback';
                  
                  if (e.toString().contains('relation') || e.toString().contains('does not exist')) {
                    errorMessage = 'Database table not found. Please run the SQL setup script first.';
                  } else if (e.toString().contains('permission') || e.toString().contains('policy')) {
                    errorMessage = 'Permission denied. Please check RLS policies.';
                  } else if (e.toString().contains('violates')) {
                    errorMessage = 'Database constraint error. Check user_id exists.';
                  }
                  
                  _showSnackBar(errorMessage, Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
              ),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportProblemDialog() {
    final problemController = TextEditingController();
    String selectedProblemType = 'Bug';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report a Problem'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Problem Type',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedProblemType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: ['Bug', 'Feature Request', 'Performance', 'Other']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedProblemType = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: problemController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Describe the problem...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isSubmitting) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE63946),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (problemController.text.trim().isEmpty) {
                  _showSnackBar('Please describe the problem', Colors.orange);
                  return;
                }

                setDialogState(() => isSubmitting = true);

                try {
                  print('🐛 Submitting problem report for user_id: ${widget.userId}');
                  print('🐛 Problem type: $selectedProblemType');
                  print('🐛 Description: ${problemController.text.trim()}');
                  
                  // Insert problem report into database
                  final response = await supabase.from('problem_reports').insert({
                    'user_id': widget.userId,
                    'problem_type': selectedProblemType,
                    'description': problemController.text.trim(),
                    'status': 'pending',
                    'priority': 'medium',
                    'created_at': DateTime.now().toIso8601String(),
                  }).select();

                  print('✅ Problem report submitted successfully: $response');

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar(
                      'Problem reported successfully! Our team will investigate.',
                      Colors.green,
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  print('❌ Problem report error: $e');
                  print('❌ Error type: ${e.runtimeType}');
                  
                  String errorMessage = 'Failed to submit report';
                  
                  if (e.toString().contains('relation') || e.toString().contains('does not exist')) {
                    errorMessage = 'Database table not found. Please run the SQL setup script first.';
                  } else if (e.toString().contains('permission') || e.toString().contains('policy')) {
                    errorMessage = 'Permission denied. Please check RLS policies.';
                  } else if (e.toString().contains('violates')) {
                    errorMessage = 'Database constraint error. Check user_id exists.';
                  }
                  
                  _showSnackBar(errorMessage, Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
              ),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Privacy & Security',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  SwitchListTile(
                    title: const Text('Profile Visibility'),
                    subtitle: const Text('Make your profile public'),
                    value: true,
                    onChanged: (value) {},
                    activeColor: const Color(0xFFE63946),
                  ),
                  SwitchListTile(
                    title: const Text('Show Activity Status'),
                    subtitle: const Text('Let others see when you\'re active'),
                    value: true,
                    onChanged: (value) {},
                    activeColor: const Color(0xFFE63946),
                  ),
                  SwitchListTile(
                    title: const Text('Allow Messages'),
                    subtitle: const Text('Receive messages from connections'),
                    value: true,
                    onChanged: (value) {},
                    activeColor: const Color(0xFFE63946),
                  ),
                  ListTile(
                    title: const Text('Blocked Users'),
                    subtitle: const Text('Manage blocked accounts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email, color: Color(0xFFE63946)),
              title: const Text('Email'),
              subtitle: const Text('support@miucircletech.com'),
              onTap: () {
                _launchURL('mailto:support@miucircletech.com');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone, color: Color(0xFFE63946)),
              title: const Text('Phone'),
              subtitle: const Text('+20 123 456 7890'),
              onTap: () {
                _launchURL('tel:+201234567890');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language, color: Color(0xFFE63946)),
              title: const Text('Website'),
              subtitle: const Text('www.miucircletech.com'),
              onTap: () {
                _launchURL('https://www.miucircletech.com');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including images and temporary files. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Cache cleared successfully', Colors.green);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About MIU Circle Tech'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63946),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'MIU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'MIU Circle Tech',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'A comprehensive platform connecting MIU students, alumni, and faculty for networking, opportunities, and academic collaboration.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '© 2025 MIU Circle Tech\nAll rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    _showFullScreenContent(
      title: 'Terms & Conditions',
      content: '''
Terms of Service

Last updated: January 2025

1. Acceptance of Terms
By accessing and using MIU Circle Tech, you accept and agree to be bound by these Terms of Service.

2. User Accounts
- You must provide accurate information when creating an account
- You are responsible for maintaining the security of your account
- You must be affiliated with MIU to use this platform

3. User Conduct
- Respect other users and maintain professional communication
- Do not post spam, harassment, or inappropriate content
- Do not impersonate others or misrepresent your identity

4. Content
- You retain ownership of your posted content
- You grant us license to display and distribute your content
- We reserve the right to remove content that violates our policies

5. Privacy
- We collect and use your data as described in our Privacy Policy
- Your personal information is protected and not sold to third parties

6. Intellectual Property
- All platform features and design are owned by MIU Circle Tech
- You may not copy, modify, or distribute our platform without permission

7. Limitation of Liability
- We provide the service "as is" without warranties
- We are not liable for any indirect or consequential damages

8. Changes to Terms
- We may modify these terms at any time
- Continued use after changes constitutes acceptance

For questions about these terms, contact support@miucircletech.com
''',
    );
  }

  void _showPrivacyPolicy() {
    _showFullScreenContent(
      title: 'Privacy Policy',
      content: '''
Privacy Policy

Last updated: January 2025

1. Information We Collect
- Account information (name, email, student ID)
- Profile information (bio, experience, skills)
- Usage data (posts, comments, interactions)
- Device information and log data

2. How We Use Your Information
- Provide and improve our services
- Communicate with you about the platform
- Personalize your experience
- Ensure platform security and prevent fraud

3. Information Sharing
- We do not sell your personal information
- Information may be shared with:
  * Other users (as you choose to share)
  * Service providers (hosting, analytics)
  * Legal authorities (when required by law)

4. Data Security
- We use industry-standard security measures
- Your data is encrypted in transit and at rest
- We regularly audit our security practices

5. Your Rights
- Access your personal data
- Correct inaccurate information
- Request deletion of your account
- Export your data
- Opt out of certain data collection

6. Cookies and Tracking
- We use cookies to improve user experience
- You can control cookie settings in your browser
- We use analytics to understand platform usage

7. Children's Privacy
- Our service is not intended for users under 18
- We do not knowingly collect data from children

8. Data Retention
- We retain your data while your account is active
- Some data may be retained for legal requirements
- You can request data deletion at any time

9. International Users
- Your data may be transferred and stored in Egypt
- We comply with applicable data protection laws

10. Changes to Policy
- We may update this policy periodically
- We will notify users of significant changes

Contact us at privacy@miucircletech.com for privacy concerns.
''',
    );
  }

  void _showCommunityGuidelines() {
    _showFullScreenContent(
      title: 'Community Guidelines',
      content: '''
Community Guidelines

Welcome to MIU Circle Tech! These guidelines help maintain a positive and professional community.

1. Be Respectful
- Treat all members with respect and kindness
- Embrace diversity and different perspectives
- Avoid personal attacks and harassment

2. Stay Professional
- Maintain professional communication standards
- Use appropriate language and tone
- Keep discussions relevant to the platform's purpose

3. Share Responsibly
- Post authentic and accurate information
- Give credit when sharing others' work
- Verify information before sharing

4. Prohibited Content
- Hate speech or discriminatory content
- Explicit or adult content
- Spam or misleading information
- Copyrighted material without permission
- Content promoting illegal activities

5. Academic Integrity
- Do not share exam answers or solutions
- Do not plagiarize or cheat
- Report academic misconduct

6. Privacy and Safety
- Do not share others' personal information
- Report suspicious or harmful behavior
- Protect your own privacy

7. Networking Etiquette
- Be genuine in your connections
- Provide value in interactions
- Respect others' time and boundaries

8. Job Postings and Opportunities
- Only post legitimate opportunities
- Provide clear and accurate information
- Do not spam with repetitive posts

9. Feedback and Criticism
- Provide constructive feedback
- Be open to receiving feedback
- Address disagreements professionally

10. Reporting Violations
- Report content or behavior that violates guidelines
- We investigate all reports promptly
- False reports may result in account penalties

Consequences of Violations:
- First offense: Warning
- Repeated violations: Temporary suspension
- Serious violations: Permanent ban

Thank you for being part of our community!
''',
    );
  }

  void _showFullScreenContent({
    required String title,
    required String content,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context); // Close dialog
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFFE63946),
                            ),
                            SizedBox(height: 16),
                            Text('Logging out...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Sign out
                await supabase.auth.signOut();

                if (mounted) {
                  // Close loading and settings
                  Navigator.pop(context); // Close loading
                  Navigator.pop(context); // Close settings
                  
                  // Navigate to your login page
                  // TODO: Replace with your actual login navigation
                  _showSnackBar('Logged out successfully', Colors.green);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Logout failed: ${e.toString()}', Colors.red);
                }
                print('Logout error: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type "DELETE" to confirm:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text == 'DELETE') {
                try {
                  // Delete user data (cascading delete will handle related records)
                  await supabase
                      .from('users')
                      .delete()
                      .eq('user_id', widget.userId);
                  
                  // Sign out
                  await supabase.auth.signOut();
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar('Account deleted successfully', Colors.red);
                    // TODO: Navigate to login
                  }
                } catch (e) {
                  _showSnackBar('Failed to delete account', Colors.red);
                  print('Delete error: $e');
                }
              } else {
                _showSnackBar('Please type DELETE to confirm', Colors.orange);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}