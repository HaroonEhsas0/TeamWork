import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/leave_model.dart';
import '../providers/leave_provider.dart';
import '../providers/user_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({Key? key}) : super(key: key);

  @override
  _LeaveManagementScreenState createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _userId;
  String? _organizationId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
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
      
      _userId = currentUser.id;
      _organizationId = currentUser.organizationId;
      _isAdmin = currentUser.role == 'admin' || currentUser.role == 'manager';
      
      // Load leave requests
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      
      if (_isAdmin && _organizationId != null) {
        // Admin sees all leave requests for the organization
        await leaveProvider.loadTeamLeaves(_organizationId!);
      } else if (_userId != null) {
        // Regular user sees only their leave requests
        await leaveProvider.loadUserLeaves(_userId!);
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading leave data: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showAddLeaveDialog() {
    if (_organizationId == null || _userId == null) {
      ErrorUtils.showErrorSnackBar(context, 'Unable to create leave request. Please try again later.');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => LeaveRequestDialog(
        organizationId: _organizationId!,
        userId: _userId!,
        onSave: () {
          // Refresh the leave list
          final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
          if (_isAdmin && _organizationId != null) {
            leaveProvider.loadTeamLeaves(_organizationId!);
          } else if (_userId != null) {
            leaveProvider.loadUserLeaves(_userId!);
          }
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leave Management'),
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
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Consumer<LeaveProvider>(
                builder: (context, leaveProvider, _) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaveList(leaveProvider.pendingLeaves),
                      _buildLeaveList(leaveProvider.approvedLeaves),
                      _buildLeaveList(leaveProvider.rejectedLeaves),
                    ],
                  );
                },
              ),
        floatingActionButton: _userId != null
            ? FloatingActionButton(
                onPressed: _showAddLeaveDialog,
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                child: Icon(Icons.add),
                tooltip: 'Request Leave',
              )
            : null,
      ),
    );
  }
  
  Widget _buildLeaveList(List<LeaveModel> leaves) {
    if (leaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No leave requests found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: leaves.length,
      itemBuilder: (context, index) {
        final leave = leaves[index];
        return _buildLeaveCard(leave);
      },
    );
  }
  
  Widget _buildLeaveCard(LeaveModel leave) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isCurrentUserLeave = leave.userId == _userId;
    
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
            if (!isCurrentUserLeave && leave.userName != null)
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
            if (leave.isRejected && leave.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection reason: ${leave.rejectionReason}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            if (leave.isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isCurrentUserLeave)
                    TextButton.icon(
                      onPressed: () => _cancelLeaveRequest(leave.id),
                      icon: Icon(Icons.cancel, color: Colors.red.shade700),
                      label: Text(
                        'Cancel Request',
                        style: TextStyle(
                          color: Colors.red.shade700,
                        ),
                      ),
                    )
                  else if (_isAdmin)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showRejectDialog(leave.id),
                          icon: Icon(Icons.close, color: Colors.red.shade700),
                          label: Text(
                            'Reject',
                            style: TextStyle(
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _approveLeaveRequest(leave.id),
                          icon: Icon(Icons.check),
                          label: Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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
  
  Future<void> _approveLeaveRequest(String leaveId) async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final success = await leaveProvider.approveLeaveRequest(leaveId, _userId!);
      
      if (success) {
        ErrorUtils.showSuccessSnackBar(context, 'Leave request approved successfully');
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to approve leave request');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error approving leave request: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _cancelLeaveRequest(String leaveId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Leave Request'),
        content: Text('Are you sure you want to cancel this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final success = await leaveProvider.cancelLeaveRequest(leaveId);
      
      if (success) {
        ErrorUtils.showSuccessSnackBar(context, 'Leave request cancelled successfully');
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to cancel leave request');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error cancelling leave request: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showRejectDialog(String leaveId) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Leave Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for rejecting this leave request:'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ErrorUtils.showErrorSnackBar(context, 'Please provide a reason for rejection');
                return;
              }
              
              Navigator.of(context).pop();
              _rejectLeaveRequest(leaveId, reasonController.text.trim());
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _rejectLeaveRequest(String leaveId, String reason) async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final success = await leaveProvider.rejectLeaveRequest(leaveId, _userId!, reason);
      
      if (success) {
        ErrorUtils.showSuccessSnackBar(context, 'Leave request rejected successfully');
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to reject leave request');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error rejecting leave request: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class LeaveRequestDialog extends StatefulWidget {
  final String organizationId;
  final String userId;
  final VoidCallback onSave;
  
  const LeaveRequestDialog({
    Key? key,
    required this.organizationId,
    required this.userId,
    required this.onSave,
  }) : super(key: key);

  @override
  _LeaveRequestDialogState createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends State<LeaveRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  DateTime _startDate = DateTime.now().add(Duration(days: 1));
  DateTime _endDate = DateTime.now().add(Duration(days: 1));
  String _leaveType = 'Annual Leave';
  
  bool _isLoading = false;
  
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
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
  
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, update it
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }
  
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }
  
  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check for overlapping leave
      final leaveProvider = Provider.of<LeaveProvider>(context, listen: false);
      final hasOverlap = leaveProvider.hasOverlappingLeave(widget.userId, _startDate, _endDate);
      
      if (hasOverlap) {
        ErrorUtils.showErrorSnackBar(context, 'You already have an approved leave during this period');
        return;
      }
      
      // Get user name
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      final userName = currentUser?.name;
      
      // Create leave request
      final newLeave = LeaveModel(
        id: '', // Will be generated by Firestore
        userId: widget.userId,
        userName: userName,
        organizationId: widget.organizationId,
        startDate: _startDate,
        endDate: _endDate,
        leaveType: _leaveType,
        reason: _reasonController.text,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      final success = await leaveProvider.createLeaveRequest(newLeave);
      
      if (success) {
        Navigator.of(context).pop();
        widget.onSave();
        ErrorUtils.showSuccessSnackBar(context, 'Leave request submitted successfully');
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to submit leave request');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error submitting leave request: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return AlertDialog(
      title: Text('Request Leave'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(),
                ),
                value: _leaveType,
                items: _leaveTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _leaveType = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a leave type';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(dateFormat.format(_startDate)),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(dateFormat.format(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Duration: ${_endDate.difference(_startDate).inDays + 1} days',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for Leave',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for your leave request';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitLeaveRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Submit'),
        ),
      ],
    );
  }
}
