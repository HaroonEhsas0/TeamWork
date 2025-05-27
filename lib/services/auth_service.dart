import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../database_helper.dart';
import 'auth_cache_service.dart';
import 'service_locator.dart';
import 'biometric_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Connectivity _connectivity = Connectivity();
  
  // Session timeout in minutes (default: 30 days)
  final int _sessionTimeoutMinutes = 30 * 24 * 60;
  
  // Token refresh timer
  Timer? _tokenRefreshTimer;
  
  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  
  factory AuthService() {
    return _instance;
  }
  
  AuthService._internal() {
    // Initialize token refresh mechanism
    _initTokenRefresh();
  }
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Initialize token refresh mechanism
  void _initTokenRefresh() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      // Cancel existing timer if any
      _tokenRefreshTimer?.cancel();
      
      if (user != null) {
        // Start token refresh timer
        _scheduleTokenRefresh();
      }
    });
  }
  
  // Schedule token refresh
  void _scheduleTokenRefresh() {
    // Refresh token every 50 minutes (Firebase tokens typically last 60 minutes)
    _tokenRefreshTimer = Timer.periodic(Duration(minutes: 50), (timer) async {
      try {
        // Check if user is still logged in
        final user = _auth.currentUser;
        if (user == null) {
          timer.cancel();
          return;
        }
        
        // Check connectivity before attempting refresh
        final connectivityResult = await _connectivity.checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          print('No internet connection, skipping token refresh');
          return;
        }
        
        // Refresh token
        await user.getIdToken(true);
        print('Token refreshed successfully');
      } catch (e) {
        print('Error refreshing token: $e');
      }
    });
  }
  
  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        // Offline login
        return await _offlineSignIn(email, password);
      }
      
      // Online login
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Cache user data for offline login
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        
        // Get user data from Firestore
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          
          // Cache user data
          await AuthCacheService.cacheUserData(userModel);
          
          // Cache credentials (hashed for security)
          final passwordHash = _hashPassword(password);
          await AuthCacheService.cacheCredentials(email, passwordHash);
          
          // Set credential expiry (30 days by default)
          await AuthCacheService.setCredentialExpiry(30);
          
          // Enable offline login
          await AuthCacheService.setOfflineLoginEnabled(true);
          
          // Update last login time
          await AuthCacheService.updateLastLoginTime();
        }
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }
  
  // Sign in with biometric authentication
  Future<UserCredential> signInWithBiometrics() async {
    try {
      // Get biometric service
      final biometricService = locator<BiometricService>();
      
      // Check if biometric is available
      final isBiometricAvailable = await biometricService.isBiometricAvailable();
      if (!isBiometricAvailable) {
        throw FirebaseAuthException(
          code: 'biometric-not-available',
          message: 'Biometric authentication is not available on this device',
        );
      }
      
      // Get saved credentials
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedUserId = prefs.getString('saved_user_id');
      
      if (savedEmail == null || savedUserId == null) {
        throw FirebaseAuthException(
          code: 'no-saved-credentials',
          message: 'No saved credentials found. Please sign in with email and password first.',
        );
      }
      
      // Authenticate with biometrics
      final isAuthenticated = await biometricService.authenticate(
        localizedReason: 'Authenticate to sign in to TeamWork',
      );
      
      if (!isAuthenticated) {
        throw FirebaseAuthException(
          code: 'biometric-authentication-failed',
          message: 'Biometric authentication failed',
        );
      }
      
      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Try to get stored password
        final storedPassword = await biometricService.getStoredCredentials(savedEmail);
        
        if (storedPassword != null) {
          // Online login with stored credentials
          return await signInWithEmailAndPassword(savedEmail, storedPassword);
        } else {
          throw FirebaseAuthException(
            code: 'no-stored-password',
            message: 'No stored password found. Please sign in with email and password.',
          );
        }
      } else {
        // Offline login
        final cachedUser = await AuthCacheService.getCachedUserData();
        
        if (cachedUser != null && cachedUser.id == savedUserId) {
          // Update last login time
          await AuthCacheService.updateLastLoginTime();
          
          // Create offline user credential
          return _createOfflineUserCredential(cachedUser);
        } else {
          throw FirebaseAuthException(
            code: 'no-cached-user',
            message: 'No cached user data found and device is offline',
          );
        }
      }
    } catch (e) {
      print('Error signing in with biometrics: $e');
      rethrow;
    }
  }
  
  // Offline sign in
  Future<UserCredential> _offlineSignIn(String email, String password) async {
    // Check if offline login is enabled
    final isOfflineEnabled = await AuthCacheService.isOfflineLoginEnabled();
    if (!isOfflineEnabled) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'No internet connection and offline login is not enabled',
      );
    }
    
    // Check if cached credentials are valid
    final areCredentialsValid = await AuthCacheService.areCachedCredentialsValid();
    if (!areCredentialsValid) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'Your offline session has expired. Please sign in online.',
      );
    }
    
    // Get cached credentials
    final cachedCredentials = await AuthCacheService.getCachedCredentials();
    if (cachedCredentials == null) {
      throw FirebaseAuthException(
        code: 'no-cached-credentials',
        message: 'No cached credentials found. Please sign in online.',
      );
    }
    
    // Verify email and password
    final passwordHash = _hashPassword(password);
    if (email != cachedCredentials['email'] || passwordHash != cachedCredentials['password_hash']) {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Incorrect email or password',
      );
    }
    
    // Get cached user data
    final cachedUser = await AuthCacheService.getCachedUserData();
    if (cachedUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User data not found in cache',
      );
    }
    
    // Update last login time
    await AuthCacheService.updateLastLoginTime();
    
    // Create a mock UserCredential for offline login
    // This allows the app to function without an actual Firebase connection
    return _createOfflineUserCredential(cachedUser);
  }
  
  // Create a mock UserCredential for offline login
  UserCredential _createOfflineUserCredential(UserModel user) {
    // Create a mock User object
    final mockUser = _MockUser(
      uid: user.id,
      email: user.email,
      displayName: user.name,
      photoURL: user.photoUrl,
      isAnonymous: false,
    );
    
    // Create a mock UserCredential
    return _MockUserCredential(mockUser);
  }
  
  // Hash password for secure storage
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name,
    String role,
  ) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      // Create user document in Firestore
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        
        final userModel = UserModel(
          id: userId,
          name: name,
          email: email,
          role: role,
          createdAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(userId).set(userModel.toMap());
        
        // Set user role in local database
        await _databaseHelper.setUserRole(userId, role);
      }
      
      return userCredential;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      // Cancel token refresh timer
      _tokenRefreshTimer?.cancel();
      
      // Clear auth cache
      await AuthCacheService.clearAuthCache();
      
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }
  
  // Check if user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      return await _databaseHelper.isUserAdmin(userId);
    } catch (e) {
      print('Error checking if user is admin: $e');
      return false;
    }
  }
  
  // Check if user is connected to an organization
  Future<bool> isUserConnected(String userId) async {
    try {
      return await _databaseHelper.isUserConnected(userId);
    } catch (e) {
      print('Error checking if user is connected: $e');
      return false;
    }
  }
  
  // Connect user to organization
  Future<bool> connectUserToOrganization(String userId, String orgCode) async {
    try {
      // Verify organization code
      final orgData = await _databaseHelper.verifyOrganizationCode(orgCode);
      
      if (orgData != null) {
        // Connect user to organization
        await _databaseHelper.connectUserToOrganization(userId, orgCode);
        
        // Update user document in Firestore
        await _firestore.collection('users').doc(userId).update({
          'organizationCode': orgCode,
          'isConnected': true,
        });
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error connecting user to organization: $e');
      return false;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (name != null) {
        updateData['name'] = name;
        await currentUser?.updateDisplayName(name);
      }
      
      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
        await currentUser?.updatePhotoURL(photoUrl);
      }
      
      if (phoneNumber != null) {
        updateData['phoneNumber'] = phoneNumber;
      }
      
      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updateData);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Change password
      await user.updatePassword(newPassword);
      
      // Update cached credentials if offline login is enabled
      final isOfflineEnabled = await AuthCacheService.isOfflineLoginEnabled();
      if (isOfflineEnabled && user.email != null) {
        // Update cached credentials with new password
        final passwordHash = _hashPassword(newPassword);
        await AuthCacheService.cacheCredentials(user.email!, passwordHash);
        
        // Update stored credentials for biometric auth if available
        final biometricService = locator<BiometricService>();
        final isBiometricAvailable = await biometricService.isBiometricAvailable();
        if (isBiometricAvailable) {
          await biometricService.storeCredentials(user.email!, newPassword);
        }
      }
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }
}

