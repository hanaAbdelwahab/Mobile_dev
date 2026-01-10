// import 'dart:ui';
// import 'package:flutter/material.dart';

// import 'package:provider/provider.dart';

// class StorySection extends StatelessWidget {
//   final String? myAvatarUrl;
//   final List<Map<String, dynamic>> stories;
//   final bool hasMyStory;
//   final int currentUserId;

//   const StorySection({
//     super.key,
//     required this.myAvatarUrl,
//     required this.stories,
//     required this.hasMyStory,
//     required this.currentUserId,
//   });

//   // =========================
//   // هل كل stories اتشافوا؟
//   // =========================
//   bool _areAllStoriesSeen(List<Map<String, dynamic>> stories) {
//     return stories.every((s) => s['is_seen'] == true);
//   }

//   @override
//   Widget build(BuildContext context) {
//     // ================= GROUP STORIES BY USER =================
//     final Map<int, List<Map<String, dynamic>>> groupedStories = {};

//     for (final story in stories) {
//       final int userId = story['user_id'];
//       groupedStories.putIfAbsent(userId, () => []);
//       groupedStories[userId]!.add(story);
//     }

//     // ================= SORT USERS =================
//     final users =
//         groupedStories.entries.where((e) => e.key != currentUserId).toList()
//           ..sort((a, b) {
//             final aSeen = _areAllStoriesSeen(a.value);
//             final bSeen = _areAllStoriesSeen(b.value);
//             return aSeen == bSeen ? 0 : (aSeen ? 1 : -1);
//           });

//     return SizedBox(
//       height: 120,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: users.length + 1,
//         itemBuilder: (context, index) {
//           // ================= MY STORY =================
//           if (index == 0) {
//             return Padding(
//               padding: const EdgeInsets.only(right: 12),
//               child: _StoryAdd(avatarUrl: myAvatarUrl, hasStory: hasMyStory),
//             );
//           }

//           // ================= OTHER USERS =================
//           final userIndex = index - 1;
//           final entry = users[userIndex];

//           final allSeen = _areAllStoriesSeen(entry.value);

//           // أول story مش متشاف
//           final firstUnseenIndex = entry.value.indexWhere(
//             (s) => s['is_seen'] == false,
//           );

//           return Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: GestureDetector(
//               onTap: () async {
//                 final finished = await Navigator.push<bool>(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => StoryViewerPage(
//                       stories: entry.value,
//                       initialIndex: firstUnseenIndex == -1
//                           ? 0
//                           : firstUnseenIndex,
//                       currentUserId: currentUserId,
//                     ),
//                   ),
//                 );

//                 // ✅ دي الإضافة المهمة
//                 if (finished == true) {
//                   await context.read<StoryProvider>().refresh(
//                     currentUserId: currentUserId,
//                     forYou: true, // لو عندك Discover / ForYou عدليها حسب التاب
//                   );
//                 }

//                 // لو خلص stories الشخص ده → افتحي اللي بعده
//                 if (finished == true && userIndex + 1 < users.length) {
//                   final nextUser = users[userIndex + 1];
//                   final nextFirstUnseen = nextUser.value.indexWhere(
//                     (s) => s['is_seen'] == false,
//                   );

//                   await Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => StoryViewerPage(
//                         stories: nextUser.value,
//                         initialIndex: nextFirstUnseen == -1
//                             ? 0
//                             : nextFirstUnseen,
//                         currentUserId: currentUserId,
//                       ),
//                     ),
//                   );
//                 }
//               },
//               child: _StoryCard(
//                 name: entry.value.first['user_name'] ?? "User",
//                 imageUrl: entry.value.first['story_image'],
//                 avatarUrl: entry.value.first['profile_image'],
//                 allSeen: allSeen,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// //
// // ========================= MY STORY =========================
// //
// class _StoryAdd extends StatelessWidget {
//   final String? avatarUrl;
//   final bool hasStory;

//   const _StoryAdd({this.avatarUrl, required this.hasStory});

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 86,
//       child: Column(
//         children: [
//           Stack(
//             children: [
//               if (hasStory)
//                 Container(
//                   padding: const EdgeInsets.all(3),
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(
//                       colors: [Color(0xFFF44336), Color(0xFFFF9800)],
//                     ),
//                   ),
//                   child: _avatar(),
//                 )
//               else
//                 _avatar(),

//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: Container(
//                   width: 22,
//                   height: 22,
//                   decoration: BoxDecoration(
//                     color: Colors.red,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.white, width: 2),
//                   ),
//                   child: const Icon(Icons.add, size: 16, color: Colors.white),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           const Text("My Story", style: TextStyle(fontSize: 12)),
//         ],
//       ),
//     );
//   }

//   Widget _avatar() {
//     return CircleAvatar(
//       radius: 32,
//       backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
//           ? NetworkImage(avatarUrl!)
//           : null,
//       child: (avatarUrl == null || avatarUrl!.isEmpty)
//           ? const Icon(Icons.person)
//           : null,
//     );
//   }
// }

// //
// // ========================= STORY CARD =========================
// //
// class _StoryCard extends StatelessWidget {
//   final String name;
//   final String imageUrl;
//   final String? avatarUrl;
//   final bool allSeen;

//   const _StoryCard({
//     required this.name,
//     required this.imageUrl,
//     required this.avatarUrl,
//     required this.allSeen,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: 118,
//       child: Column(
//         children: [
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               Container(
//                 width: 110,
//                 height: 72,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(18),
//                   gradient: LinearGradient(
//                     colors: allSeen
//                         ? [Colors.grey.shade400, Colors.grey.shade500]
//                         : [const Color(0xFFF44336), const Color(0xFFFF9800)],
//                   ),
//                 ),
//                 padding: const EdgeInsets.all(3),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(15),
//                   child: ImageFiltered(
//                     imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
//                     child: Image.network(imageUrl, fit: BoxFit.cover),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 bottom: -14,
//                 left: (110 / 2) - 29,
//                 child: CircleAvatar(
//                   radius: 29,
//                   backgroundColor: Colors.white,
//                   child: CircleAvatar(
//                     radius: 26,
//                     backgroundImage: avatarUrl != null
//                         ? NetworkImage(avatarUrl!)
//                         : null,
//                     child: avatarUrl == null
//                         ? const Icon(Icons.person, size: 16)
//                         : null,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Text(name, style: const TextStyle(fontSize: 12)),
//         ],
//       ),
//     );
//   }
// }