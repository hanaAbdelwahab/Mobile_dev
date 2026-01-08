import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result_model.dart';
import '../providers/search_repository_provider.dart';

// =======================
// Search Notifier (Riverpod 3.x)
// =======================
class SearchNotifier
    extends StateNotifier<AsyncValue<List<SearchResultModel>>> {
  SearchNotifier(this.ref) : super(const AsyncValue.data([]));

  final Ref ref;

  Timer? _debounceTimer;
  String _lastQuery = '';
  Map<String, dynamic> _filters = {};

  void updateQuery(String query) {
    _lastQuery = query;
    _debounceTimer?.cancel();

    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      _performSearch,
    );
  }

  void updateFilters(Map<String, dynamic> filters) {
    _filters = filters;
    _performSearch();
  }

  Future<void> _performSearch() async {
    final hasActiveFilters =
        (_filters['type'] != null && _filters['type'] != 'All') ||
        (_filters['location'] != null && _filters['location'] != 'All');

    if (_lastQuery.isEmpty && !hasActiveFilters) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final repository = ref.read(searchRepositoryProvider);
      final results = await repository.search(_lastQuery, _filters);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// =======================
// Provider (autoDispose هنا)
// =======================
final searchProvider =
    StateNotifierProvider.autoDispose<
        SearchNotifier,
        AsyncValue<List<SearchResultModel>>>(
  (ref) => SearchNotifier(ref),
);

