import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../database_helper.dart';
import '../services/biometric_service.dart';
import '../services/service_locator.dart';
import '../providers/user_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class FingerprintRegistrationScreen extends StatefulWidget {
  const FingerprintRegistrationScreen({Key? key}) : super(key: key);

  @override
  _FingerprintRegistrationScreenState createState() => _FingerprintRegistrationScreenState();
}

class _FingerprintRegistrationScreenState extends State<FingerprintRegistrationScreen> {
  final BiometricService _biometricService = locator<BiometricService>();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  bool _isLoading = true;
  bool _isBiometricAvailable = false;
  bool _isRegistered = false;
  List<BiometricType> _availableBiometrics = [];
  String _statusMessage = 'Checking biometric availability...';
  
  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }
  
  Future<void> _checkBiometricStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking biometric availability...';
    });
    
    try {
      // Check if biometric authentication is available
      final isAvailable = await _biometricService.isBiometricAvailable();
      
      if (isAvailable) {
        // Get available biometric types
        final availableBiometrics = await _biometricService.getAvailableBiometrics();
        
        // Check if user already has registered fingerprint
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.currentUser;
        
        if (currentUser != null) {
          // Get employee record
          final employee = await _databaseHelper.getEmployeeByUserId(currentUser.id);
          
          if (employee != null) {
            final isRegistered = await _databaseHelper.isFingerprintRegistered(employee['id'] as int);
            
            setState(() {
              _isRegistered = isRegistered;
            });
          }
        }
        
        setState(() {
          _isBiometricAvailable = true;
          _availableBiometrics = availableBiometrics;
          _statusMessage = 'Biometric authentication is available';
        });
      } else {
        setState(() {
          _isBiometricAvailable = false;
          _statusMessage = 'Biometric authentication is not available on this device';
        });
      }
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
  
  Future<void> _registerFingerprint() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Authenticating...';
    });
    
    try {
      // Authenticate with biometrics
      final isAuthenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to register your fingerprint',
      );
      
      if (!isAuthenticated) {
        setState(() {
          _statusMessage = 'Authentication failed';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Authentication successful. Registering fingerprint...';
      });
      
      // Get current user
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      // Get or create employee record
      Map<String, dynamic>? employee = await _databaseHelper.getEmployeeByUserId(currentUser.id);
      
      int employeeId;
      if (employee == null) {
        // Create new employee record
        employeeId = await _databaseHelper.createEmployee({
          'user_id': currentUser.id,
          'name': currentUser.name,
          'email': currentUser.email,
          'organization_id': currentUser.organizationId ?? '',
          'team_id': currentUser.teamId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        if (employeeId <= 0) {
          throw Exception('Failed to create employee record');
        }
      } else {
        employeeId = employee['id'] as int;
      }
      
      // Generate credential ID and public key (in a real app, these would be actual cryptographic values)
      final credentialId = 'cred_${DateTime.now().millisecondsSinceEpoch}';
      final publicKey = 'pk_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Register fingerprint
      final success = await _databaseHelper.registerFingerprint(
        employeeId,
        currentUser.id,
        credentialId,
        publicKey,
      );
      
      if (success) {
        setState(() {
          _isRegistered = true;
          _statusMessage = 'Fingerprint registered successfully';
        });
        
        ErrorUtils.showSuccessSnackBar(context, 'Fingerprint registered successfully');
      } else {
        setState(() {
          _statusMessage = 'Failed to register fingerprint';
        });
        
        ErrorUtils.showErrorSnackBar(context, 'Failed to register fingerprint');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error registering fingerprint: ${e.toString()}';
      });
      
      ErrorUtils.showErrorSnackBar(context, 'Error registering fingerprint: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _removeFingerprint() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Fingerprint'),
        content: Text('Are you sure you want to remove your registered fingerprint? You will need to register again to use biometric authentication for check-ins.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Removing fingerprint...';
    });
    
    try {
      // Get current user
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      // Get employee record
      final employee = await _databaseHelper.getEmployeeByUserId(currentUser.id);
      
      if (employee == null) {
        throw Exception('Employee record not found');
      }
      
      // Update employee record to mark fingerprint as not registered
      final db = await _databaseHelper.database;
      await db.update(
        'employees',
        {'fingerprint_registered': 0},
        where: 'id = ?',
        whereArgs: [employee['id']],
      );
      
      // Delete credentials
      await db.delete(
        'employee_credentials',
        where: 'employee_id = ?',
        whereArgs: [employee['id']],
      );
      
      setState(() {
        _isRegistered = false;
        _statusMessage = 'Fingerprint removed successfully';
      });
      
      ErrorUtils.showSuccessSnackBar(context, 'Fingerprint removed successfully');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error removing fingerprint: ${e.toString()}';
      });
      
      ErrorUtils.showErrorSnackBar(context, 'Error removing fingerprint: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _getBiometricTypesText() {
    if (_availableBiometrics.isEmpty) {
      return 'No biometric types available';
    }
    
    return _availableBiometrics.map((type) => _biometricService.getBiometricTypeName(type)).join(', ');
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Fingerprint Registration'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _isBiometricAvailable 
                          ? (_isRegistered ? Icons.fingerprint : Icons.add) 
                          : Icons.error_outline,
                      size: 120,
                      color: _isBiometricAvailable 
                          ? (_isRegistered ? Colors.green.shade600 : Colors.blue.shade700) 
                          : Colors.red.shade700,
                    ),
                    SizedBox(height: 24),
                    Text(
                      _isRegistered
                          ? 'Fingerprint Registered'
                          : (_isBiometricAvailable 
                              ? 'Register Your Fingerprint' 
                              : 'Biometric Authentication Unavailable'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _isRegistered
                          ? 'Your fingerprint is registered and can be used for attendance verification.'
                          : (_isBiometricAvailable 
                              ? 'Register your fingerprint to use biometric authentication for attendance check-ins and check-outs.' 
                              : 'This device does not support biometric authentication or it is not properly configured.'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isBiometricAvailable && _availableBiometrics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Available biometric types: ${_getBiometricTypesText()}',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: 32),
                    if (_isBiometricAvailable)
                      _isRegistered
                          ? ElevatedButton.icon(
                              onPressed: _removeFingerprint,
                              icon: Icon(Icons.delete),
                              label: Text('Remove Fingerprint'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _registerFingerprint,
                              icon: Icon(Icons.fingerprint),
                              label: Text('Register Fingerprint'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                    SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),
                    Card(
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
                              'Why Register Your Fingerprint?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildInfoItem(
                              icon: Icons.security,
                              title: 'Enhanced Security',
                              description: 'Prevent unauthorized check-ins and ensure accurate attendance tracking.',
                            ),
                            SizedBox(height: 12),
                            _buildInfoItem(
                              icon: Icons.speed,
                              title: 'Faster Check-ins',
                              description: 'Quick and convenient way to verify your identity when checking in or out.',
                            ),
                            SizedBox(height: 12),
                            _buildInfoItem(
                              icon: Icons.privacy_tip,
                              title: 'Privacy Protection',
                              description: 'Your biometric data never leaves your device. Only a secure token is stored on our servers.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
