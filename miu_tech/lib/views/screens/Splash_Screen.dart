import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart'; // Updated import

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark icons for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, 
    ));

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _controller.forward();

    // Navigate to Login page after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryRed = const Color(0xFFE63946);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- Gradient Orbs and Geometric Lines ---
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: _buildGradientOrb(size: size.width * 0.9, color: primaryRed, opacity: 0.15),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: _buildGradientOrb(size: size.width * 1.0, color: Colors.grey, opacity: 0.1),
          ),
          Positioned.fill(
            child: CustomPaint(painter: GeometricPainter(primaryColor: primaryRed)),
          ),

          // --- TOP RIGHT LOGO ---
          Positioned(
            top: 60,
            right: 30,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Image.asset('assets/newlogo.png', fit: BoxFit.contain),
              ),
            ),
          ),

          // --- Content ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2), 
                
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome!",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800, 
                            color: Colors.black, 
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // RichText for branding
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: "MIU TechCircle.\n",
                                style: TextStyle(
                                  fontSize: 24,
                                  color: primaryRed,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                              ),
                              const TextSpan(
                                text: "Your centralized hub for every opportunity.",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(flex: 3),

                Padding(
                  padding: const EdgeInsets.only(bottom: 50.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.auto_awesome, 
                      color: primaryRed.withOpacity(0.8), 
                      size: 30
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOrb({required double size, required Color color, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7],
          center: Alignment.center,
        ),
      ),
    );
  }
}

// --- Custom Painter for the Thin Lines & Stars ---
class GeometricPainter extends CustomPainter {
  final Color primaryColor;

  GeometricPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; 

    // 1. Top Right Circles (Thin Arcs)
    final centerTopRight = Offset(size.width * 0.8, size.height * 0.2);
    canvas.drawCircle(centerTopRight, size.width * 0.35, paint);
    canvas.drawCircle(centerTopRight, size.width * 0.55, paint);

    // 2. Bottom Left Circles
    final centerBottomLeft = Offset(size.width * 0.2, size.height * 0.8);
    canvas.drawCircle(centerBottomLeft, size.width * 0.4, paint);

    // 3. Draw the "Code Spark" (8-pointed star aesthetic)
    _drawSpark(canvas, Offset(size.width * 0.3, size.height * 0.15), 40, primaryColor.withOpacity(0.8));
    
    // Secondary spark
    _drawSpark(canvas, Offset(size.width * 0.15, size.height * 0.65), 25, Colors.grey.withOpacity(0.3));
  }

  void _drawSpark(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Create a 4-pointed star shape
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radius * 0.6, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radius * 0.6, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}