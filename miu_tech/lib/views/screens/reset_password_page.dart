import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'login_page.dart';

class ResetPasswordWithOtpPage extends StatefulWidget {
  final String email;
  
  const ResetPasswordWithOtpPage({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPasswordWithOtpPage> createState() => _ResetPasswordWithOtpPageState();
}

class _ResetPasswordWithOtpPageState extends State<ResetPasswordWithOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      final newPassword = _newPasswordController.text.trim();
      
      print("========================================");
      print("🔄 Starting password reset for: ${widget.email}");
      print("========================================");

      // Method 1: Try using RPC function
      try {
        print("📞 Attempting RPC function: reset_user_password");
        
        final response = await Supabase.instance.client.rpc(
          'reset_user_password',
          params: {
            'user_email': widget.email,
            'new_password': newPassword,
          },
        );
        
        print("📋 RPC Response: $response");
        
        if (response != null && response['success'] == true) {
          print("✅ Password reset via RPC successful!");
          
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Password successfully reset!\n\n'
                'You can now login with your new password.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) return;
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
          return;
        } else {
          print("⚠️ RPC returned error: ${response?['error']}");
          throw Exception(response?['error'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print("❌ RPC Error: $rpcError");
        print("🔄 Trying alternative method...");
        
        // Method 2: Try alternative RPC function
        try {
          print("📞 Attempting alternative RPC: update_auth_password");
          
          final response2 = await Supabase.instance.client.rpc(
            'update_auth_password',
            params: {
              'user_email': widget.email,
              'new_password': newPassword,
            },
          );
          
          print("📋 Alternative RPC Response: $response2");
          
          if (response2 != null && response2['success'] == true) {
            print("✅ Password reset via alternative RPC successful!");
            
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Password successfully reset!\n\n'
                  'You can now login with your new password.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            await Future.delayed(const Duration(seconds: 2));

            if (!mounted) return;
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
            return;
          }
        } catch (rpc2Error) {
          print("❌ Alternative RPC Error: $rpc2Error");
          print("🔄 Trying direct database update...");
        }
        
        // Method 3: Direct database update (fallback)
        print("📝 Attempting direct database update");
        
        // Get user record
        final userRecord = await Supabase.instance.client
            .from('users')
            .select('user_id, auth_user_id')
            .eq('email', widget.email)
            .maybeSingle();

        if (userRecord == null) {
          throw 'User not found in database';
        }

        print("✅ User found: ${userRecord['user_id']}");

        // Update password in users table (hashed)
        final hashedPassword = _hashPassword(newPassword);
        await Supabase.instance.client
            .from('users')
            .update({
              'password': hashedPassword,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('email', widget.email);
        
        print("✅ Password updated in users table");

        if (!mounted) return;
        
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '⚠️ Password updated in database',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Note: You may need to contact admin to sync with authentication system.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(seconds: 3));

        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }

    } catch (e) {
      print('❌ Fatal Error: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error resetting password\n\n$e\n\n'
            'Please contact support or try again later.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create New Password',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Container(
                    height: 100,
                    width: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.vpn_key,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Create New Password',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your email has been verified.\nSet your new password below.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email (read-only)
                  TextFormField(
                    initialValue: widget.email,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Password Field
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter your new password',
                      prefixIcon: const Icon(Icons.vpn_key, color: Colors.red),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter your new password',
                      prefixIcon: const Icon(Icons.check_circle_outline, color: Colors.red),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Password Requirements:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRequirement('At least 6 characters'),
                        _buildRequirement('Passwords must match'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Reset Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      disabledBackgroundColor: Colors.grey[300],
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
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}