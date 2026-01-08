import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';

final supabase = Supabase.instance.client;

class AnnouncementController {
  static Future<List<AnnouncementModel>> fetchAnnouncements({
    int? categoryId,
  }) async {
    var query = supabase.from('announcement').select();

    if (categoryId != null && categoryId != 0) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query.order('created_at', ascending: false);

    return (data as List)
        .map((e) => AnnouncementModel.fromMap(e))
        .toList();
  }
}
