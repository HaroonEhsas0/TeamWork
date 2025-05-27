import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/leave_model.dart';
import '../providers/leave_provider.dart';
import '../providers/team_provider.dart';
import '../providers/user_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({Key? key}) : super(key: key);

  @override
  _LeaveCalendarScreenState createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _organizationId;
  
  // Calendar variables
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  // Leave events
  Map<DateTime, List<LeaveModel>> _leaveEvents = {};
  List<LeaveModel> _selectedLeaves = [];
  
  // Filter options
  String? _selectedTeamId;
  List<String> _selectedLeaveTypes = [];
  List<String> _selectedStatuses = ['pending', 'approved', 'rejected'];
  
  final List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Personal Leave',
    'Family Leave',
    'Bereavement Leave',
    'Unpaid Leave',
    'Other',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadData();
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
      
      _organizationId = currentUser.organizationId;
      _isAdmin = currentUser.role == 'admin' || currentUser.role == 'manager';
      
      // Load teams if admin
      if (_isAdmin) {
        final teamProvider = Provider.of<TeamProvider>(context, listen: false);
        await teamProvider.loadTeams();
        
        if (teamProvider.teams.isNotEmpty && _selectedTeamId == null) {
          _selectedTeamId = teamProvider.teams.first.id;
        }
      }
      
      // Load leave data
      await _loadLeaveData();
      
      // Set selected leaves for today
      _updateSelectedLeaves();
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading calendar data: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadLeaveData() async {
    if (_organizationId == null) return;
    
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      
      // Load all leaves for the organization
      await leaveProvider.loadTeamLeaves(_organizationId!);
      
      // Process leaves into events
      _processLeavesIntoEvents(leaveProvider.leaves);
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading leave data: ${ErrorUtils.formatErrorMessage(e)}');
    }
  }
  
  void _processLeavesIntoEvents(List<LeaveModel> leaves) {
    // Clear existing events
    _leaveEvents.clear();
    
    // Filter leaves based on selected filters
    final filteredLeaves = leaves.where((leave) {
      // Filter by team if selected
      if (_selectedTeamId != null && _isAdmin) {
        // We would need to check if the user belongs to the selected team
        // This would require additional data that we don't have in this implementation
        // For now, we'll skip team filtering
      }
      
      // Filter by leave type if any selected
      if (_selectedLeaveTypes.isNotEmpty && !_selectedLeaveTypes.contains(leave.leaveType)) {
        return false;
      }
      
      // Filter by status
      if (!_selectedStatuses.contains(leave.status)) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Add each leave to the events map
    for (final leave in filteredLeaves) {
      // Get all days in the leave period
      final days = _getDaysInRange(leave.startDate, leave.endDate);
      
      // Add the leave to each day
      for (final day in days) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        
        if (_leaveEvents[normalizedDay] == null) {
          _leaveEvents[normalizedDay] = [];
        }
        
        _leaveEvents[normalizedDay]!.add(leave);
      }
    }
  }
  
  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      days.add(start.add(Duration(days: i)));
    }
    
    return days;
  }
  
  void _updateSelectedLeaves() {
    final normalizedSelectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    _selectedLeaves = _leaveEvents[normalizedSelectedDay] ?? [];
  }
  
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateSelectedLeaves();
    });
  }
  
  void _showFilterDialog() {
    // Store current selections for cancellation
    final currentLeaveTypes = List<String>.from(_selectedLeaveTypes);
    final currentStatuses = List<String>.from(_selectedStatuses);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Leaves'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Types',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _leaveTypes.map((type) {
                        final isSelected = _selectedLeaveTypes.contains(type);
                        
                        return FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLeaveTypes.add(type);
                              } else {
                                _selectedLeaveTypes.remove(type);
                              }
                            });
                          },
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue.shade700,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text('Pending'),
                          selected: _selectedStatuses.contains('pending'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedStatuses.add('pending');
                              } else {
                                _selectedStatuses.remove('pending');
                              }
                            });
                          },
                          selectedColor: Colors.orange.shade100,
                          checkmarkColor: Colors.orange.shade700,
                        ),
                        FilterChip(
                          label: Text('Approved'),
                          selected: _selectedStatuses.contains('approved'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedStatuses.add('approved');
                              } else {
                                _selectedStatuses.remove('approved');
                              }
                            });
                          },
                          selectedColor: Colors.green.shade100,
                          checkmarkColor: Colors.green.shade700,
                        ),
                        FilterChip(
                          label: Text('Rejected'),
                          selected: _selectedStatuses.contains('rejected'),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedStatuses.add('rejected');
                              } else {
                                _selectedStatuses.remove('rejected');
                              }
                            });
                          },
                          selectedColor: Colors.red.shade100,
                          checkmarkColor: Colors.red.shade700,
                        ),
                      ],
                    ),
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Consumer<TeamProvider>(
                          builder: (context, teamProvider, _) {
                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Team',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              value: _selectedTeamId,
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Teams'),
                                ),
                                ...teamProvider.teams.map((team) {
                                  return DropdownMenuItem<String>(
                                    value: team.id,
                                    child: Text(team.name),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedTeamId = value;
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Reset to previous selections
                    _selectedLeaveTypes = currentLeaveTypes;
                    _selectedStatuses = currentStatuses;
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    
                    // Apply filters
                    final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
                    _processLeavesIntoEvents(leaveProvider.leaves);
                    _updateSelectedLeaves();
                    
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leave Calendar'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter',
            ),
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
                  _buildCalendar(),
                  Divider(height: 1),
                  _buildLeavesForSelectedDay(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      eventLoader: (day) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        return _leaveEvents[normalizedDay] ?? [];
      },
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: _onDaySelected,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      calendarStyle: CalendarStyle(
        markersMaxCount: 3,
        markerDecoration: BoxDecoration(
          color: Colors.blue.shade700,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.blue.shade200,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.blue.shade700,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonTextStyle: TextStyle(color: Colors.blue.shade700),
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade700),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  Widget _buildLeavesForSelectedDay() {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    if (_selectedLeaves.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'No leaves for ${dateFormat.format(_selectedDay)}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Leaves for ${dateFormat.format(_selectedDay)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedLeaves.length,
              itemBuilder: (context, index) {
                final leave = _selectedLeaves[index];
                return _buildLeaveCard(leave);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeaveCard(LeaveModel leave) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(leave.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(leave.status),
                    style: TextStyle(
                      color: _getStatusColor(leave.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  '${leave.durationInDays} ${leave.durationInDays == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (leave.userName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 8),
                    Text(
                      leave.userName!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(
                  '${dateFormat.format(leave.startDate)} - ${dateFormat.format(leave.endDate)}',
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(
                  leave.leaveType,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Expanded(
                  child: Text(leave.reason),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }
}
