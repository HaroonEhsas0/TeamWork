import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../database_helper.dart';
import '../widgets/connection_check_wrapper.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({Key? key}) : super(key: key);

  @override
  _TeamManagementScreenState createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _databaseHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  final _teamNameController = TextEditingController();
  final _teamDescriptionController = TextEditingController();
  
  bool _isLoading = true;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, List<Map<String, dynamic>>> _teamMembers = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _teamNameController.dispose();
    _teamDescriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Check if user is admin
      _isAdmin = await _databaseHelper.isUserAdmin(userId);
      
      // Load teams
      _teams = await _databaseHelper.getTeams(userId);
      
      // Load members
      _members = await _databaseHelper.getTeamMembers(userId);
      
      // Group members by team
      _teamMembers = {};
      for (var team in _teams) {
        final teamId = team['id'] as String;
        _teamMembers[teamId] = await _databaseHelper.getTeamMembersByTeam(teamId);
      }
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createTeam() async {
    if (_teamNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a team name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Create team
      await _databaseHelper.createTeam(
        userId,
        _teamNameController.text.trim(),
        _teamDescriptionController.text.trim(),
      );
      
      // Clear form
      _teamNameController.clear();
      _teamDescriptionController.clear();
      
      // Reload data
      await _loadData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Team created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Close dialog
      Navigator.pop(context);
    } catch (e) {
      print('Error creating team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating team: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _showCreateTeamDialog() async {
    _teamNameController.clear();
    _teamDescriptionController.clear();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Team'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _teamNameController,
                decoration: InputDecoration(
                  labelText: 'Team Name',
                  hintText: 'Enter team name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _teamDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter team description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createTeam,
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showAddMemberDialog(String teamId, String teamName) async {
    final availableMembers = _members.where((member) {
      // Check if member is already in the team
      final teamMembersList = _teamMembers[teamId] ?? [];
      return !teamMembersList.any((teamMember) => teamMember['id'] == member['id']);
    }).toList();
    
    if (availableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No available members to add'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    String? selectedMemberId;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Member to $teamName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...availableMembers.map((member) => RadioListTile<String>(
                    title: Text(member['name'] as String),
                    subtitle: Text(member['email'] as String),
                    value: member['id'] as String,
                    groupValue: selectedMemberId,
                    onChanged: (value) {
                      setState(() {
                        selectedMemberId = value;
                      });
                    },
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedMemberId == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        
                        // Add member to team
                        try {
                          await _databaseHelper.addMemberToTeam(teamId, selectedMemberId!);
                          
                          // Reload data
                          await _loadData();
                          
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Member added to team'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          print('Error adding member to team: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding member to team: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: Text('Add to Team'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _removeMemberFromTeam(String teamId, String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
        content: Text('Are you sure you want to remove $memberName from this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    try {
      await _databaseHelper.removeMemberFromTeam(teamId, memberId);
      
      // Reload data
      await _loadData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Member removed from team'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error removing member from team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing member from team: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _deleteTeam(String teamId, String teamName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Team'),
        content: Text('Are you sure you want to delete the team "$teamName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) return;
    
    try {
      await _databaseHelper.deleteTeam(teamId);
      
      // Reload data
      await _loadData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Team deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting team: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting team: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildTeamCard(Map<String, dynamic> team) {
    final teamId = team['id'] as String;
    final teamName = team['name'] as String;
    final teamDescription = team['description'] as String? ?? '';
    final teamMembers = _teamMembers[teamId] ?? [];
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (teamDescription.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          teamDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isAdmin) ...[
                  IconButton(
                    icon: Icon(Icons.person_add, color: Colors.white),
                    onPressed: () => _showAddMemberDialog(teamId, teamName),
                    tooltip: 'Add Member',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.white),
                    onPressed: () => _deleteTeam(teamId, teamName),
                    tooltip: 'Delete Team',
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team Members (${teamMembers.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                if (teamMembers.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No members in this team yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_isAdmin) ...[
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddMemberDialog(teamId, teamName),
                              icon: Icon(Icons.person_add),
                              label: Text('Add Members'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: teamMembers.length,
                    itemBuilder: (context, index) {
                      final member = teamMembers[index];
                      final memberId = member['id'] as String;
                      final memberName = member['name'] as String;
                      final memberEmail = member['email'] as String;
                      final memberRole = member['role'] as String? ?? 'Member';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            memberName.isNotEmpty ? memberName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(memberName),
                        subtitle: Text(memberEmail),
                        trailing: _isAdmin
                            ? IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeMemberFromTeam(teamId, memberId, memberName),
                                tooltip: 'Remove from Team',
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Team Management'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        floatingActionButton: _isAdmin
            ? FloatingActionButton(
                onPressed: _showCreateTeamDialog,
                child: Icon(Icons.add),
                tooltip: 'Create Team',
              )
            : null,
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: _teams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No teams found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _isAdmin
                                  ? 'Create a team to get started'
                                  : 'You are not part of any team yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_isAdmin) ...[
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showCreateTeamDialog,
                                icon: Icon(Icons.add),
                                label: Text('Create Team'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.all(16),
                        children: [
                          ..._teams.map((team) => _buildTeamCard(team)),
                        ],
                      ),
              ),
      ),
    );
  }
}
