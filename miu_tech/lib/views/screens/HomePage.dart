import 'dart:ui';
import 'package:flutter/material.dart';
import '../../controllers/competition_request_controller.dart';
import '../../models/competition_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/posts_model.dart';
import '../../models/tag_model.dart';
import '../widgets/top_navbar.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/user_drawer_header.dart';
import '../widgets/category_chip.dart';
import 'stories_row.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/repost_provider.dart';
import '../../controllers/user_controller.dart';
import 'comments_page.dart';
import 'package:confetti/confetti.dart';
import '../../providers/StoryProvider.dart';
import '../../providers/SavedPostProvider.dart';
import '../../models/announcement_model.dart';
import '../widgets/announcement_card.dart';
import '../../controllers/announcement_controller.dart';
import '../widgets/competition_request_card.dart';
import '../../models/FreelanceProjectModel.dart';
import '../widgets/freelance_project_card.dart';
import 'OtherUserProfilePage.dart'; 
final supabase = Supabase.instance.client;
class FeedItem {
  final PostModel? post;
  final AnnouncementModel? announcement;
  final CompetitionRequestModel? request;
  final DateTime createdAt;
  final FeedType type;

  FeedItem.fromPost(this.post)
    : announcement = null,
      request = null,
      createdAt = post!.createdAt,
      type = FeedType.post;

  FeedItem.fromAnnouncement(this.announcement)
    : post = null,
      request = null,
      createdAt = announcement!.createdAt,
      type = FeedType.announcement;

  FeedItem.fromRequest(this.request)
    : post = null,
      announcement = null,
      createdAt = request!.createdAt,
      type = FeedType.request;
}

enum FeedType { post, announcement, request }

class HomePage extends StatefulWidget {
  final int currentUserId;

  const HomePage({super.key, required this.currentUserId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Cache comment counts
  final Map<int, int> _commentCounts = {};
  bool _isLoadingFeed = false;
  late final ScrollController _scrollController;

  // Category selection
  String _selectedCategory = "ALL";

  // For You toggle (false = Discover, true = For You)
  bool _showForYou = false;

// ADD THIS LINE HERE:
  bool _showFreelancingHub = false;

  // Cached posts future
  late Future<List<FeedItem>> _feedFuture;

  // Cache friend IDs for repost indicator
  List<int> _cachedFriendIds = [];

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _feedFuture = _fetchFeed();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoryProvider>().loadStories(
        currentUserId: widget.currentUserId,
        forYou: _showForYou,
      );

      context.read<SavedPostProvider>().loadSavedPosts(widget.currentUserId);
    });
  }

