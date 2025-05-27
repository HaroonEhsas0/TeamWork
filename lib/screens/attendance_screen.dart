import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../database_helper.dart';
import '../widgets/connection_check_wrapper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _databaseHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  final _localAuth = LocalAuthentication();
  
  bool _isLoading = true;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  Map<String, dynamic>? _todayAttendance;
  List<Map<String, dynamic>> _weeklyAttendance = [];
  
  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }
  
  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Get today's attendance record
      _todayAttendance = await _databaseHelper.getTodayAttendance(userId);
      
      // Check if user is checked in
      if (_todayAttendance != null) {
        if (_todayAttendance!['check_in_time'] != null) {
          _checkInTime = DateTime.parse(_todayAttendance!['check_in_time'] as String);
          _isCheckedIn = true;
        }
        
        if (_todayAttendance!['check_out_time'] != null) {
          _checkOutTime = DateTime.parse(_todayAttendance!['check_out_time'] as String);
          _isCheckedIn = false;
        }
      }
      
      // Get weekly attendance records
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      
      _weeklyAttendance = await _databaseHelper.getAttendanceInRange(
        userId,
        DateFormat('yyyy-MM-dd').format(startOfWeek),
        DateFormat('yyyy-MM-dd').format(endOfWeek),
      );
    } catch (e) {
      print('Error loading attendance data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading attendance data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkInOut() async {
    // Check if biometric authentication is available
    bool canCheckBiometrics = false;
    try {
      canCheckBiometrics = await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometric availability: $e');
    }
    
    // Authenticate user
    bool isAuthenticated = false;
    if (canCheckBiometrics) {
      try {
        isAuthenticated = await _localAuth.authenticate(
          localizedReason: _isCheckedIn 
              ? 'Authenticate to check out' 
              : 'Authenticate to check in',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
      } catch (e) {
        print('Error during authentication: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // If biometrics not available, proceed without authentication
      isAuthenticated = true;
    }
    
    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Get current location
    Position? position;
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions are permanently denied, cannot check in/out'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Get current position
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
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
      
      if (_isCheckedIn) {
        // Check out
        await _databaseHelper.checkOut(
          userId, 
          position.latitude, 
          position.longitude,
        );
        
        setState(() {
          _isCheckedIn = false;
          _checkOutTime = DateTime.now();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully checked out'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Check in
        await _databaseHelper.checkIn(
          userId, 
          position.latitude, 
          position.longitude,
        );
        
        setState(() {
          _isCheckedIn = true;
          _checkInTime = DateTime.now();
          _checkOutTime = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully checked in'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload attendance data
      await _loadAttendanceData();
    } catch (e) {
      print('Error during check in/out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
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
  
  Widget _buildWeeklyAttendanceChart() {
    // Create a map of weekdays to attendance records
    final Map<String, Map<String, dynamic>> weekdayAttendance = {};
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    for (var record in _weeklyAttendance) {
      final date = DateTime.parse(record['date'] as String);
      final weekday = DateFormat('EEEE').format(date);
      weekdayAttendance[weekday] = record;
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
              'Weekly Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekdays.map((weekday) {
                final record = weekdayAttendance[weekday];
                final isToday = weekday == DateFormat('EEEE').format(DateTime.now());
                
                Color color;
                IconData icon;
                
                if (record == null) {
                  // No record for this day
                  color = Colors.grey.shade300;
                  icon = Icons.circle_outlined;
                } else if (record['check_in_time'] == null) {
                  // Absent
                  color = Colors.red.shade300;
                  icon = Icons.cancel_outlined;
                } else if (record['check_out_time'] == null) {
                  // Checked in but not out
                  color = Colors.orange.shade300;
                  icon = Icons.access_time;
                } else {
                  // Present (checked in and out)
                  color = Colors.green.shade300;
                  icon = Icons.check_circle_outline;
                }
                
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue.shade100 : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: color,
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      weekday.substring(0, 3),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  color: Colors.green.shade300,
                  label: 'Present',
                  icon: Icons.check_circle_outline,
                ),
                _buildLegendItem(
                  color: Colors.orange.shade300,
                  label: 'Partial',
                  icon: Icons.access_time,
                ),
                _buildLegendItem(
                  color: Colors.red.shade300,
                  label: 'Absent',
                  icon: Icons.cancel_outlined,
                ),
                _buildLegendItem(
                  color: Colors.grey.shade300,
                  label: 'No Data',
                  icon: Icons.circle_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttendanceStatusCard() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (_isCheckedIn) {
      statusText = 'Checked In';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_checkOutTime != null) {
      statusText = 'Checked Out';
      statusColor = Colors.blue;
      statusIcon = Icons.logout;
    } else {
      statusText = 'Not Checked In';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
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
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 32,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (_checkInTime != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Check In: ${DateFormat('h:mm a').format(_checkInTime!)}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_checkOutTime != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Check Out: ${DateFormat('h:mm a').format(_checkOutTime!)}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_checkInTime != null && _checkOutTime != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Duration: ${_formatDuration(_checkOutTime!.difference(_checkInTime!))}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Attendance'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadAttendanceData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: Icon(Icons.history),
              onPressed: () {
                Navigator.pushNamed(context, '/attendance_history');
              },
              tooltip: 'History',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAttendanceData,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Check In/Out Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _checkInOut,
                          icon: Icon(
                            _isCheckedIn ? Icons.logout : Icons.login,
                            size: 24,
                          ),
                          label: Text(
                            _isCheckedIn ? 'Check Out' : 'Check In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCheckedIn 
                                ? Colors.red.shade600 
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Today's Attendance Status
                      _buildAttendanceStatusCard(),
                      SizedBox(height: 24),
                      
                      // Weekly Attendance Chart
                      _buildWeeklyAttendanceChart(),
                      SizedBox(height: 24),
                      
                      // View Full History Button
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/attendance_history');
                        },
                        icon: Icon(Icons.history),
                        label: Text('View Full Attendance History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
