import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'admin_home_page.dart';
import 'email_verification_page.dart';
import 'HomePage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool isMIUEmail(String email) {
    return email.toLowerCase().trim().endsWith("@miuegypt.edu.eg");
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      // 1) Sign in
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user == null) {
        throw "Invalid credentials";
      }

      final user = response.user!;

      // 2) Check if email is verified
      if (user.emailConfirmedAt == null) {
        await Supabase.instance.client.auth.signOut();

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text("⚠️ Please verify your email before logging in"),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(
              email: _emailController.text.trim(),
            ),
          ),
        );
        return;
      }

      // 3) Check if profile exists
      final profile = await _service.getUserByEmail(_emailController.text.trim());

      if (profile == null) {
        // Create profile from metadata - FIX: Pass user.id as userId
        final userMetadata = user.userMetadata;
        await _service.createUserProfile(
          userId: user.id,  // ✅ FIXED: Pass the user ID here
          name: userMetadata?['name'] ?? 'User',
          email: _emailController.text.trim(),
          role: userMetadata?['role'] ?? 'Student',
          profileImage: userMetadata?['profile_image'],
          department: userMetadata?['department'] ?? 'Unknown',
          bio: userMetadata?['bio'] ?? '',
          academicYear: userMetadata?['academic_year'] ?? 1,
          location: userMetadata?['location'],
        );
        
        print("✅ Profile created for user: ${user.id}");
      }

      // 4) Get user role and ID to determine navigation
      final userProfile = await _service.getUserByEmail(_emailController.text.trim());
      final userRole = userProfile?['role'] ?? 'Student';
      final userId = userProfile?['user_id'] as int? ?? 0; // ✅ Get the user_id as int

      // 5) Success
      if (!mounted) return;
      
      messenger.showSnackBar(
        const SnackBar(
          content: Text("✅ Login successful! Welcome back!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      
      // 6) Navigate based on role
      if (userRole == 'Admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else {
        // ✅ FIX: Pass the actual user ID as an integer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(currentUserId: userId)),
        );
      }

    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("❌ ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("❌ Login failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.lock_outline, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    'Welcome Back',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to your account',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'MIU Email',
                      hintText: 'example@miuegypt.edu.eg',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!isMIUEmail(value)) {
                        return 'Only MIU emails are allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.red),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                      child: const Text('Forgot Password?', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}