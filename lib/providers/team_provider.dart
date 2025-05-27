import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../database_helper.dart';

class TeamProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<TeamModel> _teams = [];
  TeamModel? _selectedTeam;
  List<UserModel> _teamMembers = [];
  bool _isLoading = false;
  String? _error;
  
  List<TeamModel> get teams => _teams;
  TeamModel? get selectedTeam => _selectedTeam;
  List<UserModel> get teamMembers => _teamMembers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  TeamProvider() {
    _initTeams();
  }
  
  Future<void> _initTeams() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadTeams(currentUser.uid);
    }
  }
  
  Future<void> loadTeams(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('teams')
          .where('adminId', isEqualTo: userId)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _teams = querySnapshot.docs
            .map((doc) => TeamModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.getTeams(userId);
        
        _teams = records
            .map((record) => TeamModel.fromMap(record))
            .toList();
      }
      
      // If there are teams, select the first one by default
      if (_teams.isNotEmpty && _selectedTeam == null) {
        _selectedTeam = _teams.first;
        await loadTeamMembers(_selectedTeam!.id);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading teams: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadTeamMembers(String teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('team_members')
          .where('teamId', isEqualTo: teamId)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final memberIds = querySnapshot.docs
            .map((doc) => (doc.data()['userId'] ?? '') as String)
            .toList();
        
        _teamMembers = [];
        
        // Get user details for each member
        for (var memberId in memberIds) {
          final userDoc = await _firestore.collection('users').doc(memberId).get();
          if (userDoc.exists) {
            _teamMembers.add(UserModel.fromFirestore(userDoc));
          }
        }
      } else {
        // Try local database
        final records = await _databaseHelper.getTeamMembersByTeam(teamId);
        
        _teamMembers = records
            .map((record) => UserModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading team members: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> createTeam(String name, String description) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _error = 'User not logged in';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final now = DateTime.now();
      final id = 'team_${currentUser.uid}_${now.millisecondsSinceEpoch}';
      
      // Create team
      final team = TeamModel(
        id: id,
        name: name,
        adminId: currentUser.uid,
        description: description,
        createdAt: now,
      );
      
      // Save to Firestore
      await _firestore
          .collection('teams')
          .doc(id)
          .set(team.toMap());
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'teams',
          {
            'id': team.id,
            'name': team.name,
            'admin_id': team.adminId,
            'created_at': team.createdAt.toIso8601String(),
            'description': team.description,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      // Add to list
      _teams.add(team);
      _selectedTeam = team;
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating team: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> addTeamMember(String email) async {
    if (_selectedTeam == null) {
      _error = 'No team selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find user by email
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        _error = 'User not found';
        return false;
      }
      
      final userDoc = querySnapshot.docs.first;
      final user = UserModel.fromFirestore(userDoc);
      
      // Check if already a member
      final memberCheck = await _firestore
          .collection('team_members')
          .where('teamId', isEqualTo: _selectedTeam!.id)
          .where('userId', isEqualTo: user.id)
          .limit(1)
          .get();
      
      if (memberCheck.docs.isNotEmpty) {
        _error = 'User is already a team member';
        return false;
      }
      
      final now = DateTime.now();
      final id = 'member_${_selectedTeam!.id}_${user.id}';
      
      // Add to team_members
      await _firestore
          .collection('team_members')
          .doc(id)
          .set({
            'id': id,
            'teamId': _selectedTeam!.id,
            'userId': user.id,
            'joinedAt': now,
            'role': 'member',
          });
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'team_members',
          {
            'id': id,
            'team_id': _selectedTeam!.id,
            'user_id': user.id,
            'joined_at': now.toIso8601String(),
            'role': 'member',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      // Add to list
      _teamMembers.add(user);
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error adding team member: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> removeTeamMember(String userId) async {
    if (_selectedTeam == null) {
      _error = 'No team selected';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final id = 'member_${_selectedTeam!.id}_$userId';
      
      // Remove from Firestore
      await _firestore
          .collection('team_members')
          .doc(id)
          .delete();
      
      // Remove from local database
      await _databaseHelper.database.then((db) async {
        await db.delete(
          'team_members',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      
      // Remove from list
      _teamMembers.removeWhere((member) => member.id == userId);
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error removing team member: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void selectTeam(TeamModel team) async {
    _selectedTeam = team;
    notifyListeners();
    
    await loadTeamMembers(team.id);
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
