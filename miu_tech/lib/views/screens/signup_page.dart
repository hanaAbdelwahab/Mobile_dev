import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'email_verification_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _location = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  File? _selectedProfileImage;
  File? _selectedCoverImage;
  String? _uploadedProfileImageUrl;
  String? _uploadedCoverImageUrl;
  


  String _selectedRole = "Student";
  int _selectedAcademicYear = 1;
  bool _showAcademicYear = true;
  bool _isRoleDropdownEnabled = true;
  List<String> _availableRoles = ["Student"];

  bool isMIUEmail(String email) {
    return email.toLowerCase().trim().endsWith("@miuegypt.edu.eg");
  }

  // ============================================================
  // ENHANCED EMAIL DETECTION WITH COMPREHENSIVE AUTO-DETECTION
  // ============================================================
Map<String, dynamic> analyzeEmail(String email) {
  // 1️⃣ Check MIU email
  if (!isMIUEmail(email)) {
    return {
      'isValid': false,
      'detectedRole': 'Student',
      'academicYear': 1,
      'availableRoles': ['Student'],
      'showYearDropdown': false,
      'isRoleEditable': false,
      'message': '❌ Please use a valid MIU email',
      'messageColor': Colors.red,
    };
  }

  final emailPrefix = email.split('@')[0].toLowerCase();
  final hasNumbers = RegExp(r'\d').hasMatch(emailPrefix);

  // 2️⃣ Staff emails (no numbers)
  if (!hasNumbers) {
    return {
      'isValid': true,
      'detectedRole': 'Instructor',
      'academicYear': 1,
      'availableRoles': ['Instructor', 'TA'],
      'showYearDropdown': false,
      'isRoleEditable': true,
      'message': '👨‍🏫 Staff email detected',
      'messageColor': Colors.blue,
    };
  }

  // 3️⃣ Extract registration year (first 2 digits)
  final yearMatch = RegExp(r'(\d{2})').firstMatch(emailPrefix);
  if (yearMatch == null) {
    return {
      'isValid': true,
      'detectedRole': 'Student',
      'academicYear': 1,
      'availableRoles': ['Student'],
      'showYearDropdown': true,
      'isRoleEditable': true,
      'message': '📚 Student email detected',
      'messageColor': Colors.green,
    };
  }

  final regTwoDigits = int.parse(yearMatch.group(1)!);
  final fullYear = 2000 + regTwoDigits;


  final currentYear = DateTime.now().year;

// ❌ FUTURE ID → INVALID (اقفلي الدالة هنا)
if (fullYear > currentYear) {
  return {
    'isValid': false,
    'detectedRole': 'Student',
    'academicYear': 1,
    'availableRoles': ['Student'],
    'showYearDropdown': false,
    'isRoleEditable': false,
    'message': '❌ Invalid student ID (future registration year)',
    'messageColor': Colors.red,
  };
}

  final currentMonth = DateTime.now().month;
  final yearsSinceJoining = currentYear - fullYear;
  final graduationYear = fullYear + 4;

  // 4️⃣ INVALID ID (future registration)
  if (yearsSinceJoining == 0 && fullYear > currentYear) {
    return {
      'isValid': false,
      'detectedRole': 'Student',
      'academicYear': 1,
      'availableRoles': ['Student'],
      'showYearDropdown': false,
      'isRoleEditable': false,
      'message': '❌ Invalid student ID (future year)',
      'messageColor': Colors.red,
    };
  }

  // 5️⃣ ALUMNI rules
  final isAlumni =
      graduationYear < currentYear ||
      (graduationYear == currentYear && currentMonth >= 9);

  if (isAlumni) {
    final yearsSinceGraduation = currentYear - graduationYear;
    final message = yearsSinceGraduation == 0
        ? '🎓 Alumni detected! You graduated this year'
        : '🎓 Alumni detected! You graduated $yearsSinceGraduation year${yearsSinceGraduation == 1 ? '' : 's'} ago';

    return {
      'isValid': true,
      'detectedRole': 'Alumni',
      'academicYear': 4,
      'availableRoles': ['Alumni'],
      'showYearDropdown': true,
      'isRoleEditable': false,
      'message': message,
      'messageColor': Colors.purple,
    };
  }

  // 6️⃣ STUDENT academic year calculation
  int academicYear = 1;

  if (yearsSinceJoining == 0) {
    academicYear = 1;
  } else if (yearsSinceJoining == 1) {
    academicYear = currentMonth < 9 ? 1 : 2;
  } else if (yearsSinceJoining == 2) {
    academicYear = currentMonth < 9 ? 2 : 3;
  } else if (yearsSinceJoining == 3) {
    academicYear = currentMonth < 9 ? 3 : 4;
  } else {
    academicYear = 4;
  }

  return {
    'isValid': true,
    'detectedRole': 'Student',
    'academicYear': academicYear,
    'availableRoles': ['Student'],
    'showYearDropdown': true,
    'isRoleEditable': true,
    'message': '📚 Student detected - Year $academicYear',
    'messageColor': Colors.green,
  };
}

  // ============================================================
  // EMAIL CHANGE HANDLER - APPLIES AUTO-DETECTION
  // ============================================================
  void _onEmailChanged(String email) {
  final analysis = analyzeEmail(email);

  // 🟥 CASE 1: INVALID EMAIL / FUTURE ID
  if (!analysis['isValid']) {
    setState(() {
      _selectedRole = analysis['detectedRole'];
      _availableRoles = analysis['availableRoles'];
      _isRoleDropdownEnabled = false;
      _showAcademicYear = false;
    });

    // 🔔 Show error message
    if (analysis['message'] != null &&
        analysis['message'].toString().isNotEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(analysis['message']),
          backgroundColor: analysis['messageColor'] ?? Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    return; // ⛔ stop here
  }

  // 🟩 CASE 2: VALID EMAIL (Student / Alumni / Staff)
  setState(() {
    _selectedRole = analysis['detectedRole'];
    _selectedAcademicYear = analysis['academicYear'];
    _availableRoles = analysis['availableRoles'];
    _showAcademicYear = analysis['showYearDropdown'];
    _isRoleDropdownEnabled = analysis['isRoleEditable'];
  });

  // 🔔 Show success / info message
  if (analysis['message'] != null &&
      analysis['message'].toString().isNotEmpty) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(analysis['message']),
        backgroundColor: analysis['messageColor'] ?? Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

  @override
  void initState() {
    super.initState();
    // Listen to email changes for auto-detection
    _email.addListener(() {
      _onEmailChanged(_email.text.trim());
    });
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

  // ============================================================
  // PICK PROFILE IMAGE
  // ============================================================
  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Choose Profile Photo'),
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
          _selectedProfileImage = File(pickedFile.path);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Profile photo selected!"),
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

  // ============================================================
  // PICK COVER IMAGE
  // ============================================================
  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Choose Cover Photo'),
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
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedCoverImage = File(pickedFile.path);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cover photo selected!"),
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

  // ============================================================
  // UPLOAD PROFILE IMAGE
  // ============================================================
  Future<String?> _uploadProfileImage() async {
    if (_selectedProfileImage == null) return null;

    try {
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}_${_email.text.split('@')[0]}.jpg';
      final bytes = await _selectedProfileImage!.readAsBytes();

      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary('public/$fileName', bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl('public/$fileName');

      return imageUrl;
    } catch (e) {
      print('❌ Profile image upload error: $e');
      return null;
    }
  }

  // ============================================================
  // UPLOAD COVER IMAGE
  // ============================================================
  Future<String?> _uploadCoverImage() async {
    if (_selectedCoverImage == null) return null;

    try {
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}_${_email.text.split('@')[0]}.jpg';
      final bytes = await _selectedCoverImage!.readAsBytes();

      await Supabase.instance.client.storage
          .from('cover-images')
          .uploadBinary('public/$fileName', bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('cover-images')
          .getPublicUrl('public/$fileName');

      return imageUrl;
    } catch (e) {
      print('❌ Cover image upload error: $e');
      return null;
    }
  }

  // ============================================================
  // HANDLE SIGNUP
  // ============================================================
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      // 1) Upload images
      if (_selectedProfileImage != null || _selectedCoverImage != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("📤 Uploading photos..."),
            duration: Duration(seconds: 2),
          ),
        );

        final results = await Future.wait([
          _uploadProfileImage(),
          _uploadCoverImage(),
        ]);

        _uploadedProfileImageUrl = results[0];
        _uploadedCoverImageUrl = results[1];
      }

      // 2) Determine approval status
      final approvalStatus = _selectedRole == 'Admin' ? 'pending' : 'approved';

      // 3) Sign up
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
        data: {
          'name': _name.text.trim(),
          'role': _selectedRole,
          'department': _department.text.trim(),
          'bio': _bio.text.trim(),
          'academic_year': _showAcademicYear ? _selectedAcademicYear : null,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'profile_image': _uploadedProfileImageUrl,
          'cover_image': _uploadedCoverImageUrl,
          'approval_status': approvalStatus,
        },
      );

      if (res.user == null) {
        throw "Signup failed - no user returned";
      }

      print("✅ Signup successful for: ${res.user!.email}");
      print("📋 Role: $_selectedRole");
      if (_showAcademicYear) {
        print("📚 Academic Year: $_selectedAcademicYear");
      }

      if (!mounted) return;
      
      if (_selectedRole == 'Admin') {
        await _showPendingApprovalDialog();
      } else {
        await _showSuccessDialog();
      }

    } on AuthException catch (e) {
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

  Future<void> _showPendingApprovalDialog() async {
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
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending_actions,
                color: Colors.orange,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Admin Request Pending",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Your admin access request has been submitted.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "An administrator will review your request. You'll receive confirmation once approved.",
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
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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

                // COVER IMAGE
                GestureDetector(
                  onTap: _pickCoverImage,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedCoverImage != null ? Colors.green : Colors.grey[300]!,
                        width: 2,
                      ),
                      image: _selectedCoverImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedCoverImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedCoverImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 4),
                              Text(
                                'Add Cover Photo (Optional)',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // PROFILE IMAGE
                GestureDetector(
                  onTap: _pickProfileImage,
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
                          backgroundImage: _selectedProfileImage != null
                              ? FileImage(_selectedProfileImage!)
                              : null,
                          child: _selectedProfileImage == null
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
                  _selectedProfileImage == null ? "Tap to add photo" : "Tap to change photo",
                  style: TextStyle(
                    color: _selectedProfileImage == null ? Colors.grey[600] : Colors.green,
                    fontSize: 13,
                    fontWeight: _selectedProfileImage == null ? FontWeight.normal : FontWeight.bold,
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

                // ROLE DROPDOWN - DYNAMICALLY RESTRICTED BASED ON EMAIL
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: Icon(
                      _selectedRole == "Alumni" 
                          ? Icons.school 
                          : _selectedRole == "Instructor" || _selectedRole == "TA"
                              ? Icons.person_pin
                              : Icons.badge,
                      color: Colors.red,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: !_isRoleDropdownEnabled 
                        ? "🔒 Role locked based on email"
                        : "✓ Auto-detected from email",
                    helperStyle: TextStyle(
                      color: !_isRoleDropdownEnabled 
                          ? Colors.purple 
                          : _selectedRole == "Alumni" 
                              ? Colors.purple 
                              : _selectedRole == "Instructor" || _selectedRole == "TA"
                                  ? Colors.blue
                                  : Colors.green[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: !_isRoleDropdownEnabled,
                    fillColor: !_isRoleDropdownEnabled ? Colors.grey[100] : null,
                  ),
                  items: _availableRoles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        role == "Alumni" ? "Alumni 🎓" : role,
                        style: TextStyle(
                          fontWeight: role == _selectedRole ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _isRoleDropdownEnabled 
                      ? (v) {
                          setState(() {
                            _selectedRole = v ?? _selectedRole;
                            // Update year visibility when role changes
                            _showAcademicYear = (v == "Student" || v == "Alumni");
                          });
                        }
                      : null, // Disable if not editable
                ),
                const SizedBox(height: 16),

                // ACADEMIC YEAR - SHOW ONLY FOR STUDENTS AND ALUMNI
                if (_showAcademicYear) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedAcademicYear,
                    decoration: InputDecoration(
                      labelText: _selectedRole == "Alumni" ? "Graduation Year" : "Academic Year",
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: _selectedRole == "Alumni" 
                          ? "🎓 Auto-detected: Graduated (4+ years)" 
                          : "📚 Auto-detected from registration year",
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: _selectedRole == "Alumni" ? Colors.purple : Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                      filled: _selectedRole == "Alumni",
                      fillColor: _selectedRole == "Alumni" ? Colors.purple.withOpacity(0.05) : null,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Year 1")),
                      DropdownMenuItem(value: 2, child: Text("Year 2")),
                      DropdownMenuItem(value: 3, child: Text("Year 3")),
                      DropdownMenuItem(value: 4, child: Text("Year 4 / Graduated")),
                    ],
                    onChanged: (v) => setState(() => _selectedAcademicYear = v!),
                  ),
                  const SizedBox(height: 16),
                ],

                _input("Bio", Icons.info, _bio, maxLines: 2),
                const SizedBox(height: 16),

                _input("Location (optional)", Icons.location_on, _location, validator: (_) => null),
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
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.red),
                  ),
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