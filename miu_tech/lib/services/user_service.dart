import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final supabase = Supabase.instance.client;

  Future<UserModel?> getUserById(int userId) async {
    final response =
        await supabase.from('users').select().eq('user_id', userId).single();

    return UserModel.fromMap(response);
  }
}
