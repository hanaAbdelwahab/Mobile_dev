import 'package:flutter/material.dart';
import '../../models/user_stories.dart';
import 'story_player.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserStories> users;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.users,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialUserIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextUser() {
    if (_pageController.page!.toInt() < widget.users.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousUser() {
    if (_pageController.page!.toInt() > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // 🟢 WRAP WITH DISMISSIBLE
      body: Dismissible(
        key: const Key('story_viewer_dismiss'), // Unique key required
        direction: DismissDirection.down, // Only allow swiping down
        onDismissed: (_) {
          Navigator.of(context).pop(); // Close screen when swiped
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.users.length,
          itemBuilder: (context, index) {
            return StoryPlayer(
              userStories: widget.users[index],
              onFinished: _nextUser,
              onBack: _previousUser,
            );
          },
        ),
      ),
    );
  }
}