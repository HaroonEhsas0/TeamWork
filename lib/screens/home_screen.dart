import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../database_helper.dart';
import '../widgets/connection_check_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _databaseHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  final _localAuth = LocalAuthentication();
  
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isCheckedIn = false;
  String? _userName;
  String? _orgName;
  DateTime? _lastCheckInTime;
  List<Map<String, dynamic>> _recentAttendance = [];
  Map<String, dynamic>? _todayAttendance;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkForOrgCodeDialog();
  }
  
  Future<void> _checkForOrgCodeDialog() async {
    // Check if we need to show org code dialog (from login screen)
    try {
      final prefs = await SharedPreferences.getInstance();
      final showDialog = prefs.getBool('show_org_code_dialog') ?? false;
      
      if (showDialog) {
        // Clear the flag
        await prefs.setBool('show_org_code_dialog', false);
        
        // Wait for the build to complete before showing dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Show organization code dialog
          // This will be handled by the ConnectionCheckWrapper
        });
      }
    } catch (e) {
      print('Error checking for org code dialog: $e');
    }
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
      
      // Get user name
      _userName = _auth.currentUser?.displayName ?? 'User';
      
      // Check if user is admin
      _isAdmin = await _databaseHelper.isUserAdmin(userId);
      
      // Get organization name
      final userOrg = await _databaseHelper.getUserOrganization(userId);
      _orgName = userOrg?['org_name'] as String?;
      
      // Check if user is checked in today
      _todayAttendance = await _databaseHelper.getTodayAttendance(userId);
      _isCheckedIn = _todayAttendance != null && 
                    _todayAttendance!['check_in_time'] != null && 
                    _todayAttendance!['check_out_time'] == null;
      
      if (_isCheckedIn && _todayAttendance != null) {
        _lastCheckInTime = DateTime.parse(_todayAttendance!['check_in_time'] as String);
      }
      
      // Get recent attendance records
      _recentAttendance = await _databaseHelper.getRecentAttendance(userId, limit: 7);
      
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
          _lastCheckInTime = null;
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
          _lastCheckInTime = DateTime.now();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully checked in'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload attendance data
      await _loadUserData();
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
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: isToday ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? Colors.blue.shade300 : Colors.transparent,
          width: isToday ? 1 : 0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isToday ? Colors.blue.shade100 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.blue.shade800 : Colors.grey.shade800,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday 
                        ? 'Today' 
                        : DateFormat('EEEE, MMM d').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.login,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        checkInTime != null 
                            ? DateFormat('h:mm a').format(checkInTime) 
                            : 'Not checked in',
                        style: TextStyle(
                          fontSize: 12,
                          color: checkInTime != null 
                              ? Colors.black87 
                              : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(width: 16),
                      Icon(
                        Icons.logout,
                        size: 14,
                        color: Colors.red.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        checkOutTime != null 
                            ? DateFormat('h:mm a').format(checkOutTime) 
                            : checkInTime != null 
                                ? 'Not checked out' 
                                : '---',
                        style: TextStyle(
                          fontSize: 12,
                          color: checkOutTime != null 
                              ? Colors.black87 
                              : checkInTime != null 
                                  ? Colors.orange.shade800 
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (duration != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
          title: Text('TeamWork'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadUserData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              tooltip: 'Sign Out',
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        _userName?.isNotEmpty == true 
                            ? _userName![0].toUpperCase() 
                            : 'U',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _userName ?? 'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _orgName ?? 'No Organization',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home),
                title: Text('Home'),
                selected: true,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text('Attendance History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/attendance_history');
                },
              ),
              if (_isAdmin) ...[
                Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.business),
                  title: Text('Organization'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/organization');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Team Management'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/team_management');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('Attendance Reports'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/attendance_reports');
                  },
                ),
              ],
              Divider(),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & Support'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/help');
                },
              ),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade500],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${_userName?.split(' ').first ?? 'User'}!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              SizedBox(height: 20),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isCheckedIn 
                                          ? Colors.green.withOpacity(0.2) 
                                          : Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _isCheckedIn 
                                            ? Colors.green.shade300 
                                            : Colors.red.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isCheckedIn ? Icons.check_circle : Icons.cancel,
                                          size: 16,
                                          color: _isCheckedIn ? Colors.white : Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          _isCheckedIn ? 'Checked In' : 'Not Checked In',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isCheckedIn && _lastCheckInTime != null) ...[
                                    SizedBox(width: 8),
                                    Text(
                                      'since ${DateFormat('h:mm a').format(_lastCheckInTime!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Check In/Out Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _checkInOut,
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
                      
                      // Recent Attendance
                      Text(
                        'Recent Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      if (_recentAttendance.isEmpty) ...[
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No attendance records found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Your recent attendance will appear here',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        ..._recentAttendance.map((attendance) => _buildAttendanceCard(attendance)),
                        SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/attendance_history');
                          },
                          icon: Icon(Icons.history, size: 16),
                          label: Text('View Full History'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                      ],
                      
                      SizedBox(height: 24),
                      
                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionCard(
                              icon: Icons.history,
                              title: 'History',
                              onTap: () {
                                Navigator.pushNamed(context, '/attendance_history');
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionCard(
                              icon: Icons.people,
                              title: 'Team',
                              onTap: () {
                                Navigator.pushNamed(context, '/team');
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionCard(
                              icon: Icons.settings,
                              title: 'Settings',
                              onTap: () {
                                Navigator.pushNamed(context, '/settings');
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      if (_isAdmin) ...[
                        SizedBox(height: 24),
                        
                        // Admin Section
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Administrator Tools',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/organization');
                                      },
                                      icon: Icon(Icons.business),
                                      label: Text('Organization'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(color: Colors.blue.shade300),
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/team_management');
                                      },
                                      icon: Icon(Icons.people),
                                      label: Text('Teams'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(color: Colors.blue.shade300),
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/attendance_reports');
                                },
                                icon: Icon(Icons.analytics),
                                label: Text('View Attendance Reports'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue.shade700,
                                  side: BorderSide(color: Colors.blue.shade300),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
  
  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.blue.shade700,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
