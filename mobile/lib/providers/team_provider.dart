import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/team.dart';
import '../models/user.dart';

class TeamProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Team> _teams = [];
  bool _isLoading = false;
  String? _error;

  List<Team> get teams => _teams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTeams() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/teams');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _teams = data.map((json) => Team.fromJson(json)).toList();
      } else {
        _error = 'Failed to load teams';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTeam(String name, String description) async {
    try {
      final response = await _apiService.post('/teams', data: {
        'name': name,
        'description': description,
      });
      
      if (response.statusCode == 201) {
        await fetchTeams();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinTeam(String inviteCode) async {
    try {
      final response = await _apiService.post('/teams/join', data: {
        'invite_code': inviteCode,
      });
      
      if (response.statusCode == 200) {
        await fetchTeams();
        return true;
      }
      _error = response.data['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTeam(int teamId, String name, String description) async {
    try {
      final response = await _apiService.put('/teams/$teamId', data: {
        'name': name,
        'description': description,
      });
      
      if (response.statusCode == 200) {
        await fetchTeams();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTeam(int teamId) async {
    try {
      final response = await _apiService.delete('/teams/$teamId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTeams();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveTeam(int teamId) async {
    try {
      final response = await _apiService.post('/teams/$teamId/leave');
      if (response.statusCode == 200) {
        await fetchTeams();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<User>> fetchTeamMembers(int teamId) async {
    try {
      final response = await _apiService.get('/teams/$teamId/members');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching team members: $e');
      }
      return [];
    }
  }

  Future<Team?> getTeamById(int teamId) async {
    try {
      final response = await _apiService.get('/teams/$teamId');
      if (response.statusCode == 200) {
        return Team.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