// Mock classes for offline authentication

/// Mock implementation of User for offline authentication
class _MockUser implements User {
  @override
  final String uid;
  
  @override
  final String? email;
  
  @override
  final String? displayName;
  
  @override
  final String? photoURL;
  
  @override
  final bool isAnonymous;
  
  _MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.isAnonymous,
  });
  
  // Implement required methods with minimal functionality
  @override
  Future<void> delete() async => throw UnimplementedError('Offline mode');
  
  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => 'offline-mock-token';
  
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    return _MockIdTokenResult();
  }
  
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> reload() async {}
  
  @override
  Future<void> sendEmailVerification([ActionCodeSettings? actionCodeSettings]) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<User> unlink(String providerId) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> updateEmail(String newEmail) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> updatePassword(String newPassword) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    throw UnimplementedError('Offline mode');
  }
  
  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail, [ActionCodeSettings? actionCodeSettings]) async {
    throw UnimplementedError('Offline mode');
  }
  
  // Implement other required properties with minimal functionality
  @override
  List<UserInfo> get providerData => [];
  
  @override
  String get providerId => 'offline';
  
  @override
  String? get tenantId => null;
  
  @override
  bool get emailVerified => true;
  
  @override
  UserMetadata get metadata => _MockUserMetadata();
  
  @override
  String? get phoneNumber => null;
  
  @override
  String? get refreshToken => 'offline-refresh-token';
}

/// Mock implementation of UserCredential for offline authentication
class _MockUserCredential implements UserCredential {
  @override
  final User user;
  
  _MockUserCredential(this.user);
  
  @override
  AdditionalUserInfo? get additionalUserInfo => null;
  
  @override
  AuthCredential? get credential => null;
}

/// Mock implementation of IdTokenResult for offline authentication
class _MockIdTokenResult implements IdTokenResult {
  @override
  Map<String, dynamic> get claims => {};
  
  @override
  String get token => 'offline-mock-token';
  
  @override
  DateTime get authTime => DateTime.now();
  
  @override
  DateTime get expirationTime => DateTime.now().add(const Duration(hours: 1));
  
  @override
  DateTime get issuedAtTime => DateTime.now();
  
  @override
  String? get signInProvider => 'offline';
  
  @override
  String? get tenantId => null;
}

/// Mock implementation of UserMetadata for offline authentication
class _MockUserMetadata implements UserMetadata {
  @override
  DateTime? get creationTime => DateTime.now().subtract(const Duration(days: 1));
  
  @override
  DateTime? get lastSignInTime => DateTime.now();
}
