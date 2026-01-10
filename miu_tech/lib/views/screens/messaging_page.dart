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
  final int unreadCount; // ✅ NEW: Track unread messages
  final DateTime? lastMessageTime;
  final String requestStatus; // ✅ NEW: Track last message timestamp

  Chat({
    required this.id,
    required this.name,
    required this.userId,
    this.avatarUrl,
    required this.lastMessage,
    required this.settings,
    this.conversationId,
    this.unreadCount = 0, // ✅ NEW
    this.lastMessageTime,
     this.requestStatus = 'accepted', // ✅ NEW
  });
}

class ChatSettings {
  bool isMuted;
  bool isBlocked;
  bool isBlockedByOther; // NEW: Track if we're blocked by the other user
  bool isFriend; // ✅ NEW: Track if user is a friend
  
  ChatSettings({
    this.isMuted = false, 
    this.isBlocked = false,
    this.isBlockedByOther = false,
    this.isFriend = true, // Default to true for backwards compatibility
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
  final bool isRead; // ✅ NEW: Track read status

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
    this.isRead = false, // ✅ NEW
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
      isRead: json['is_read'] ?? false, // ✅ NEW
    );
  }

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => attachmentType?.startsWith('image/') ?? false;
}

// --------------------- RIVERPOD PROVIDERS ---------------------

// StateNotifier for managing chats list
class ChatsNotifier extends StateNotifier<List<Chat>> {
  final int currentUserId;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _settingsChannel;
  
  ChatsNotifier(this.currentUserId) : super([]) {
    _setupRealtimeSubscriptions();
  }

 void _setupRealtimeSubscriptions() {
  _messagesChannel = supabase
      .channel('chats_messages_$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          print('🔔 New message detected: ${payload.newRecord}');
          
          try {
            final newMessage = payload.newRecord;
            final conversationId = newMessage['conversation_id'] as String;
            final senderId = newMessage['sender_id'] as int;
            final content = newMessage['content'] as String? ?? '';
            final attachmentName = newMessage['attachment_name'] as String?;
            
            final participants = await supabase
                .from('conversation_participants')
                .select('user_id')
                .eq('conversation_id', conversationId)
                .neq('user_id', currentUserId);
            
            if ((participants as List).isEmpty) {
              print('⚠️ No other participants found');
              return;
            }
            
            final otherUserId = participants[0]['user_id'] as int;
            
            final displayMessage = attachmentName != null 
                ? '📎 $attachmentName' 
                : content;
            
            final currentChat = state.firstWhere(
              (c) => c.userId == otherUserId,
              orElse: () => Chat(
                id: '',
                name: '',
                userId: 0,
                lastMessage: '',
                settings: ChatSettings(),
                unreadCount: 0,
              ),
            );
            
            if (senderId != currentUserId) {
              print('📩 Message from other user - incrementing unread count');
              updateLastMessage(
                otherUserId,
                displayMessage,
                unreadCount: currentChat.unreadCount + 1,
              );
            } else {
              print('📤 Message from me - just updating last message');
              updateLastMessage(otherUserId, displayMessage);
            }
          } catch (e) {
            print('❌ Error handling new message: $e');
          }
        },
      )
      .subscribe();

  // ✅ FIXED: Subscribe to ALL changes in conversation_settings
  _settingsChannel = supabase
      .channel('chats_settings_$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_settings',
        callback: (payload) async {
          print('🔔 Settings changed: ${payload.newRecord}');
          
          // ✅ NEW: Check if the change affects current user
          final record = payload.newRecord;
          final conversationId = record['conversation_id'] as String?;
          
          if (conversationId == null) return;
          
          // Find which user this conversation belongs to
          try {
            final participants = await supabase
                .from('conversation_participants')
                .select('user_id')
                .eq('conversation_id', conversationId)
                .neq('user_id', currentUserId);
            
            if ((participants as List).isEmpty) return;
            
            final otherUserId = participants[0]['user_id'] as int;
            
            // ✅ Check if THEY blocked ME
            if (record['user_id'] == otherUserId && record['is_blocked'] != null) {
              final isBlockedByOther = record['is_blocked'] as bool;
              
              print('🚫 Block status changed for user $otherUserId: blocked=$isBlockedByOther');
              
              // Find current chat
              final currentChat = state.firstWhere(
                (c) => c.userId == otherUserId,
                orElse: () => Chat(
                  id: '',
                  name: '',
                  userId: 0,
                  lastMessage: '',
                  settings: ChatSettings(),
                  unreadCount: 0,
                ),
              );
              
              if (currentChat.userId != 0) {
                // Update the block status in real-time
                updateBlockStatus(
                  otherUserId,
                  currentChat.settings.isBlocked,
                  isBlockedByOther,
                );
              }
            }
          } catch (e) {
            print('❌ Error processing settings change: $e');
          }
        },
      )
      .subscribe();
      