Future<void> _refreshFeed() async {
  setState(() {
    _feedFuture = _fetchFeed();
    _commentCounts.clear(); // Clear comment cache
  });
  
  // Reload stories
  context.read<StoryProvider>().loadStories(
    currentUserId: widget.currentUserId,
    forYou: _showForYou,
  );
  
  // Reload saved posts
  context.read<SavedPostProvider>().loadSavedPosts(widget.currentUserId);
}
  Future<List<AnnouncementModel>> _fetchAnnouncements() async {
    try {
      int? categoryId;

      if (_selectedCategory != "ALL" && _selectedCategory != "Announcements") {
        categoryId = _categoryNameToId(_selectedCategory);
      }

      return await AnnouncementController.fetchAnnouncements(
        categoryId: categoryId,
      );
    } catch (e) {
      debugPrint("❌ Error fetching announcements: $e");
      return [];
    }
  }

  Future<List<FeedItem>> _fetchFeed() async {
    if (_isLoadingFeed) return [];

    _isLoadingFeed = true;

    try {
      List<FeedItem> feedItems = [];

      final posts = await _fetchPosts();
      feedItems.addAll(posts.map((p) => FeedItem.fromPost(p)));

      final announcements = await _fetchAnnouncements();
      feedItems.addAll(announcements.map((a) => FeedItem.fromAnnouncement(a)));

      /*feedItems.addAll(requests.map((r) => FeedItem.fromRequest(r)));*/
      if (!_showForYou && _selectedCategory == "Competitions") {
  final requests = await CompetitionRequestController.fetchAllRequests();
  feedItems.addAll(requests.map((r) => FeedItem.fromRequest(r)));
}
if (_showForYou) {
  final friendIds = await _getFriendIds();

  if (friendIds.isNotEmpty) {
    final allRequests =
        await CompetitionRequestController.fetchAllRequests();

    final friendRequests = allRequests
        .where((r) => friendIds.contains(r.userId))
        .toList();

    feedItems.addAll(
      friendRequests.map((r) => FeedItem.fromRequest(r)),
    );
  }
}
      feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return feedItems;
    } catch (e) {
      debugPrint("❌ Error loading feed: $e");
      return [];
    } finally {
      _isLoadingFeed = false;
    }
  }

  Future<void> _loadLikesAndRepostsForPosts(List<FeedItem> items) async {
    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final repostProvider = Provider.of<RepostProvider>(
        context,
        listen: false,
      );

      final postIds = items
          .where((item) => item.type == FeedType.post)
          .map((item) => item.post!.postId)
          .toList();

      for (final id in postIds) {
        postProvider.loadPostLikes(id);
      }

      if (postIds.isNotEmpty) {
        await repostProvider.loadRepostsForPosts(postIds);
      }
    } catch (e) {
      debugPrint('Error loading likes and reposts: $e');
    }
  }

  Future<bool> _isFollowing(int targetUserId) async {
    final res = await supabase
        .from('friendships')
        .select()
        .eq('user_id', widget.currentUserId)
        .eq('friend_id', targetUserId)
        .eq('status', 'accepted')
        .maybeSingle();

    return res != null;
  }

  Future<void> _toggleFollow(int targetUserId, String userName) async {
    final existing = await supabase
        .from('friendships')
        .select('friendship_id')
        .eq('user_id', widget.currentUserId)
        .eq('friend_id', targetUserId)
        .maybeSingle();

    if (existing == null) {
      // FOLLOW
      await supabase.from('friendships').insert({
        'user_id': widget.currentUserId,
        'friend_id': targetUserId,
        'status': 'accepted',
      });

      // 🎉 SHOW CELEBRATION
      _confettiController.play();

      // 💬 POPUP MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You are now friends with $userName 🎉"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // UNFOLLOW
      await supabase
          .from('friendships')
          .delete()
          .eq('friendship_id', existing['friendship_id']);
    }

    setState(() {});
  }

  // Add this method to handle calendar event creation:
  // CATEGORY MAPPING (updated per your DB)
  // ================================================================
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
      default:
        return 0; // ALL
    }
  }

  // ===========================================================
  // FRIENDSHIP CHECK
  // ===========================================================
  Future<bool> _areFriends(int user1, int user2) async {
    try {
      final result = await supabase
          .from('friendships')
          .select()
          .or(
            'and(user_id.eq.$user1,friend_id.eq.$user2),and(user_id.eq.$user2,friend_id.eq.$user1)',
          )
          .maybeSingle();
      if (result == null) return false;
      return result['status'] == 'accepted';
    } catch (e) {
      debugPrint("Error checking friendship: $e");
      return false;
    }
  }
