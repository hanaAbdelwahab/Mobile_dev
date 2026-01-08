import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get Supabase client
final supabase = Supabase.instance.client;

// MOCKED USER ID - Currently set to your test user
const String MOCKED_USER_ID = '11111111-1111-1111-1111-111111111111';

// --------------------- Helper Functions ---------------------
/// Safely builds a CircleAvatar with initials or network image
CircleAvatar buildAvatarHelper(String name, String? avatarUrl, double radius) {
  if (avatarUrl != null && avatarUrl.isNotEmpty && Uri.tryParse(avatarUrl)?.hasAbsolutePath == true) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(avatarUrl),
      backgroundColor: Colors.red[700],
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
    backgroundColor: Colors.red[700],
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white, 
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}

// --------------------- Models ---------------------
class Chat {
  final String id;
  final String name;
  final String userId;
  final String? avatarUrl;
  String lastMessage;
  ChatSettings settings;

  Chat({
    required this.id,
    required this.name,
    required this.userId,
    this.avatarUrl,
    required this.lastMessage,
    required this.settings,
  });
}

class ChatSettings {
  bool isMuted;
  bool isBlocked;
  
  ChatSettings({this.isMuted = false, this.isBlocked = false});

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    return ChatSettings(
      isMuted: json['is_muted'] ?? false,
      isBlocked: json['is_blocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_muted': isMuted,
      'is_blocked': isBlocked,
    };
  }
}

