import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsProvider with ChangeNotifier {
  int? _userId;
  int _unreadCount = 0;
  List<String> _activeChannels = [];
  
  NotificationsProvider({int? userId}) {
    if (userId != null) {
      _userId = userId;
      _initializeRealtimeSubscription();
      fetchUnreadCount();
    }
  }

  int get unreadCount => _unreadCount;
  int? get userId => _userId;

  final supabase = Supabase.instance.client;

  /// Update user ID and reinitialize subscriptions
  void updateUserId(int newUserId) {
    if (_userId != newUserId) {
      print('🔄 Updating NotificationsProvider userId from $_userId to $newUserId');
      
      // Unsubscribe from old channels
      _unsubscribeAll();
      
      // Update user ID
      _userId = newUserId;
      _unreadCount = 0;
      
      // Reinitialize with new user
      _initializeRealtimeSubscription();
      fetchUnreadCount();
      
      notifyListeners();
    }
  }

  /// Fetch initial unread count
  Future<void> fetchUnreadCount() async {
    if (_userId == null) {
      print('⚠️ Cannot fetch unread count: userId is null');
      return;
    }

    try {
      print('🔔 Fetching unread notification count for user: $_userId');

      // Count unread general notifications (excluding follow_request which are in folders)
      final generalNotifications = await supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', _userId!)
          .eq('is_read', false)
          .neq('type', 'follow_request'); // Exclude follow requests

      // Count pending friend requests
      final friendRequests = await supabase
          .from('friendship_requests')
          .select('request_id')
          .eq('receiver_id', _userId!)
          .eq('status', 'pending');

      // Count pending competition requests
      final competitionRequests = await supabase
          .from('team_join_requests')
          .select('request_id')
          .eq('competition_owner_id', _userId!)
          .eq('status', 'pending');

      final totalCount = generalNotifications.length +
          friendRequests.length +
          competitionRequests.length;

      _unreadCount = totalCount;
      print('✅ Total unread notifications: $_unreadCount (General: ${generalNotifications.length}, Friends: ${friendRequests.length}, Competitions: ${competitionRequests.length})');
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching unread count: $e');
    }
  }

  /// Mark notification as read and update count
  Future<void> markAsRead(int notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);

      // Decrease count locally
      if (_unreadCount > 0) {
        _unreadCount--;
        notifyListeners();
      }
      
      print('✅ Marked notification $notificationId as read. New count: $_unreadCount');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Decrease count when request is accepted/rejected
  void decrementCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
      print('🔽 Decremented notification count to: $_unreadCount');
    }
  }

  /// Initialize realtime subscription for notifications
  void _initializeRealtimeSubscription() {
    if (_userId == null) {
      print('⚠️ Cannot initialize subscriptions: userId is null');
      return;
    }

    print('🔄 Initializing realtime subscriptions for user: $_userId');

    // Subscribe to general notifications changes
    final notificationsChannel = 'notifications_$_userId';
    _activeChannels.add(notificationsChannel);
    
    supabase
        .channel(notificationsChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('🔔 New notification received: ${payload.newRecord}');
            // Don't count follow_request notifications (they're in folders)
            if (payload.newRecord['type'] != 'follow_request') {
              _unreadCount++;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('🔄 Notification updated: ${payload.newRecord}');
            // If notification was marked as read, decrease count
            if (payload.newRecord['is_read'] == true &&
                payload.oldRecord['is_read'] == false) {
              if (_unreadCount > 0) {
                _unreadCount--;
                notifyListeners();
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('🗑️ Notification deleted: ${payload.oldRecord}');
            // If deleted notification was unread, decrease count
            if (payload.oldRecord['is_read'] == false) {
              if (_unreadCount > 0) {
                _unreadCount--;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();

    // Subscribe to friend requests
    final friendRequestsChannel = 'friend_requests_$_userId';
    _activeChannels.add(friendRequestsChannel);
    
    supabase
        .channel(friendRequestsChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendship_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('👥 New friend request received');
            if (payload.newRecord['status'] == 'pending') {
              _unreadCount++;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friendship_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('👥 Friend request updated');
            // If status changed from pending to accepted/rejected, decrease count
            if (payload.oldRecord['status'] == 'pending' &&
                payload.newRecord['status'] != 'pending') {
              if (_unreadCount > 0) {
                _unreadCount--;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();

    // Subscribe to competition requests
    final competitionRequestsChannel = 'competition_requests_$_userId';
    _activeChannels.add(competitionRequestsChannel);
    
    supabase
        .channel(competitionRequestsChannel)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'team_join_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'competition_owner_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('🏆 New competition request received');
            if (payload.newRecord['status'] == 'pending') {
              _unreadCount++;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'team_join_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'competition_owner_id',
            value: _userId!,
          ),
          callback: (payload) {
            print('🏆 Competition request updated');
            // If status changed from pending to accepted/rejected, decrease count
            if (payload.oldRecord['status'] == 'pending' &&
                payload.newRecord['status'] != 'pending') {
              if (_unreadCount > 0) {
                _unreadCount--;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }

  /// Unsubscribe from all channels
  void _unsubscribeAll() {
    print('🔄 Unsubscribing from ${_activeChannels.length} channels');
    for (var channelName in _activeChannels) {
      try {
        supabase.removeChannel(supabase.channel(channelName));
      } catch (e) {
        print('⚠️ Error unsubscribing from channel $channelName: $e');
      }
    }
    _activeChannels.clear();
  }

  @override
  void dispose() {
    // Unsubscribe from channels
    _unsubscribeAll();
    super.dispose();
  }
}