  print('✅ Real-time subscriptions active for user $currentUserId');
}
  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _settingsChannel?.unsubscribe();
    super.dispose();
  }

Future<void> loadChats() async {
  try {
    // ✅ STEP 1: Get list of friends for current user
    final friendshipsResponse = await supabase
      .from('friendships')
      .select('user_id, friend_id')
      .eq('status', 'accepted')
      .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId');

    // Extract friend IDs where current user is involved
    Set<int> friendIds = {};
    for (var friendship in (friendshipsResponse as List)) {
      if (friendship['user_id'] == currentUserId) {
        friendIds.add(friendship['friend_id'] as int);
      } else if (friendship['friend_id'] == currentUserId) {
        friendIds.add(friendship['user_id'] as int);
      }
    }

    // ✅ STEP 2: Get ALL users (not just friends) - we'll filter in the UI
    final response = await supabase
      .from('users')
      .select('user_id, name, profile_image, bio, role, location')
      .neq('user_id', currentUserId)  // Don't show current user
      .order('name');

    final conversations = await _loadConversationsWithSettings();

    state = (response as List).map((user) {
      final existingConv = conversations.firstWhere(
  (conv) => conv['other_user_id'] == user['user_id'],
  orElse: () => <String, dynamic>{},
);

// ✅ Check if this user is a friend
final isFriend = friendIds.contains(user['user_id']);

// ✅ FIXED: Determine request status
// ✅ FIXED: Determine request status - SENDER should always be 'accepted'
String requestStatus;
if (existingConv.isEmpty) {
  // No conversation exists yet
  requestStatus = 'none';
} else {
  // Get MY request_status from MY conversation settings
  final myRequestStatus = existingConv['my_request_status'];
  
  // ✅ DEBUG
  print('🎯 Loading chat with ${user['name']} (user ${user['user_id']}):');
  print('   My request_status from DB: $myRequestStatus');
  print('   Am I friends with them: $isFriend');
  if (myRequestStatus != null) {
    // Use existing status from database
    requestStatus = myRequestStatus;
    print('   ✅ Using DB status: $requestStatus');
  } else {
    // No settings exist - determine based on who sent first message
    final firstMessageSenderId = existingConv['first_message_sender_id'];
    
    if (firstMessageSenderId == null) {
      // No messages yet
      requestStatus = 'none';
      print('   ⚠️ No messages yet! Status: none');
    } else if (firstMessageSenderId == currentUserId) {
      // ✅ I sent the first message = I'm the SENDER = always accepted for me
      requestStatus = 'accepted';
      print('   ✅ I am the SENDER (sent first message) - status: accepted');
    } else {
      // ✅ They sent first message = I'm the RECEIVER = pending unless friends
      requestStatus = isFriend ? 'accepted' : 'pending';
      print('   ✅ I am the RECEIVER - status: $requestStatus (friends: $isFriend)');
    }
  }
}

return Chat(
  id: user['user_id'].toString(),
  name: user['name'] ?? 'Unknown User',
  userId: user['user_id'],
  avatarUrl: user['profile_image'],
  lastMessage: existingConv.isEmpty 
      ? (user['bio'] ?? 'No bio available')
      : (existingConv['last_message'] ?? 'Start a conversation'),
  conversationId: existingConv['conversation_id'],
  unreadCount: existingConv['unread_count'] ?? 0,
  lastMessageTime: existingConv['last_message_time'],
  requestStatus: requestStatus,
  settings: ChatSettings(
    isMuted: existingConv['is_muted'] ?? false,
    isBlocked: existingConv['is_blocked'] ?? false,
    isBlockedByOther: existingConv['is_blocked_by_other'] ?? false,
    isFriend: isFriend,
  ),
);
   }).toList()
  ..sort((a, b) {
    // Sort by last message time, most recent first
    if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
    if (a.lastMessageTime == null) return 1;
    if (b.lastMessageTime == null) return -1;
    
    // ✅ FIXED: Proper comparison for descending order (most recent first)
    final comparison = b.lastMessageTime!.compareTo(a.lastMessageTime!);
    
    print('🔍 Comparing: ${a.name} (${a.lastMessageTime}) vs ${b.name} (${b.lastMessageTime}) = $comparison');
    
    return comparison;
  });
    
    // ✅ ADD DEBUG CODE HERE:
    print('📊 LOADED ${state.length} CHATS for user $currentUserId:');
    for (var chat in state) {
      if (chat.conversationId != null) {
        print('  - ${chat.name} (userId: ${chat.userId})');
        print('    requestStatus: ${chat.requestStatus}');
        print('    isFriend: ${chat.settings.isFriend}');
        print('    conversationId: ${chat.conversationId}');
        print('    lastMessage: ${chat.lastMessage}');
        print('---');
      }
    }
    
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

    Map<String, int> convToOtherUser = {};
    for (var part in (allParticipants as List)) {
      if (part['user_id'] != currentUserId) {
        convToOtherUser[part['conversation_id']] = part['user_id'] as int;
      }
    }

    // ✅ FIXED: Get MY settings with better query
 // ✅ FIXED: Get MY settings with better query
print('🔍 Loading settings for user $currentUserId, conversations: $myConvIds');

final mySettings = await supabase
    .from('conversation_settings')
    .select('conversation_id, is_muted, is_blocked, request_status, user_id')
    .eq('user_id', currentUserId)
    .inFilter('conversation_id', myConvIds);

print('🔍 Found ${(mySettings as List).length} settings rows:');
for (var setting in (mySettings as List)) {
  print('   Conv: ${setting['conversation_id']}, User: ${setting['user_id']}, Status: ${setting['request_status']}');
}
    // Get THEIR settings (check if they've blocked me)
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

    // Get unread count and last message for each conversation
// Get unread count, last message, and first message sender for each conversation
    Map<String, int> unreadCounts = {};
    Map<String, String> lastMessages = {};
    Map<String, DateTime> lastMessageTimes = {};
    Map<String, int> firstMessageSenders = {}; // ✅ NEW: Track who sent first message
    
    for (var convId in myConvIds) {
      // Count unread messages
      final unreadResponse = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', convId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);
      
      unreadCounts[convId] = (unreadResponse as List).length;
      
      // ✅ NEW: Get FIRST message to determine sender
      final firstMessageResponse = await supabase
          .from('messages')
          .select('sender_id')
          .eq('conversation_id', convId)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();
      
      if (firstMessageResponse != null) {
        firstMessageSenders[convId] = firstMessageResponse['sender_id'] as int;
      }
      
      // Get last message
      final lastMessageResponse = await supabase
          .from('messages')
          .select('content, created_at, attachment_name')
          .eq('conversation_id', convId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (lastMessageResponse != null) {
        if (lastMessageResponse['attachment_name'] != null) {
          lastMessages[convId] = '📎 ${lastMessageResponse['attachment_name']}';
        } else {
          lastMessages[convId] = lastMessageResponse['content'] ?? '';
        }
        lastMessageTimes[convId] = DateTime.parse(lastMessageResponse['created_at']);
      }
    }

    // ✅ FIXED: Build result with proper request_status
    List<Map<String, dynamic>> result = [];
    
    // Create a map for faster lookup
    Map<String, Map<String, dynamic>> settingsMap = {};
    for (var setting in (mySettings as List)) {
      settingsMap[setting['conversation_id']] = setting;
    }
    
    for (var convId in myConvIds) {
      final setting = settingsMap[convId];
      
      // ✅ CRITICAL FIX: Include ALL conversations, even without settings
   result.add({
        'conversation_id': convId,
        'other_user_id': convToOtherUser[convId],
        'is_muted': setting?['is_muted'] ?? false,
        'is_blocked': setting?['is_blocked'] ?? false,
        'is_blocked_by_other': blockedByOther[convId] ?? false,
        'my_request_status': setting?['request_status'], // Can be null
        'first_message_sender_id': firstMessageSenders[convId], // ✅ NEW
        'unread_count': unreadCounts[convId] ?? 0,
        'last_message': lastMessages[convId],
        'last_message_time': lastMessageTimes[convId],
      });
      
      // ✅ DEBUG
      print('🔍 Conv $convId: status=${setting?['request_status']}, otherUser=${convToOtherUser[convId]}');
    }

    return result;
  } catch (e) {
    print('Error loading conversation settings: $e');
    return [];
  }
}

void updateLastMessage(int userId, String message, {int? unreadCount}) {
  final newState = <Chat>[];
  Chat? updatedChat;
  
  for (final chat in state) {
    if (chat.userId == userId) {
      updatedChat = Chat(
        id: chat.id,
        name: chat.name,
        userId: chat.userId,
        avatarUrl: chat.avatarUrl,
        lastMessage: message,
        conversationId: chat.conversationId,
        settings: chat.settings,
        unreadCount: unreadCount ?? chat.unreadCount,
        lastMessageTime: DateTime.now(),
        requestStatus: chat.requestStatus,
      );
      newState.add(updatedChat);
    } else {
      newState.add(chat);
    }
  }
  
  // Sort by most recent message first
  newState.sort((a, b) {
    if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
    if (a.lastMessageTime == null) return 1;
    if (b.lastMessageTime == null) return -1;
    return b.lastMessageTime!.compareTo(a.lastMessageTime!);
  });
  
  state = newState;
  print('✅ Updated chat list - ${updatedChat?.name} moved to top');
}

// ✅ NEW: Method to mark messages as read
void markAsRead(int userId) {
  final newState = <Chat>[];
  
  for (final chat in state) {
    if (chat.userId == userId) {
      newState.add(Chat(
        id: chat.id,
        name: chat.name,
        userId: chat.userId,
        avatarUrl: chat.avatarUrl,
        lastMessage: chat.lastMessage,
        conversationId: chat.conversationId,
        settings: chat.settings,
        unreadCount: 0,
        lastMessageTime: chat.lastMessageTime,
        requestStatus: chat.requestStatus,
      ));
    } else {
      newState.add(chat);
    }
  }
  
  state = newState;
}

// ✅ NEW: Method to update request status
void updateRequestStatus(int userId, String status) {
  final newState = <Chat>[];
  
  for (final chat in state) {
    if (chat.userId == userId) {
      newState.add(Chat(
        id: chat.id,
        name: chat.name,
        userId: chat.userId,
        avatarUrl: chat.avatarUrl,
        lastMessage: chat.lastMessage,
        conversationId: chat.conversationId,
        settings: chat.settings,
        unreadCount: chat.unreadCount,
        lastMessageTime: chat.lastMessageTime,
        requestStatus: status,
      ));
    } else {
      newState.add(chat);
    }
  }
  
  state = newState;
}
// ✅ NEW: Method to update blocking status
void updateBlockStatus(int userId, bool isBlocked, bool isBlockedByOther) {
  final newState = <Chat>[];
  
  for (final chat in state) {
    if (chat.userId == userId) {
      newState.add(Chat(
        id: chat.id,
        name: chat.name,
        userId: chat.userId,
        avatarUrl: chat.avatarUrl,
        lastMessage: chat.lastMessage,
        conversationId: chat.conversationId,
        settings: ChatSettings(
          isMuted: chat.settings.isMuted,
          isBlocked: isBlocked,
          isBlockedByOther: isBlockedByOther,
          isFriend: chat.settings.isFriend,
        ),
        unreadCount: chat.unreadCount,
        lastMessageTime: chat.lastMessageTime,
        requestStatus: chat.requestStatus,
      ));
    } else {
      newState.add(chat);
    }
  }
  
  state = newState;
}

}

