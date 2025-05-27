import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'TeamWork';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Employee Attendance Management System';
  static const String appDeveloper = 'TeamWork Development Team';
  static const String appWebsite = 'https://teamwork-app.com';
  static const String appSupportEmail = 'support@teamwork-app.com';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String teamsCollection = 'teams';
  static const String teamMembersCollection = 'team_members';
  static const String attendanceCollection = 'attendance';
  static const String organizationCodesCollection = 'organization_codes';
  
  // Shared Preferences Keys
  static const String userConnectedKey = 'user_connected';
  static const String userAdminKey = 'user_admin';
  static const String userOrgCodeKey = 'user_org_code';
  static const String userOrgNameKey = 'user_org_name';
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String locationEnabledKey = 'location_enabled';
  static const String darkModeEnabledKey = 'dark_mode_enabled';
  static const String userDataKey = 'user_data';
  static const String workLocationLatKey = 'work_location_lat';
  static const String workLocationLngKey = 'work_location_lng';
  static const String workLocationNameKey = 'work_location_name';
  
  // Routes
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String organizationRoute = '/organization';
  static const String attendanceHistoryRoute = '/attendance_history';
  static const String attendanceRoute = '/attendance';
  static const String teamManagementRoute = '/team_management';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String helpRoute = '/help';
  static const String attendanceReportsRoute = '/attendance_reports';
  
  // Error Messages
  static const String networkErrorMessage = 'Network error. Please check your internet connection and try again.';
  static const String authErrorMessage = 'Authentication error. Please try again.';
  static const String permissionDeniedMessage = 'Permission denied. Please grant the required permissions to use this feature.';
  static const String locationErrorMessage = 'Location error. Please enable location services and try again.';
  static const String biometricErrorMessage = 'Biometric authentication error. Please try again or use an alternative authentication method.';
  static const String generalErrorMessage = 'An error occurred. Please try again.';
  static const String sessionExpiredMessage = 'Your session has expired. Please log in again.';
  
  // Success Messages
  static const String loginSuccessMessage = 'Login successful.';
  static const String registerSuccessMessage = 'Registration successful.';
  static const String checkInSuccessMessage = 'Check-in successful.';
  static const String checkOutSuccessMessage = 'Check-out successful.';
  static const String teamCreatedMessage = 'Team created successfully.';
  static const String memberAddedMessage = 'Member added successfully.';
  static const String memberRemovedMessage = 'Member removed successfully.';
  static const String profileUpdatedMessage = 'Profile updated successfully.';
  static const String settingsUpdatedMessage = 'Settings updated successfully.';
  static const String passwordChangedMessage = 'Password changed successfully.';
  static const String organizationCodeGeneratedMessage = 'Organization code generated successfully.';
  
  // Validation Messages
  static const String emailRequiredMessage = 'Email is required.';
  static const String invalidEmailMessage = 'Please enter a valid email address.';
  static const String passwordRequiredMessage = 'Password is required.';
  static const String passwordLengthMessage = 'Password must be at least 6 characters.';
  static const String nameRequiredMessage = 'Name is required.';
  static const String orgCodeRequiredMessage = 'Organization code is required.';
  static const String orgCodeLengthMessage = 'Organization code must be 6 characters.';
  
  // Timeouts
  static const int networkTimeoutSeconds = 10;
  static const int locationTimeoutSeconds = 10;
  static const int biometricTimeoutSeconds = 30;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double defaultElevation = 2.0;
  static const double defaultIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double defaultButtonHeight = 48.0;
  static const double defaultTextFieldHeight = 56.0;
  
  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // Colors
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF03A9F4);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFFFA000);
  static const Color infoColor = Color(0xFF2196F3);
  
  // Work Hours
  static const TimeOfDay workStartTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay workEndTime = TimeOfDay(hour: 17, minute: 0);
  static const int lateGraceMinutes = 15;
  static const int earlyCheckoutGraceMinutes = 15;
  
  // Location
  static const double defaultLocationRadius = 100.0; // meters
  
  // Biometric
  static const String biometricReason = 'Authenticate to verify your identity';
  
  // Notification Channels
  static const String attendanceChannelId = 'attendance_channel';
  static const String teamChannelId = 'team_channel';
  static const String generalChannelId = 'general_channel';
}
