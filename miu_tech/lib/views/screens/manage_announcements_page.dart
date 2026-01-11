import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageAnnouncementsPage extends StatefulWidget {
  const ManageAnnouncementsPage({super.key});

  @override
  State<ManageAnnouncementsPage> createState() => _ManageAnnouncementsPageState();
}

class _ManageAnnouncementsPageState extends State<ManageAnnouncementsPage> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _categories = [];
  Map<int, String> _categoryCache = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select()
          .order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });

      for (var cat in _categories) {
        _categoryCache[cat['category_id'] as int] = cat['name'] as String;
      }

      _loadAnnouncements();
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      _loadAnnouncements();
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📥 Loading announcements...');

      // ✅ FIXED: Use ann_id instead of announcement_id
      final response = await Supabase.instance.client
          .from('announcement')
          .select('''
            ann_id,
            title,
            description,
            date,
            time,
            category_id,
            auth_id,
            created_at,
            users!auth_id (
              user_id,
              name,
              email,
              profile_image,
              role
            )
          ''')
          .order('date', ascending: false)
          .order('time', ascending: false);

      debugPrint('✅ Found ${(response as List).length} announcements');

      List<Map<String, dynamic>> processedAnnouncements = [];

      for (var announcement in response) {
        final userData = announcement['users'];
        
        final String userName = userData?['name'] ?? 'Unknown User';
        final String? userEmail = userData?['email'];
        final String? userImage = userData?['profile_image'];
        final String? userRole = userData?['role'];

        processedAnnouncements.add({
          'ann_id': announcement['ann_id'],  // ✅ FIXED
          'title': announcement['title'],
          'description': announcement['description'],
          'date': announcement['date'],
          'time': announcement['time'],
          'category_id': announcement['category_id'],
          'auth_id': announcement['auth_id'],
          'user_name': userName,
          'user_email': userEmail,
          'user_image': userImage,
          'user_role': userRole,
        });

        debugPrint('  ✅ Announcement by: $userName ($userEmail)');
      }

      if (_filterType == 'upcoming') {
        processedAnnouncements = processedAnnouncements.where((announcement) {
          if (announcement['date'] == null) return false;
          final eventDate = DateTime.parse(announcement['date']);
          return eventDate.isAfter(DateTime.now()) ||
              eventDate.isAtSameMomentAs(DateTime.now());
        }).toList();
      } else if (_filterType == 'past') {
        processedAnnouncements = processedAnnouncements.where((announcement) {
          if (announcement['date'] == null) return false;
          final eventDate = DateTime.parse(announcement['date']);
          return eventDate.isBefore(DateTime.now());
        }).toList();
      }

      setState(() {
        _announcements = processedAnnouncements;
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_announcements.length} announcements');
    } catch (e) {
      debugPrint('❌ Error loading announcements: $e');
      setState(() {
        _errorMessage = 'Failed to load announcements: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Use ann_id
  Future<void> _deleteAnnouncement(int annId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Announcement'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this announcement? This action cannot be undone.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('announcement')
            .delete()
            .eq('ann_id', annId);  // ✅ FIXED

        setState(() {
          _announcements.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Announcement deleted successfully', style: TextStyle(fontSize: 15)),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: $e', style: const TextStyle(fontSize: 15))),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _showAnnouncementDialog([Map<String, dynamic>? announcement]) async {
    final isEditing = announcement != null;
    final titleController = TextEditingController(text: announcement?['title'] ?? '');
    final descriptionController = TextEditingController(text: announcement?['description'] ?? '');
    final dateController = TextEditingController(
      text: announcement?['date'] ?? DateTime.now().toIso8601String().split('T')[0],
    );
    final timeController = TextEditingController(text: announcement?['time'] ?? '09:00:00');
    int? selectedCategoryId = announcement?['category_id'] as int?;
    DateTime selectedDate = announcement?['date'] != null 
        ? DateTime.parse(announcement!['date'])
        : DateTime.now();
    TimeOfDay selectedTime = announcement?['time'] != null
        ? TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(announcement!['time']))
        : TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.add,
                  color: Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.title),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.description),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Category *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['category_id'] as int,
                        child: Text(cat['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'Date *',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                          dateController.text = date.toIso8601String().split('T')[0];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Time *',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.access_time),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    readOnly: true,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedTime = time;
                          timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Please enter a title', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Please select a category', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }

                try {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    throw Exception('No user logged in');
                  }

                  final userResponse = await Supabase.instance.client
                      .from('users')
                      .select('user_id')
                      .eq('email', user.email!)
                      .maybeSingle();

                  if (userResponse == null) {
                    throw Exception('User not found in database');
                  }

                  final userId = userResponse['user_id'] as int;

                  final announcementData = {
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'date': dateController.text,
                    'time': timeController.text,
                    'category_id': selectedCategoryId,
                    'auth_id': userId,
                  };

                  if (isEditing) {
                    // ✅ FIXED: Use ann_id
                    await Supabase.instance.client
                        .from('announcement')
                        .update(announcementData)
                        .eq('ann_id', announcement['ann_id']);
                  } else {
                    await Supabase.instance.client
                        .from('announcement')
                        .insert(announcementData);
                  }

                  Navigator.pop(ctx);
                  _loadAnnouncements();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              isEditing
                                  ? 'Announcement updated successfully'
                                  : 'Announcement created successfully',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Error: $e', style: const TextStyle(fontSize: 15))),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
              label: Text(
                isEditing ? 'Update' : 'Create',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateAnnouncement(Map<String, dynamic> announcement) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userResponse == null) {
        throw Exception('User not found in database');
      }

      final userId = userResponse['user_id'] as int;

      final duplicateData = {
        'title': '${announcement['title']} (Copy)',
        'description': announcement['description'],
        'date': announcement['date'],
        'time': announcement['time'],
        'category_id': announcement['category_id'],
        'auth_id': userId,
      };

      await Supabase.instance.client
          .from('announcement')
          .insert(duplicateData);

      _loadAnnouncements();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.copy, color: Colors.white),
                SizedBox(width: 12),
                Text('Announcement duplicated successfully', style: TextStyle(fontSize: 15)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e', style: const TextStyle(fontSize: 15))),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _viewAnnouncementDetails(Map<String, dynamic> announcement) {
    final categoryName = _categoryCache[announcement['category_id']];
    final eventDate = announcement['date'] != null 
        ? DateTime.parse(announcement['date'])
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Announcement Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Title', announcement['title'], Icons.title),
              const Divider(height: 24),
              _buildDetailRow('Description', announcement['description'] ?? 'N/A', Icons.description),
              const Divider(height: 24),
              _buildDetailRow('Category', categoryName ?? 'N/A', Icons.category),
              const Divider(height: 24),
              _buildDetailRow(
                'Date', 
                eventDate != null ? DateFormat('EEEE, MMMM d, y').format(eventDate) : 'N/A',
                Icons.calendar_today,
              ),
              const Divider(height: 24),
              _buildDetailRow('Time', announcement['time'] ?? 'N/A', Icons.access_time),
              const Divider(height: 24),
              _buildDetailRow('Created by', announcement['user_name'], Icons.person),
              const Divider(height: 24),
              _buildDetailRow('Email', announcement['user_email'] ?? 'N/A', Icons.email),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.redAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Announcements'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAnnouncementDialog(),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add),
        label: const Text('New Announcement'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 12),
                _buildFilterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 12),
                _buildFilterChip('Past', 'past'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_announcements.length} announcements',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Error', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAnnouncements,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _announcements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No announcements found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                                const SizedBox(height: 8),
                                Text('Create your first announcement', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAnnouncements,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _announcements.length,
                              itemBuilder: (context, index) {
                                final announcement = _announcements[index];
                                return _buildAnnouncementCard(announcement, index);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
        _loadAnnouncements();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, int index) {
    final title = announcement['title'] as String? ?? 'Untitled';
    final description = announcement['description'] as String? ?? '';
    final dateStr = announcement['date'] as String?;
    final timeStr = announcement['time'] as String?;
    final userName = announcement['user_name'] as String;
    final userImage = announcement['user_image'] as String?;
    final categoryId = announcement['category_id'] as int?;
    final categoryName = categoryId != null ? _categoryCache[categoryId] : null;
    final annId = announcement['ann_id'] as int? ?? 0;  // ✅ FIXED

    DateTime? eventDate;
    if (dateStr != null) {
      eventDate = DateTime.parse(dateStr);
    }

    final isUpcoming = eventDate != null && eventDate.isAfter(DateTime.now());
    final isPast = eventDate != null && eventDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUpcoming ? Colors.green : isPast ? Colors.grey.shade300 : Colors.redAccent.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUpcoming
                  ? Colors.green.withOpacity(0.1)
                  : isPast
                      ? Colors.grey.withOpacity(0.1)
                      : Colors.redAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? Colors.green.withOpacity(0.2)
                        : isPast
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: isUpcoming ? Colors.green : isPast ? Colors.grey : Colors.redAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.redAccent[100],
                            backgroundImage: userImage != null ? NetworkImage(userImage) : null,
                            child: userImage == null
                                ? Text(
                                    userName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'By $userName',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (categoryName != null) ...[
                            Text(' • ', style: TextStyle(color: Colors.grey[600])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.green : isPast ? Colors.grey : Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUpcoming ? 'UPCOMING' : isPast ? 'PAST' : 'SCHEDULED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eventDate != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(eventDate),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                if (timeStr != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewAnnouncementDetails(announcement),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _duplicateAnnouncement(announcement),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Duplicate', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAnnouncementDialog(announcement),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteAnnouncement(annId, index),  // ✅ FIXED
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}