// Provider for chats list
final chatsProvider = StateNotifierProvider.family<ChatsNotifier, List<Chat>, int>((ref, userId) {
  return ChatsNotifier(userId);
});

// StateProvider for search query
// StateProvider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// ✅ NEW: Provider for message requests (pending)
// ✅ FIXED: Provider for message requests (only show users who have SENT messages)
final messageRequestsProvider = Provider.family<List<Chat>, int>((ref, userId) {
  final chats = ref.watch(chatsProvider(userId));
  
  // ✅ DEBUG: Print all chats to see what we have
  print('🔍 MESSAGE REQUESTS FILTER for user $userId:');
  print('   Total chats: ${chats.length}');
  
  final filtered = chats.where((c) {
    final matches = c.requestStatus == 'pending' && 
        c.conversationId != null && 
        c.lastMessage.isNotEmpty && 
        c.lastMessage != 'No bio available' && 
        c.lastMessage != 'Start a conversation';
    
    if (c.conversationId != null) {
      print('   - ${c.name}: requestStatus=${c.requestStatus}, hasConv=${c.conversationId != null}, lastMsg="${c.lastMessage}", matches=$matches');
    }
    
    return matches;
  }).toList();
  
  print('   ✅ Filtered requests: ${filtered.length}');
  return filtered;
});

