import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/StoryProvider.dart';

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final int currentUserId; // 👈 لازم يجي من بره

  const StoryViewerPage({
    super.key,
    required this.stories,
    required this.currentUserId,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with TickerProviderStateMixin {

  late PageController _pageController;
  late AnimationController _progressController;

  int currentIndex = 0;

@override
void initState() {
  super.initState();

  currentIndex = widget.initialIndex;

  _pageController = PageController();

  _progressController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(currentIndex);
    }
    _progressController.forward();
    _markStoryAsSeen(widget.stories[currentIndex]['id']);
  });
}

  // =========================
  // تسجيل إن الستوري اتشافت
  // =========================
  Future<void> _markStoryAsSeen(int storyId) async {
  final supabase = Supabase.instance.client;

  try {
    await supabase.from('story_views').insert({
      'story_id': storyId,
      'viewer_id': widget.currentUserId,
    });
  } catch (e) {
    // already seen
  }

  // ✅ قولي للـ Provider
  if (mounted) {
    context.read<StoryProvider>().markStorySeen(storyId);
  }
}

  // =========================
  // التنقل
  // =========================
  void _nextStory() {
    if (!mounted) return;

    if (currentIndex < widget.stories.length - 1) {
      setState(() {
        currentIndex++;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_pageController.hasClients) {
  _pageController.jumpToPage(currentIndex);
}

});

      _progressController.forward(from: 0);

      _markStoryAsSeen(widget.stories[currentIndex]['id']);
    } else {
      Navigator.pop(context, true); // خلصت stories الشخص ده
    }
  }

  void _prevStory() {
    if (!mounted) return;

    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });

      _pageController.jumpToPage(currentIndex);
      _progressController.forward(from: 0);

      _markStoryAsSeen(widget.stories[currentIndex]['id']);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final story = widget.stories[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ===== IMAGE =====
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 2) {
                _prevStory();
              } else {
                _nextStory();
              }
            },
            child: Image.network(
              story['story_image'],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // ===== TOP =====
          SafeArea(
            child: Column(
              children: [

                // ===== PROGRESS =====
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: List.generate(widget.stories.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (_, __) {
                              return LinearProgressIndicator(
                                value: index < currentIndex
                                    ? 1
                                    : index == currentIndex
                                        ? _progressController.value
                                        : 0,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.red),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ===== USER INFO =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: story['profile_image'] != null
                            ? NetworkImage(story['profile_image'])
                            : null,
                        child: story['profile_image'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story['user_name'] ?? "User",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _timeAgo(story['created_at']),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // TIME AGO
  // =========================
  String _timeAgo(dynamic date) {
    if (date == null) return "0 minutes ago";

    DateTime d;
    try {
      d = DateTime.parse(date.toString()).toLocal();
    } catch (_) {
      return "0 minutes ago";
    }

    final diff = DateTime.now().difference(d);

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} minutes ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} hours ago";
    } else {
      return "${diff.inDays} days ago";
    }
  }
}
