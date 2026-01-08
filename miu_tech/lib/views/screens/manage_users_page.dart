import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({Key? key}) : super(key: key);

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  // ============================================================
  // CREATE USER
  // ============================================================
  Future<void> _createUser() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final departmentController = TextEditingController();
    final bioController = TextEditingController();
    String selectedRole = 'Student';
    int selectedYear = 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Instructor', child: Text('Instructor')),
                    DropdownMenuItem(value: 'TA', child: Text('TA')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Year 1')),
                    DropdownMenuItem(value: 2, child: Text('Year 2')),
                    DropdownMenuItem(value: 3, child: Text('Year 3')),
                    DropdownMenuItem(value: 4, child: Text('Year 4')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedYear = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and Email are required')),
                  );
                  return;
                }

                try {
                  await Supabase.instance.client.from('users').insert({
                    'name': nameController.text,
                    'email': emailController.text,
                    'department': departmentController.text,
                    'role': selectedRole,
                    'academic_year': selectedYear,
                    'bio': bioController.text,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  Navigator.pop(ctx, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ User created successfully'), backgroundColor: Colors.green),
      );
      _loadUsers();
    }
  }

  // ============================================================
  // UPDATE USER
  // ============================================================
  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final departmentController = TextEditingController(text: user['department']);
    final bioController = TextEditingController(text: user['bio'] ?? '');
    String selectedRole = user['role'] ?? 'Student';
    int selectedYear = user['academic_year'] ?? 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email (cannot be changed)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Instructor', child: Text('Instructor')),
                    DropdownMenuItem(value: 'TA', child: Text('TA')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Year 1')),
                    DropdownMenuItem(value: 2, child: Text('Year 2')),
                    DropdownMenuItem(value: 3, child: Text('Year 3')),
                    DropdownMenuItem(value: 4, child: Text('Year 4')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedYear = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.from('users').update({
                    'name': nameController.text,
                    'department': departmentController.text,
                    'role': selectedRole,
                    'academic_year': selectedYear,
                    'bio': bioController.text,
                  }).eq('user_id', user['user_id']);

                  Navigator.pop(ctx, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ User updated successfully'), backgroundColor: Colors.green),
      );
      _loadUsers();
    }
  }

  // ============================================================
  // DELETE USER
  // ============================================================
  Future<void> _deleteUser(int userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('users')
            .delete()
            .eq('user_id', userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createUser,
            tooltip: 'Add New User',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.red),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _getRoleColor(user['role']).withOpacity(0.2),
          backgroundImage: user['profile_image'] != null
              ? NetworkImage(user['profile_image'])
              : null,
          child: user['profile_image'] == null
              ? Text(
                  (user['name'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(user['role']),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
              : null,
        ),
        title: Text(
          user['name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user['email'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user['role']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user['role'] ?? 'Student',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getRoleColor(user['role']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Year ${user['academic_year'] ?? 1}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editUser(user),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteUser(
                user['user_id'],
                user['email'] ?? '',
              ),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Admin':
        return Colors.red;
      case 'Instructor':
        return Colors.blue;
      case 'TA':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}