// ============================================================
// FILE: supabase_service.dart
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // CREATE USER PROFILE IN public.users
  // ============================================================
  Future<void> createUserProfile({
    required String userId, // This is the auth user ID (UUID)
    required String name,
    required String email,
    required String role,
    String? profileImage,
    required String department,
    required String bio,
    required int academicYear,
    String? location,
  }) async {
    try {
      // Check if user already exists by email
      final existing = await client
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existing != null) {
        print("⚠️ User profile already exists for $email");
        return;
      }

      // Check if user already exists by auth_user_id
      final existingByAuthId = await client
          .from('users')
          .select('auth_user_id')
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (existingByAuthId != null) {
        print("⚠️ User profile already exists for auth_user_id: $userId");
        return;
      }

      // Insert new user profile
      // user_id will auto-increment if you ran OPTION 1 from the SQL fix
      final response = await client.from('users').insert({
        'name': name,
        'email': email,
        'role': role,
        'profile_image': profileImage,
        'department': department,
        'bio': bio,
        'academic_year': academicYear,
        'location': location,
        'auth_user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      print("✅ User profile created for $email");
      print("Response: $response");
    } catch (e) {
      print("❌ Error creating user profile: $e");
      rethrow;
    }
  }

  // ============================================================
  // FETCH USER BY EMAIL
  // ============================================================
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final data = await client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      return data;
    } catch (e) {
      print("❌ Error fetching user: $e");
      return null;
    }
  }

  // ============================================================
  // FETCH USER BY AUTH USER ID (UUID)
  // ============================================================
  Future<Map<String, dynamic>?> getUserByAuthId(String authUserId) async {
    try {
      final data = await client
          .from('users')
          .select()
          .eq('auth_user_id', authUserId)
          .maybeSingle();
      return data;
    } catch (e) {
      print("❌ Error fetching user by auth ID: $e");
      return null;
    }
  }

  // ============================================================
  // CHECK IF USER EMAIL IS VERIFIED
  // ============================================================
  Future<bool> isEmailVerified() async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    // Refresh session to get latest email_confirmed_at
    await client.auth.refreshSession();
    final refreshedUser = client.auth.currentUser;

    return refreshedUser?.emailConfirmedAt != null;
  }
}