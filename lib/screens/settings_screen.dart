import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _databaseHelper = DatabaseHelper();
  final _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _useBiometrics = true;
  bool _enableNotifications = true;
  bool _locationTracking = true;
  bool _darkMode = false;
  String _appVersion = '';
  String _userName = '';
  String _userEmail = '';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load app info
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      
      // Load user info
      final user = _auth.currentUser;
      if (user != null) {
        _userName = user.displayName ?? 'User';
        _userEmail = user.email ?? '';
      }
      
      // Load preferences
      final prefs = await SharedPreferences.getInstance();
      _useBiometrics = prefs.getBool('use_biometrics') ?? true;
      _enableNotifications = prefs.getBool('notifications_enabled') ?? true;
      _locationTracking = prefs.getBool('location_tracking') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    } catch (e) {
      print('Error loading settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_biometrics', _useBiometrics);
      await prefs.setBool('notifications_enabled', _enableNotifications);
      await prefs.setBool('location_tracking', _locationTracking);
      await prefs.setBool('dark_mode', _darkMode);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
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
    
    // Request password for verification
    final passwordController = TextEditingController();
    final passwordConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please enter your password to confirm account deletion.',
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
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
            child: Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!passwordConfirmed) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Reauthenticate user
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordController.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Delete user data from database
        await _databaseHelper.deleteUserData(user.uid);
        
        // Delete user account
        await user.delete();
        
        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // Clear password
      passwordController.dispose();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                // Account Section
                _buildSectionHeader('Account'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(_userName),
                        subtitle: Text(_userEmail),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            Navigator.pushNamed(context, '/profile');
                          },
                          tooltip: 'Edit Profile',
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.blue.shade700),
                        title: Text('Sign Out'),
                        onTap: () async {
                          await _auth.signOut();
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: Colors.red),
                        title: Text('Delete Account'),
                        subtitle: Text('Permanently delete your account and all data'),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Preferences Section
                _buildSectionHeader('Preferences'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('Use Biometric Authentication'),
                        subtitle: Text('Use fingerprint or face ID for check-in/out'),
                        value: _useBiometrics,
                        onChanged: (value) {
                          setState(() {
                            _useBiometrics = value;
                          });
                          _saveSettings();
                        },
                        secondary: Icon(Icons.fingerprint, color: Colors.blue.shade700),
                      ),
                      Divider(height: 1),
                      SwitchListTile(
                        title: Text('Enable Notifications'),
                        subtitle: Text('Receive reminders and updates'),
                        value: _enableNotifications,
                        onChanged: (value) {
                          setState(() {
                            _enableNotifications = value;
                          });
                          _saveSettings();
                        },
                        secondary: Icon(Icons.notifications, color: Colors.blue.shade700),
                      ),
                      Divider(height: 1),
                      SwitchListTile(
                        title: Text('Location Tracking'),
                        subtitle: Text('Track location during check-in/out'),
                        value: _locationTracking,
                        onChanged: (value) {
                          setState(() {
                            _locationTracking = value;
                          });
                          _saveSettings();
                        },
                        secondary: Icon(Icons.location_on, color: Colors.blue.shade700),
                      ),
                      Divider(height: 1),
                      SwitchListTile(
                        title: Text('Dark Mode'),
                        subtitle: Text('Use dark theme (requires app restart)'),
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                          _saveSettings();
                        },
                        secondary: Icon(Icons.dark_mode, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Support Section
                _buildSectionHeader('Support'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.help_outline, color: Colors.blue.shade700),
                        title: Text('Help & Support'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pushNamed(context, '/help');
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.privacy_tip_outlined, color: Colors.blue.shade700),
                        title: Text('Privacy Policy'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Open privacy policy
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.description_outlined, color: Colors.blue.shade700),
                        title: Text('Terms of Service'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Open terms of service
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader('About'),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('App Version'),
                        trailing: Text(_appVersion),
                      ),
                      Divider(height: 1),
                      ListTile(
                        title: Text('© 2025 TeamWork'),
                        subtitle: Text('All rights reserved'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
