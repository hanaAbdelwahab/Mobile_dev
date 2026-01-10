import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/top_navbar.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/user_drawer_header.dart';

class CalendarScreen extends StatefulWidget {
  final int userId;

  const CalendarScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool loading = true;
  List<Map<String, dynamic>> reminders = [];
  DateTime selectedDate = DateTime.now();
  DateTime currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final supabase = Supabase.instance.client;

      final reminderRows = await supabase
          .from('announcement_reminders')
          .select('ann_id')
          .eq('user_id', widget.userId);

      if (reminderRows.isEmpty) {
        setState(() {
          reminders = [];
          loading = false;
        });
        return;
      }

      final List<Object> annIds =
          reminderRows.map<Object>((e) => e['ann_id'] as int).toList();

      final announcementRows = await supabase
          .from('announcement')
          .select('ann_id, title, description, date, time')
          .inFilter('ann_id', annIds)
          .order('date', ascending: true);

      setState(() {
        reminders = List<Map<String, dynamic>>.from(announcementRows);
        loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading reminders: $e');
      setState(() => loading = false);
    }
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];

    // Add empty days for alignment
    for (int i = 0; i < firstDay.weekday % 7; i++) {
      days.add(DateTime(1900));
    }

    // Add actual days
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    return days;
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return reminders.where((reminder) {
      final rawDate = reminder['date'];

      DateTime reminderDate;
      if (rawDate is DateTime) {
        reminderDate = rawDate;
      } else {
        reminderDate = DateTime.parse(rawDate.toString());
      }

      return reminderDate.year == date.year &&
          reminderDate.month == date.month &&
          reminderDate.day == date.day;
    }).toList();
  }

  bool _hasEventsOnDate(DateTime date) {
    return _getEventsForDate(date).isNotEmpty;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    // Custom date formatting without intl package
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final dateStr = '$weekday, ${date.day} $month';

    if (targetDate == today) {
      return 'Today · $dateStr';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow · $dateStr';
    } else {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(currentMonth);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get events for selected date
    final selectedEvents = _getEventsForDate(selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      endDrawer: UserDrawerContent(userId: widget.userId),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            TopNavbar(userId: widget.userId),

            // Calendar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Month Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_getMonthName(currentMonth.month)} ${currentMonth.year}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                currentMonth = DateTime(
                                  currentMonth.year,
                                  currentMonth.month - 1,
                                );
                              });
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                currentMonth = DateTime(
                                  currentMonth.year,
                                  currentMonth.month + 1,
                                );
                              });
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weekday Headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((day) => SizedBox(
                              width: 40,
                              child: Center(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),

                  // Calendar Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: daysInMonth.length,
                    itemBuilder: (context, index) {
                      final date = daysInMonth[index];
                      if (date.year == 1900) {
                        return const SizedBox();
                      }

                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;

                      final isSelected = date.year == selectedDate.year &&
                          date.month == selectedDate.month &&
                          date.day == selectedDate.day;

                      final hasEvents = _hasEventsOnDate(date);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = date;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.red
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                            ? Colors.red
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                              if (hasEvents && !isSelected)
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Selected Date Events
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDateLabel(selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Events List
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : selectedEvents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: Colors.red,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nothing Scheduled Yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No events for this day',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: selectedEvents.length,
                          itemBuilder: (context, index) {
                            final event = selectedEvents[index];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.red,
                                    width: 4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'] ?? 'Untitled Event',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    event['description'] ?? 'No description',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        event['time']?.toString() ?? 'No time',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: 2,
        currentUserId: widget.userId,
      ),
    );
  }
}