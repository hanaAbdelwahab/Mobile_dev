import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewersSheet extends StatefulWidget {
  final int storyId;
  final int currentUserId;
  final ValueChanged<int>? onViewersCountUpdated;

  const ViewersSheet({
    super.key,
    required this.storyId,
    required this.currentUserId,
    this.onViewersCountUpdated,
  });

  @override
  State<ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<ViewersSheet> {
  List<Map<String, dynamic>>? _viewers;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchViewers();
  }

  Future<void> _fetchViewers() async {
    try {
      // 1. Fetch latest viewer IDs from DB for this story
      final viewsData = await Supabase.instance.client
          .from('story_views')
          .select('viewer_id')
          .eq('story_id', widget.storyId);

      final List<int> viewerIds = List<int>.from(
        (viewsData as List).map((e) => e['viewer_id']),
      );

      // Filter out self
      viewerIds.removeWhere((id) => id == widget.currentUserId);

      // Notify parent about updated count
      if (widget.onViewersCountUpdated != null) {
        widget.onViewersCountUpdated!(viewerIds.length);
      }

      if (viewerIds.isEmpty) {
        if (mounted) {
          setState(() {
            _viewers = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fetch user details
      final usersData = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('user_id', viewerIds);

      if (mounted) {
        setState(() {
          _viewers = List<Map<String, dynamic>>.from(usersData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching viewers: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        // 🟢 FIX: Wrap everything in a Container with a color
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E), // Dark background color
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Text(
                "Viewers (${_viewers?.length ?? 0})",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Divider(color: Colors.white24),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _viewers == null || _viewers!.isEmpty
                    ? const Center(
                        child: Text(
                          "No views yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: _viewers!.length,
                        itemBuilder: (_, i) {
                          final p = _viewers![i];
                          final img = p['profile_image'];
                          final hasImg =
                              img != null && img.toString().isNotEmpty;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              backgroundImage: hasImg
                                  ? NetworkImage(img)
                                  : null,
                              child: !hasImg
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              p['name'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