List<FreelanceProjectModel> _getHardcodedProjects() {
  return [
    FreelanceProjectModel(
      projectId: 1,
      title: "Mobile App UI/UX Designer Needed",
      companyName: "TechStart Inc.",
      companyLogo: "https://via.placeholder.com/100",
      postedAt: DateTime.now().subtract(const Duration(hours: 2)),
      description: "We're looking for a talented UI/UX designer to redesign our mobile app. Must have experience with modern design principles and mobile-first approach.",
      skillsNeeded: ["Figma", "UI/UX", "Mobile Design", "Prototyping"],
      duration: "2-3 months",
      deadline: DateTime.now().add(const Duration(days: 15)),
      budgetRange: "\$3000-\$5000",
      keyResponsibilities: "• Create wireframes and prototypes\n• Design user interface\n• Conduct user research\n• Collaborate with development team",
    ),
    FreelanceProjectModel(
      projectId: 2,
      title: "Flutter Developer for E-commerce App",
      companyName: "ShopHub",
      companyLogo: "https://via.placeholder.com/100",
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      description: "Seeking experienced Flutter developer to build a cross-platform e-commerce application with payment integration.",
      skillsNeeded: ["Flutter", "Dart", "Firebase", "REST API"],
      duration: "3-4 months",
      deadline: DateTime.now().add(const Duration(days: 20)),
      budgetRange: "\$5000-\$8000",
      keyResponsibilities: "• Develop mobile app using Flutter\n• Integrate payment gateways\n• Implement real-time features\n• Write clean, maintainable code",
    ),
    FreelanceProjectModel(
      projectId: 3,
      title: "Social Media Content Creator",
      companyName: "Digital Marketing Co.",
      companyLogo: "https://via.placeholder.com/100",
      postedAt: DateTime.now().subtract(const Duration(days: 3)),
      description: "Need creative content creator for managing social media accounts and creating engaging posts.",
      skillsNeeded: ["Content Writing", "Social Media", "Canva", "Photography"],
      duration: "1 month",
      deadline: DateTime.now().add(const Duration(days: 10)),
      budgetRange: "\$1000-\$2000",
      keyResponsibilities: "• Create daily social media posts\n• Design graphics\n• Engage with audience\n• Track analytics",
    ),
    FreelanceProjectModel(
      projectId: 4,
      title: "Full Stack Web Developer",
      companyName: "WebSolutions Ltd.",
      companyLogo: "https://via.placeholder.com/100",
      postedAt: DateTime.now().subtract(const Duration(hours: 12)),
      description: "Looking for full stack developer to build a modern web application with React and Node.js.",
      skillsNeeded: ["React", "Node.js", "MongoDB", "TypeScript"],
      duration: "4-6 months",
      deadline: DateTime.now().add(const Duration(days: 25)),
      budgetRange: "\$8000-\$12000",
      keyResponsibilities: "• Build responsive web application\n• Design database schema\n• Implement authentication\n• Deploy and maintain application",
    ),
  ];
}
Widget _buildStatCard(String number, String label) {
  return Column(
    children: [
      Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 11,
        ),
      ),
    ],
  );
}
  // ========================= BUILD =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: _showFreelancingHub 
        ? const Color(0xFFFFF5F5)  // Very light red/pink tint
        : const Color(0xffF5F7FA),  // Original light grey
      endDrawer: UserDrawerContent(userId: widget.currentUserId),

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: TopNavbar(userId: widget.currentUserId),
      ),

      body: Stack(
        children: [
          RefreshIndicator(
      onRefresh: _refreshFeed,
      color: const Color(0xFFE63946),
      displacement: 40,
      strokeWidth: 3.0,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(10),
        physics: const AlwaysScrollableScrollPhysics(), // ADD THIS LINE
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= DISCOVER HEADER =================
Padding(
  padding: const EdgeInsets.only(left: 4, bottom: 10),
  child: Row(
    children: [
      GestureDetector(
        onTap: () {
          setState(() {
            _showForYou = false;
            _showFreelancingHub = false;
            _feedFuture = _fetchFeed();
          });
        },
        child: Text(
          "Discover ",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: (!_showForYou && !_showFreelancingHub) ? Colors.black : Colors.grey,
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () {
          setState(() {
            _showForYou = true;
            _showFreelancingHub = false;
            _feedFuture = _fetchFeed();
          });
        },
        child: Text(
          "For You",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: _showForYou ? Colors.black : Colors.grey,
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () {
          setState(() {
            _showFreelancingHub = true;
            _showForYou = false;
          });
        },
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: _showFreelancingHub
                ? [Colors.red.shade700, Colors.red.shade400]
                : [Colors.red.shade200, Colors.red.shade100],
          ).createShader(bounds),
          child: Text(
            "Freelancing Hub",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  ),
),

                // ================= CREATE POST BAR =================
                FutureBuilder<Map<String, dynamic>?>(
                  future: UserController.fetchUserData(widget.currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _loadingCreatePostBar();
                    }

                    final data = snapshot.data;
                    final name =
                        (data != null &&
                            (data['name'] ?? "").toString().trim().isNotEmpty)
                        ? data['name']
                        : "User";
                    final imageUrl = data != null
                        ? data['profile_image']
                        : null;

                    return _createPostBar(name, imageUrl);
                  },
                ),

                const SizedBox(height: 8),
   
const SizedBox(height: 20),

// ================= CONDITIONAL CONTENT =================
if (_showFreelancingHub) ...[
  // GRADIENT BANNER FOR FREELANCING HUB
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.red.shade400,
          Colors.red.shade600,
          Colors.red.shade800,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.work_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Find Your Next Project",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Browse opportunities from top companies",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatCard("24", "Active Projects"),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatCard("150+", "Companies"),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            _buildStatCard("500+", "Freelancers"),
          ],
        ),
      ],
    ),
  ),
  
  const SizedBox(height: 20),
  
  // FREELANCING HUB PROJECTS
  ..._getHardcodedProjects().map((project) {
    return FreelanceProjectCard(project: project);
  }).toList(),
] else ...[
  // CATEGORIES (Only show in Discover/For You)
  SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      children: [
        CategoryChip(
          text: "ALL",
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "ALL";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Internships",
          icon: Icons.school,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Internships";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Competitions",
          icon: Icons.emoji_events,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Competitions";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Courses",
          icon: Icons.menu_book,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Courses";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "News",
          icon: Icons.article,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "News";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Events",
          icon: Icons.event,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Events";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Jobs",
          icon: Icons.work,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Jobs";
              _feedFuture = _fetchFeed();
            });
          },
        ),
        CategoryChip(
          text: "Announcements",
          icon: Icons.campaign,
          selectedCategory: _selectedCategory,
          onTap: () {
            setState(() {
              _selectedCategory = "Announcements";
              _feedFuture = _fetchFeed();
            });
          },
        ),
      ],
    ),
  ),
  
  const SizedBox(height: 20),
  
