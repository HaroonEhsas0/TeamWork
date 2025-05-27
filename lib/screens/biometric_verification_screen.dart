import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/user_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/biometric_service.dart';
import '../services/location_service.dart';
import '../services/service_locator.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class BiometricVerificationScreen extends StatefulWidget {
  final bool isCheckIn;
  
  const BiometricVerificationScreen({
    Key? key,
    required this.isCheckIn,
  }) : super(key: key);

  @override
  _BiometricVerificationScreenState createState() => _BiometricVerificationScreenState();
}

class _BiometricVerificationScreenState extends State<BiometricVerificationScreen> {
  final BiometricService _biometricService = locator<BiometricService>();
  final LocationService _locationService = locator<LocationService>();
  
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  String _statusMessage = 'Initializing biometric verification...';
  
  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }
  
  Future<void> _checkBiometricAvailability() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking biometric availability...';
    });
    
    try {
      final isAvailable = await _biometricService.checkBiometricAvailability();
      
      setState(() {
        _isBiometricAvailable = isAvailable;
        _statusMessage = isAvailable
            ? 'Biometric authentication is available'
            : 'Biometric authentication is not available on this device';
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
        _statusMessage = 'Error checking biometric availability: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _authenticateAndRecordAttendance() async {
    if (!_isBiometricAvailable) {
      ErrorUtils.showErrorSnackBar(context, 'Biometric authentication is not available on this device');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating...';
    });
    
    try {
      // Authenticate with biometrics
      final isAuthenticated = await _biometricService.authenticate(
        localizedReason: widget.isCheckIn
            ? 'Authenticate to check in'
            : 'Authenticate to check out',
      );
      
      if (!isAuthenticated) {
        setState(() {
          _statusMessage = 'Authentication failed';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Authentication successful. Getting location...';
      });
      
      // Get current location
      final position = await _locationService.getCurrentPosition();
      
      if (position == null) {
        setState(() {
          _statusMessage = 'Failed to get location';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = widget.isCheckIn
            ? 'Recording check-in...'
            : 'Recording check-out...';
      });
      
      // Record attendance
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      final locationString = '${position.latitude},${position.longitude}';
      
      bool success;
      if (widget.isCheckIn) {
        success = await attendanceProvider.checkIn(
          userId: currentUser.id,
          verified: true,
          location: locationString,
        );
      } else {
        success = await attendanceProvider.checkOut(
          userId: currentUser.id,
          verified: true,
          location: locationString,
        );
      }
      
      if (success) {
        setState(() {
          _statusMessage = widget.isCheckIn
              ? 'Check-in recorded successfully'
              : 'Check-out recorded successfully';
        });
        
        // Show success message and navigate back
        ErrorUtils.showSuccessSnackBar(
          context,
          widget.isCheckIn
              ? 'Check-in recorded successfully'
              : 'Check-out recorded successfully',
        );
        
        // Delay navigation to show the success message
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _statusMessage = widget.isCheckIn
              ? 'Failed to record check-in'
              : 'Failed to record check-out';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
      ErrorUtils.showErrorSnackBar(context, 'Error: ${ErrorUtils.formatErrorMessage(e)}');
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
          title: Text(widget.isCheckIn ? 'Check-In Verification' : 'Check-Out Verification'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isCheckIn ? Icons.login : Icons.logout,
                  size: 80,
                  color: Colors.blue.shade700,
                ),
                SizedBox(height: 24),
                Text(
                  widget.isCheckIn
                      ? 'Biometric Check-In'
                      : 'Biometric Check-Out',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Please authenticate using your fingerprint or face recognition to record your attendance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 32),
                if (_isLoading)
                  CircularProgressIndicator()
                else if (!_isBiometricAvailable)
                  Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade700,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Biometric authentication is not available on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Go Back'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _authenticateAndRecordAttendance,
                        icon: Icon(Icons.fingerprint),
                        label: Text(
                          widget.isCheckIn
                              ? 'Authenticate & Check In'
                              : 'Authenticate & Check Out',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
                SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
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
