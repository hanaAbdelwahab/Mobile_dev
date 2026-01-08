import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/supabase_service.dart';
import 'email_verification_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _location = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  File? _selectedImage;
  String? _uploadedImageUrl;

  String _selectedRole = "Student";
  int _selectedAcademicYear = 1;

  bool isMIUEmail(String email) {
    return email.toLowerCase().trim().endsWith("@miuegypt.edu.eg");
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _department.dispose();
    _bio.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Choose Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.red),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.red),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Photo selected!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_email.text.split('@')[0]}.jpg';
      final bytes = await _selectedImage!.readAsBytes();

      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary('public/$fileName', bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl('public/$fileName');

      return imageUrl;
    } catch (e) {
      print('❌ Image upload error: $e');
      return null;
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      // 1) Upload image
      if (_selectedImage != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Uploading photo..."),
            duration: Duration(seconds: 2),
          ),
        );
        _uploadedImageUrl = await _uploadImage();
      }

      // 2) Sign up
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
        data: {
          'name': _name.text.trim(),
          'role': _selectedRole,
          'department': _department.text.trim(),
          'bio': _bio.text.trim(),
          'academic_year': _selectedAcademicYear,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'profile_image': _uploadedImageUrl,
        },
      );

      if (res.user == null) {
        throw "Signup failed - no user returned";
      }

      print("✅ Signup successful for: ${res.user!.email}");

      // 3) Show success dialog
      if (!mounted) return;
      await _showSuccessDialog();

    } on AuthException catch (e) {
      // Handle duplicate email error
      if (e.message.contains('already registered') || e.message.contains('duplicate')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("❌ This email is already registered. Please login instead."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text("❌ ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("❌ Signup Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Account Created! 🎉",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "We've sent a confirmation email to:",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _email.text.trim(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Please check your inbox (and spam folder) to verify your email.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailVerificationPage(
                        email: _email.text.trim(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color.fromARGB(40, 255, 0, 0),
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : null,
                          child: _selectedImage == null
                              ? const Icon(Icons.person, size: 60, color: Colors.red)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  _selectedImage == null ? "Tap to add photo" : "Tap to change photo",
                  style: TextStyle(
                    color: _selectedImage == null ? Colors.grey[600] : Colors.green,
                    fontSize: 13,
                    fontWeight: _selectedImage == null ? FontWeight.normal : FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Use your MIU email to join",
                  style: TextStyle(color: Colors.grey[600]),
                ),

                const SizedBox(height: 22),

                _input("Full Name", Icons.person, _name),
                const SizedBox(height: 16),

                _input("MIU Email", Icons.email, _email, validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (!isMIUEmail(v)) return "Use MIU email only (@miuegypt.edu.eg)";
                  return null;
                }),
                const SizedBox(height: 16),

                _input("Department", Icons.school, _department),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _selectedAcademicYear,
                  decoration: InputDecoration(
                    labelText: "Academic Year",
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Year 1")),
                    DropdownMenuItem(value: 2, child: Text("Year 2")),
                    DropdownMenuItem(value: 3, child: Text("Year 3")),
                    DropdownMenuItem(value: 4, child: Text("Year 4")),
                  ],
                  onChanged: (v) => setState(() => _selectedAcademicYear = v!),
                ),
                const SizedBox(height: 16),

                _input("Bio", Icons.info, _bio, maxLines: 2),
                const SizedBox(height: 16),

                _input("Location (optional)", Icons.location_on, _location, validator: (_) => null),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: const Icon(Icons.badge, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Student", child: Text("Student")),
                    DropdownMenuItem(value: "Instructor", child: Text("Instructor")),
                    DropdownMenuItem(value: "TA", child: Text("TA")),
                    DropdownMenuItem(value: "Alumni", child: Text("Alumni")),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v ?? "Student"),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock, color: Colors.red),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v != null && v.length >= 6 ? null : "Min 6 characters",
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Create Account",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text("Already have an account? Login", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    String label,
    IconData icon,
    TextEditingController controller, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}