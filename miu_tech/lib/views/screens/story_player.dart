import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../controllers/stories_controller.dart';
import '../../models/user_stories.dart';
import '../../models/story.dart';
import '../widgets/story_header.dart';
import '../widgets/story_progress_bar.dart';
import '../widgets/viewers_button.dart';
import '../widgets/viewers_sheet.dart';
import '../widgets/story_image.dart';

class StoryPlayer extends ConsumerStatefulWidget {
  final UserStories userStories;
  final VoidCallback onFinished;
  final VoidCallback onBack;

  const StoryPlayer({
    super.key,
    required this.userStories,
    required this.onFinished,
    required this.onBack,
  });

  @override
  ConsumerState<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends ConsumerState<StoryPlayer>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  VideoPlayerController? _videoController;

  // 🟢 PRELOADING STATE
  VideoPlayerController? _nextVideoController;
  int? _preloadedIndex;

  // New map to store updated viewer counts for each story index
  final Map<int, int> _updatedViewerCounts = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
    _loadStory(animate: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoController?.dispose();
    _nextVideoController?.dispose(); // Dispose preloaded
    super.dispose();
  }

  Story get _currentStory => widget.userStories.stories[_currentIndex];

  Future<void> _preloadNextStory() async {
    final nextIndex = _currentIndex + 1;
    // Only preload if there is a next story
    if (nextIndex >= widget.userStories.stories.length) return;

    final nextStory = widget.userStories.stories[nextIndex];

    // Only preload videos
    if (nextStory.mediaType != MediaType.video) return;

    // If already preloaded, skip
    if (_preloadedIndex == nextIndex && _nextVideoController != null) return;

    // Dispose old preload if any
    _nextVideoController?.dispose();
    _nextVideoController = null;
    _preloadedIndex = null;

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(nextStory.mediaUrl),
      );
      await controller.initialize();
      _nextVideoController = controller;
      _preloadedIndex = nextIndex;
      debugPrint("Preloaded video for story index: $nextIndex");
    } catch (e) {
      debugPrint("Error preloading video: $e");
    }
  }

  void _loadStory({bool animate = true}) async {
    _animController.stop();
    _animController.reset();

    // 🟢 CHECK PRELOAD
    VideoPlayerController? promotedController;
    if (_preloadedIndex == _currentIndex && _nextVideoController != null) {
      promotedController = _nextVideoController;
      _nextVideoController = null;
      _preloadedIndex = null;
      debugPrint("Using preloaded video for index: $_currentIndex");
    }

    _videoController?.dispose();
    _videoController = null;

    // 🟢 FIX: Delay state modification to avoid build-phase errors
    Future.microtask(() {
      if (mounted) {
        ref.read(storiesProvider.notifier).markStoryAsSeen(_currentStory.id);
      }
    });

    if (animate) {
      if (_currentStory.mediaType == MediaType.video) {
        // 🟢 VIDEO LOGIC
        if (promotedController != null) {
          // USE PRELOADED CONTROLLER
          _videoController = promotedController;
          _animController.duration = _videoController!.value.duration;
          await _videoController!.play();
          _animController.forward().whenComplete(() {
            if (mounted) _onTapNext();
          });
          if (mounted) setState(() {});
        } else {
          // LOAD NORMALLY
          final controller = VideoPlayerController.networkUrl(
            Uri.parse(_currentStory.mediaUrl),
          );
          _videoController = controller;

          try {
            await controller.initialize();

            // Check if this controller is still the active one
            if (_videoController != controller) {
              return;
            }

            // Set animation duration to video duration
            _animController.duration = controller.value.duration;
            await controller.play();
            _animController.forward().whenComplete(() {
              if (mounted) _onTapNext();
            });
          } catch (e) {
            debugPrint("Error loading video: $e");
            if (mounted) _onTapNext(); // Skip if error
          }

          if (mounted) setState(() {});
        }
      } else {
        // 🟢 IMAGE LOGIC
        _animController.duration = const Duration(seconds: 5);
        // Animation started by StoryImage callback
        if (mounted) setState(() {});
      }

      // 🟢 TRIGGER PRELOAD FOR NEXT STORY
      _preloadNextStory();
    }
  }

  void _onTapNext() {
    if (!mounted) return;
    if (_currentIndex < widget.userStories.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory();
    } else {
      widget.onFinished();
    }
  }

  void _onTapPrevious() {
    if (!mounted) return;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory();
    } else {
      widget.onBack();
    }
  }

  void _showViewers() async {
    _animController.stop();
    _videoController?.pause();

    final currentUserId = ref.read(storiesProvider.notifier).currentUserId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      enableDrag: true,
      builder: (_) => ViewersSheet(
        storyId: _currentStory.id,
        currentUserId: currentUserId,
        onViewersCountUpdated: (count) {
          if (mounted) {
            setState(() {
              _updatedViewerCounts[_currentIndex] = count;
            });
          }
        },
      ),
    );

    _animController.forward();
    _videoController?.play();
  }

  Future<void> _onTapDelete() async {
    _animController.stop();
    _videoController?.pause();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Story?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storyId = widget.userStories.stories[_currentIndex].id;
        await ref.read(storiesProvider.notifier).deleteStory(storyId);

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
          _animController.forward();
          _videoController?.play();
        }
      }
    } else {
      _animController.forward();
      _videoController?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _currentStory;
    final currentUserId = ref.read(storiesProvider.notifier).currentUserId;
    final isMine = widget.userStories.user.userId == currentUserId;
    final isVideo = story.mediaType == MediaType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) {
          _animController.stop();
          _videoController?.pause();
        },
        onLongPressEnd: (_) {
          _animController.forward();
          _videoController?.play();
        },
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _onTapPrevious();
          } else {
            _onTapNext();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Media (Image or Video)
            if (isVideo &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else if (!isVideo)
              StoryImage(
                imageUrl: story.mediaUrl,
                onImageLoaded: () {
                  if (mounted &&
                      _animController.status == AnimationStatus.dismissed) {
                    _animController.forward().whenComplete(() {
                      if (mounted) _onTapNext();
                    });
                  }
                },
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 1.5 Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.15, 0.85, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Progress Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return StoryProgressBar(
                        itemCount: widget.userStories.stories.length,
                        currentIndex: _currentIndex,
                        progress: _animController.value,
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. Header
            StoryHeader(
              user: widget.userStories.user,
              storyDate: story.createdAt,
              onClose: () => Navigator.pop(context),
            ),

            // 4. Viewers Button
            if (isMine)
              ViewersButton(
                count:
                    _updatedViewerCounts[_currentIndex] ??
                    story.seenBy.where((id) => id != currentUserId).length,
                onTap: _showViewers,
              ),

            // 5. Delete Button
            if (isMine)
              Positioned(
                bottom: 24,
                right: 16,
                child: GestureDetector(
                  onTap: _onTapDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
