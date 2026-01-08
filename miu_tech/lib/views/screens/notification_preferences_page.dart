import 'package:flutter/material.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({Key? key}) : super(key: key);

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  bool _postNotifications = true;
  bool _projectNotifications = true;
  bool _eventNotifications = true;
  bool _messageNotifications = true;
  bool _emailNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _postNotifications,
                  onChanged: (v) => setState(() => _postNotifications = v),
                  title: const Text('Post Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Get notified about new posts'),
                  secondary: const Icon(Icons.article_outlined, color: Colors.red),
                  activeColor: Colors.red,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _projectNotifications,
                  onChanged: (v) => setState(() => _projectNotifications = v),
                  title: const Text('Project Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Updates on graduation projects'),
                  secondary: const Icon(Icons.work_outline, color: Colors.red),
                  activeColor: Colors.red,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _eventNotifications,
                  onChanged: (v) => setState(() => _eventNotifications = v),
                  title: const Text('Event Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Stay updated on campus events'),
                  secondary: const Icon(Icons.event_outlined, color: Colors.red),
                  activeColor: Colors.red,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _messageNotifications,
                  onChanged: (v) => setState(() => _messageNotifications = v),
                  title: const Text('Message Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('New direct messages'),
                  secondary: const Icon(Icons.message_outlined, color: Colors.red),
                  activeColor: Colors.red,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _emailNotifications,
                  onChanged: (v) => setState(() => _emailNotifications = v),
                  title: const Text('Email Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receive notifications via email'),
                  secondary: const Icon(Icons.email_outlined, color: Colors.red),
                  activeColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}