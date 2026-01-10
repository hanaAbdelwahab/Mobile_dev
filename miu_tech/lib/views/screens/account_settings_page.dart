import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('email', user.email!)
          .single();

      setState(() {
        _nameController.text = data['name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _locationController.text = data['location'] ?? '';
        _departmentController.text = data['department'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Not authenticated';

      await Supabase.instance.client.from('users').update({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'department': _departmentController.text.trim(),
      }).eq('email', user.email!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputCard(
                      'Full Name',
                      Icons.person_outline,
                      _nameController,
                      'Enter your full name',
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      'Department',
                      Icons.school_outlined,
                      _departmentController,
                      'Your department',
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      'Bio',
                      Icons.info_outline,
                      _bioController,
                      'Tell us about yourself',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      'Location',
                      Icons.location_on_outlined,
                      _locationController,
                      'Your location',
                      required: false,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputCard(
    String label,
    IconData icon,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.red),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
      ),
    );
  }
}