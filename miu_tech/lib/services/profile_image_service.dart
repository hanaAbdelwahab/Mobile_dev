import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<String> uploadProfileImage(File file, String userId) async {
  final filePath = '$userId/avatar.jpg';

  await supabase.storage
      .from('profile-images')
      .upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

  await supabase.from('profiles').update({
    'avatar_path': filePath,
  }).eq('id', userId);

  return supabase.storage
      .from('profile-images')
      .getPublicUrl(filePath);
}