// Provider for filtered chats
// Provider for filtered chats (accepted conversations only)
// Provider for filtered chats (accepted conversations only)
final filteredChatsProvider = Provider.family<List<Chat>, int>((ref, userId) {
  final chats = ref.watch(chatsProvider(userId));
  final query = ref.watch(searchQueryProvider).toLowerCase();
  
  if (query.isNotEmpty) {
    // ✅ When searching, show ALL users (friends and non-friends)
    return chats.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.lastMessage.toLowerCase().contains(query))
        .toList();
  }
  
  // ✅ When NOT searching, show ALL chats with accepted status
  // (includes both friends AND accepted message requests)
  return chats
      .where((c) => c.requestStatus == 'accepted')
      .toList();
});
// StateNotifier for managing messages in a conversation
class MessagesNotifier extends StateNotifier<List<Message>> {
  MessagesNotifier() : super(const []);

  Future<void> loadMessages(String conversationId) async {
    try {
      print('🔍 MessagesNotifier: Loading messages for $conversationId');
      
      final response = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      print('🔍 MessagesNotifier: Got ${(response as List).length} messages from DB');

      state = (response as List)
          .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
          .toList();
          
      print('✅ MessagesNotifier: State updated with ${state.length} messages');
    } catch (e) {
      print('❌ Error loading messages: $e');
      rethrow;
    }
  }

