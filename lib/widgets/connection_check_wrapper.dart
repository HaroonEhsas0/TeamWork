import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../database/database_helper.dart';

/// A wrapper widget that checks if a user is connected to an organization
/// and restricts access to features if they're not connected.
class ConnectionCheckWrapper extends StatefulWidget {
  final Widget child;
  final bool adminBypass;
  
  const ConnectionCheckWrapper({
    super.key,
    required this.child,
    this.adminBypass = true,
  });

  @override
  _ConnectionCheckWrapperState createState() => _ConnectionCheckWrapperState();
}

class _ConnectionCheckWrapperState extends State<ConnectionCheckWrapper> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isChecking = true;
  bool _isConnected = false;
  bool _isAdmin = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _checkConnection();
  }
  
  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null; // Clear any previous error messages
    });
    
    try {
      // Check if there's an active network connection with timeout
      bool hasNetwork = true;
      try {
        // Add timeout to prevent hanging on network issues
        final result = await InternetAddress.lookup('google.com')
            .timeout(Duration(seconds: 5), onTimeout: () {
          print('Network connectivity check timed out');
          return <InternetAddress>[];
        });
        hasNetwork = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        print('Network connectivity check failed: SocketException');
        hasNetwork = false;
      } catch (e) {
        print('Network connectivity check failed: $e');
        hasNetwork = false;
      }
      
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isChecking = false;
          _isConnected = false;
          _errorMessage = 'User not logged in. Please log in again.';
        });
        return;
      }
      
      // If offline, try to use cached connection status
      if (!hasNetwork) {
        final prefs = await SharedPreferences.getInstance();
        final cachedIsConnected = prefs.getBool('user_connected_$userId') ?? false;
        final cachedIsAdmin = prefs.getBool('user_admin_$userId') ?? false;
        final cachedOrgCode = prefs.getString('user_org_code_$userId');
        
        if (cachedIsConnected || cachedIsAdmin) {
          setState(() {
            _isChecking = false;
            _isAdmin = cachedIsAdmin;
            _isConnected = cachedIsConnected;
            _orgCode = cachedOrgCode;
            _errorMessage = null;
          });
          return;
        }
      }
      
      // Check if user is admin
      final isAdmin = await _checkIfUserIsAdmin(userId);
      
      // Check if user is connected to an organization
      final isConnected = await _checkIfUserIsConnected(userId);
      
      // Get organization code if connected
      String? orgCode;
      String? orgName;
      if (isConnected) {
        orgCode = await _getUserOrganizationCode(userId);
        
        // Verify if the organization code is still valid
        final codeData = await _verifyOrganizationCode(orgCode ?? '');
        if (codeData == null) {
          // Code has expired or been deactivated
          setState(() {
            _isChecking = false;
            _isAdmin = isAdmin;
            _isConnected = false;
            _orgCode = null;
            _errorMessage = 'Your organization code has expired or been deactivated. Please enter a new code.';
          });
          
          // Clear cached connection status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('user_connected_$userId', false);
          await prefs.remove('user_org_code_$userId');
          await prefs.remove('user_org_name_$userId');
          
          return;
        } else if (codeData != null) {
          orgName = codeData['org_name'] as String?;
        }
      }
      
      // Cache connection status for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_connected_$userId', isConnected);
      await prefs.setBool('user_admin_$userId', isAdmin);
      if (orgCode != null) {
        await prefs.setString('user_org_code_$userId', orgCode);
      }
      if (orgName != null) {
        await prefs.setString('user_org_name_$userId', orgName);
      }
      
      setState(() {
        _isChecking = false;
        _isAdmin = isAdmin;
        _isConnected = isConnected;
        _orgCode = orgCode;
        _errorMessage = isConnected ? null : 'You need to connect to an organization to access this feature.';
      });
    } catch (e) {
      print('Error checking connection: $e');
      setState(() {
        _isChecking = false;
        _isConnected = false;
        _errorMessage = 'Error checking connection: ${e.toString()}';
      });
    }
  }
  
  Future<bool> _connectToOrganization(String code) async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'User not logged in. Please log in again.';
        });
        return false;
      }
      
      // Verify organization code
      final codeData = await _verifyOrganizationCode(code);
      if (codeData == null) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Invalid organization code. Please check and try again.';
        });
        return false;
      }
      
      // Connect user to organization
      final success = await _connectUserToOrg(userId, code);
      
      if (success) {
        // Cache connection status for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_connected_$userId', true);
        await prefs.setString('user_org_code_$userId', code);
        if (codeData['org_name'] != null) {
          await prefs.setString('user_org_name_$userId', codeData['org_name'] as String);
        }
        
        setState(() {
          _isChecking = false;
          _isConnected = true;
          _errorMessage = null;
        });
        return true;
      } else {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Failed to connect to organization. Please try again.';
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _errorMessage = 'Error connecting to organization: ${e.toString()}';
      });
      return false;
    }
  }
  
  // Validate organization code format
  bool _isValidOrgCode(String code) {
    // Organization codes should be 6 characters, uppercase alphanumeric
    final RegExp orgCodeRegex = RegExp(r'^[A-Z0-9]{6}$');
    return orgCodeRegex.hasMatch(code);
  }
  
  // Helper method to build instruction steps
  Widget _buildInstructionStep({required int number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _showOrgCodeDialog() async {
    final orgCodeController = TextEditingController();
    bool isLoading = false;
    String? errorText;
    String? orgName;
    
    // Check if we have a cached organization name for better UX
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        orgName = prefs.getString('user_org_name_$userId');
      }
    } catch (e) {
      print('Error getting cached org name: $e');
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Connect to Organization'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your organization code to connect to your team.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: orgCodeController,
                      decoration: InputDecoration(
                        labelText: 'Organization Code',
                        hintText: 'Enter 6-character code',
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      onChanged: (value) {
                        // Clear error when user types
                        if (errorText != null) {
                          setState(() {
                            errorText = null;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      'How to get an organization code:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildInstructionStep(
                      number: 1,
                      text: 'Ask your administrator to generate a code for your organization.',
                    ),
                    SizedBox(height: 8),
                    _buildInstructionStep(
                      number: 2,
                      text: 'Enter the 6-character code above exactly as provided.',
                    ),
                    SizedBox(height: 8),
                    _buildInstructionStep(
                      number: 3,
                      text: 'Once connected, you\'ll have access to your team\'s data.',
                    ),
                    if (isLoading) ...[
                      SizedBox(height: 16),
                      Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading 
                    ? null 
                    : () async {
                        final code = orgCodeController.text.trim().toUpperCase();
                        
                        // Validate code format
                        if (!_isValidOrgCode(code)) {
                          setState(() {
                            errorText = 'Invalid code format. Must be 6 characters (letters and numbers).';
                          });
                          return;
                        }
                        
                        // Show loading state
                        setState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        
                        // Verify and connect with timeout to prevent UI freezing
                        bool success = false;
                        try {
                          success = await Future.timeout(
                            Duration(seconds: 15),
                            () => _databaseHelper.connectUserToOrganization(_auth.currentUser!.uid, code)
                          ).catchError((error) {
                            print('Connection attempt timed out or failed: $error');
                            // Cache the failed attempt for analytics
                            try {
                              final prefs = SharedPreferences.getInstance();
                              prefs.then((p) {
                                final failedAttempts = p.getInt('failed_connection_attempts') ?? 0;
                                p.setInt('failed_connection_attempts', failedAttempts + 1);
                                p.setString('last_failed_code', code);
                                p.setString('last_failure_reason', error.toString());
                              });
                            } catch (e) {
                              print('Error caching failed attempt: $e');
                            }
                            return false;
                          });
                        } catch (e) {
                          print('Error during connection attempt: $e');
                          setState(() {
                            isLoading = false;
                            errorText = 'Connection failed: ${e.toString().replaceAll('Exception: ', '')}';
                          });
                        }
                        
                        // Get organization name if successful
                        String? orgName;
                        if (success) {
                          try {
                            final codeData = await _databaseHelper.verifyOrganizationCode(code);
                            orgName = codeData?['org_name'] as String?;
                          } catch (e) {
                            print('Error getting organization name: $e');
                          }
                        }
                        
                        // Handle result
                        if (success) {
                          Navigator.pop(dialogContext);
                          
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Successfully connected to ${orgName ?? 'organization'}',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          
                          // Refresh connection status
            );
          },
        );
      },
    );
  }
  
  // Helper method to verify organization code
  Future<void> _verifyAndConnectToOrganization(String code) async {
    if (!_isValidOrgCode(code)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid code format. Organization codes should be 6 characters, uppercase alphanumeric.')),
      );
      return;
    }
    
    final codeData = await _verifyOrganizationCode(code);
    if (codeData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid organization code. Please check and try again.')),
      );
      return;
    }
    
    // If code is valid, attempt to connect
    final success = await _connectToOrganization(code);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully connected to organization!')),
      );
    }
  }
  
  // Helper methods to implement database functionality
  Future<bool> _checkIfUserIsAdmin(String userId) async {
    // Implementation would depend on your database structure
    // For now, we'll use SharedPreferences as a mock
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('user_admin_$userId') ?? false;
  }

  Future<bool> _checkIfUserIsConnected(String userId) async {
    // Implementation would depend on your database structure
    // For now, we'll use SharedPreferences as a mock
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('user_connected_$userId') ?? false;
  }

  Future<String?> _getUserOrganizationCode(String userId) async {
    // Implementation would depend on your database structure
    // For now, we'll use SharedPreferences as a mock
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_org_code_$userId');
  }

  Future<Map<String, dynamic>?> _verifyOrganizationCode(String code) async {
    // Implementation would depend on your database structure
    // For now, return a mock response if the code matches a pattern
    if (_isValidOrgCode(code)) {
      return {'org_name': 'Test Organization', 'active': true};
    }
    return null;
  }

  Future<bool> _connectUserToOrg(String userId, String code) async {
    // Implementation would depend on your database structure
    // For now, we'll use SharedPreferences as a mock
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_connected_$userId', true);
      await prefs.setString('user_org_code_$userId', code);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checking, show loading
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking connection status...'),
            ],
          ),
        ),
      );
    }
    
    // If admin and adminBypass is true, allow access
    if (_isAdmin && widget.adminBypass) {
      return widget.child;
    }
    
    // If connected, allow access
    if (_isConnected) {
      return widget.child;
    }
    
    // Otherwise, show connection required screen
    return Scaffold(
      appBar: AppBar(
        title: Text('Connection Required'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _checkConnection,
            tooltip: 'Refresh Connection',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business,
                size: 80,
                color: Colors.blue,
              ),
              SizedBox(height: 24),
              Text(
                'Connect to Your Organization',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage ?? 'You need to connect to an organization to access this feature.',
                style: TextStyle(
                  fontSize: 16,
                  color: _errorMessage != null ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showOrgCodeDialog,
                icon: Icon(Icons.vpn_key),
                label: Text('Enter Organization Code'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              if (_isAdmin) ...[
                Text(
                  'As an admin, you can create your own organization.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to organization creation screen
                    Navigator.pushNamed(context, '/organization');
                  },
                  icon: Icon(Icons.add_business),
                  label: Text('Create Organization'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
