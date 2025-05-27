import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../providers/team_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({Key? key}) : super(key: key);

  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _currentUserId;
  String? _currentUserName;
  String? _selectedTeamId;
  String? _organizationId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user info
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      _currentUserId = currentUser.id;
      _currentUserName = currentUser.name;
      _organizationId = currentUser.organizationId;
      
      // Load teams
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      await teamProvider.loadTeams();
      
      if (teamProvider.teams.isNotEmpty && _selectedTeamId == null) {
        _selectedTeamId = teamProvider.teams.first.id;
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading data: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedTeamId == null || _currentUserId == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _firestore.collection('messages').add({
        'text': _messageController.text.trim(),
        'teamId': _selectedTeamId,
        'senderId': _currentUserId,
        'senderName': _currentUserName ?? 'Unknown User',
        'timestamp': FieldValue.serverTimestamp(),
        'organizationId': _organizationId,
      });
      
      _messageController.clear();
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error sending message: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Team Chat'),
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
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Team selector
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Consumer<TeamProvider>(
                      builder: (context, teamProvider, _) {
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Team',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          value: _selectedTeamId,
                          items: teamProvider.teams.map((team) {
                            return DropdownMenuItem<String>(
                              value: team.id,
                              child: Text(team.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeamId = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  
                  // Messages list
                  Expanded(
                    child: _selectedTeamId == null
                        ? Center(
                            child: Text('Please select a team to view messages'),
                          )
                        : StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('messages')
                                .where('teamId', isEqualTo: _selectedTeamId)
                                .orderBy('timestamp', descending: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: CircularProgressIndicator());
                              }
                              
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error loading messages: ${snapshot.error}'),
                                );
                              }
                              
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No messages yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Start the conversation!',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final messages = snapshot.data!.docs;
                              
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });
                              
                              return ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index].data() as Map<String, dynamic>;
                                  final isCurrentUser = message['senderId'] == _currentUserId;
                                  
                                  // Format timestamp
                                  String formattedTime = 'Just now';
                                  if (message['timestamp'] != null) {
                                    final timestamp = message['timestamp'] as Timestamp;
                                    final dateTime = timestamp.toDate();
                                    
                                    // If today, show time only
                                    if (dateTime.day == DateTime.now().day &&
                                        dateTime.month == DateTime.now().month &&
                                        dateTime.year == DateTime.now().year) {
                                      formattedTime = DateFormat('HH:mm').format(dateTime);
                                    } else {
                                      formattedTime = DateFormat('MMM d, HH:mm').format(dateTime);
                                    }
                                  }
                                  
                                  return _buildMessageBubble(
                                    message: message['text'] ?? '',
                                    senderName: message['senderName'] ?? 'Unknown User',
                                    time: formattedTime,
                                    isCurrentUser: isCurrentUser,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  
                  // Message input
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        SizedBox(width: 8),
                        FloatingActionButton(
                          onPressed: _sendMessage,
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          mini: true,
                          child: Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildMessageBubble({
    required String message,
    required String senderName,
    required String time,
    required bool isCurrentUser,
  }) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: isCurrentUser ? 64 : 0,
          right: isCurrentUser ? 0 : 64,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
