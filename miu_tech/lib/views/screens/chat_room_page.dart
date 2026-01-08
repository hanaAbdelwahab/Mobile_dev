import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  
  // Mock current user ID (same as everywhere else)
  final String mockCurrentUserId = "11111111-1111-1111-1111-111111111111";

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    try {
      print('💬 Fetching messages for conversation: ${widget.conversationId}');
      
      final response = await supabase
          .from('messages')
          .select('id, content, sender_id, created_at, users(username)')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('✅ Messages fetched: ${(response as List).length}');

      setState(() {
        messages = (response as List).map((msg) {
          return {
            'id': msg['id'],
            'content': msg['content'],
            'sender_id': msg['sender_id'],
            'created_at': msg['created_at'],
            'sender_name': msg['users']['username'] ?? 'Unknown',
            'isMe': msg['sender_id'] == mockCurrentUserId,
          };
        }).toList();
        loading = false;
      });

      // Scroll to bottom after loading
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });

    } catch (e) {
      print('❌ Error fetching messages: $e');
      setState(() {
        messages = [];
        loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      print('📤 Sending message...');
      
      await supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': mockCurrentUserId,
        'content': text,
      });

      print('✅ Message sent');

      _messageController.clear();
      
      // Refresh messages
      await fetchMessages();

    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.red[700],
              child: Text(
                widget.otherUserName
                    .split(' ')
                    .map((e) => e.isNotEmpty ? e[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.red[700],
                    ),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey[300],
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
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['isMe'] ?? false;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? LinearGradient(
                                        colors: [Colors.red[700]!, Colors.red[600]!],
                                      )
                                    : null,
                                color: isMe ? null : Colors.grey[200],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(Icons.image, color: Colors.red[700]),
                                  title: const Text('Image'),
                                  onTap: () {
                                    print('Image clicked');
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: Icon(Icons.attach_file, color: Colors.red[700]),
                                  title: const Text('Document'),
                                  onTap: () {
                                    print('Document clicked');
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: Icon(Icons.camera_alt, color: Colors.red[700]),
                                  title: const Text('Camera'),
                                  onTap: () {
                                    print('Camera clicked');
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.add_circle, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[700]!, Colors.red[600]!],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}