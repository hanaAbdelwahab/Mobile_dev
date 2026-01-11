import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  int _unreadCount = 0;
  bool _isLoading = false;
  int? _currentUserId; // ✅ NEW: Track which user we're monitoring
  final Set<int> _unreadSenders = {};
  final Set<int> _readSenders = {};
  
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  Set<int> get unreadSenders => _unreadSenders;
  bool get isInitialized => _currentUserId != null; // ✅ NEW

  bool hasUnreadFrom(int userId) {
    return _unreadSenders.contains(userId);
  }

  // ✅ NEW: Initialize with user ID (call this once when app starts)
  void initialize(int currentUserId) {
    if (_currentUserId != currentUserId) {
      debugPrint('🎯 Initializing MessageProvider for user $currentUserId');
      _currentUserId = currentUserId;
      loadUnreadCount(currentUserId);
      subscribeToMessages(currentUserId);
    }
  }

  // ✅ FIXED: Only count unread messages from ACCEPTED conversations
  Future<void> loadUnreadCount(int currentUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📊 Loading unread messages for user $currentUserId...');

      // ✅ STEP 1: Get all conversations where current user is a participant
      final myConversations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      if ((myConversations as List).isEmpty) {
        _unreadCount = 0;
        _unreadSenders.clear();
        debugPrint('✅ No conversations found');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final conversationIds = myConversations
          .map((p) => p['conversation_id'] as String)
          .toList();

      debugPrint('🔍 Found ${conversationIds.length} conversations');

      // ✅ STEP 2: Get MY settings for these conversations (only accepted ones)
      final mySettings = await _supabase
          .from('conversation_settings')
          .select('conversation_id, request_status')
          .eq('user_id', currentUserId)
          .inFilter('conversation_id', conversationIds);

      // ✅ Filter to only ACCEPTED conversations
      final acceptedConversationIds = <String>[];
      for (var setting in (mySettings as List)) {
        // ✅ Only include if status is 'accepted' OR null (backwards compatibility)
        final status = setting['request_status'];
        if (status == 'accepted' || status == null) {
          acceptedConversationIds.add(setting['conversation_id'] as String);
        }
      }

      debugPrint('✅ Found ${acceptedConversationIds.length} accepted conversations');

      if (acceptedConversationIds.isEmpty) {
        _unreadCount = 0;
        _unreadSenders.clear();
        debugPrint('✅ No accepted conversations');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // ✅ STEP 3: Get unread messages ONLY from accepted conversations
      final unreadMessages = await _supabase
          .from('messages')
          .select('sender_id, conversation_id')
          .eq('is_read', false)
          .neq('sender_id', currentUserId)
          .inFilter('conversation_id', acceptedConversationIds)
          .order('created_at', ascending: false);

      final messages = unreadMessages as List;

      if (messages.isEmpty) {
        _unreadCount = 0;
        _unreadSenders.clear();
        debugPrint('✅ No unread messages in accepted conversations');
      } else {
        // Count unique senders who aren't in the "read" list
        _unreadSenders.clear();
        for (var msg in messages) {
          final senderId = msg['sender_id'] as int;
          
          if (!_readSenders.contains(senderId)) {
            _unreadSenders.add(senderId);
          }
        }

        _unreadCount = _unreadSenders.length;
        debugPrint('✅ Unread conversations: $_unreadCount');
        debugPrint('✅ Unread from users: ${_unreadSenders.toList()}');
        debugPrint('✅ Read senders: ${_readSenders.toList()}');
      }
      
    } catch (e) {
      debugPrint('❌ Error loading unread count: $e');
      _unreadCount = 0;
      _unreadSenders.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Mark chat with specific user as read
  void markChatAsRead(int otherUserId, int currentUserId) {
    debugPrint('📝 Marking chat with user $otherUserId as read');
    
    _readSenders.add(otherUserId);
    _unreadSenders.remove(otherUserId);
    
    // Update count immediately
    _unreadCount = _unreadSenders.length;
    notifyListeners();
    
    // Reload count in background to sync with database
    loadUnreadCount(currentUserId);
  }

  // ✅ Subscribe to real-time message updates
  void subscribeToMessages(int currentUserId) {
    try {
      debugPrint('🔔 Subscribing to new messages for user $currentUserId...');
      
      // Remove any existing subscription first
      _supabase.removeChannel(_supabase.channel('messages_notifications'));
      
      _supabase
          .channel('messages_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newMessage = payload.newRecord;
              final senderId = newMessage['sender_id'] as int?;
              
              debugPrint('🔔 New message from sender: $senderId');
              
              // If message is not from current user, reload count
              if (senderId != null && senderId != currentUserId) {
                loadUnreadCount(currentUserId);
              }
            },
          )
          .subscribe();
      
      debugPrint('✅ Subscribed to real-time messages');
    } catch (e) {
      debugPrint('❌ Error subscribing to messages: $e');
    }
  }

  // ✅ Unsubscribe from real-time updates
  void unsubscribe() {
    try {
      _supabase.removeAllChannels();
      debugPrint('✅ Unsubscribed from messages');
    } catch (e) {
      debugPrint('❌ Error unsubscribing: $e');
    }
  }

  // ✅ Reset everything (on logout)
  void reset() {
    _unreadCount = 0;
    _readSenders.clear();
    _unreadSenders.clear();
    _currentUserId = null;
    unsubscribe();
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}