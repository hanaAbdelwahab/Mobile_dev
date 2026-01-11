import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ================= Supabase =================
import 'package:supabase_flutter/supabase_flutter.dart';

// ================= Riverpod =================
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

// ================= Provider =================
import 'package:provider/provider.dart';

// ================= App Screens =================
import 'views/screens/Splash_Screen.dart';
import 'views/screens/HomePage.dart';
import 'views/screens/login_page.dart';
import 'views/screens/signup_page.dart';
import 'views/screens/forgot_password_page.dart';
import 'views/screens/email_confirmed_page.dart';


// ================= Providers =================
import 'providers/SavedPostProvider.dart';
import 'providers/StoryProvider.dart';
import 'providers/post_provider.dart';
import 'providers/repost_provider.dart';
import 'providers/comment_provider.dart';
import 'providers/FreelancingHubProvider.dart'; 
import 'providers/friendship_provider.dart';

// ================= Services =================
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: 'https://aadoraweupxxqnotvkyw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g',
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    print("🔔 Auth event: $event");

    if (event == AuthChangeEvent.signedIn && session?.user != null) {
      final user = session!.user;
      
      print("✅ User signed in: ${user.email}");
      print("📧 Email confirmed at: ${user.emailConfirmedAt}");
      
      // Only create profile if email is confirmed
      if (user.emailConfirmedAt != null) {
        final service = SupabaseService();
        final existingProfile = await service.getUserByEmail(user.email!);
        
        if (existingProfile == null) {
          // Create profile from metadata stored during signup
          final metadata = user.userMetadata;
          
          // ✅ FIXED: Pass user.id as userId parameter
          await service.createUserProfile(
            userId: user.id,
            name: metadata?['name'] ?? 'User',
            email: user.email!,
            role: metadata?['role'] ?? 'Student',
            profileImage: metadata?['profile_image'],
            department: metadata?['department'] ?? 'Unknown',
            bio: metadata?['bio'] ?? '',
            academicYear: metadata?['academic_year'] ?? 1,
            location: metadata?['location'],
          );
          
          print("✅ Profile created in database for ${user.email}");
        } else {
          print("ℹ️ Profile already exists for ${user.email}");
        }
      }
    }
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    riverpod.ProviderScope(
      child: const MIUTechCircleApp(),
    ),
  );
}

class MIUTechCircleApp extends StatelessWidget {
  const MIUTechCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // ============================================================
      // Providers wrapped around the entire app
      // ============================================================
      providers: [
        ChangeNotifierProvider(create: (_) => SavedPostProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(
          create: (_) => PostProvider(
            currentUserId: _getCurrentUserId(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RepostProvider(
            currentUserId: _getCurrentUserId(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => FreelancingHubProvider()),
        ChangeNotifierProvider(create: (_) => FriendshipProvider()),
      ],
      child: MaterialApp(
        title: 'MIU TechCircle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFE63946),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
          brightness: Brightness.light,
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFE63946),
            secondary: const Color(0xFFDC2F41),
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
        ),
        
        // Start with splash screen
        home: const SplashScreen(),
        
        // Define routes
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginPage(),
          '/signup': (_) => const SignUpPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/email-confirmed': (_) => const EmailConfirmedPage(),
          '/home': (_) => HomePage(currentUserId: _getCurrentUserId()),
          '/new-home': (_) => HomePage(currentUserId: _getCurrentUserId()),
        },
      ),
    );
  }

  // ============================================================
  // Helper method to get current user ID
  // ============================================================
  int _getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Try to get user ID from your database
      // For now, return a temporary ID or parse from user metadata
      // You might want to fetch this from your users table based on user.id
      return user.userMetadata?['user_id'] ?? 6; // Fallback to 6 as in original
    }
    return 6; // Default temporary ID when not logged in
  }
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;