const StoriesRow(),
  const SizedBox(height: 10),
  Divider(color: Colors.grey.shade300),

  // POSTS
  FutureBuilder<List<FeedItem>>(
    future: _feedFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Center(child: Text("No content available")),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLikesAndRepostsForPosts(snapshot.data!);
      });

      return Column(
        children: snapshot.data!.map((item) {
          switch (item.type) {
            case FeedType.post:
              return _feedCard(item.post!);

            case FeedType.announcement:
              return AnnouncementCard(
                announcement: item.announcement!,
                currentUserId: widget.currentUserId,
              );

            case FeedType.request:
              return CompetitionRequestCard(
                request: item.request!,
                currentUserId: widget.currentUserId,
              );
          }
        }).toList(),
      );
    },
  ),
],              ],
            ),
          ),
           ), // ================= CONFETTI =================
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.orange,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavbar(
        currentUserId: widget.currentUserId,
        currentIndex: 0, // Home page is index 0
      ),
    );
  }

  // ===========================================================================
  // FETCH TAGS FOR A POST
  // ===========================================================================
  Future<List<TagModel>> _fetchTags(int postId) async {
    try {
      final data = await supabase
          .from('tags')
          .select('tag_id, tag_name, post_id')
          .eq('post_id', postId);

      final list = data as List<dynamic>;
      return list
          .map((t) => TagModel.fromMap(t as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching tags for post $postId: $e");
      return [];
    }
  }

  // ===========================================================================
  // FETCH POSTS (NEWEST FIRST) with category and For You filtering
  // ===========================================================================
  Future<List<PostModel>> _fetchPosts() async {
    try {
      // If For You: gather friend ids (exclude current user)
      List<int> friendIds = [];
      if (_showForYou) {
        // 1️⃣ friends ids
        final friendsResult = await supabase
            .from('friendships')
            .select('user_id, friend_id, status')
            .or(
              'and(user_id.eq.${widget.currentUserId},status.eq.accepted),'
              'and(friend_id.eq.${widget.currentUserId},status.eq.accepted)',
            );

        for (final f in friendsResult as List) {
          if (f['user_id'] != widget.currentUserId) friendIds.add(f['user_id']);
          if (f['friend_id'] != widget.currentUserId)
            friendIds.add(f['friend_id']);
        }

        // Cache the friend IDs for repost indicator
        _cachedFriendIds = friendIds;

        if (friendIds.isEmpty) return [];

        // 2️⃣ reposted posts by friends
        final reposts = await supabase
            .from('reposts')
            .select('post_id, user_id')
            .filter('user_id', 'in', '(${friendIds.join(',')})');

        final repostedPostIds = reposts
            .map<int>((r) => r['post_id'] as int)
            .toList();

        // 3️⃣ fetch posts (friends posts OR reposted posts)
        if (_selectedCategory != "ALL") {
          final categoryId = _categoryNameToId(_selectedCategory);

          if (repostedPostIds.isEmpty) {
            final data = await supabase
                .from('posts')
                .select('*')
                .filter('author_id', 'in', '(${friendIds.join(',')})')
                .eq('category_id', categoryId)
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          } else {
            final data = await supabase
                .from('posts')
                .select('*')
                .or(
                  'author_id.in.(${friendIds.join(',')}),'
                  'post_id.in.(${repostedPostIds.join(',')})',
                )
                .eq('category_id', categoryId)
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          }
        } else {
          // ALL categories
          if (repostedPostIds.isEmpty) {
            final data = await supabase
                .from('posts')
                .select('*')
                .filter('author_id', 'in', '(${friendIds.join(',')})')
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          } else {
            final data = await supabase
                .from('posts')
                .select('*')
                .or(
                  'author_id.in.(${friendIds.join(',')}),'
                  'post_id.in.(${repostedPostIds.join(',')})',
                )
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          }
        }
      } else {
        // Discover mode
        _cachedFriendIds = []; // Clear cached friend IDs

        if (_selectedCategory != "ALL") {
          // ✅ Return empty list if "Announcements" is selected (show only announcements, no posts)
          if (_selectedCategory == "Announcements") {
            return [];
          }

          final categoryId = _categoryNameToId(_selectedCategory);
          final data = await supabase
              .from('posts')
              .select('*')
              .eq('category_id', categoryId)
              .order('created_at', ascending: false);

          final listData = data as List<dynamic>;
          return listData
              .map<PostModel>(
                (p) => PostModel.fromMap(p as Map<String, dynamic>),
              )
              .toList();
        } else {
          // Discover + ALL
          final data = await supabase
              .from('posts')
              .select('*')
              .order('created_at', ascending: false);

          final listData = data as List<dynamic>;
          return listData
              .map<PostModel>(
                (p) => PostModel.fromMap(p as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading posts: $e");
      return [];
    }
  }

Future<List<int>> _getFriendIds() async {
  final res = await supabase
      .from('friendships')
      .select('user_id, friend_id, status')
      .or(
        'and(user_id.eq.${widget.currentUserId},status.eq.accepted),'
        'and(friend_id.eq.${widget.currentUserId},status.eq.accepted)',
      );

  List<int> ids = [];
  for (final f in res as List) {
    if (f['user_id'] != widget.currentUserId) {
      ids.add(f['user_id']);
    }
    if (f['friend_id'] != widget.currentUserId) {
      ids.add(f['friend_id']);
    }
  }
  return ids;
}

  Future<void> _ensureCommentCount(int postId) async {
    if (_commentCounts.containsKey(postId)) return;

    try {
      final comments = await supabase
          .from('comments')
          .select()
          .eq('post_id', postId);
      final count = (comments as List).length;

      setStateIfMounted(() {
        _commentCounts[postId] = count;
      });
    } catch (e) {
      debugPrint("Error fetching comment count for post $postId: $e");
      setStateIfMounted(() {
        _commentCounts.putIfAbsent(postId, () => 0);
      });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

Widget _feedCard(PostModel post) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: UserController.fetchUserData(post.authorId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final user = snapshot.data!;
      final userName = user["name"] ?? "User";
      final avatar = user["profile_image"];
      final userRole = user["role"];
      final userDept = user["department"];

      return FutureBuilder<bool>(
        future: _areFriends(widget.currentUserId, post.authorId),
        builder: (context, friendSnapshot) {
          final isFriend = friendSnapshot.data ?? false;

          if (!_commentCounts.containsKey(post.postId)) {
            _ensureCommentCount(post.postId);
          }

          return StatefulBuilder(
            builder: (context, setCardState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REPOST INDICATOR (only in For You mode)
                  if (_showForYou && _cachedFriendIds.isNotEmpty)
                    Consumer<RepostProvider>(
                      builder: (context, repostProvider, _) {
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: repostProvider.getRepostedByFriends(
                            post.postId,
                            _cachedFriendIds,
                          ),
                          builder: (context, repostSnapshot) {
                            if (!repostSnapshot.hasData ||
                                repostSnapshot.data!.isEmpty) {
                              return const SizedBox();
                            }

                            final friends = repostSnapshot.data!;
                            final names = friends
                                .take(3)
                                .map((f) => f['name'])
                                .where((n) => n != null)
                                .join(', ');
                            final othersCount = friends.length > 3
                                ? friends.length - 3
                                : 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8, left: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.repeat,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    othersCount > 0
                                        ? "$names and $othersCount others reposted this"
                                        : "$names reposted this",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                  // POST CARD - Using Profile Page Design
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // USER INFO HEADER
                          Row(
                            children: [
                              Expanded(
      child: GestureDetector(
        onTap: () {
          // Navigate to user profile
          if (post.authorId != widget.currentUserId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(
                  userId: post.authorId.toString(),
                  currentUserId: widget.currentUserId.toString(),
                ),
              ),
            );
          }
          // If it's the current user, you might want to navigate to their own profile page
          // or show a message that they're viewing their own content
        },
        child: Row(
          children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                                    ? NetworkImage(avatar)
                                    : null,
                                child: (avatar == null || avatar.toString().isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (userRole != null)
                                          Text(
                                            userRole,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        if (userRole != null && userDept != null)
                                          Text(
                                            ' · ',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        if (userDept != null)
                                          Flexible(
                                            child: Text(
                                              userDept,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      timeAgo(post.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
                              // FOLLOW BUTTON
                              if (!isFriend && post.authorId != widget.currentUserId)
                                TextButton.icon(
                                  onPressed: () {
                                    _toggleFollow(post.authorId, userName);
                                  },
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text("Follow"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC143C),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              // SAVE ICON
                              Consumer<SavedPostProvider>(
                                builder: (context, savedProvider, _) {
                                  final isSaved = savedProvider.isSaved(post.postId);
                                  return IconButton(
                                    icon: Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      color: isSaved ? const Color(0xFFDC143C) : Colors.grey,
                                    ),
                                    onPressed: () {
                                      savedProvider.toggleSave(
                                        userId: widget.currentUserId,
                                        postId: post.postId,
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // POST TITLE (if exists)
                          if (post.content != null && post.content.isNotEmpty)
                            Text(
                              post.content,
                              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),

                          // TAGS
                          FutureBuilder<List<TagModel>>(
                            future: _fetchTags(post.postId),
                            builder: (context, tagSnapshot) {
                              if (!tagSnapshot.hasData || tagSnapshot.data!.isEmpty) {
                                return const SizedBox();
                              }

                              final tags = tagSnapshot.data!;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 10),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: tags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC143C).withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "#${tag.tagName}",
                                        style: const TextStyle(
                                          color: Color(0xFFDC143C),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),

                          // POST IMAGE
                          if (post.mediaUrl != null && post.mediaUrl!.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                post.mediaUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          Divider(height: 1, color: Colors.grey[300]),
                          const SizedBox(height: 8),

                          // INTERACTION STATS
                          Consumer<PostProvider>(
                            builder: (context, postProvider, _) {
                              return Consumer<RepostProvider>(
                                builder: (context, repostProvider, _) {
                                  final likeCount = postProvider.postLikeCounts[post.postId] ?? 0;
                                  final commentCount = _commentCounts[post.postId] ?? 0;
                                  final repostCount = repostProvider.getRepostCount(post.postId);

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (likeCount > 0)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.favorite,
                                              color: Color(0xFFDC143C),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$likeCount',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        const SizedBox(),
                                      Text(
                                        '$commentCount comment${commentCount != 1 ? 's' : ''} · $repostCount repost${repostCount != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 8),
                          Divider(height: 1, color: Colors.grey[300]),

                          // ACTION BUTTONS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // LIKE BUTTON
                              Consumer<PostProvider>(
                                builder: (context, provider, _) {
                                  final liked = provider.likedByMe.contains(post.postId);
                                  return TextButton.icon(
                                    onPressed: () {
                                      provider.togglePostLike(post.postId);
                                      setCardState(() {});
                                    },
                                    icon: Icon(
                                      liked ? Icons.favorite : Icons.favorite_border,
                                      color: liked ? const Color(0xFFDC143C) : Colors.grey[700],
                                      size: 20,
                                    ),
                                    label: Text(
                                      'Like',
                                      style: TextStyle(
                                        color: liked ? const Color(0xFFDC143C) : Colors.grey[700],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // COMMENT BUTTON
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CommentsPage(
                                        postId: post.postId,
                                        currentUserId: widget.currentUserId,
                                      ),
                                    ),
                                  ).then((_) {
                                    setStateIfMounted(() {
                                      _commentCounts.remove(post.postId);
                                    });
                                    _ensureCommentCount(post.postId);

                                    final postProvider = Provider.of<PostProvider>(
                                      context,
                                      listen: false,
                                    );
                                    final repostProvider = Provider.of<RepostProvider>(
                                      context,
                                      listen: false,
                                    );

                                    postProvider.loadPostLikes(post.postId);
                                    repostProvider.loadRepostData(post.postId);
                                  });
                                },
                                icon: Icon(
                                  Icons.comment_outlined,
                                  color: Colors.grey[700],
                                  size: 20,
                                ),
                                label: Text(
                                  'Comment',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),

                              // REPOST BUTTON
                              Consumer<RepostProvider>(
                                builder: (context, repostProvider, _) {
                                  final isReposted = repostProvider.isReposted(post.postId);
                                  return TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await repostProvider.toggleRepost(post.postId);
                                        setCardState(() {});
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to update repost'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      Icons.repeat,
                                      color: isReposted ? const Color(0xFFDC143C) : Colors.grey[700],
                                      size: 20,
                                    ),
                                    label: Text(
                                      'Repost',
                                      style: TextStyle(
                                        color: isReposted ? const Color(0xFFDC143C) : Colors.grey[700],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
  Widget _postAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 6),
          if (count != null) ...[
            Text(
              '$count',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _createPostBar(String name, String? imageUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                ? NetworkImage(imageUrl)
                : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xffF5F6F8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "What's in your mind, $name?",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCreatePostBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

String timeAgo(DateTime createdAtUtc) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(createdAtUtc);

  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
  if (diff.inHours < 24) return "${diff.inHours} h ago";
  if (diff.inDays < 7) return "${diff.inDays} d ago";

  final weeks = (diff.inDays / 7).floor();
  return "$weeks week${weeks > 1 ? 's' : ''} ago";
}

}
