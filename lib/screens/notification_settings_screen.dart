import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../utils/error_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = locator<NotificationService>();
  
  bool _isLoading = true;
  
  // Notification settings
  bool _enableCheckInReminders = true;
  bool _enableCheckOutReminders = true;
  bool _enableTeamUpdates = true;
  bool _enableReportNotifications = true;
  
  // Reminder times
  TimeOfDay _checkInReminderTime = TimeOfDay(hour: 8, minute: 45);
  TimeOfDay _checkOutReminderTime = TimeOfDay(hour: 16, minute: 45);
  
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
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _enableCheckInReminders = prefs.getBool('enable_check_in_reminders') ?? true;
        _enableCheckOutReminders = prefs.getBool('enable_check_out_reminders') ?? true;
        _enableTeamUpdates = prefs.getBool('enable_team_updates') ?? true;
        _enableReportNotifications = prefs.getBool('enable_report_notifications') ?? true;
        
        final checkInHour = prefs.getInt('check_in_reminder_hour') ?? 8;
        final checkInMinute = prefs.getInt('check_in_reminder_minute') ?? 45;
        _checkInReminderTime = TimeOfDay(hour: checkInHour, minute: checkInMinute);
        
        final checkOutHour = prefs.getInt('check_out_reminder_hour') ?? 16;
        final checkOutMinute = prefs.getInt('check_out_reminder_minute') ?? 45;
        _checkOutReminderTime = TimeOfDay(hour: checkOutHour, minute: checkOutMinute);
      });
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading notification settings: ${ErrorUtils.formatErrorMessage(e)}');
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
      
      await prefs.setBool('enable_check_in_reminders', _enableCheckInReminders);
      await prefs.setBool('enable_check_out_reminders', _enableCheckOutReminders);
      await prefs.setBool('enable_team_updates', _enableTeamUpdates);
      await prefs.setBool('enable_report_notifications', _enableReportNotifications);
      
      await prefs.setInt('check_in_reminder_hour', _checkInReminderTime.hour);
      await prefs.setInt('check_in_reminder_minute', _checkInReminderTime.minute);
      
      await prefs.setInt('check_out_reminder_hour', _checkOutReminderTime.hour);
      await prefs.setInt('check_out_reminder_minute', _checkOutReminderTime.minute);
      
      // Schedule notifications based on new settings
      await _scheduleNotifications();
      
      ErrorUtils.showSuccessSnackBar(context, 'Notification settings saved successfully');
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error saving notification settings: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _scheduleNotifications() async {
    // Cancel existing notifications
    await _notificationService.cancelAllScheduledNotifications();
    
    // Schedule check-in reminders
    if (_enableCheckInReminders) {
      await _notificationService.scheduleCheckInReminder(_checkInReminderTime);
    }
    
    // Schedule check-out reminders
    if (_enableCheckOutReminders) {
      await _notificationService.scheduleCheckOutReminder(_checkOutReminderTime);
    }
  }
  
  Future<void> _selectCheckInReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _checkInReminderTime,
    );
    
    if (picked != null && picked != _checkInReminderTime) {
      setState(() {
        _checkInReminderTime = picked;
      });
    }
  }
  
  Future<void> _selectCheckOutReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _checkOutReminderTime,
    );
    
    if (picked != null && picked != _checkOutReminderTime) {
      setState(() {
        _checkOutReminderTime = picked;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Daily Reminders'),
                _buildNotificationToggle(
                  title: 'Check-in Reminders',
                  subtitle: 'Get reminded to check in at work',
                  value: _enableCheckInReminders,
                  onChanged: (value) {
                    setState(() {
                      _enableCheckInReminders = value;
                    });
                  },
                ),
                if (_enableCheckInReminders)
                  _buildTimeSelector(
                    title: 'Check-in Reminder Time',
                    time: _checkInReminderTime,
                    onTap: _selectCheckInReminderTime,
                  ),
                _buildNotificationToggle(
                  title: 'Check-out Reminders',
                  subtitle: 'Get reminded to check out at the end of the day',
                  value: _enableCheckOutReminders,
                  onChanged: (value) {
                    setState(() {
                      _enableCheckOutReminders = value;
                    });
                  },
                ),
                if (_enableCheckOutReminders)
                  _buildTimeSelector(
                    title: 'Check-out Reminder Time',
                    time: _checkOutReminderTime,
                    onTap: _selectCheckOutReminderTime,
                  ),
                
                Divider(height: 32),
                
                _buildSectionTitle('Other Notifications'),
                _buildNotificationToggle(
                  title: 'Team Updates',
                  subtitle: 'Get notified about team changes and announcements',
                  value: _enableTeamUpdates,
                  onChanged: (value) {
                    setState(() {
                      _enableTeamUpdates = value;
                    });
                  },
                ),
                _buildNotificationToggle(
                  title: 'Report Notifications',
                  subtitle: 'Get notified when new reports are available',
                  value: _enableReportNotifications,
                  onChanged: (value) {
                    setState(() {
                      _enableReportNotifications = value;
                    });
                  },
                ),
                
                SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: () async {
                    final result = await _notificationService.requestPermission();
                    if (result) {
                      ErrorUtils.showSuccessSnackBar(context, 'Notification permissions granted');
                    } else {
                      ErrorUtils.showErrorSnackBar(context, 'Notification permissions denied');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Request Notification Permissions'),
                ),
                
                SizedBox(height: 16),
                
                OutlinedButton(
                  onPressed: () async {
                    await _notificationService.sendTestNotification();
                    ErrorUtils.showInfoSnackBar(context, 'Test notification sent');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade700),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Send Test Notification'),
                ),
              ],
            ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
  
  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue.shade700,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
  
  Widget _buildTimeSelector({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.blue.shade700,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${time.format(context)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
