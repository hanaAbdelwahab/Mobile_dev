import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';


// Get Supabase client
final supabase = Supabase.instance.client;

// Professional Color Palette
class AppColors {
  static const primary = Color(0xFFD32F2F); // Professional red1
  static const primaryDark = Color(0xFFB71C1C);
  static const primaryLight = Color(0xFFEF5350);
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const divider = Color(0xFFE0E0E0);
}

// --------------------- Helper Functions ---------------------
Widget buildAvatarHelper(String name, String? avatarUrl, double radius) {
  if (avatarUrl != null && avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(avatarUrl),
      backgroundColor: AppColors.primary,
      onBackgroundImageError: (exception, stackTrace) {
        print('Error loading avatar: $exception');
      },
    );
  }
  
  // Generate initials safely
  String initials = '';
  try {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      initials = '?';
    } else if (parts.length == 1) {
      initials = parts[0].substring(0, 1).toUpperCase();
    } else {
      initials = parts[0].substring(0, 1).toUpperCase() + 
                 parts[1].substring(0, 1).toUpperCase();
    }
  } catch (e) {
    print('Error generating initials for "$name": $e');
    initials = '?';
  }
  
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.primary,
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white, 
        fontWeight: FontWeight.w600,
        fontSize: radius * 0.5,
      ),
    ),
  );
}

// --------------------- Models ---------------------
class Chat {
  final String id;
  final String name;
  final int userId;
  final String? avatarUrl;
  final String lastMessage;
  final ChatSettings settings;
  final String? conversationId;

  Chat({
    required this.id,
    required this.name,
    required this.userId,
    this.avatarUrl,
    required this.lastMessage,
    required this.settings,
    this.conversationId,
  });
}

class ChatSettings {
  bool isMuted;
  bool isBlocked;
  bool isBlockedByOther; // NEW: Track if we're blocked by the other user
  
  ChatSettings({
    this.isMuted = false, 
    this.isBlocked = false,
    this.isBlockedByOther = false,
  });
}

class Message {
  final String id;
  final int senderId;
  final String conversationId;
  final String content;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final bool isDelivered; // NEW: Track delivery status

  Message({
    required this.id,
    required this.senderId,
    required this.conversationId,
    required this.content,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    this.isDelivered = true,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      conversationId: json['conversation_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      attachmentName: json['attachment_name'],
      isDelivered: json['is_delivered'] ?? true,
    );
  }

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => attachmentType?.startsWith('image/') ?? false;
}

// --------------------- RIVERPOD PROVIDERS ---------------------

// StateNotifier for managing chats list
class ChatsNotifier extends StateNotifier<List<Chat>> {
  final int currentUserId;
  ChatsNotifier(this.currentUserId) : super([]);

