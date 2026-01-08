import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/announcement_model.dart';
import '../../services/google_calendar_service.dart';

final supabase = Supabase.instance.client;

class AnnouncementCard extends StatefulWidget {
  final AnnouncementModel announcement;
  final int currentUserId;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.currentUserId,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  bool _isAdded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkIfAdded();
  }

  // 🔍 check if reminder exists
  Future<void> _checkIfAdded() async {
    final res = await supabase
        .from('announcement_reminders')
        .select()
        .eq('user_id', widget.currentUserId)
        .eq('ann_id', widget.announcement.annId)
        .maybeSingle();

    if (mounted && res != null) {
      setState(() => _isAdded = true);
    }
  }

  // 🔁 TOGGLE REMINDER
  // 🔁 TOGGLE REMINDER - FIXED VERSION
Future<void> _toggleReminder() async {
  if (_loading) return;

  setState(() => _loading = true);

  try {
    if (_isAdded) {
      // ❌ REMOVE
      
      // 1️⃣ Get the stored Google Calendar event ID
      final reminderData = await supabase
          .from('announcement_reminders')
          .select('google_event_id')
          .eq('user_id', widget.currentUserId)
          .eq('ann_id', widget.announcement.annId)
          .maybeSingle();

      // 2️⃣ Delete from Google Calendar if event ID exists
      if (reminderData != null && reminderData['google_event_id'] != null) {
        try {
          await GoogleCalendarService.deleteEvent(
            reminderData['google_event_id'] as String,
          );
        } catch (e) {
          debugPrint("Google Calendar deletion error: $e");
        }
      }

      // 3️⃣ Delete from database
      await supabase
          .from('announcement_reminders')
          .delete()
          .eq('user_id', widget.currentUserId)
          .eq('ann_id', widget.announcement.annId);

      if (mounted) setState(() => _isAdded = false);
      
    } else {
      // ➕ ADD
      
      // 1️⃣ Native calendar
      final event = Event(
        title: widget.announcement.title,
        description: widget.announcement.description,
        startDate: widget.announcement.eventDateTime,
        endDate: widget.announcement.eventDateTime.add(const Duration(hours: 1)),
      );
      await Add2Calendar.addEvent2Cal(event);

      // 2️⃣ Google Calendar - Store the event ID
      String? googleEventId;
      try {
        googleEventId = await GoogleCalendarService.addEvent(
          title: widget.announcement.title,
          description: widget.announcement.description,
          startTime: widget.announcement.eventDateTime,
          endTime: widget.announcement.eventDateTime.add(const Duration(hours: 1)),
        );
      } catch (e) {
        debugPrint("Google Calendar error: $e");
      }

      // 3️⃣ Save to database WITH Google event ID
      await supabase.from('announcement_reminders').insert({
        'user_id': widget.currentUserId,
        'ann_id': widget.announcement.annId,
        'google_event_id': googleEventId, // 🔑 Store this!
      });

      if (mounted) setState(() => _isAdded = true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 📅 DATE
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(_dayLabel(widget.announcement.eventDateTime)),
                const SizedBox(height: 6),
                Text(
                  _timeOnly(widget.announcement.eventDateTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // 📝 CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.announcement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.announcement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ➕ / ✓ BUTTON
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _loading ? null : _toggleReminder,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAdded ? Colors.green : Colors.red,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
  _isAdded ? Icons.notifications_active : Icons.notification_add,
  color: _isAdded ? Colors.green : Colors.red,
)
                    
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return "TODAY";
    }
    return "${date.day}/${date.month}";
  }

  String _timeOnly(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
