import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/task.dart';
import '../models/task_link.dart';

class TaskProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  List<TaskLink> _links = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  List<TaskLink> get links => _links;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTasks(int projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/tasks', queryParameters: {'project_id': projectId, 'fetch_all': 'true'});
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _tasks = data.map((json) => Task.fromJson(json)).toList();
      } else {
        _error = 'Failed to load tasks';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask(int projectId, String title, String description, {
    String? priority,
    String? startDate,
    String? endDate,
    List<int>? assigneeIds,
    int? parentId,
  }) async {
    try {
      final response = await _apiService.post('/tasks', data: {
        'project_id': projectId,
        'title': title,
        'description': description,
        if (priority != null) 'priority': priority,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (assigneeIds != null) 'assignee_ids': assigneeIds,
        if (parentId != null) 'parent_id': parentId,
      });
      
      if (response.statusCode == 201) {
        await fetchTasks(projectId);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask(int taskId, {
    String? title,
    String? description,
    String? status,
    String? priority,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (status != null) data['status'] = status;
      if (priority != null) data['priority'] = priority;
      if (startDate != null) data['start_date'] = startDate;
      if (endDate != null) data['end_date'] = endDate;

      final response = await _apiService.put('/tasks/$taskId', data: data);
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(int taskId) async {
    try {
      final response = await _apiService.delete('/tasks/$taskId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTaskStatus(int taskId, String status) async {
    try {
      final response = await _apiService.put('/tasks/$taskId', data: {
        'status': status,
      });
      
      if (response.statusCode == 200) {
        // Since we don't have projectId here easily to refetch everything,
        // we just return true and let the UI trigger a refresh if needed
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>> fetchComments(int taskId) async {
    try {
      final response = await _apiService.get('/tasks/$taskId/comments');
      if (response.statusCode == 200) {
        return response.data;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> addComment(int taskId, String content) async {
    try {
      final response = await _apiService.post('/tasks/$taskId/comments', data: {
        'content': content,
      });
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // 甘特图相关API
  Future<void> fetchGanttData(int projectId) async {
    try {
      final response = await _apiService.get('/tasks/gantt-data', queryParameters: {'project_id': projectId});
      if (response.statusCode == 200) {
        final List<dynamic> linksData = response.data['links'] ?? [];
        _links = linksData.map((json) => TaskLink.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createLink(int source, int target, String type) async {
    try {
      final response = await _apiService.post('/tasks/links', data: {
        'source': source,
        'target': target,
        'type': type,
      });
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteLink(int linkId) async {
    try {
      final response = await _apiService.delete('/tasks/links/$linkId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTaskProgress(int taskId, int progress) async {
    try {
      final response = await _apiService.put('/tasks/$taskId', data: {
        'progress': progress,
      });
      if (response.statusCode == 200) {
        // Update local task state to avoid full refresh
        final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
        if (taskIndex != -1) {
          final oldTask = _tasks[taskIndex];
          _tasks[taskIndex] = Task(
            id: oldTask.id,
            title: oldTask.title,
            description: oldTask.description,
            status: progress >= 100 ? 'completed' : oldTask.status,
            priority: oldTask.priority,
            startDate: oldTask.startDate,
            endDate: oldTask.endDate,
            progress: progress,
            projectId: oldTask.projectId,
            parentId: oldTask.parentId,
            level: oldTask.level,
            hasSubtasks: oldTask.hasSubtasks,
            participants: oldTask.participants,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
