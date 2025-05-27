import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  _HelpScreenState createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool _isLoading = true;
  String _appVersion = '';
  String _userEmail = '';
  
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
      // Load app info
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      
      // Load user email
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userEmail = user.email ?? '';
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _sendSupportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@teamwork-app.com',
      query: 'subject=TeamWork App Support Request&body=App Version: $_appVersion\nUser Email: $_userEmail\n\nPlease describe your issue:\n',
    );
    
    if (!await launchUrl(emailUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch email client'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Support Card
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
                            'Need Help?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'If you\'re experiencing issues or have questions about the TeamWork app, our support team is here to help.',
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _sendSupportEmail,
                                  icon: Icon(Icons.email),
                                  label: Text('Email Support'),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _launchUrl('https://teamwork-app.com/support'),
                                  icon: Icon(Icons.help),
                                  label: Text('Support Center'),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // FAQ Section
                  Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildFaqItem(
                          'How do I check in and out?',
                          'To check in, go to the Home screen or Attendance screen and tap the "Check In" button. You\'ll need to authenticate with your biometrics (if enabled) and allow location access. To check out, follow the same process but tap the "Check Out" button.',
                        ),
                        _buildFaqItem(
                          'What is an organization code?',
                          'Organization codes are unique 6-character codes that connect users to their organization. Administrators generate these codes and share them with team members. When you sign up or log in, you\'ll be prompted to enter this code if you\'re not already connected to an organization.',
                        ),
                        _buildFaqItem(
                          'How do I join a team?',
                          'Your administrator will add you to teams. Once added, you\'ll see your team assignments in the Team Management section. If you need to be added to a specific team, contact your administrator.',
                        ),
                        _buildFaqItem(
                          'Can I use the app offline?',
                          'Yes, the TeamWork app has offline capabilities. You can check in and out even without an internet connection. Your data will sync once you\'re back online. However, some features like team management require an internet connection.',
                        ),
                        _buildFaqItem(
                          'How do I reset my password?',
                          'On the login screen, tap "Forgot Password?" and enter your email address. You\'ll receive a password reset link via email. Alternatively, go to Settings > Change Password if you\'re already logged in.',
                        ),
                        _buildFaqItem(
                          'How does location tracking work?',
                          'The app uses your device\'s GPS to record your location when you check in or out. This helps verify that you\'re at the designated work location. You can disable location tracking in Settings, but this may affect your attendance verification.',
                        ),
                        _buildFaqItem(
                          'How do I generate attendance reports?',
                          'Administrators can generate attendance reports from the Attendance Reports section. Regular users can export their own attendance history from the Attendance History screen by tapping the export icon.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Video Tutorials
                  Text(
                    'Video Tutorials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.play_circle_filled, color: Colors.red),
                          title: Text('Getting Started with TeamWork'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/tutorials/getting-started'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.play_circle_filled, color: Colors.red),
                          title: Text('Admin: Managing Your Organization'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/tutorials/admin-guide'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.play_circle_filled, color: Colors.red),
                          title: Text('Tracking Attendance Effectively'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/tutorials/attendance-tracking'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.play_circle_filled, color: Colors.red),
                          title: Text('Team Management Features'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/tutorials/team-management'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // App Information
                  Text(
                    'App Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Version'),
                          trailing: Text(_appVersion),
                        ),
                        Divider(height: 1),
                        ListTile(
                          title: Text('Terms of Service'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/terms'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          title: Text('Privacy Policy'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _launchUrl('https://teamwork-app.com/privacy'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          title: Text('Open Source Licenses'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            showLicensePage(
                              context: context,
                              applicationName: 'TeamWork',
                              applicationVersion: _appVersion,
                              applicationIcon: Image.asset(
                                'assets/images/logo.png',
                                width: 50,
                                height: 50,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
