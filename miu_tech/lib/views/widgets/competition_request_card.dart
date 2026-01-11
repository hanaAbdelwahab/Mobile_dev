import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import '../../models/competition_request_model.dart';
import '../screens/OtherUserProfilePage.dart';
final supabase = Supabase.instance.client;

class CompetitionRequestCard extends StatefulWidget {
  final CompetitionRequestModel request;
  final int currentUserId;
  const CompetitionRequestCard({
    super.key,
    required this.request,
    required this.currentUserId,
  });

  @override
  State<CompetitionRequestCard> createState() =>
      _CompetitionRequestCardState();
}

class _CompetitionRequestCardState extends State<CompetitionRequestCard> {
  bool _requested = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
  super.initState();
  _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));

  _checkIfAlreadyRequested(); // ✅ مهم
}
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
Future<void> _checkIfAlreadyRequested() async {
  try {
    final res = await supabase
        .from('team_join_requests')
        .select('id')
        .eq('request_id', widget.request.requestId)
        .eq('requester_id', widget.currentUserId)
        .maybeSingle();

    if (res != null && mounted) {
      setState(() {
        _requested = true;
      });
    }
  } catch (e) {
    debugPrint("Check request error: $e");
  }
}

Future<void> _sendJoinRequest() async {
  try {
    await supabase.from('team_join_requests').insert({
      'request_id': widget.request.requestId,
      'requester_id': widget.currentUserId, // ✅ INT
      'competition_owner_id': widget.request.userId,
      'status': 'pending',
    });

    setState(() => _requested = true);
    _confettiController.play();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Request sent successfully 🎉"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    debugPrint("ERROR INSERT: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Future<void> _cancelJoinRequest() async {
  try {
    await supabase
        .from('team_join_requests')
        .delete()
        .eq('request_id', widget.request.requestId)
        .eq('requester_id', widget.currentUserId);

    setState(() => _requested = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Request cancelled"),
        backgroundColor: Colors.orange,
      ),
    );
  } catch (e) {
    debugPrint("ERROR DELETE: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to cancel request"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<Map<String, dynamic>?> _fetchUser(int userId) async {
    return await supabase
        .from('users')
        .select('name, profile_image')
        .eq('user_id', userId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.request.neededSkills.split(',');

    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUser(widget.request.userId),
      builder: (context, snapshot) {
        final userName = snapshot.data?['name'] ?? "User";
        final avatarUrl = snapshot.data?['profile_image'];

        return Stack(
          children: [
           Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ================= HEADER =================
      Row(
        children: [
          GestureDetector(
            onTap: () {
              if (widget.request.userId != widget.currentUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfilePage(
                      userId: widget.request.userId.toString(),
                      currentUserId:
                          widget.currentUserId.toString(),
                    ),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 24,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              backgroundColor: Colors.grey[200],
              child: avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              userName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed:
                _requested ? _cancelJoinRequest : _sendJoinRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _requested ? Colors.grey.shade300 : Colors.redAccent,
              foregroundColor:
                  _requested ? Colors.grey.shade700 : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _requested ? "Request Sent" : "Request to Join",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 14),

      // ================= TITLE =================
      Text(
        widget.request.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 6),

      // ================= DESCRIPTION =================
      Text(
        widget.request.description,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
      ),

      const SizedBox(height: 12),

      // ================= SKILLS =================
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills.map((skill) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              skill.trim(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    ],
  ),
),

            // 🎉 Confetti
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality:
                      BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.red,
                    Colors.orange,
                    Colors.blue,
                    Colors.green,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
