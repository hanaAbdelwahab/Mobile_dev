import 'package:flutter/material.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _darkMode = false;
  String _language = 'English';
  bool _autoPlayVideos = true;
  bool _dataUsageWarning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Appearance',
            [
              _buildSwitchTile(
                'Dark Mode',
                'Enable dark theme',
                Icons.dark_mode_outlined,
                _darkMode,
                (value) => setState(() => _darkMode = value),
              ),
              _buildDropdownTile(
                'Language',
                'Select your preferred language',
                Icons.language_outlined,
                _language,
                ['English', 'Arabic', 'French'],
                (value) => setState(() => _language = value!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Media',
            [
              _buildSwitchTile(
                'Auto-play Videos',
                'Automatically play videos',
                Icons.play_circle_outline,
                _autoPlayVideos,
                (value) => setState(() => _autoPlayVideos = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Data',
            [
              _buildSwitchTile(
                'Data Usage Warning',
                'Warn when using mobile data',
                Icons.data_usage_outlined,
                _dataUsageWarning,
                (value) => setState(() => _dataUsageWarning = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      secondary: Icon(icon, color: Colors.red),
      activeThumbColor: Colors.red,
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}