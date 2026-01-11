import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/FreelanceProjectModel.dart';
import '../models/FreelanceApplicationModel.dart';
import '../controllers/FreelancingHubController.dart';

class FreelancingHubProvider with ChangeNotifier {
  // Projects
  List<FreelanceProjectModel> _projects = [];
  bool _isLoadingProjects = false;
  String? _projectsError;

  // Saved projects
  final Set<String> _savedProjectIds = {};  // UUID as String

  // ✅ NEW: Saved posts
  final Set<int> _savedPostIds = {};  // Post IDs as int

  // Applications
  final Map<String, FreelanceApplicationModel> _userApplications = {}; // projectId -> application
  final Map<String, int> _applicationCounts = {}; // projectId -> count

  // Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Getters
  List<FreelanceProjectModel> get projects => _projects;
  bool get isLoadingProjects => _isLoadingProjects;
  String? get projectsError => _projectsError;
  
  bool isProjectSaved(String projectId) => _savedProjectIds.contains(projectId);
  
  // ✅ NEW: Check if post is saved
  bool isPostSaved(int postId) => _savedPostIds.contains(postId);
  
  bool hasApplied(String projectId) {
    final result = _userApplications.containsKey(projectId);
    debugPrint('🔍 hasApplied($projectId): $result');
    return result;
  }
  
  FreelanceApplicationModel? getApplication(String projectId) => _userApplications[projectId];
  int getApplicationCount(String projectId) => _applicationCounts[projectId] ?? 0;

  // ============================================
  // 🚀 INITIALIZE
  // ============================================
  
  Future<void> initialize({bool showInactive = false}) async {
    debugPrint('🚀 Initializing FreelancingHubProvider...');
    
    try {
      await Future.wait([
        loadProjects(showInactive: showInactive),
        loadSavedProjects(),
        loadSavedPosts(),  // ✅ NEW
        loadUserApplications(),
      ]);
      
      _isInitialized = true;
      debugPrint('✅ FreelancingHubProvider initialized successfully');
      debugPrint('📊 Projects: ${_projects.length}');
      debugPrint('📊 Saved Projects: ${_savedProjectIds.length}');
      debugPrint('📊 Saved Posts: ${_savedPostIds.length}');
      debugPrint('📊 Applications: ${_userApplications.length}');
      
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      _isInitialized = false;
    }
    
    notifyListeners();
  }

  // ============================================
  // LOAD PROJECTS
  // ============================================

  Future<void> loadProjects({
    String sortBy = 'posted_at', 
    bool ascending = false,
    bool showInactive = false,
  }) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      if (showInactive) {
        _projects = await FreelancingHubController.fetchAllProjects(
          sortBy: sortBy,
          ascending: ascending,
          isActive: null,
        );
      } else {
        _projects = await FreelancingHubController.fetchAllProjects(
          sortBy: sortBy,
          ascending: ascending,
          isActive: true,
        );
      }
      
      debugPrint('✅ Loaded ${_projects.length} projects');
      
      if (_projects.isNotEmpty) {
        await loadApplicationCounts(_projects.map((p) => p.projectId).toList());
      }
      
