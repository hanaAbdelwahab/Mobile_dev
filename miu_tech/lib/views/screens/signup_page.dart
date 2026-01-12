import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'email_verification_page.dart';
import 'login_page.dart';
import 'package:miu_tech/app_theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

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

  final FocusNode _emailFocusNode = FocusNode();

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

  Map<String, dynamic> analyzeEmail(String email) {
    if (!isMIUEmail(email)) {
      return {
        'isValid': false,
        'detectedRole': 'Student',
        'academicYear': 1,
        'availableRoles': ['Student'],
        'showYearDropdown': false,
        'isRoleEditable': false,
        'message': '❌ Please use a valid MIU email',
        'messageColor': AppColors.error,
      };
    }

    final emailPrefix = email.split('@')[0].toLowerCase();
    final hasNumbers = RegExp(r'\d').hasMatch(emailPrefix);

    if (!hasNumbers) {
      return {
        'isValid': true,
        'detectedRole': 'Instructor',
        'academicYear': 1,
        'availableRoles': ['Instructor', 'TA'],
        'showYearDropdown': false,
        'isRoleEditable': true,
        'message': '👨‍🏫 Staff email detected',
        'messageColor': AppColors.info,
      };
    }

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
        'messageColor': AppColors.success,
      };
    }

    final regTwoDigits = int.parse(yearMatch.group(1)!);
    final fullYear = 2000 + regTwoDigits;

    final currentYear = DateTime.now().year;

    if (fullYear > currentYear) {
      return {
        'isValid': false,
        'detectedRole': 'Student',
        'academicYear': 1,
        'availableRoles': ['Student'],
        'showYearDropdown': false,
        'isRoleEditable': false,
        'message': '❌ Invalid student ID (future registration year)',
        'messageColor': AppColors.error,
      };
    }

    final currentMonth = DateTime.now().month;
    final yearsSinceJoining = currentYear - fullYear;
    final graduationYear = fullYear + 4;

    if (yearsSinceJoining == 0 && fullYear > currentYear) {
      return {
        'isValid': false,
        'detectedRole': 'Student',
        'academicYear': 1,
        'availableRoles': ['Student'],
        'showYearDropdown': false,
        'isRoleEditable': false,
        'message': '❌ Invalid student ID (future year)',
        'messageColor': AppColors.error,
      };
    }

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
        'messageColor': const Color(0xFF9C27B0), // Purple
      };
    }

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
      'messageColor': AppColors.success,
    };
  }

  void _onEmailChanged(String email) {
    final analysis = analyzeEmail(email);

    if (!analysis['isValid']) {
      setState(() {
        _selectedRole = analysis['detectedRole'];
        _availableRoles = analysis['availableRoles'];
        _isRoleDropdownEnabled = false;
        _showAcademicYear = false;
      });

      if (analysis['message'] != null &&
          analysis['message'].toString().isNotEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              analysis['message'],
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: analysis['messageColor'] ?? AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      return;
    }

    setState(() {
      _selectedRole = analysis['detectedRole'];
      _selectedAcademicYear = analysis['academicYear'];
      _availableRoles = analysis['availableRoles'];
      _showAcademicYear = analysis['showYearDropdown'];
      _isRoleDropdownEnabled = analysis['isRoleEditable'];
    });

    if (analysis['message'] != null &&
        analysis['message'].toString().isNotEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            analysis['message'],
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: analysis['messageColor'] ?? AppColors.success,
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

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _onEmailChanged(_email.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _department.dispose();
    _bio.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    try {
      final picker = ImagePicker();
      
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Choose Profile Photo',
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryRed),
                title: Text(
                  'Gallery',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primaryRed),
                title: Text(
                  'Camera',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
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
          SnackBar(
            content: const Text(
              "✅ Profile photo selected!",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ Error: $e",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    try {
      final picker = ImagePicker();
      
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Choose Cover Photo',
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryRed),
                title: Text(
                  'Gallery',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primaryRed),
                title: Text(
                  'Camera',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
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
          SnackBar(
            content: const Text(
              "✅ Cover photo selected!",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ Error: $e",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      if (_selectedProfileImage != null || _selectedCoverImage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              "📤 Uploading photos...",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 2),
          ),
        );

        final results = await Future.wait([
          _uploadProfileImage(),
          _uploadCoverImage(),
        ]);

        _uploadedProfileImageUrl = results[0];
        _uploadedCoverImageUrl = results[1];
      }

      final approvalStatus = _selectedRole == 'Admin' ? 'pending' : 'approved';

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
          SnackBar(
            content: const Text(
              "❌ This email is already registered. Please login instead.",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "❌ ${e.message}",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "❌ Signup Error: $e",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPendingApprovalDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending_actions,
                color: AppColors.warning,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Admin Request Pending",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Your admin access request has been submitted.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "An administrator will review your request. You'll receive confirmation once approved.",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                  backgroundColor: AppColors.warning,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Account Created! 🎉",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "We've sent a confirmation email to:",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _email.text.trim(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Please check your inbox (and spam folder) to verify your email.",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                  backgroundColor: AppColors.primaryRed,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedCoverImage != null 
                            ? AppColors.success 
                            : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
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
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: isDark ? AppColors.darkIconSecondary : AppColors.lightIconSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Cover Photo (Optional)',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontSize: 12,
                                ),
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
                          border: Border.all(color: AppColors.primaryRed, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.primaryRed.withOpacity(0.15),
                          backgroundImage: _selectedProfileImage != null
                              ? FileImage(_selectedProfileImage!)
                              : null,
                          child: _selectedProfileImage == null
                              ? const Icon(Icons.person, size: 60, color: AppColors.primaryRed)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                              width: 2,
                            ),
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
                    color: _selectedProfileImage == null 
                        ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                        : AppColors.success,
                    fontSize: 13,
                    fontWeight: _selectedProfileImage == null ? FontWeight.normal : FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Use your MIU email to join",
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                const SizedBox(height: 22),

                _input("Full Name", Icons.person, _name),
                const SizedBox(height: 16),

                _input(
                  "MIU Email",
                  Icons.email,
                  _email,
                  focusNode: _emailFocusNode,
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Required";
                    if (!isMIUEmail(v)) return "Use MIU email only (@miuegypt.edu.eg)";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _input("Department", Icons.school, _department),
                const SizedBox(height: 16),

                // ROLE DROPDOWN
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  dropdownColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: "Role",
                    labelStyle: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    prefixIcon: Icon(
                      _selectedRole == "Alumni" 
                          ? Icons.school 
                          : _selectedRole == "Instructor" || _selectedRole == "TA"
                              ? Icons.person_pin
                              : Icons.badge,
                      color: AppColors.primaryRed,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    helperText: !_isRoleDropdownEnabled 
                        ? "🔒 Role locked based on email"
                        : "✓ Auto-detected from email",
                    helperStyle: TextStyle(
                      color: !_isRoleDropdownEnabled 
                          ? const Color(0xFF9C27B0)
                          : _selectedRole == "Alumni" 
                              ? const Color(0xFF9C27B0)
                              : _selectedRole == "Instructor" || _selectedRole == "TA"
                                  ? AppColors.info
                                  : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: !_isRoleDropdownEnabled,
                    fillColor: !_isRoleDropdownEnabled 
                        ? (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant)
                        : null,
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
                            _showAcademicYear = (v == "Student" || v == "Alumni");
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),

                // ACADEMIC YEAR
                if (_showAcademicYear) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedAcademicYear,
                    dropdownColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: _selectedRole == "Alumni" ? "Graduation Year" : "Academic Year",
                      labelStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primaryRed),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                        ),
                      ),
                      helperText: _selectedRole == "Alumni" 
                          ? "🎓 Auto-detected: Graduated (4+ years)" 
                          : "📚 Auto-detected from registration year",
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: _selectedRole == "Alumni" ? const Color(0xFF9C27B0) : AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: _selectedRole == "Alumni",
                      fillColor: _selectedRole == "Alumni" 
                          ? const Color(0xFF9C27B0).withOpacity(0.05)
                          : null,
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
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    prefixIcon: const Icon(Icons.lock, color: AppColors.primaryRed),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? AppColors.darkIconSecondary : AppColors.lightIconSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      ),
                    ),
                  ),
                  validator: (v) => v != null && v.length >= 6 ? null : "Min 6 characters",
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
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
                    style: TextStyle(color: AppColors.primaryRed),
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
    FocusNode? focusNode,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryRed),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ),
    );
  }
}