import 'package:supabase_flutter/supabase_flutter.dart';

class UserController {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> fetchUserData(int id) async {
    try {
      return await _supabase
          .from('users')
          .select('name, profile_image')
          .eq('user_id', id)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }
}
