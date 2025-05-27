import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if biometric authentication is available
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }
  
  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }
  
  // Authenticate with biometrics
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to verify your identity',
    bool useErrorDialogs = true,
    bool stickyAuth = false,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Error authenticating: $e');
      if (e.code == auth_error.notAvailable) {
        print('Biometric authentication not available');
      } else if (e.code == auth_error.notEnrolled) {
        print('No biometrics enrolled on this device');
      } else if (e.code == auth_error.lockedOut) {
        print('Biometric authentication locked out due to too many attempts');
      } else if (e.code == auth_error.permanentlyLockedOut) {
        print('Biometric authentication permanently locked out');
      }
      return false;
    }
  }
  
  // Check if biometric authentication is enabled in app settings
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_enabled') ?? false;
    } catch (e) {
      print('Error checking if biometric is enabled: $e');
      return false;
    }
  }
  
  // Enable or disable biometric authentication in app settings
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('biometric_enabled', enabled);
    } catch (e) {
      print('Error setting biometric enabled: $e');
      return false;
    }
  }
  
  // Get user-friendly name for biometric type
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }
  
  // Get user-friendly error message for biometric authentication errors
  String getBiometricErrorMessage(String errorCode) {
    switch (errorCode) {
      case auth_error.notAvailable:
        return 'Biometric authentication is not available on this device.';
      case auth_error.notEnrolled:
        return 'No biometric credentials are enrolled on this device.';
      case auth_error.lockedOut:
        return 'Biometric authentication is temporarily locked due to too many failed attempts.';
      case auth_error.permanentlyLockedOut:
        return 'Biometric authentication is permanently locked due to too many failed attempts.';
      case auth_error.passcodeNotSet:
        return 'Device does not have a passcode set up.';
      case auth_error.otherOperatingSystem:
        return 'This feature is not supported on the current operating system.';
      default:
        return 'An error occurred during biometric authentication.';
    }
  }
  
  // Secure storage for credentials
  final _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );
  
  // Generate a secure key for storing credentials
  String _generateSecureKey(String email) {
    final bytes = utf8.encode(email.toLowerCase() + 'teamwork_biometric_auth');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Store user credentials securely for biometric authentication
  Future<bool> storeCredentials(String email, String password) async {
    try {
      final key = _generateSecureKey(email);
      await _secureStorage.write(key: key, value: password);
      
      // Store the email as a reference that credentials exist
      final prefs = await SharedPreferences.getInstance();
      final storedEmails = prefs.getStringList('biometric_auth_emails') ?? [];
      
      if (!storedEmails.contains(email)) {
        storedEmails.add(email);
        await prefs.setStringList('biometric_auth_emails', storedEmails);
      }
      
      return true;
    } catch (e) {
      print('Error storing credentials: $e');
      return false;
    }
  }
  
  // Get stored credentials for biometric authentication
  Future<String?> getStoredCredentials(String email) async {
    try {
      final key = _generateSecureKey(email);
      return await _secureStorage.read(key: key);
    } catch (e) {
      print('Error getting stored credentials: $e');
      return null;
    }
  }
  
  // Delete stored credentials
  Future<bool> deleteStoredCredentials(String email) async {
    try {
      final key = _generateSecureKey(email);
      await _secureStorage.delete(key: key);
      
      // Remove email from reference list
      final prefs = await SharedPreferences.getInstance();
      final storedEmails = prefs.getStringList('biometric_auth_emails') ?? [];
      
      if (storedEmails.contains(email)) {
        storedEmails.remove(email);
        await prefs.setStringList('biometric_auth_emails', storedEmails);
      }
      
      return true;
    } catch (e) {
      print('Error deleting stored credentials: $e');
      return false;
    }
  }
  
  // Check if credentials are stored for a given email
  Future<bool> hasStoredCredentials(String email) async {
    try {
      final key = _generateSecureKey(email);
      final value = await _secureStorage.read(key: key);
      return value != null;
    } catch (e) {
      print('Error checking stored credentials: $e');
      return false;
    }
  }
}