  void addMessage(Message message) {
    if (!state.any((m) => m.id == message.id)) {
      state = [...state, message];
      print('➕ Added message to state: ${message.content}');
    }
  }

  void clearMessages() {
    state = [];
  }
}
// Provider for messages (parameterized by conversation ID)
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<Message>, String?>(
  (ref, conversationId) {
    final notifier = MessagesNotifier();
    // ✅ Auto-load messages when conversationId is provided
    if (conversationId != null && conversationId.isNotEmpty) {
      Future.microtask(() => notifier.loadMessages(conversationId));
    }
    return notifier;
  },
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


class _ChatsListPageState extends ConsumerState<ChatsListPage> 
    with SingleTickerProviderStateMixin { // ✅ NEW: Added mixin for TabController
  late TextEditingController searchController;
  late TabController _tabController; // ✅ NEW
  bool isLoading = true;

  @override
void initState() {
  super.initState();
  searchController = TextEditingController();
  _tabController = TabController(length: 2, vsync: this); // ✅ NEW: 2 tabs
  loadChats();

  searchController.addListener(() {
    ref.read(searchQueryProvider.notifier).state = searchController.text;
  });
}


 Future<void> loadChats() async {
  if (mounted) {
    setState(() => isLoading = true);
  }
  
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
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}
  Widget buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

void startChatWithUser(int userId) {
  final chats = ref.read(chatsProvider(widget.currentUserId));
  final chat = chats.firstWhere((c) => c.userId == userId);
  
  // Mark as read immediately when opening
  ref.read(chatsProvider(widget.currentUserId).notifier).markAsRead(userId);
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatRoomPage(
        chat: chat,
        currentUserId: widget.currentUserId,
      ),
    ),
  );
  // ✅ REMOVED manual reload - real-time subscription handles it automatically
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

  // ✅ NEW: Format timestamp for chat list
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Today: show time
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // This week: show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Older: show date
      return '${dateTime.day}/${dateTime.month}/${dateTime.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
     final filteredChats = ref.watch(filteredChatsProvider(widget.currentUserId));
  final requests = ref.watch(messageRequestsProvider(widget.currentUserId)); // ✅ NEW


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
  preferredSize: const Size.fromHeight(130), // ✅ NEW: Increased for tabs
  child: Column(
    children: [
      // Search bar
      Container(
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
      // ✅ NEW: Tabs
      Container(
        color: AppColors.primary,
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Chats'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (requests.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${requests.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ],
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
    : TabBarView(
        controller: _tabController,
        children: [
          _buildChatsList(filteredChats),
          _buildRequestsList(requests),
        ],
      ),
floatingActionButton: FloatingActionButton(
  backgroundColor: AppColors.primary,
  elevation: 3,
  onPressed: openNewMessage,
  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
),
    );
  } // ← This closes the build method

// ✅ NEW: Build regular chats list
Widget _buildChatsList(List<Chat> chats) {
  if (chats.isEmpty) {
    return Center(
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
    );
  }

  return RefreshIndicator(
    onRefresh: loadChats,
    color: AppColors.primary,
    child: ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.divider,
        indent: 88,
        endIndent: 16,
      ),
itemBuilder: (context, index) {
  final chat = chats[index];
  final hasUnread = chat.unreadCount > 0;
  final isSearching = searchController.text.isNotEmpty;
final showNotFriendsIndicator = isSearching && !chat.settings.isFriend;
  
  return Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: () => startChatWithUser(chat.userId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              children: [
                buildAvatar(chat.name, chat.avatarUrl, 28),
                if (!showNotFriendsIndicator) // ✅ Only show online indicator for friends
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
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.settings.isMuted && !showNotFriendsIndicator)
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
                      // ✅ NEW: Show "Not Friends" indicator when searching
                      if (showNotFriendsIndicator)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_outlined,
                                  size: 12,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Not Friends',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (chat.settings.isBlocked && !showNotFriendsIndicator)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.block_rounded,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                        ),
                      if (chat.settings.isBlockedByOther && !chat.settings.isBlocked && !showNotFriendsIndicator)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 14,
                            color: Colors.red[700],
                          ),
                        ),
                      if (!showNotFriendsIndicator) // ✅ Only show status text for friends
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
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              color: (chat.settings.isBlocked || chat.settings.isBlockedByOther)
                                  ? Colors.orange[700]
                                  : (hasUnread ? AppColors.textPrimary : AppColors.textSecondary),
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (chat.lastMessageTime != null && !showNotFriendsIndicator)
                  Text(
                    _formatTimestamp(chat.lastMessageTime!),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                if (hasUnread && !showNotFriendsIndicator) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(minWidth: 24),
                    child: Center(
                      child: Text(
                        chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else if (chat.lastMessageTime == null && !showNotFriendsIndicator)
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.5), size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
},
    ),
  );
}

// ✅ NEW: Build message requests list
Widget _buildRequestsList(List<Chat> requests) {
  if (requests.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            'No message requests',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textPrimary,
             fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Requests from people who aren\'t your friends will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  return RefreshIndicator(
    onRefresh: loadChats,
    color: AppColors.primary,
    child: ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.divider,
        indent: 88,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final chat = requests[index];
        final hasUnread = chat.unreadCount > 0;
        
        return Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => startChatWithUser(chat.userId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  buildAvatar(chat.name, chat.avatarUrl, 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.name,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chat.lastMessage.isEmpty ? 'New message request' : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chat.lastMessageTime != null)
                        Text(
                          _formatTimestamp(chat.lastMessageTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      if (hasUnread) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

@override
void dispose() {
  searchController.dispose();
  _tabController.dispose();
  super.dispose();
}}
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
    
    // ✅ Check if blocked initially
    await _checkIfBlockedByOther();
    
    await loadMessages();
    subscribeToMessages();
    
    // ✅ NEW: Subscribe to settings changes in real-time
    _subscribeToSettingsChanges();
    
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
  final isBlockedByOther = otherUserSettings['is_blocked'] ?? false;
  
  // ✅ ONLY UPDATE THE PROVIDER (no setState needed)
  ref
      .read(chatsProvider(currentUserId).notifier)
      .updateBlockStatus(
        widget.chat.userId,
        widget.chat.settings.isBlocked,
        isBlockedByOther,
      );
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
    print('🆕 Created conversation: $conversationId');

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
    print('✅ Added participants: $currentUserId and ${widget.chat.userId}');

    // ✅ FIXED: Check actual friendship in database
    final friendshipCheck = await supabase
        .from('friendships')
        .select('status')
        .eq('status', 'accepted')
        .or('and(user_id.eq.$currentUserId,friend_id.eq.${widget.chat.userId}),and(user_id.eq.${widget.chat.userId},friend_id.eq.$currentUserId)')
        .maybeSingle();

    final areFriends = friendshipCheck != null;

    print('🔐 Creating conversation settings:');
    print('   Sender (me): $currentUserId');
    print('   Receiver: ${widget.chat.userId}');
    print('   Are friends: $areFriends');

    // ✅ For SENDER (currentUserId): ALWAYS accepted (they initiated)
    try {
      await supabase.from('conversation_settings').insert({
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'is_muted': false,
        'is_blocked': false,
        'request_status': 'accepted',
      });
      print('   ✅ Created sender settings with status: accepted');
    } catch (e) {
      print('   ❌ Error creating sender settings: $e');
      rethrow;
    }

    // ✅ For RECEIVER (widget.chat.userId): pending if NOT friends, accepted if friends
  // ✅ For RECEIVER (widget.chat.userId): pending if NOT friends, accepted if friends
    final receiverStatus = areFriends ? 'accepted' : 'pending';
    
    // ✅ CRITICAL FIX: Insert BOTH settings in ONE operation
    try {
      await supabase.from('conversation_settings').insert([
        {
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'is_muted': false,
          'is_blocked': false,
          'request_status': 'accepted', // Sender is ALWAYS accepted
        },
        {
          'conversation_id': conversationId,
          'user_id': widget.chat.userId,
          'is_muted': false,
          'is_blocked': false,
          'request_status': receiverStatus, // Receiver: pending if not friends
        },
      ]);
      print('   ✅ Created settings for BOTH users:');
      print('      - Sender ($currentUserId): accepted');
      print('      - Receiver (${widget.chat.userId}): $receiverStatus');
    } catch (e) {
      print('   ❌ Error creating conversation settings: $e');
      rethrow;
    }
    // ✅ Verify settings were created
    final verifySettings = await supabase
        .from('conversation_settings')
        .select('*')
        .eq('conversation_id', conversationId!);
    
    print('   🔍 Verification: Found ${(verifySettings as List).length} settings rows for this conversation');
    for (var setting in (verifySettings as List)) {
      print('      User ${setting['user_id']}: status=${setting['request_status']}');
    }

  } catch (e) {
    print('❌ Error creating conversation: $e');
    rethrow;
  }
}
  Future<void> loadMessages() async {
  if (conversationId == null) {
    print('⚠️ Cannot load messages: conversationId is null');
    return;
  }

  try {
    print('📨 Loading messages for conversation: $conversationId');
    
    await ref.read(messagesProvider(conversationId).notifier).loadMessages(conversationId!);
    
    final loadedMessages = ref.read(messagesProvider(conversationId));
    print('✅ Loaded ${loadedMessages.length} messages');
    
    // ✅ Only mark as read if NOT pending (receiver shouldn't auto-mark as read until accepting)
    if (widget.chat.requestStatus != 'pending') {
      await _markMessagesAsRead();
      await ref.read(chatsProvider(currentUserId).notifier).loadChats();
    } else {
      print('⏸️ Request is pending, not marking as read yet');
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToBottom();
    });
  } catch (e) {
    print('❌ Error loading messages: $e');
  }
}

  // ✅ NEW: Mark all unread messages as read
  Future<void> _markMessagesAsRead() async {
    if (conversationId == null) return;
    
    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId!)
          .eq('is_read', false)
          .neq('sender_id', currentUserId); // Don't mark own messages
    } catch (e) {
      print('Error marking messages as read: $e');
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
          
          // If message is from OTHER user (not me), mark it as read since I'm viewing the chat
          if (newMessage.senderId != currentUserId) {
            _markMessagesAsRead();
            // Update chat list with unread count = 0 since we're in the chat
            ref
              .read(chatsProvider(currentUserId).notifier)
              .updateLastMessage(widget.chat.userId, newMessage.content, unreadCount: 0);
          } else {
            // My own message - just update the last message
            ref
              .read(chatsProvider(currentUserId).notifier)
              .updateLastMessage(widget.chat.userId, newMessage.content);
          }

          scrollToBottom();
        },
      )
      .subscribe();
}
void _subscribeToSettingsChanges() {
  if (conversationId == null) return;

  supabase
      .channel('settings:$conversationId:${widget.chat.userId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_settings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) async {
          print('🔔 Settings changed in chat room: ${payload.newRecord}');
          
          final record = payload.newRecord;
          final settingsUserId = record['user_id'] as int?;
          
          // ✅ Only react if OTHER user changed their settings
          if (settingsUserId == widget.chat.userId) {
            final isBlockedByOther = record['is_blocked'] as bool? ?? false;
            
            print('🚫 Other user block status changed: $isBlockedByOther');
            
            // Update provider
            ref
                .read(chatsProvider(currentUserId).notifier)
                .updateBlockStatus(
                  widget.chat.userId,
                  widget.chat.settings.isBlocked,
                  isBlockedByOther,
                );
            
            // Force UI update
            if (mounted) {
              setState(() {});
            }
            
            // Show notification if just got blocked
            if (isBlockedByOther && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${widget.chat.name} has blocked you',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red[700],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      )
      .subscribe();
  
  print('✅ Subscribed to settings changes for conversation $conversationId');
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
        'is_read': false, // ✅ FIXED: Start as unread so receiver sees unread badge
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
// ✅ NEW: Accept message request
// ✅ FIXED: Accept message request with proper upsert
Future<void> _acceptRequest() async {
  if (conversationId == null) return;

  try {
    print('🔄 Accepting request for conversation: $conversationId, user: $currentUserId');
    
    // ✅ Check if settings row exists
    final existing = await supabase
        .from('conversation_settings')
        .select('id, request_status')
        .eq('conversation_id', conversationId!)
        .eq('user_id', currentUserId)
        .maybeSingle();

    print('🔍 Existing settings: $existing');

    if (existing != null) {
      // Update existing row
      await supabase
          .from('conversation_settings')
          .update({
            'request_status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId!)
          .eq('user_id', currentUserId);
      
      print('✅ Updated existing settings to accepted');
    } else {
      // Insert new row if it doesn't exist
      await supabase.from('conversation_settings').insert({
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'is_muted': false,
        'is_blocked': false,
        'request_status': 'accepted',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Inserted new settings row with accepted status');
    }

    // ✅ Verify the update worked
    final verify = await supabase
        .from('conversation_settings')
        .select('request_status')
        .eq('conversation_id', conversationId!)
        .eq('user_id', currentUserId)
        .single();
    
    print('✅ Verification: request_status is now ${verify['request_status']}');

    // Update the provider
    ref
        .read(chatsProvider(currentUserId).notifier)
        .updateRequestStatus(widget.chat.userId, 'accepted');
    

    if (mounted) {
      // Mark messages as read now that request is accepted
      await _markMessagesAsRead();
      
      // Update the local state
      setState(() {
        // Force a rebuild with the new status
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Message request accepted'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // ✅ IMPORTANT: Don't pop immediately - let user see the accepted state
      // The banner will disappear automatically after setState
    }
  } catch (e) {
    print('❌ Error accepting request: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
// ✅ NEW: Decline message request
Future<void> _declineRequest() async {
  if (conversationId == null) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Decline Request?'),
      content: const Text('This conversation will be removed from your requests.'),
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
          child: const Text('Decline'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await supabase
        .from('conversation_settings')
        .update({'request_status': 'declined'})
        .eq('conversation_id', conversationId!)
        .eq('user_id', currentUserId);

    ref
        .read(chatsProvider(currentUserId).notifier)
        .updateRequestStatus(widget.chat.userId, 'declined');

    if (mounted) {
      Navigator.pop(context); // Go back to chat list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message request declined'),
          backgroundColor: Colors.orange[600],
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
  if (conversationId == null) return;

  setState(() => isSending = true);

  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last;
    final uniqueFileName = '$conversationId/$timestamp.$extension';

    // ✅ FIXED: Changed from 'chat-attachments' to 'chat_attachments'
    await supabase.storage
        .from('chat_attachments')
        .uploadBinary(
          uniqueFileName,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    // ✅ FIXED: Changed from 'chat-attachments' to 'chat_attachments'
    final publicUrl = supabase.storage
        .from('chat_attachments')
        .getPublicUrl(uniqueFileName);

    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': fileName,
      'attachment_url': publicUrl,
      'attachment_type': mimeType,
      'attachment_name': fileName,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
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
  if (conversationId == null) return;

  setState(() => isSending = true);

  try {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last;
    final uniqueFileName = '$conversationId/$timestamp.$extension';

    // ✅ FIXED: Changed from 'chat-attachments' to 'chat_attachments'
    await supabase.storage
        .from('chat_attachments')
        .uploadBinary(
          uniqueFileName,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );

    // ✅ FIXED: Changed from 'chat-attachments' to 'chat_attachments'
    final publicUrl = supabase.storage
        .from('chat_attachments')
        .getPublicUrl(uniqueFileName);

    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': fileName,
      'attachment_url': publicUrl,
      'attachment_type': mimeType,
      'attachment_name': fileName,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
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
  final messages = ref.watch(messagesProvider(conversationId));
  
  // ✅ Watch the chats provider to get real-time updates
  final chats = ref.watch(chatsProvider(currentUserId));
  final currentChat = chats.firstWhere(
    (c) => c.userId == widget.chat.userId,
    orElse: () => widget.chat,
  );
  
  // ✅ Use values from currentChat (provider), not from widget.chat
  final isBlocked = currentChat.settings.isBlocked;
  final isBlockedByOther = currentChat.settings.isBlockedByOther;
  final cannotSend = isBlocked || isBlockedByOther;
  final isPending = currentChat.requestStatus == 'pending';
  
  // ✅ KEY FIX: Determine if I'm the receiver (they sent first message)
// ✅ KEY FIX: Determine if I'm the receiver (they sent first message)
// messages list is sorted by created_at ascending, so first item is the oldest/first message
final firstMessageSenderId = messages.isNotEmpty ? messages.first.senderId : null;
final isReceiver = firstMessageSenderId != null && firstMessageSenderId != currentUserId;

print('🔍 Banner Check:');
print('   isPending: $isPending');
print('   firstMessageSenderId: $firstMessageSenderId');
print('   currentUserId: $currentUserId');
print('   isReceiver: $isReceiver');
print('   showRequestBanner: ${isPending && isReceiver}');
  final showRequestBanner = isPending && isReceiver;
    
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
            buildAvatar(currentChat.name, currentChat.avatarUrl, 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentChat.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                 Text(
  isPending 
      ? 'Message Request' 
      : (isBlockedByOther ? 'Blocked you' : 'Online'),
  style: TextStyle(
    color: isPending 
        ? Colors.orange[200]
        : (isBlockedByOther 
            ? Colors.red[200]
            : Colors.white.withOpacity(0.8)),
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
                            'You blocked ${currentChat.name}',
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
                            '${currentChat.name} has blocked you',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
          
               ,
      // ✅ Messages area
     Expanded(
                  child: Column(
                    children: [
                      // ✅ Show Accept/Decline banner for RECEIVER with pending status
                      if (showRequestBanner) 
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.blue[200]!, width: 1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${currentChat.name} wants to send you a message',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _declineRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        foregroundColor: Colors.grey[800],
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _acceptRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      // ✅ Messages area
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
                    ],
                  ),
                ),
                // ✅ FIXED: Hide input field completely for pending requests
                if (!showRequestBanner)
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
        'request_status': 'accepted',
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
        'is_blocked': value,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('conversation_id', widget.conversationId)
      .eq('user_id', widget.currentUserId);
} else {
  await supabase.from('conversation_settings').insert({
    'conversation_id': widget.conversationId,
    'user_id': widget.currentUserId,
    'is_muted': false,
    'is_blocked': value,
     'request_status': 'accepted',
  });
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