import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../widgets/connection_check_wrapper.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryScreenState createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _databaseHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _selectedUserId;
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _teamMembers = [];
  
  // Filters
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
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
      
      // Set selected user to current user by default
      _selectedUserId = userId;
      
      // If admin, load team members
      if (_isAdmin) {
        _teamMembers = await _databaseHelper.getTeamMembers(userId);
      }
      
      // Load attendance records
      await _loadAttendanceRecords();
    } catch (e) {
      print('Error loading user data: $e');
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
  
  Future<void> _loadAttendanceRecords() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _selectedUserId ?? _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user selected');
      }
      
      // Format dates for database query
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      
      // Load attendance records
      _attendanceRecords = await _databaseHelper.getAttendanceInRange(
        userId, 
        startDateStr, 
        endDateStr,
      );
      
      // Cache the last filter settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_attendance_start_date', startDateStr);
      await prefs.setString('last_attendance_end_date', endDateStr);
      
    } catch (e) {
      print('Error loading attendance records: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading attendance records: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      await _loadAttendanceRecords();
    }
  }
  
  Future<void> _exportAttendanceData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Generate CSV data
      final csv = await _databaseHelper.exportAttendanceToCSV(
        _selectedUserId ?? _auth.currentUser!.uid,
        DateFormat('yyyy-MM-dd').format(_startDate),
        DateFormat('yyyy-MM-dd').format(_endDate),
      );
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance data copied to clipboard as CSV'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error exporting attendance data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);
    return '$twoDigitHours:$twoDigitMinutes';
  }
  
  Widget _buildAttendanceCard(Map<String, dynamic> attendance) {
    final date = DateTime.parse(attendance['date'] as String);
    final checkInTime = attendance['check_in_time'] != null 
        ? DateTime.parse(attendance['check_in_time'] as String) 
        : null;
    final checkOutTime = attendance['check_out_time'] != null 
        ? DateTime.parse(attendance['check_out_time'] as String) 
        : null;
    
    final isToday = DateFormat('yyyy-MM-dd').format(date) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    Duration? duration;
    if (checkInTime != null && checkOutTime != null) {
      duration = checkOutTime.difference(checkInTime);
    }
    
    final checkInLocation = attendance['check_in_location'] as String?;
    final checkOutLocation = attendance['check_out_location'] as String?;
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: isToday ? 2 : 1,
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
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.blue.shade800 : Colors.black87,
                    ),
                  ),
                ),
                Spacer(),
                if (duration != null) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Hours: ${_formatDuration(duration)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check In',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        checkInTime != null 
                            ? DateFormat('h:mm a').format(checkInTime) 
                            : 'Not checked in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: checkInTime != null 
                              ? Colors.green.shade700 
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (checkInLocation != null && checkInLocation.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                checkInLocation,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check Out',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        checkOutTime != null 
                            ? DateFormat('h:mm a').format(checkOutTime) 
                            : checkInTime != null 
                                ? 'Not checked out' 
                                : '---',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: checkOutTime != null 
                              ? Colors.red.shade700 
                              : checkInTime != null 
                                  ? Colors.orange.shade700 
                                  : Colors.grey.shade500,
                        ),
                      ),
                      if (checkOutLocation != null && checkOutLocation.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                checkOutLocation,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (attendance['notes'] != null && (attendance['notes'] as String).isNotEmpty) ...[
              SizedBox(height: 12),
              Divider(),
              SizedBox(height: 8),
              Text(
                'Notes:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                attendance['notes'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryCard() {
    // Calculate summary statistics
    int totalDays = _attendanceRecords.length;
    int presentDays = _attendanceRecords.where((record) => 
      record['check_in_time'] != null).length;
    int absentDays = totalDays - presentDays;
    
    Duration totalHours = Duration.zero;
    int lateCheckIns = 0;
    int earlyCheckOuts = 0;
    
    // Define work hours (9 AM to 5 PM)
    final workStartTime = TimeOfDay(hour: 9, minute: 0);
    final workEndTime = TimeOfDay(hour: 17, minute: 0);
    
    for (var record in _attendanceRecords) {
      if (record['check_in_time'] != null && record['check_out_time'] != null) {
        final checkIn = DateTime.parse(record['check_in_time'] as String);
        final checkOut = DateTime.parse(record['check_out_time'] as String);
        
        // Add to total hours
        totalHours += checkOut.difference(checkIn);
        
        // Check if late
        final checkInTimeOfDay = TimeOfDay.fromDateTime(checkIn);
        if (checkInTimeOfDay.hour > workStartTime.hour || 
            (checkInTimeOfDay.hour == workStartTime.hour && 
             checkInTimeOfDay.minute > workStartTime.minute + 15)) { // 15 min grace period
          lateCheckIns++;
        }
        
        // Check if early checkout
        final checkOutTimeOfDay = TimeOfDay.fromDateTime(checkOut);
        if (checkOutTimeOfDay.hour < workEndTime.hour || 
            (checkOutTimeOfDay.hour == workEndTime.hour && 
             checkOutTimeOfDay.minute < workEndTime.minute)) {
          earlyCheckOuts++;
        }
      }
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _buildSummaryItem(
                  title: 'Present',
                  value: '$presentDays',
                  color: Colors.green,
                ),
                _buildSummaryItem(
                  title: 'Absent',
                  value: '$absentDays',
                  color: Colors.red,
                ),
                _buildSummaryItem(
                  title: 'Total Hours',
                  value: '${totalHours.inHours}',
                  color: Colors.blue,
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryItem(
                  title: 'Late Check-ins',
                  value: '$lateCheckIns',
                  color: Colors.orange,
                ),
                _buildSummaryItem(
                  title: 'Early Check-outs',
                  value: '$earlyCheckOuts',
                  color: Colors.purple,
                ),
                _buildSummaryItem(
                  title: 'Avg Hours/Day',
                  value: presentDays > 0 
                      ? (totalHours.inMinutes / (presentDays * 60)).toStringAsFixed(1)
                      : '0',
                  color: Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
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
          title: Text('Attendance History'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
            IconButton(
              icon: Icon(Icons.file_download),
              onPressed: _exportAttendanceData,
              tooltip: 'Export Data',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Filters Section
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _selectDateRange,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.date_range,
                                        size: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey.shade600,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_isAdmin && _teamMembers.isNotEmpty) ...[
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _selectedUserId,
                                hint: Text('Select User'),
                                underline: Container(),
                                icon: Icon(Icons.person, size: 16),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedUserId = newValue;
                                  });
                                  _loadAttendanceRecords();
                                },
                                items: [
                                  DropdownMenuItem<String>(
                                    value: _auth.currentUser?.uid,
                                    child: Text('Me'),
                                  ),
                                  ..._teamMembers.map((user) {
                                    return DropdownMenuItem<String>(
                                      value: user['id'] as String,
                                      child: Text(user['name'] as String),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: _attendanceRecords.isEmpty
                        ? Center(
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
                                  'No attendance records found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try selecting a different date range',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.all(16),
                            children: [
                              // Summary Card
                              _buildSummaryCard(),
                              SizedBox(height: 16),
                              
                              // Attendance Records
                              Text(
                                'Daily Records',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),
                              ..._attendanceRecords.map((record) => _buildAttendanceCard(record)),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