  Future<void> loadChats() async {
    try {
      final response = await supabase
        .from('users')
        .select('user_id, name, profile_image, bio, role, location')
        .order('name');

      final conversations = await _loadConversationsWithSettings();

      state = (response as List).map((user) {
        final existingConv = conversations.firstWhere(
          (conv) => conv['other_user_id'] == user['user_id'],
          orElse: () => <String, dynamic>{},
        );

        return Chat(
        id: user['user_id'].toString(),
        name: user['name'] ?? 'Unknown User',
        userId: user['user_id'],
        avatarUrl: user['profile_image'],
        lastMessage: user['bio'] ?? 'No bio available',
        conversationId: existingConv['conversation_id'],
        settings: ChatSettings(
          isMuted: existingConv['is_muted'] ?? false,
          isBlocked: existingConv['is_blocked'] ?? false,
          isBlockedByOther: existingConv['is_blocked_by_other'] ?? false,
        ),
        );
      }).toList();
    } catch (e) {
      print('Error loading chats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadConversationsWithSettings() async {
    try {
      final myParticipations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      if ((myParticipations as List).isEmpty) {
        return [];
      }

      final myConvIds = myParticipations
          .map((p) => p['conversation_id'] as String)
          .toList();

      final allParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', myConvIds);

      Map<String, String> convToOtherUser = {};
      for (var part in (allParticipants as List)) {
        if (part['user_id'] != currentUserId) {
          convToOtherUser[part['conversation_id']] = part['user_id'];
        }
      }

      // Get MY settings (conversations I've muted/blocked)
      final mySettings = await supabase
          .from('conversation_settings')
          .select('conversation_id, is_muted, is_blocked')
          .eq('user_id', currentUserId)
          .inFilter('conversation_id', myConvIds);

      // NEW: Get THEIR settings (check if they've blocked me)
      final theirSettings = await supabase
          .from('conversation_settings')
          .select('conversation_id, user_id, is_blocked')
          .inFilter('conversation_id', myConvIds)
          .eq('is_blocked', true);

      Map<String, bool> blockedByOther = {};
      for (var setting in (theirSettings as List)) {
        if (setting['user_id'] != currentUserId) {
  blockedByOther[setting['conversation_id']] = true;
}

      }

      List<Map<String, dynamic>> result = [];
      for (var setting in (mySettings as List)) {
        final convId = setting['conversation_id'];
        result.add({
          'conversation_id': convId,
          'other_user_id': convToOtherUser[convId],
          'is_muted': setting['is_muted'] ?? false,
          'is_blocked': setting['is_blocked'] ?? false,
          'is_blocked_by_other': blockedByOther[convId] ?? false,
        });
      }

      return result;
    } catch (e) {
      print('Error loading conversation settings: $e');
      return [];
    }
  }

void updateLastMessage(int userId, String message) {
  state = [
    for (final chat in state)
      if (chat.userId == userId)
        Chat(
          id: chat.id,
          name: chat.name,
          userId: chat.userId,
          avatarUrl: chat.avatarUrl,
          lastMessage: message,
          conversationId: chat.conversationId,
          settings: chat.settings,
        )
      else
        chat
  ];
}

}

// Provider for chats list
final chatsProvider = StateNotifierProvider.family<ChatsNotifier, List<Chat>, int>((ref, userId) {
  return ChatsNotifier(userId);
});

// StateProvider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for filtered chats
// ✅ CORRECT: Use .family to pass userId as a parameter
final filteredChatsProvider = Provider.family<List<Chat>, int>((ref, userId) {
  final chats = ref.watch(chatsProvider(userId));
  final query = ref.watch(searchQueryProvider).toLowerCase();
  
  if (query.isEmpty) return chats;
  
  return chats.where((c) =>
      c.name.toLowerCase().contains(query) ||
      c.lastMessage.toLowerCase().contains(query))
      .toList();
});

// StateNotifier for managing messages in a conversation
class MessagesNotifier extends StateNotifier<List<Message>> {
  MessagesNotifier() : super(const []);

  Future<void> loadMessages(String conversationId) async {
    try {
      final response = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      state = (response as List)
          .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      rethrow;
    }
  }

  void addMessage(Message message) {
    if (!state.any((m) => m.id == message.id)) {
      state = [...state, message];
    }
  }

  void clearMessages() {
    state = [];
  }
}

// Provider for messages (parameterized by conversation ID)
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<Message>, String?>(
  (ref, conversationId) => MessagesNotifier(),
);

// --------------------- Chats List ---------------------
class ChatsListPage extends ConsumerStatefulWidget {
  final int currentUserId;

  const ChatsListPage({
    super.key,
    required this.currentUserId,
  });

  @override
  ConsumerState<ChatsListPage> createState() => _ChatsListPageState();
}


class _ChatsListPageState extends ConsumerState<ChatsListPage> {
  late TextEditingController searchController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    loadChats();

    searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = searchController.text;
    });
  }

  Future<void> loadChats() async {
    setState(() => isLoading = true);
    try {
      await ref
    .read(chatsProvider(widget.currentUserId).notifier)
    .loadChats();
    } catch (e) {
      print('Error loading chats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  void startChatWithUser(int userId) {
    final chats = ref.read(chatsProvider(widget.currentUserId));
    final chat = chats.firstWhere((c) => c.userId == userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
  chat: chat,
  currentUserId: widget.currentUserId,
),

      ),
    ).then((_) {
      loadChats();
    });
  }