class Message {
  final String id;
  final String senderId;
  final String conversationId;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.conversationId,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      conversationId: json['conversation_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// --------------------- Chats List ---------------------
class ChatsListPage extends StatefulWidget {
  final Function(String userName)? onSendPost;
  
  const ChatsListPage({super.key, this.onSendPost});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  List<Chat> chats = [];
  List<Chat> filteredChats = [];
  late TextEditingController searchController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    loadChats();

    searchController.addListener(() {
      final query = searchController.text.toLowerCase();
      setState(() {
        filteredChats = chats
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.lastMessage.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  Future<void> loadChats() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Fetch all users from Supabase
      final response = await supabase
          .from('users')
          .select('id, username, profile_url, bio, role, location, institution, experience, skills')
          .order('username');

      final usersList = response as List;

      // Get all conversations where current user is a participant
      final myConversations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', MOCKED_USER_ID);

      final myConversationIds = (myConversations as List)
          .map((p) => p['conversation_id'] as String)
          .toList();

      print('Found ${myConversationIds.length} conversations for current user');

      // Create a map: otherUserId -> settings
      Map<String, ChatSettings> settingsMap = {};

      if (myConversationIds.isNotEmpty) {
        // For each conversation, find the other participant and get settings
        for (var conversationId in myConversationIds) {
          try {
            // Get all participants in this conversation
            final participants = await supabase
                .from('conversation_participants')
                .select('user_id')
                .eq('conversation_id', conversationId);

            // Find the other user (not me)
            String? otherUserId;
            for (var participant in participants) {
              if (participant['user_id'] != MOCKED_USER_ID) {
                otherUserId = participant['user_id'];
                break;
              }
            }

            if (otherUserId != null) {
              // Get my settings for this conversation
              final settingsResult = await supabase
                  .from('conversation_settings')
                  .select('is_muted, is_blocked')
                  .eq('conversation_id', conversationId)
                  .eq('user_id', MOCKED_USER_ID)
                  .maybeSingle();

              if (settingsResult != null) {
                settingsMap[otherUserId] = ChatSettings.fromJson(settingsResult);
                print('✓ Loaded settings for user $otherUserId: muted=${settingsResult['is_muted']}, blocked=${settingsResult['is_blocked']}');
              }
            }
          } catch (e) {
            print('Error loading settings for conversation $conversationId: $e');
          }
        }
      }

      setState(() {
        chats = usersList.map((user) {
          final userId = user['id'] as String;
          final settings = settingsMap[userId] ?? ChatSettings();
          
          return Chat(
            id: userId,
            name: user['username'] ?? 'Unknown User',
            userId: userId,
            avatarUrl: user['profile_url'],
            lastMessage: user['bio'] ?? 'No bio available',
            settings: settings,
          );
        }).toList();
        filteredChats = chats;
        isLoading = false;
      });

      print('✓ Chat list loaded with ${chats.length} users');
    } catch (e) {
      print('❌ Error loading chats: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  CircleAvatar buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  void startChatWithUser(String userId) async {
    final chat = chats.firstWhere((c) => c.userId == userId);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(chat: chat),
      ),
    );
    
    // Reload chats when returning to update muted icons
    if (result == true) {
      loadChats();
    }
  }

  void openNewMessage() {
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: "Search users...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[700],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredChats.isEmpty
              ? const Center(child: Text("No users found"))
              : RefreshIndicator(
                  onRefresh: loadChats,
                  child: ListView.builder(
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return ListTile(
                        leading: buildAvatar(chat.name, chat.avatarUrl, 25),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (chat.settings.isMuted)
                              Icon(
                                Icons.notifications_off,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                          ],
                        ),
                        subtitle: Text(
                          chat.lastMessage.isEmpty ? 'Start a conversation' : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (widget.onSendPost != null) {
                            widget.onSendPost!(chat.userId);
                          } else {
                            startChatWithUser(chat.userId);
                          }
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red[700],
        child: const Icon(Icons.message, color: Colors.white),
        onPressed: openNewMessage,
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
  final Function(String userId) onStartChat;
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

  CircleAvatar buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        backgroundColor: Colors.red[700],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return ListTile(
                        leading: buildAvatar(user.name, user.avatarUrl, 25),
                        title: Text(user.name),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onStartChat(user.userId);
                        },
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
class ChatRoomPage extends StatefulWidget {
  final Chat chat;
  const ChatRoomPage({super.key, required this.chat});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  List<Message> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool isLoading = true;
  bool isSending = false;
  String? conversationId;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    initializeChat();
  }

  Future<void> initializeChat() async {
    try {
      // Set mocked user ID
      currentUserId = MOCKED_USER_ID;

      print('🚀 Initializing chat with user ID: $currentUserId');

      // Check if user exists in database
      try {
        final userCheck = await supabase
            .from('users')
            .select('id, username')
            .eq('id', currentUserId!)
            .maybeSingle();
        
        if (userCheck == null) {
          setState(() {
            isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ User ID 11111111-1111-1111-1111-111111111111 not found in database. Please run add_test_user.sql first.'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        print('✓ User found: ${userCheck['username']}');
      } catch (e) {
        print('Error checking user: $e');
      }

      // Find or create conversation
      await findOrCreateConversation();
      
      // Load conversation settings
      await loadConversationSettings();
      
      // Load messages
      await loadMessages();
      
      // Subscribe to new messages
      subscribeToMessages();
      
      setState(() {
        isLoading = false;
      });
      
      print('✓ Chat initialized successfully');
    } catch (e) {
      print('❌ Error initializing chat: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> findOrCreateConversation() async {
    try {
      print('🔍 Looking for existing conversation...');
      
      // Find conversation where both users are participants
      final participantsResponse = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId!);

      final myConversations = (participantsResponse as List)
          .map((p) => p['conversation_id'] as String)
          .toList();

      print('Found ${myConversations.length} conversations for current user');

      if (myConversations.isEmpty) {
        // Create new conversation
        await createNewConversation();
        return;
      }

      // Check which of my conversations includes the other user
      final otherUserParticipants = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', widget.chat.userId)
          .inFilter('conversation_id', myConversations);

      if ((otherUserParticipants as List).isNotEmpty) {
        conversationId = otherUserParticipants[0]['conversation_id'];
        print('✓ Found existing conversation: $conversationId');
      } else {
        // Create new conversation
        await createNewConversation();
      }
    } catch (e) {
      print('❌ Error finding/creating conversation: $e');
      rethrow;
    }
  }

  Future<void> createNewConversation() async {
    try {
      print('📝 Creating new conversation...');
      
      // Create new conversation
      final newConversation = await supabase
          .from('conversations')
          .insert({
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      conversationId = newConversation['id'];
      print('✓ Created conversation: $conversationId');

      // Add both participants
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
      
      print('✓ Added participants to conversation');

      // Create default settings for both users
      await supabase.from('conversation_settings').insert([
        {
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'is_muted': false,
          'is_blocked': false,
        },
        {
          'conversation_id': conversationId,
          'user_id': widget.chat.userId,
          'is_muted': false,
          'is_blocked': false,
        },
      ]);
      
      print('✓ Created default settings for both users');
    } catch (e) {
      print('❌ Error creating conversation: $e');
      rethrow;
    }
  }

  Future<void> loadConversationSettings() async {
    if (conversationId == null || currentUserId == null) return;

    try {
      print('⚙️ Loading conversation settings...');
      
      final response = await supabase
          .from('conversation_settings')
          .select('*')
          .eq('conversation_id', conversationId!)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (response != null) {
        setState(() {
          widget.chat.settings = ChatSettings.fromJson(response);
        });
        print('✓ Loaded settings: muted=${widget.chat.settings.isMuted}, blocked=${widget.chat.settings.isBlocked}');
      } else {
        // Create default settings if none exist
        await supabase.from('conversation_settings').insert({
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'is_muted': false,
          'is_blocked': false,
        });
        print('✓ Created default settings');
      }
    } catch (e) {
      print('❌ Error loading conversation settings: $e');
    }
  }

  Future<void> updateConversationSettings() async {
    if (conversationId == null || currentUserId == null) return;

    try {
      print('💾 Updating conversation settings...');
      
      await supabase
          .from('conversation_settings')
          .upsert({
            'conversation_id': conversationId,
            'user_id': currentUserId,
            'is_muted': widget.chat.settings.isMuted,
            'is_blocked': widget.chat.settings.isBlocked,
          });
      
      print('✓ Settings updated successfully');
    } catch (e) {
      print('❌ Error updating conversation settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> loadMessages() async {
    if (conversationId == null) return;

    try {
      print('📨 Loading messages for conversation: $conversationId');
      
      final response = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId!)
          .order('created_at', ascending: true);

      setState(() {
        messages = (response as List)
            .map((msg) => Message.fromJson(msg))
            .toList();
      });
      
      print('✓ Loaded ${messages.length} messages');
      
      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  void subscribeToMessages() {
    if (conversationId == null) return;

    print('👂 Subscribing to real-time messages for conversation: $conversationId');

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
            print('📩 New message received: ${payload.newRecord}');
            final newMessage = Message.fromJson(payload.newRecord);
            
            // Only add if not already in list (avoid duplicates)
            if (!messages.any((m) => m.id == newMessage.id)) {
              setState(() {
                messages.add(newMessage);
                widget.chat.lastMessage = newMessage.content;
              });
              
              // Scroll to bottom when new message arrives
              scrollToBottom();
            }
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
    // Check if user is blocked
    if (widget.chat.settings.isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cannot send messages to blocked users'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate inputs
    if (messageController.text.trim().isEmpty) {
      print('⚠️ Message is empty');
      return;
    }
    
    if (conversationId == null) {
      print('⚠️ No conversation ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Conversation not initialized'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (currentUserId == null) {
      print('⚠️ No user ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ User not initialized'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isSending) {
      print('⚠️ Already sending a message');
      return;
    }

    final messageText = messageController.text.trim();
    messageController.clear();

    setState(() {
      isSending = true;
    });

    try {
      print('📤 Sending message: "$messageText" to conversation: $conversationId');
      
      // Insert message into database
      final response = await supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': messageText,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      print('✅ Message sent successfully: ${response['id']}');

      // Update conversation's last message timestamp
      await supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId!);

      widget.chat.lastMessage = messageText;
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent ✓'),
            duration: Duration(milliseconds: 1000),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      
      // Restore message text if sending failed
      messageController.text = messageText;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  Future<void> clearChat() async {
    if (conversationId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to delete all messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print('🗑️ Clearing chat history...');
      
      await supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId!);

      setState(() {
        messages.clear();
        widget.chat.lastMessage = "";
      });
      
      print('✓ Chat history cleared');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error clearing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSettingsPage(
          conversationId: conversationId,
          currentUserId: currentUserId,
          settings: widget.chat.settings,
          clearChat: clearChat,
          onSettingsChanged: () {
            // Update settings in database
            updateConversationSettings();
          },
        ),
      ),
    );

    // Reload settings when returning from settings page
    if (result == true) {
      await loadConversationSettings();
    }
  }

  void openAttachments() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attachment feature not implemented")),
    );
  }

  CircleAvatar buildAvatar(String name, String? avatarUrl, double radius) {
    return buildAvatarHelper(name, avatarUrl, radius);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return true to indicate settings may have changed
        Navigator.of(context).pop(true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              buildAvatar(widget.chat.name, widget.chat.avatarUrl, 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.chat.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: openSettings,
              icon: const Icon(Icons.settings),
            )
          ],
          backgroundColor: Colors.red[700],
        ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Show blocked user warning
                if (widget.chat.settings.isBlocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.red[50],
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have blocked ${widget.chat.name}. You cannot send or receive messages.',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[messages.length - 1 - index];
                            final isMe = message.senderId == currentUserId;
                            
                            // Show date separator if needed
                            bool showDateSeparator = false;
                            if (index == messages.length - 1) {
                              showDateSeparator = true;
                            } else {
                              // Get the previous message (the one that will be shown above this one)
                              final prevMessage = messages[messages.length - 2 - index];
                              if (message.createdAt.day != prevMessage.createdAt.day) {
                                showDateSeparator = true;
                              }
                            }
                            
                            return Column(
                              children: [
                                if (showDateSeparator)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      _formatDate(message.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 14,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 3,
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.red[700] : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.content,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black87,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTime(message.createdAt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, -1),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: openAttachments,
                          icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: messageController,
                              decoration: const InputDecoration(
                                hintText: "Type a message",
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => sendMessage(),
                              enabled: !isSending && !widget.chat.settings.isBlocked,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: (isSending || widget.chat.settings.isBlocked) 
                                ? Colors.grey 
                                : Colors.red[700],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: (isSending || widget.chat.settings.isBlocked) 
                                ? null 
                                : sendMessage,
                            icon: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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

// --------------------- Chat Settings ---------------------
class ChatSettingsPage extends StatefulWidget {
  final String? conversationId;
  final String? currentUserId;
  final ChatSettings settings;
  final VoidCallback clearChat;
  final VoidCallback onSettingsChanged;
  
  const ChatSettingsPage({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.settings,
    required this.clearChat,
    required this.onSettingsChanged,
  });

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  bool isUpdating = false;

  Future<void> updateSetting(String settingName, bool value) async {
    if (widget.conversationId == null || widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cannot update settings: conversation not initialized'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      print('💾 Updating $settingName to $value...');
      
      Map<String, dynamic> updateData = {
        'conversation_id': widget.conversationId,
        'user_id': widget.currentUserId,
      };

      if (settingName == 'mute') {
        updateData['is_muted'] = value;
        widget.settings.isMuted = value;
      } else if (settingName == 'block') {
        updateData['is_blocked'] = value;
        widget.settings.isBlocked = value;
      }

      await supabase
          .from('conversation_settings')
          .upsert(updateData);
      
      print('✓ Setting updated successfully');
      
      // Notify parent that settings changed
      widget.onSettingsChanged();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settingName == 'mute'
                  ? (value ? 'Chat muted' : 'Chat unmuted')
                  : (value ? 'User blocked' : 'User unblocked')
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating setting: $e');
      
      // Revert the change on error
      setState(() {
        if (settingName == 'mute') {
          widget.settings.isMuted = !value;
        } else if (settingName == 'block') {
          widget.settings.isBlocked = !value;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating setting: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return true to indicate settings may have changed
        Navigator.of(context).pop(true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chat Settings"),
          backgroundColor: Colors.red[700],
        ),
        body: Stack(
          children: [
            ListView(
              children: [
                SwitchListTile(
                  value: widget.settings.isMuted,
                  title: const Text("Mute Notifications"),
                  subtitle: const Text("Turn off notifications for this chat"),
                  secondary: const Icon(Icons.notifications_off),
                  activeColor: Colors.red[700],
                  onChanged: isUpdating 
                      ? null 
                      : (value) {
                          setState(() {
                            widget.settings.isMuted = value;
                          });
                          updateSetting('mute', value);
                        },
                ),
                const Divider(),
                SwitchListTile(
                  value: widget.settings.isBlocked,
                  title: const Text("Block User"),
                  subtitle: const Text("Block messages from this user"),
                  secondary: const Icon(Icons.block),
                  activeColor: Colors.red[700],
                  onChanged: isUpdating 
                      ? null 
                      : (value) {
                          setState(() {
                            widget.settings.isBlocked = value;
                          });
                          updateSetting('block', value);
                        },
                ),
                const Divider(),
                ListTile(
                  enabled: !isUpdating,
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text("Clear Chat History"),
                  subtitle: const Text("Delete all messages in this chat"),
                  onTap: () {
                    Navigator.pop(context, true);
                    widget.clearChat();
                  },
                ),
              ],
            ),
            if (isUpdating)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}