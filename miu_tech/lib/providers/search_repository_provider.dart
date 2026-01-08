import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/search_result_model.dart';

// =======================
// Search Repository
// =======================
class SearchRepository {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<SearchResultModel>> search(
    String query,
    Map<String, dynamic> filters,
  ) async {
    var request = supabase.from('search_view').select();

    if (query.isNotEmpty) {
      request = request.ilike('title', '%$query%');
    }

    if (filters['type'] != null && filters['type'] != 'All') {
      request = request.eq('type', filters['type']);
    }

    if (filters['location'] != null && filters['location'] != 'All') {
      request = request.eq('location', filters['location']);
    }

    final response = await request;

    return (response as List)
        .map((e) => SearchResultModel.fromJson(e))
        .toList();
  }
}

// =======================
// Repository Provider
// =======================
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository();
});