      _projectsError = null;
    } catch (e) {
      _projectsError = e.toString();
      debugPrint('❌ Error loading projects in provider: $e');
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> searchProjects({String? keyword, List<String>? skills}) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      _projects = await FreelancingHubController.searchProjects(
        keyword: keyword,
        skills: skills,
      );
      
      if (_projects.isNotEmpty) {
        await loadApplicationCounts(_projects.map((p) => p.projectId).toList());
      }
      
      _projectsError = null;
    } catch (e) {
      _projectsError = e.toString();
      debugPrint('❌ Error searching projects: $e');
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  // ============================================
  // ADMIN: CREATE PROJECT
  // ============================================

  Future<bool> createProject(Map<String, dynamic> projectData, {bool isAdminView = false}) async {
    try {
      final success = await FreelancingHubController.createProject(projectData);
      
      if (success) {
        await loadProjects(showInactive: isAdminView);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error creating project: $e');
      return false;
    }
  }

  // ============================================
  // ADMIN: DELETE PROJECT
  // ============================================

  Future<bool> deleteProject(String projectId) async {
    try {
      final success = await FreelancingHubController.deleteProject(projectId);
      
      if (success) {
        _projects.removeWhere((p) => p.projectId == projectId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting project: $e');
      return false;
    }
  }

  // ============================================
  // ADMIN: TOGGLE PROJECT STATUS
  // ============================================

  Future<bool> toggleProjectStatus(String projectId) async {
    try {
      final project = _projects.firstWhere((p) => p.projectId == projectId);
      final newStatus = !project.isActive;
      
      final success = await FreelancingHubController.updateProjectStatus(
        projectId,
        newStatus,
      );
      
      if (success) {
        final index = _projects.indexWhere((p) => p.projectId == projectId);
        if (index != -1) {
          _projects[index] = project.copyWith(isActive: newStatus);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling project status: $e');
      return false;
    }
  }

  // ============================================
  // SAVED PROJECTS
  // ============================================

  Future<void> loadSavedProjects() async {
    try {
      final savedProjects = await FreelancingHubController.fetchSavedProjects();
      _savedProjectIds.clear();
      _savedProjectIds.addAll(savedProjects.map((p) => p.projectId));
      debugPrint('✅ Loaded ${_savedProjectIds.length} saved projects');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading saved projects: $e');
    }
  }

  Future<void> toggleSaveProject({required String projectId}) async {
    try {
      final success = await FreelancingHubController.toggleSaveProject(
        projectId: projectId,
      );

      if (success) {
        if (_savedProjectIds.contains(projectId)) {
          _savedProjectIds.remove(projectId);
        } else {
          _savedProjectIds.add(projectId);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
    }
  }

  // ============================================
  // ✅ NEW: SAVED POSTS
  // ============================================

  Future<void> loadSavedPosts() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userResponse == null) return;
      final userId = userResponse['user_id'] as int;

      final savedPosts = await Supabase.instance.client
          .from('saved_freelance_projects')
          .select('post_id')
          .eq('user_id', userId)
          .not('post_id', 'is', null);

      _savedPostIds.clear();
      for (var saved in savedPosts) {
        if (saved['post_id'] != null) {
          _savedPostIds.add(saved['post_id'] as int);
        }
      }

      debugPrint('✅ Loaded ${_savedPostIds.length} saved posts');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading saved posts: $e');
    }
  }

  Future<bool> toggleSavePost({required int postId}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return false;
      }

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userResponse == null) {
        debugPrint('❌ User not found');
        return false;
      }

      final userId = userResponse['user_id'] as int;

      if (_savedPostIds.contains(postId)) {
        // Unsave
        await Supabase.instance.client
            .from('saved_freelance_projects')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', postId);

        _savedPostIds.remove(postId);
        debugPrint('✅ Post $postId unsaved');
      } else {
        // Save
        await Supabase.instance.client
            .from('saved_freelance_projects')
            .insert({
          'user_id': userId,
          'post_id': postId,
          'item_type': 'post',
        });

        _savedPostIds.add(postId);
        debugPrint('✅ Post $postId saved');
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling save post: $e');
      return false;
    }
  }

  // ============================================
  // APPLICATIONS
  // ============================================

  Future<void> loadUserApplications() async {
    try {
      debugPrint('📥 Loading user applications from database...');
      
      final applications = await FreelancingHubController.fetchUserApplications();
      
      _userApplications.clear();
      for (final app in applications) {
        _userApplications[app.projectId] = app;
        debugPrint('  ✓ Application: Project ${app.projectId} - Status: ${app.status}');
      }
      
      debugPrint('✅ Loaded ${applications.length} user applications');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error loading user applications: $e');
    }
  }

  Future<void> loadApplicationCounts(List<String> projectIds) async {
    try {
      for (final projectId in projectIds) {
        final count = await FreelancingHubController.getApplicationCount(projectId);
        _applicationCounts[projectId] = count;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading application counts: $e');
    }
  }

  Future<bool> submitApplication({
    required String projectId,
    required String introduction,
  }) async {
    try {
      debugPrint('📤 Submitting application for project: $projectId');
      
      final application = await FreelancingHubController.submitApplication(
        projectId: projectId,
        introduction: introduction,
      );

      if (application != null) {
        _userApplications[projectId] = application;
        _applicationCounts[projectId] = (_applicationCounts[projectId] ?? 0) + 1;
        
        debugPrint('✅ Application submitted and saved to state');
        notifyListeners();
        return true;
      }
      
      debugPrint('❌ Failed to submit application');
      return false;
      
    } catch (e) {
      debugPrint('❌ Error submitting application: $e');
      return false;
    }
  }

  Future<bool> withdrawApplication(String projectId) async {
    try {
      final application = _userApplications[projectId];
      if (application == null) return false;

      final success = await FreelancingHubController.withdrawApplication(
        application.applicationId,
      );

      if (success) {
        _userApplications[projectId] = application.copyWith(status: 'withdrawn');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error withdrawing application: $e');
      return false;
    }
  }

  // ============================================
  // REFRESH
  // ============================================

  Future<void> refreshAll() async {
    debugPrint('🔄 Refreshing all data...');
    await Future.wait([
      loadProjects(),
      loadSavedProjects(),
      loadSavedPosts(),  // ✅ NEW
      loadUserApplications(),
    ]);
  }

  // ============================================
  // RESET
  // ============================================
  
  void reset() {
    debugPrint('🧹 Resetting FreelancingHubProvider state');
    _projects.clear();
    _savedProjectIds.clear();
    _savedPostIds.clear();  // ✅ NEW
    _userApplications.clear();
    _applicationCounts.clear();
    _isInitialized = false;
    _isLoadingProjects = false;
    _projectsError = null;
    notifyListeners();
  }
}