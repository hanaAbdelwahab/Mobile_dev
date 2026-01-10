import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageApplicationsPage extends StatefulWidget {
  const ManageApplicationsPage({super.key});

  @override
  State<ManageApplicationsPage> createState() => _ManageApplicationsPageState();
}

class _ManageApplicationsPageState extends State<ManageApplicationsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final applicationsData = await _supabase
          .from('freelance_applications')
          .select('application_id, project_id, applicant_id, applicant_uuid, applicant_email, applicant_name, introduction, status, applied_at')
          .order('applied_at', ascending: false);

      debugPrint('✅ Found ${(applicationsData as List).length} applications');

      List<Map<String, dynamic>> processedApplications = [];
      
      for (var app in applicationsData) {
        debugPrint('📊 Processing application: ${app['application_id']}');
        debugPrint('📧 Applicant email from DB: ${app['applicant_email']}');
        debugPrint('👤 Applicant name from DB: ${app['applicant_name']}');
        
        try {
          // Fetch project details
          final projectData = await _supabase
              .from('freelance_projects')
              .select('title, company_name, company_logo')
              .eq('project_id', app['project_id'])
              .maybeSingle();

          // Fetch user email from the application itself (stored during submission)
          String userEmail = app['applicant_email'] ?? 'Unknown Email';
          String userName = app['applicant_name'] ?? 'Unknown User';
          final applicantUuid = app['applicant_uuid'];
          
          // If email/name not stored, try to look it up
          if (userEmail == 'Unknown Email' && applicantUuid != null) {
            try {
              final userData = await _supabase
                  .from('users')
                  .select('email, full_name')
                  .eq('user_id', applicantUuid)
                  .maybeSingle();
              
              if (userData != null) {
                userEmail = userData['email'] ?? userEmail;
                userName = userData['full_name'] ?? userName;
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching user data: $e');
            }
          }

          processedApplications.add({
            'application_id': app['application_id'],
            'project_id': app['project_id'],
            'applicant_id': applicantUuid ?? app['applicant_id']?.toString() ?? 'Unknown',
            'applicant_email': userEmail,
            'applicant_name': userName,
            'introduction': app['introduction'],
            'status': app['status'],
            'applied_at': app['applied_at'],
            'project_title': projectData?['title'] ?? 'Unknown Project',
            'company_name': projectData?['company_name'] ?? 'Unknown Company',
            'company_logo': projectData?['company_logo'],
          });
        } catch (e) {
          debugPrint('⚠️ Error loading project for application: $e');
          processedApplications.add({
            'application_id': app['application_id'],
            'project_id': app['project_id'],
            'applicant_id': app['applicant_uuid'] ?? app['applicant_id']?.toString() ?? 'Unknown',
            'applicant_email': 'Unknown Email',
            'applicant_name': 'Unknown User',
            'introduction': app['introduction'],
            'status': app['status'],
            'applied_at': app['applied_at'],
            'project_title': 'Unknown Project',
            'company_name': 'Unknown Company',
            'company_logo': null,
          });
        }
      }

      setState(() {
        _applications = processedApplications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading applications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('View Applications'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Error loading applications', 
                          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, 
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]), 
                          textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadApplications,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No applications yet', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Applications will appear here when users apply', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final app = _applications[index];
                          return _buildApplicationCard(app);
                        },
                      ),
                    ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final status = application['status'] as String? ?? 'pending';
    final appliedAtStr = application['applied_at'] as String?;
    final introduction = application['introduction'] as String? ?? 'No introduction provided';
    final applicantId = application['applicant_id'] as String? ?? 'Unknown';
    final applicantEmail = application['applicant_email'] as String? ?? 'Unknown Email';
    final applicantName = application['applicant_name'] as String? ?? 'Unknown User';
    final projectTitle = application['project_title'] as String? ?? 'Unknown Project';
    final companyName = application['company_name'] as String? ?? 'Unknown Company';
    final companyLogo = application['company_logo'] as String?;
    
    DateTime appliedAt;
    try {
      appliedAt = appliedAtStr != null ? DateTime.parse(appliedAtStr) : DateTime.now();
    } catch (e) {
      appliedAt = DateTime.now();
    }

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'withdrawn':
        statusColor = Colors.grey;
        statusIcon = Icons.remove_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: companyLogo != null && companyLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            companyLogo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.business, color: Colors.red, size: 24);
                            },
                          ),
                        )
                      : const Icon(Icons.business, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        companyName,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: Text(
                        applicantName.isNotEmpty ? applicantName.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(applicantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            applicantEmail, 
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('Applied ${_timeAgo(appliedAt)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Introduction:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    introduction, 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}