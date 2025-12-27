import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/project.dart';

class ProjectProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  List<Project> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProjects(int teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/projects', queryParameters: {'team_id': teamId});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _projects = data.map((json) => Project.fromJson(json)).toList();
      } else {
        _error = 'Failed to load projects';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProject(int teamId, String name, String description) async {
    try {
      final response = await _apiService.post('/projects', data: {
        'team_id': teamId,
        'name': name,
        'description': description,
      });
      
      if (response.statusCode == 201) {
        await fetchProjects(teamId);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProject(int projectId, {String? name, String? description, String? status}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (status != null) data['status'] = status;

      final response = await _apiService.put('/projects/$projectId', data: data);
      
      if (response.statusCode == 200) {
        // Find the project in the list and update it locally if possible
        // But for simplicity and to ensure sync, we might want to just update the local item
        final index = _projects.indexWhere((p) => p.id == projectId);
        if (index != -1) {
          final old = _projects[index];
          _projects[index] = Project(
            id: old.id,
            name: name ?? old.name,
            description: description ?? old.description,
            status: status ?? old.status,
            startDate: old.startDate,
            endDate: old.endDate,
            createdBy: old.createdBy,
            createdAt: old.createdAt,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(int projectId) async {
    try {
      final response = await _apiService.delete('/projects/$projectId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _projects.removeWhere((p) => p.id == projectId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Project?> getProjectById(int projectId) async {
    try {
      final response = await _apiService.get('/projects/$projectId');
      if (response.statusCode == 200) {
        return Project.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
