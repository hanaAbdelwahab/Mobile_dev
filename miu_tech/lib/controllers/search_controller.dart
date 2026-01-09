import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_result_model.dart';
import '../providers/supabase_provider.dart';

// State for search
class SearchState {
  final List<SearchResultModel> results;
  final bool isLoading;
  final String? error;

  SearchState({required this.results, this.isLoading = false, this.error});

  SearchState copyWith({
    List<SearchResultModel>? results,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Notifier for search
class SearchNotifier extends AutoDisposeAsyncNotifier<SearchState> {
  Timer? _debounceTimer;
  String _lastQuery = '';
  Map<String, dynamic> _filters = {};

  @override
  Future<SearchState> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return SearchState(results: []);
  }

  void updateQuery(String query) {
    _lastQuery = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void updateFilters(Map<String, dynamic> filters) {
    _filters = filters;
    _performSearch();
  }

  Future<void> _performSearch() async {
    // Check if we have any active filters
    final hasActiveFilters =
        (_filters['type'] != null && _filters['type'] != 'All') ||
        (_filters['location'] != null && _filters['location'] != 'All');

    // If no query and no active filters, clear results
    if (_lastQuery.isEmpty && !hasActiveFilters) {
      state = AsyncData(SearchState(results: []));
      return;
    }

    state = const AsyncLoading();
    try {
      final repository = ref.read(searchRepositoryProvider);
      final results = await repository.search(_lastQuery, _filters);
      state = AsyncData(SearchState(results: results));
    } catch (e) {
      state = AsyncData(SearchState(results: [], error: e.toString()));
    }
  }
}

final searchProvider =
    AsyncNotifierProvider.autoDispose<SearchNotifier, SearchState>(() {
      return SearchNotifier();
    });
