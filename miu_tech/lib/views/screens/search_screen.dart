import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/search_controller.dart';
import '../../providers/supabase_provider.dart';
import '../../models/search_result_model.dart';
import '../../models/post_model.dart';
import '../widgets/result_card.dart';
import '../widgets/post_grid_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedType = 'All';
  String selectedLocation = 'All';
  String selectedSort = 'Relevance';

  final List<String> typeOptions = [
    'All',
    'Users',
    'Internships',
    'Events',
    'Competitions',
    'Announcements',
    'Jobs',
    'Courses',
    'News',
    'Projects',
  ];
  final List<String> locationOptions = [
    'All',
    'New York',
    'California',
    'Texas',
    'Florida',
  ];
  final List<String> sortOptions = ['Relevance', 'Date'];

  final Map<String, IconData> exploreCategories = {
    'Internships': Icons.work_outline,
    'Projects': Icons.code,
    'Events': Icons.calendar_today,
    'Competitions': Icons.emoji_events_outlined,
    'Jobs': Icons.business_center_outlined,
    'Courses': Icons.school_outlined,
    'Announcements': Icons.campaign_outlined,
    'News': Icons.article_outlined,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilters() {
    ref.read(searchProvider.notifier).updateFilters({
      'type': selectedType,
      'location': selectedLocation,
      'sort': selectedSort,
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final isSearching =
        _searchController.text.isNotEmpty ||
        selectedType != 'All' ||
        selectedLocation != 'All';

    return Scaffold(
      appBar: AppBar(title: const Text('Search & Explore')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for users, posts, projects...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchProvider.notifier).updateQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
            ),
            onChanged: (value) {
              setState(() {}); // Rebuild to show/hide clear button
              ref.read(searchProvider.notifier).updateQuery(value);
            },
          ),
          const SizedBox(height: 16.0),
          if (isSearching) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    selectedType = 'All';
                    selectedLocation = 'All';
                    selectedSort = 'Relevance';
                  });
                  ref.read(searchProvider.notifier).updateQuery('');
                  _updateFilters();
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to Explore'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            ExpansionTile(
              title: const Text('Filters'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Type:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8.0,
                        children: typeOptions.map((type) {
                          return ChoiceChip(
                            label: Text(type),
                            selected: selectedType == type,
                            onSelected: (selected) {
                              setState(
                                () => selectedType = selected ? type : 'All',
                              );
                              _updateFilters();
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'Location:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: selectedLocation,
                        items: locationOptions
                            .map(
                              (loc) => DropdownMenuItem(
                                value: loc,
                                child: Text(loc),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedLocation = value!);
                          _updateFilters();
                        },
                      ),
                      const SizedBox(height: 8.0),
                      const Text(
                        'Sort by:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: selectedSort,
                        items: sortOptions
                            .map(
                              (sort) => DropdownMenuItem(
                                value: sort,
                                child: Text(sort),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedSort = value!);
                          _updateFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ...searchState.when(
              data: (state) {
                // Extract all posts
                final allPosts = state.results.where((r) {
                  return r.type == SearchResultType.post;
                }).toList();

                // Other results (e.g. users)
                final otherResults = state.results.where((r) {
                  return r.type != SearchResultType.post;
                }).toList();

                final widgets = <Widget>[];

                // Show posts grid first if any
                if (allPosts.isNotEmpty) {
                  widgets.add(
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: allPosts.length,
                      itemBuilder: (context, index) {
                        final post = allPosts[index].data as PostModel;
                        return PostGridItem(post: post);
                      },
                    ),
                  );
                  widgets.add(const SizedBox(height: 16));
                }

                // Then show other results as a list
                if (otherResults.isNotEmpty) {
                  widgets.addAll(
                    otherResults.map((result) => ResultCard(result: result)),
                  );
                }

                if (widgets.isEmpty) {
                  widgets.add(const Center(child: Text('No results found')));
                }

                return widgets;
              },
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (error, stack) => [Center(child: Text('Error: $error'))],
            ),
          ] else ...[
            _buildExploreSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildExploreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Browse Categories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 45,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: exploreCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = exploreCategories.keys.elementAt(index);
              final icon = exploreCategories.values.elementAt(index);
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedType = category;
                  });
                  _updateFilters();
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 32),
      ],
    );
  }
}