import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// A service for caching authentication data to enable offline authentication
class AuthCacheService {
  static const String _userDataKey = 'cached_user_data';
  static const String _lastLoginTimeKey = 'last_login_time';
  static const String _biometricEnabledKey = 'biometric_login_enabled';
  static const String _lastSignedInUserIdKey = 'last_signed_in_user_id';
  static const String _offlineLoginEnabledKey = 'offline_login_enabled';
  static const String _cachedCredentialsKey = 'cached_credentials';
  static const String _credentialExpiryKey = 'credential_expiry';
  
  /// Cache the user data for offline access
  static Future<bool> cacheUserData(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonEncode(user.toMap());
      await prefs.setString(_userDataKey, userData);
      await prefs.setString(_lastSignedInUserIdKey, user.id);
      await prefs.setInt(_lastLoginTimeKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error caching user data: $e');
      return false;
    }
  }
  
  /// Get cached user data
  static Future<UserModel?> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userDataKey);
      
      if (userData == null) return null;
      
      final Map<String, dynamic> userMap = jsonDecode(userData);
      return UserModel.fromMap(userMap);
    } catch (e) {
      print('Error getting cached user data: $e');
      return null;
    }
  }
  
  /// Check if cached credentials are still valid
  static Future<bool> areCachedCredentialsValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginTime = prefs.getInt(_lastLoginTimeKey) ?? 0;
      final credentialExpiry = prefs.getInt(_credentialExpiryKey) ?? 
          (DateTime.now().millisecondsSinceEpoch - 1); // Default to expired
      
      // Check if credentials have expired (default to 7 days)
      final now = DateTime.now().millisecondsSinceEpoch;
      return now < credentialExpiry;
    } catch (e) {
      print('Error checking cached credentials: $e');
      return false;
    }
  }
  
  /// Set credential expiry time (in days)
  static Future<bool> setCredentialExpiry(int expiryDays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final expiryTime = now.add(Duration(days: expiryDays)).millisecondsSinceEpoch;
      await prefs.setInt(_credentialExpiryKey, expiryTime);
      return true;
    } catch (e) {
      print('Error setting credential expiry: $e');
      return false;
    }
  }
  
  /// Enable or disable biometric login
  static Future<bool> setBiometricLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
      return true;
    } catch (e) {
      print('Error setting biometric login: $e');
      return false;
    }
  }
  
  /// Check if biometric login is enabled
  static Future<bool> isBiometricLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      print('Error checking biometric login: $e');
      return false;
    }
  }
  
  /// Enable or disable offline login
  static Future<bool> setOfflineLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_offlineLoginEnabledKey, enabled);
      return true;
    } catch (e) {
      print('Error setting offline login: $e');
      return false;
    }
  }
  
  /// Check if offline login is enabled
  static Future<bool> isOfflineLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_offlineLoginEnabledKey) ?? false;
    } catch (e) {
      print('Error checking offline login: $e');
      return false;
    }
  }
  
  /// Cache email and password hash for offline login
  static Future<bool> cacheCredentials(String email, String passwordHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentials = {
        'email': email,
        'password_hash': passwordHash,
      };
      await prefs.setString(_cachedCredentialsKey, jsonEncode(credentials));
      return true;
    } catch (e) {
      print('Error caching credentials: $e');
      return false;
    }
  }
  
  /// Get cached credentials
  static Future<Map<String, String>?> getCachedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString(_cachedCredentialsKey);
      
      if (credentialsJson == null) return null;
      
      final Map<String, dynamic> credentials = jsonDecode(credentialsJson);
      return {
        'email': credentials['email'] as String,
        'password_hash': credentials['password_hash'] as String,
      };
    } catch (e) {
      print('Error getting cached credentials: $e');
      return null;
    }
  }
  
  /// Clear all cached authentication data
  static Future<bool> clearAuthCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.remove(_lastLoginTimeKey);
      await prefs.remove(_cachedCredentialsKey);
      await prefs.remove(_credentialExpiryKey);
      // Don't clear biometric and offline settings as they are user preferences
      return true;
    } catch (e) {
      print('Error clearing auth cache: $e');
      return false;
    }
  }
  
  /// Get the last time the user logged in
  static Future<DateTime?> getLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginTime = prefs.getInt(_lastLoginTimeKey);
      
      if (lastLoginTime == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(lastLoginTime);
    } catch (e) {
      print('Error getting last login time: $e');
      return null;
    }
  }
  
  /// Update the last login time to now
  static Future<bool> updateLastLoginTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastLoginTimeKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error updating last login time: $e');
      return false;
    }
  }
  
  /// Get the last signed in user ID
  static Future<String?> getLastSignedInUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastSignedInUserIdKey);
    } catch (e) {
      print('Error getting last signed in user ID: $e');
      return null;
    }
  }
}
