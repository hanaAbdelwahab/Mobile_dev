import 'package:flutter/foundation.dart';
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

  // Applications
  final Map<String, FreelanceApplicationModel> _userApplications = {}; // projectId -> application
  final Map<String, int> _applicationCounts = {}; // projectId -> count

  // Getters
  List<FreelanceProjectModel> get projects => _projects;
  bool get isLoadingProjects => _isLoadingProjects;
  String? get projectsError => _projectsError;
  
  bool isProjectSaved(String projectId) => _savedProjectIds.contains(projectId);
  bool hasApplied(String projectId) => _userApplications.containsKey(projectId);
  FreelanceApplicationModel? getApplication(String projectId) => _userApplications[projectId];
  int getApplicationCount(String projectId) => _applicationCounts[projectId] ?? 0;

  // ============================================
  // LOAD PROJECTS
  // ============================================

  Future<void> loadProjects({String sortBy = 'posted_at', bool ascending = false}) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      _projects = await FreelancingHubController.fetchAllProjects(
        sortBy: sortBy,
        ascending: ascending,
      );
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

  Future<bool> createProject(Map<String, dynamic> projectData) async {
    try {
      final success = await FreelancingHubController.createProject(projectData);
      
      if (success) {
        // Reload projects to get the new one
        await loadProjects();
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
        // Remove from local list
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
        // Update local list
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
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading saved projects: $e');
    }
  }

  Future<void> toggleSaveProject({
    required String projectId,
  }) async {
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
  // APPLICATIONS
  // ============================================

  Future<void> loadUserApplications() async {
    try {
      final applications = await FreelancingHubController.fetchUserApplications();
      _userApplications.clear();
      for (final app in applications) {
        _userApplications[app.projectId] = app;
      }
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
      final application = await FreelancingHubController.submitApplication(
        projectId: projectId,
        introduction: introduction,
      );

      if (application != null) {
        _userApplications[projectId] = application;
        
        // Update application count
        _applicationCounts[projectId] = (_applicationCounts[projectId] ?? 0) + 1;
        
        notifyListeners();
        return true;
      }
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
    await Future.wait([
      loadProjects(),
      loadSavedProjects(),
      loadUserApplications(),
    ]);
  }
}