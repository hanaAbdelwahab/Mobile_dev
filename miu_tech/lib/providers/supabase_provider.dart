import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/search_result_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';


// Provider for Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SearchRepository(client);
});

class SearchRepository {
  final SupabaseClient client;
  SearchRepository(this.client);

  PostModel _mapPost(Map<String, dynamic> data) {
    if (data['media_url'] != null &&
        data['media_url'].toString().trim().isNotEmpty) {
      final url = data['media_url'].toString();
      if (!url.startsWith('http')) {
        data['media_url'] =
            client.storage.from('Posts').getPublicUrl(url);
      }
    }
    return PostModel.fromMap(data);
  }

  UserModel _mapUser(Map<String, dynamic> data) {
    if (data['profile_image'] != null &&
        data['profile_image'].toString().trim().isNotEmpty) {
      final url = data['profile_image'].toString();
      if (!url.startsWith('http')) {
        data['profile_image'] =
            client.storage.from('profile-images').getPublicUrl(url);
      }
    }
    return UserModel.fromMap(data);
  }

  int _categoryNameToId(String name) {
    switch (name) {
      case "Internships":
        return 11;
      case "Events":
        return 12;
      case "Competitions":
        return 13;
      case "Announcements":
        return 14;
      case "Jobs":
        return 15;
      case "Courses":
        return 16;
      case "News":
        return 17;
      case "Projects":
        return 18;
      default:
        return 0; // ALL
    }
  }

  Future<List<PostModel>> getTrendingPosts() async {
    final response = await client
        .from('posts')
        .select()
        .eq('category_id', 18) // Filter for Projects
        .order('created_at', ascending: false)
        .limit(5);
    return (response as List).map((e) => _mapPost(e)).toList();
  }

  Future<List<PostModel>> getRecommendedPosts() async {
    final response = await client
        .from('posts')
        .select()
        .order('created_at', ascending: false)
        .limit(10);
    return (response as List).map((e) => _mapPost(e)).toList();
  }

  Future<List<SearchResultModel>> search(
    String query,
    Map<String, dynamic> filters,
  ) async {
    final results = <SearchResultModel>[];
    final addedIds = <String>{}; // Track added IDs to prevent duplicates

    // This 'type' comes from the UI filter (e.g. "Internships", "Users")
    // It is NOT the same as the 'type' column in the database.
    final filterCategory = filters['type'] as String? ?? 'All';
    final location = filters['location'] as String? ?? 'All';
    final sort = filters['sort'] as String? ?? 'Relevance';

    // Search users
    if (filterCategory == 'All' || filterCategory == 'Users') {
      var userQuery = client.from('users').select('''
  user_id,
  name,
  email,
  role,
  profile_image,
  department,
  bio,
  created_at,
  location
''');

      if (location != 'All') {
        userQuery = userQuery.eq('location', location);
      }
      dynamic userQueryBuilder = userQuery.ilike('name', '%$query%');
      if (sort == 'Date') {
        userQueryBuilder = userQueryBuilder.order(
          'created_at',
          ascending: false,
        );
      }
      final usersResponse = await userQueryBuilder.limit(10);
      for (var user in usersResponse) {
        final userId = user['user_id'].toString();
        if (addedIds.add('user_$userId')) {
          results.add(
            SearchResultModel(
              type: SearchResultType.user,
              data: _mapUser(user),
            ),
          );
        }
      }
    }

    // Search posts
    // We convert the UI string (e.g. "Internships") to a database ID (e.g. 11)
    if (filterCategory == 'All' || _categoryNameToId(filterCategory) != 0) {
      // 1. Search by Title
      var postQuery = client.from('posts').select();
      if (filterCategory != 'All') {
        int categoryId = _categoryNameToId(filterCategory);
        if (categoryId != 0) {
          postQuery = postQuery.eq('category_id', categoryId);
        }
      }
      dynamic postQueryBuilder = postQuery.ilike('title', '%$query%');
      if (sort == 'Date') {
        postQueryBuilder = postQueryBuilder.order(
          'created_at',
          ascending: false,
        );
      }
      final postsResponse = await postQueryBuilder.limit(10);
      for (var post in postsResponse) {
        final postId = post['post_id'].toString();
        if (addedIds.add('post_$postId')) {
          results.add(
            SearchResultModel(
              type: SearchResultType.post,
              data: _mapPost(post),
            ),
          );
        }
      }

      // 2. Search by Tags
      // This is a 3-step process:
      // A. Find Tag IDs where name matches query
      // B. Find Post IDs associated with those Tag IDs
      // C. Fetch the actual Posts using those Post IDs
      try {
        // A. Find tags matching the query
        final tagsResponse = await client
            .from('tags')
            .select('tag_id')
            .ilike('tag_name', '%$query%')
            .limit(5);

        final tagIds = (tagsResponse as List)
            .map((e) => e['tag_id'].toString())
            .toList();

        if (tagIds.isNotEmpty) {
          // B. Find posts associated with these tags
          // We limit this to 50 to prevent fetching too many IDs if a tag is very popular
          final postTagsResponse = await client
              .from('post_tags')
              .select('post_id')
              .filter('tag_id', 'in', '(${tagIds.join(',')})')
              .limit(50);

          final postIds = (postTagsResponse as List)
              .map((e) => e['post_id'].toString())
              .toSet() // Deduplicate post IDs from multiple tags
              .toList();

          if (postIds.isNotEmpty) {
            // C. Fetch the actual Posts
            dynamic tagPostQuery = client
                .from('posts')
                .select()
                .filter('post_id', 'in', '(${postIds.join(',')})');

            // Apply category filter
            if (filterCategory != 'All') {
              int categoryId = _categoryNameToId(filterCategory);
              if (categoryId != 0) {
                tagPostQuery = tagPostQuery.eq('category_id', categoryId);
              }
            }

            if (sort == 'Date') {
              tagPostQuery = tagPostQuery.order('created_at', ascending: false);
            }

            final tagPostsResponse = await tagPostQuery.limit(10);

            for (var post in tagPostsResponse) {
              final postId = post['post_id'].toString();
              if (addedIds.add('post_$postId')) {
                results.add(
                  SearchResultModel(
                    type: SearchResultType.post,
                    data: _mapPost(post),
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        // Ignore tag search errors (e.g. if tables don't exist yet)
        print('Tag search error: $e');
      }
    }

    // Add more for projects, opportunities, etc. if tables exist

    return results;
  }
}
