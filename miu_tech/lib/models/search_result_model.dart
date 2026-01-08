
import 'post_model.dart';
import 'user_model.dart';

enum SearchResultType { user, post }

class SearchResultModel {
  final SearchResultType type;
  final Object data; // Changed from Map<String, dynamic> to Object

  SearchResultModel({
    required this.type,
    required this.data,
  });

  // Helper getters for type-safe access
  UserModel? get asUser => type == SearchResultType.user ? data as UserModel : null;
  PostModel? get asPost => type == SearchResultType.post ? data as PostModel : null;

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final String rawType = json['result_type'] ?? json['type'];

    return SearchResultModel(
      type: rawType == 'user'
          ? SearchResultType.user
          : SearchResultType.post,
      data: json,
    );
  }
}