  void openNewMessage() {
    final chats = ref.read(chatsProvider(widget.currentUserId));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewMessagePage(
          onStartChat: startChatWithUser,
          availableUsers: chats,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = ref.watch(filteredChatsProvider(widget.currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Search conversations...",
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.9), size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            )
          : filteredChats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 20),
                      Text(
                        searchController.text.isEmpty ? 'No conversations yet' : 'No results found',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        searchController.text.isEmpty 
                            ? 'Start chatting with someone'
                            : 'Try different keywords',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadChats,
                  color: AppColors.primary,
                  child: ListView.separated(
                    itemCount: filteredChats.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                      indent: 88,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return Material(
                        color: AppColors.surface,
                        child: InkWell(
                          onTap: () {
  startChatWithUser(chat.userId);
},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    buildAvatar(chat.name, chat.avatarUrl, 28),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green[500],
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              chat.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: AppColors.textPrimary,
                                                letterSpacing: 0.1,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (chat.settings.isMuted)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.volume_off_rounded,
                                                size: 16,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (chat.settings.isBlocked)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.block_rounded,
                                                size: 14,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          if (chat.settings.isBlockedByOther && !chat.settings.isBlocked)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Icon(
                                                Icons.cancel_rounded,
                                                size: 14,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              chat.settings.isBlocked 
                                                  ? 'You blocked this user' 
                                                  : chat.settings.isBlockedByOther
                                                      ? 'You are blocked'
                                                      : (chat.lastMessage.isEmpty ? 'Start a conversation' : chat.lastMessage),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: (chat.settings.isBlocked || chat.settings.isBlockedByOther)
                                                    ? Colors.orange[700]
                                                    : AppColors.textSecondary,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.5), size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 3,
        onPressed: openNewMessage,
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// --------------------- New Message Page ---------------------
class NewMessagePage extends StatefulWidget {
  final Function(int userId) onStartChat;
  final List<Chat> availableUsers;

  const NewMessagePage({
    super.key,
    required this.onStartChat,
    required this.availableUsers,
  });

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  List<Chat> filteredUsers = [];
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredUsers = widget.availableUsers;

    searchController.addListener(() {
      final query = searchController.text.toLowerCase();
      setState(() {
        filteredUsers = widget.availableUsers
            .where((user) => user.name.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  Widget buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Message',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredUsers.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.divider,
                      indent: 88,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Material(
                        color: AppColors.surface,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onStartChat(user.userId);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                buildAvatar(user.name, user.avatarUrl, 26),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        user.lastMessage.isEmpty ? 'Tap to start chatting' : user.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.5), size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// --------------------- Chat Room (THE MESSAGING PAGE) ---------------------
class ChatRoomPage extends ConsumerStatefulWidget {
  final Chat chat;
  final int currentUserId;

  const ChatRoomPage({
    super.key,
    required this.chat,
    required this.currentUserId,
  });
  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool isLoading = true;
  bool isSending = false;
  String? conversationId;
  late int currentUserId;


  @override
  void initState() {
    super.initState();
    initializeChat();
  }


  Future<void> initializeChat() async {
    try {
      currentUserId = widget.currentUserId;
      print('🚀 Initializing chat with user ID: $currentUserId');

      // Check if user exists in database
      // Check if user exists in database
try {
  final userCheck = await supabase
      .from('users')
      .select('user_id, name')
      .eq('user_id', currentUserId)
      .maybeSingle();
  
  if (userCheck == null) {
    if (mounted) {
      setState(() => isLoading = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ User not found in database'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    return;
  }
} catch (e) {
  print('Error checking user: $e');
}

      await findOrCreateConversation();
      
      // Check if we're blocked by the other user
      await _checkIfBlockedByOther();
      
      await loadMessages();
      subscribeToMessages();
      
      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error initializing chat: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
Future<void> _checkIfBlockedByOther() async {
    if (conversationId == null) return;
    
    try {
      final otherUserSettings = await supabase
          .from('conversation_settings')
          .select('is_blocked')
          .eq('conversation_id', conversationId!)
          .eq('user_id', widget.chat.userId)
          .maybeSingle();

      if (otherUserSettings != null && mounted) {
        setState(() {
          widget.chat.settings.isBlockedByOther = otherUserSettings['is_blocked'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking if blocked by other: $e');
    }
  }
  Future<void> findOrCreateConversation() async {
    try {
      final participantsResponse = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      final myConversations = (participantsResponse as List)
          .map((p) => p['conversation_id'] as String)
          .toList();

      if (myConversations.isEmpty) {
        await createNewConversation();
        return;
      }
      
      final otherUserParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', widget.chat.userId)
          .inFilter('conversation_id', myConversations);

      if ((otherUserParticipants as List).isNotEmpty) {
        conversationId = otherUserParticipants[0]['conversation_id'];
        
        // Check if we're blocked after finding conversation
        await _checkIfBlockedByOther();
      } else {
        await createNewConversation();
      }
    } catch (e) {
      print('❌ Error finding/creating conversation: $e');
      rethrow;
    }
  }
  Future<void> createNewConversation() async {
    try {
      final newConversation = await supabase
          .from('conversations')
          .insert({
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      conversationId = newConversation['id'];

      await supabase.from('conversation_participants').insert([
        {
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'joined_at': DateTime.now().toIso8601String(),
        },
        {
          'conversation_id': conversationId,
          'user_id': widget.chat.userId,
          'joined_at': DateTime.now().toIso8601String(),
        },
      ]);
    } catch (e) {
      print('❌ Error creating conversation: $e');
      rethrow;
    }
  }

  Future<void> loadMessages() async {
    if (conversationId == null) return;

    try {
      await ref.read(messagesProvider(conversationId).notifier).loadMessages(conversationId!);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  void subscribeToMessages() {
    if (conversationId == null) return;

    supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newMessage = Message.fromJson(payload.newRecord);
            ref.read(messagesProvider(conversationId).notifier).addMessage(newMessage);
            ref
  .read(chatsProvider(currentUserId).notifier)
  .updateLastMessage(widget.chat.userId, newMessage.content);

            scrollToBottom();
          },
        )
        .subscribe();
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

 Future<void> sendMessage() async {
    // Check both blocking conditions
    if (widget.chat.settings.isBlocked || widget.chat.settings.isBlockedByOther) {
      if (widget.chat.settings.isBlockedByOther) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Not delivered - You are blocked by this user',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    if (messageController.text.trim().isEmpty) return;
    if (conversationId == null) return;
    if (isSending) return;

    final messageText = messageController.text.trim();
    messageController.clear();

    setState(() => isSending = true);

    try {
      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': messageText,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId!);

      ref
  .read(chatsProvider(currentUserId).notifier)
  .updateLastMessage(widget.chat.userId, messageText);

    } catch (e) {
      messageController.text = messageText;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  Future<void> clearChat() async {
    if (conversationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to delete all messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId!);

      ref.read(messagesProvider(conversationId).notifier).clearMessages();
      ref
  .read(chatsProvider(currentUserId).notifier)
  .updateLastMessage(widget.chat.userId, '');

      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat history cleared'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void openSettings() async {
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot open settings: conversation not initialized'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSettingsPage(
          settings: widget.chat.settings,
  clearChat: clearChat,
  conversationId: conversationId!,
  otherUserName: widget.chat.name,
  currentUserId: currentUserId,
        ),
      ),
    );
    
    // Refresh blocking status after settings change
    await _checkIfBlockedByOther();
    setState(() {});
  }

  void openAttachments() async {
    if (widget.chat.settings.isBlocked || widget.chat.settings.isBlockedByOther) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildAttachmentOption(
                Icons.photo_library_rounded,
                'Photo from Gallery',
                () {
                  Navigator.pop(context);
                  _pickAndSendImage();
                },
              ),
             
              _buildAttachmentOption(
                Icons.attach_file_rounded,
                'Send File',
                () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

 Future<void> _pickAndSendImage() async {
  try {
    // ✅ Use file_picker for BOTH web and mobile
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      
      if (kIsWeb) {
        // Web: use bytes
        if (file.bytes != null) {
          await _sendAttachmentFromBytes(
            file.bytes!,
            file.name,
            'image/${file.extension ?? 'png'}',
          );
        }
      } else {
        // Mobile: use path
        if (file.path != null) {
          await _sendAttachment(
            file.path!,
            file.name,
            'image/${file.extension ?? 'png'}',
          );
        }
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
Future<void> _sendAttachmentFromBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  if (conversationId == null ) return;

  setState(() => isSending = true);

  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last;
    final uniqueFileName = '$conversationId/$timestamp.$extension';

    await supabase.storage
        .from('chat-attachments')
        .uploadBinary(
          uniqueFileName,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    final publicUrl = supabase.storage
        .from('chat-attachments')
        .getPublicUrl(uniqueFileName);

    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': fileName,
      'attachment_url': publicUrl,
      'attachment_type': mimeType,
      'attachment_name': fileName,
      'created_at': DateTime.now().toIso8601String(),
    });

    await supabase
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId!);

    ref
  .read(chatsProvider(currentUserId).notifier)
  .updateLastMessage(widget.chat.userId, '📎 $fileName');

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  } finally {
    setState(() => isSending = false);
  }
}
 
  Future<void> _pickAndSendFile() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      
      // ✅ FIX: Use bytes for web compatibility
      if (kIsWeb) {
        // Web: use bytes
        if (file.bytes != null) {
          await _sendAttachmentFromBytes(
            file.bytes!,
            file.name,
            _getMimeType(file.extension ?? ''),
          );
        }
      } else {
        // Mobile/Desktop: use path
        if (file.path != null) {
          await _sendAttachment(
            file.path!,
            file.name,
            _getMimeType(file.extension ?? ''),
          );
        }
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendAttachment(String filePath, String fileName, String mimeType) async {
    if (conversationId == null ) return;

    setState(() => isSending = true);

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final uniqueFileName = '$conversationId/$timestamp.$extension';

      await supabase.storage
          .from('chat-attachments')
          .uploadBinary(
            uniqueFileName,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage
          .from('chat-attachments')
          .getPublicUrl(uniqueFileName);

      await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': fileName,
        'attachment_url': publicUrl,
        'attachment_type': mimeType,
        'attachment_name': fileName,
        'created_at': DateTime.now().toIso8601String(),
      });

      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId!);

      ref
  .read(chatsProvider(currentUserId).notifier)
  .updateLastMessage(widget.chat.userId, '📎 $fileName');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => isSending = false);
    }
  }

  Widget buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = widget.chat.settings.isBlocked;
    final isBlockedByOther = widget.chat.settings.isBlockedByOther;
    final cannotSend = isBlocked || isBlockedByOther;
    final messages = ref.watch(messagesProvider(conversationId));
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            buildAvatar(widget.chat.name, widget.chat.avatarUrl, 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isBlockedByOther ? 'Blocked you' : 'Online',
                    style: TextStyle(
                      color: isBlockedByOther 
                          ? Colors.red[200]
                          : Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: openSettings,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          )
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Column(
              children: [
                // NEW: Banner showing blocking status
                if (isBlocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border(
                        bottom: BorderSide(color: Colors.orange[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.block_rounded, color: Colors.orange[700], size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You blocked ${widget.chat.name}',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: openSettings,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Unblock',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isBlockedByOther)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border(
                        bottom: BorderSide(color: Colors.red[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.cancel_rounded, color: Colors.red[700], size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.chat.name} has blocked you',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 64,
                                      color: AppColors.primary.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cannotSend ? 'Messaging is not available' : 'Start the conversation!',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[messages.length - 1 - index];
                                final isMe = message.senderId == currentUserId;
                                
                                bool showDateSeparator = false;
                                if (index == messages.length - 1) {
                                  showDateSeparator = true;
                                } else {
                                  final prevMessage = messages[messages.length - 2 - index];
                                  if (message.createdAt.day != prevMessage.createdAt.day) {
                                    showDateSeparator = true;
                                  }
                                }
                                
                                return Column(
                                  children: [
                                    if (showDateSeparator)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.textSecondary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _formatDate(message.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    _buildMessageBubble(message, isMe),
                                  ],
                                );
                              },
                            ),
                      if (cannotSend)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isBlockedByOther ? Icons.cancel_rounded : Icons.block_rounded, 
                                  color: isBlockedByOther ? Colors.red[700] : AppColors.textSecondary, 
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    isBlockedByOther 
                                        ? 'You cannot send messages '
                                        : 'You cannot send messages to a blocked user',
                                    style: TextStyle(
                                      color: isBlockedByOther ? Colors.red[700] : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: cannotSend ? null : openAttachments,
                            icon: Icon(
                              Icons.add_circle_rounded,
                              color: cannotSend ? AppColors.textSecondary.withOpacity(0.3) : AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: cannotSend ? AppColors.background.withOpacity(0.5) : AppColors.background,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: cannotSend ? AppColors.divider.withOpacity(0.5) : AppColors.divider,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: messageController,
                                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: cannotSend 
                                      ? (isBlockedByOther ? "You are blocked" : "Cannot send messages")
                                      : "Type a message...",
                                  hintStyle: TextStyle(
                                    color: cannotSend 
                                        ? AppColors.textSecondary.withOpacity(0.5) 
                                        : AppColors.textSecondary,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                maxLines: 5,
                                minLines: 1,
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => sendMessage(),
                                enabled: !cannotSend && !isSending,
                                readOnly: cannotSend,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: cannotSend 
                                ? AppColors.textSecondary.withOpacity(0.3)
                                : (isSending ? AppColors.textSecondary : AppColors.primary),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: (cannotSend || isSending) ? null : sendMessage,
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: isSending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(
                                        Icons.send_rounded,
                                        color: cannotSend 
                                            ? AppColors.textSecondary.withOpacity(0.5)
                                            : Colors.white,
                                        size: 22,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasAttachment) ...[
              if (message.isImage)
                GestureDetector(
                  onTap: () => _openAttachment(message.attachmentUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.attachmentUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 150,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isMe ? Colors.white : AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _openAttachment(message.attachmentUrl!),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? Colors.white.withOpacity(0.15) 
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getFileIcon(message.attachmentType ?? ''),
                            color: isMe ? Colors.white : AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.attachmentName ?? 'File',
                                style: TextStyle(
                                  color: isMe ? Colors.white : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to open',
                                style: TextStyle(
                                  color: isMe 
                                      ? Colors.white.withOpacity(0.8)
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (message.content.isNotEmpty && !message.hasAttachment)
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe 
                        ? Colors.white.withOpacity(0.75)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isDelivered 
                        ? Icons.done_all_rounded 
                        : Icons.access_time_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_rounded;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart_rounded;
    } else if (mimeType.contains('text')) {
      return Icons.text_snippet_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Future<void> _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening attachment: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    supabase.removeAllChannels();
    super.dispose();
  }
}

// --------------------- Chat Settings (Professional Design) ---------------------
class ChatSettingsPage extends StatefulWidget {
  final ChatSettings settings;
  final VoidCallback clearChat;
  final String conversationId;
  final String otherUserName;
  final int currentUserId;

  const ChatSettingsPage({
    super.key,
    required this.settings,
    required this.clearChat,
    required this.conversationId,
    required this.otherUserName,
    required this.currentUserId,
  });

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  bool isSaving = false;

Future<void> _updateMuteStatus(bool value) async {
  setState(() => isSaving = true);

  try {
    final existing = await supabase
        .from('conversation_settings')
        .select('id')
        .eq('conversation_id', widget.conversationId)
        .eq('user_id', widget.currentUserId)
        .maybeSingle();

    if (existing != null) {
      // Update existing record - NO .select() needed
      await supabase
          .from('conversation_settings')
          .update({
            'is_muted': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', widget.currentUserId);
    } else {
      // Insert new record - NO .select() needed
      await supabase.from('conversation_settings').insert({
        'conversation_id': widget.conversationId,
        'user_id': widget.currentUserId,
        'is_muted': value,
        'is_blocked': false,
      });
    }

    setState(() {
      widget.settings.isMuted = value;
      isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                value ? 'Notifications muted' : 'Notifications enabled',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    setState(() => isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
  Future<void> _updateBlockStatus(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, color: Colors.orange[700], size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Block User?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                ),
              ),
            ],
          ),
          content: Text(
            'You won\'t be able to send or receive messages from ${widget.otherUserName}. They won\'t be able to send you messages either. You can unblock them anytime.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Block', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => isSaving = true);

    try {
      final existing = await supabase
          .from('conversation_settings')
          .select('id')
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', widget.currentUserId)
          .maybeSingle();

      if (existing != null) {
  await supabase
      .from('conversation_settings')
      .update({
        'is_muted': value,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('conversation_id', widget.conversationId)
      .eq('user_id', widget.currentUserId);  // ✅ This is fine - update doesn't need .select()
} else {
  await supabase.from('conversation_settings').insert({
    'conversation_id': widget.conversationId,
    'user_id': widget.currentUserId,
    'is_muted': false,
    'is_blocked': value,
  });  // ✅ This is fine - insert doesn't need .select() either
}

      setState(() {
        widget.settings.isBlocked = value;
        isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  value ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  value ? 'User blocked' : 'User unblocked',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: value ? Colors.orange[700] : Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // Notifications Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: widget.settings.isMuted,
                  onChanged: isSaving ? null : _updateMuteStatus,
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: const Text(
                    "Mute Notifications",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Turn off notifications for this chat",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.settings.isMuted 
                          ? Icons.volume_off_rounded 
                          : Icons.volume_up_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Privacy Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'PRIVACY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: widget.settings.isBlocked,
                  onChanged: isSaving ? null : _updateBlockStatus,
                  activeColor: Colors.orange[700],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: const Text(
                    "Block User",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Block all messages from this user",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.block_rounded, color: Colors.orange[700], size: 22),
                  ),
                ),
              ],
            ),
          ),

          // Actions Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'ACTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.clearChat();
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.delete_sweep_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Clear Chat History",
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Delete all messages in this chat",
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}