import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:miu_tech/app_theme.dart';
import 'dart:math';
import 'reset_password_with_otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _generatedOtp;
  DateTime? _otpExpiry;

  bool isMIUEmail(String email) {
    return email.toLowerCase().trim().endsWith("@miuegypt.edu.eg");
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Generate 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send OTP via Supabase
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // Check if user exists in database
      final userExists = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (userExists == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ No account found with this email'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Generate OTP
      _generatedOtp = _generateOTP();
      _otpExpiry = DateTime.now().add(const Duration(minutes: 10));

      print("========================================");
      print("🔐 GENERATED OTP FOR $email: $_generatedOtp");
      print("⏰ EXPIRES AT: ${_otpExpiry!.toLocal()}");
      print("========================================");

      // Store OTP in database temporarily
      await Supabase.instance.client.from('password_reset_otps').upsert({
        'email': email,
        'otp': _generatedOtp,
        'expires_at': _otpExpiry!.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Try to send email via Supabase Edge Function
      try {
        await Supabase.instance.client.functions.invoke(
          'send-password-reset-email',
          body: {
            'to_email': email,
            'otp_code': _generatedOtp,
            'expires_minutes': 10,
          },
        );
        print("✅ Email sent successfully via Edge Function");
      } catch (emailError) {
        print("⚠️ Could not send email via Edge Function: $emailError");
        print("⚠️ User must check console or database for OTP");
      }

      if (!mounted) return;
      setState(() => _otpSent = true);

      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Verification code sent to $email'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FOR TESTING: $_generatedOtp',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('❌ Error sending OTP: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Verify OTP
  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please enter the verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final enteredOtp = _otpController.text.trim();

      print("========================================");
      print("🔍 Verifying OTP");
      print("📧 Email: $email");
      print("🔢 Entered OTP: $enteredOtp");
      print("========================================");

      // Verify OTP from database
      final otpRecord = await Supabase.instance.client
          .from('password_reset_otps')
          .select()
          .eq('email', email)
          .eq('otp', enteredOtp)
          .maybeSingle();

      print("📋 Database record found: ${otpRecord != null}");
      if (otpRecord != null) {
        print("✅ Stored OTP: ${otpRecord['otp']}");
        print("✅ Stored Email: ${otpRecord['email']}");
        print("✅ Expires at: ${otpRecord['expires_at']}");
      }

      if (otpRecord == null) {
        if (!mounted) return;

        // Check if there's any OTP for this email
        final anyOtp = await Supabase.instance.client
            .from('password_reset_otps')
            .select()
            .eq('email', email)
            .maybeSingle();

        if (anyOtp != null) {
          print(
              "❌ OTP mismatch! Expected: ${anyOtp['otp']}, Got: $enteredOtp");
        } else {
          print("❌ No OTP record found for this email");
        }

        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('❌ Invalid verification code. Please check and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if OTP expired
      final expiryTime = DateTime.parse(otpRecord['expires_at']);
      print("⏰ Current time: ${DateTime.now()}");
      print("⏰ Expiry time: $expiryTime");
      print("⏰ Is expired: ${DateTime.now().isAfter(expiryTime)}");

      if (DateTime.now().isAfter(expiryTime)) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content:
                Text('❌ Verification code expired. Please request a new one.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      print("✅ OTP verification successful!");

      // OTP is valid! Delete it and proceed
      await Supabase.instance.client
          .from('password_reset_otps')
          .delete()
          .eq('email', email);

      print("🗑️ OTP deleted from database");

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Email verified! You can now reset your password.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to reset password page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordWithOtpPage(email: email),
        ),
      );
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _otpSent ? Icons.mark_email_read : Icons.lock_reset,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    _otpSent ? 'Verify Email' : 'Forgot Password?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}'
                        : 'Enter your email to receive a verification code',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_otpSent,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'MIU Email',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      hintText: 'example@miuegypt.edu.eg',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.primaryRed,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryRed,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: _otpSent
                          ? (isDark
                              ? AppColors.darkSurfaceVariant.withOpacity(0.5)
                              : AppColors.lightSurfaceVariant)
                          : (isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant),
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

                  // OTP Field (shown after email sent)
                  if (_otpSent) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        labelStyle: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        hintText: 'Enter 6-digit code',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        prefixIcon: Icon(
                          Icons.pin,
                          color: AppColors.primaryRed,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primaryRed,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive code? ",
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _otpSent = false;
                                    _otpController.clear();
                                  });
                                  _sendOTP();
                                },
                          child: Text(
                            'Resend',
                            style: TextStyle(
                              color: _isLoading
                                  ? (isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary)
                                  : AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Action Button
                  ElevatedButton(
                    onPressed:
                        _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      disabledBackgroundColor: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _otpSent
                                ? 'Verify Code'
                                : 'Send Verification Code',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Remember your password? ",
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
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