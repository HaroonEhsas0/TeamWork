import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user_model.dart';
import '../database_helper.dart';
import '../services/auth_cache_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _user?.role == 'admin';
  bool get isConnected => _user?.isConnected ?? false;

  UserProvider() {
    _initUser();
  }

  Future<void> _initUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadUserWithFallback(currentUser.uid);
    }
  }

  Future<void> loadUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to get user from Firestore first
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists) {
        _user = UserModel.fromFirestore(docSnapshot);
        
        // Cache user data for offline access
        await AuthCacheService.cacheUserData(_user!);
      } else {
        // If not in Firestore, try local database
        final isAdmin = await _databaseHelper.isUserAdmin(userId);
        final isConnected = await _databaseHelper.isUserConnected(userId);
        final orgCode = await _databaseHelper.getUserOrganizationCode(userId);
        
        // Get user details from Firebase Auth
        final authUser = _auth.currentUser;
        
        if (authUser != null) {
          _user = UserModel(
            id: userId,
            name: authUser.displayName ?? 'User',
            email: authUser.email ?? '',
            role: isAdmin ? 'admin' : 'user',
            photoUrl: authUser.photoURL,
            organizationCode: orgCode,
            isConnected: isConnected,
            createdAt: authUser.metadata.creationTime ?? DateTime.now(),
          );
          
          // Save to Firestore for future use
          await _firestore.collection('users').doc(userId).set(_user!.toMap());
          
          // Cache user data for offline access
          await AuthCacheService.cacheUserData(_user!);
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading user: $e');
      
      // Try to load from cache as fallback
      final cachedUser = await AuthCacheService.getCachedUserData();
      if (cachedUser != null && cachedUser.id == userId) {
        _user = cachedUser;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load user with offline fallback support
  /// This method prioritizes offline data when network is unavailable
  Future<void> loadUserWithFallback(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Try online first
        await loadUser(userId);
      } else {
        // Offline mode - load from cache
        final cachedUser = await AuthCacheService.getCachedUserData();
        
        if (cachedUser != null && cachedUser.id == userId) {
          _user = cachedUser;
          
          // Also try to get additional data from local database
          try {
            final isAdmin = await _databaseHelper.isUserAdmin(userId);
            final isConnected = await _databaseHelper.isUserConnected(userId);
            final orgCode = await _databaseHelper.getUserOrganizationCode(userId);
            
            // Update with local database info
            _user = UserModel(
              id: _user!.id,
              name: _user!.name,
              email: _user!.email,
              role: isAdmin ? 'admin' : _user!.role,
              photoUrl: _user!.photoUrl,
              organizationCode: orgCode ?? _user!.organizationCode,
              isConnected: isConnected,
              createdAt: _user!.createdAt,
              teamId: _user!.teamId,
              organizationId: _user!.organizationId,
            );
          } catch (e) {
            print('Error getting additional user data from local DB: $e');
            // Continue with cached data
          }
        } else {
          _error = 'No cached user data found and device is offline';
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error in loadUserWithFallback: $e');
      
      // Final fallback - try to get from cache
      final cachedUser = await AuthCacheService.getCachedUserData();
      if (cachedUser != null && cachedUser.id == userId) {
        _user = cachedUser;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser({
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    Map<String, dynamic>? settings,
  }) async {
    if (_user == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final updatedUser = _user!.copyWith(
        name: name,
        email: email,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        settings: settings,
      );
      
      // Update in Firestore
      await _firestore.collection('users').doc(_user!.id).update(updatedUser.toMap());
      
      // Update local user
      _user = updatedUser;
      
      // Update cached user data
      await AuthCacheService.cacheUserData(_user!);
    } catch (e) {
      _error = e.toString();
      print('Error updating user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> clearUser() async {
    _user = null;
    _error = null;
    notifyListeners();
  }
  
  Future<void> setOrganizationCode(String code, String orgName) async {
    if (_user == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Update user model
      final updatedUser = _user!.copyWith(
        organizationCode: code,
        isConnected: true,
      );
      
      // Update in Firestore
      await _firestore.collection('users').doc(_user!.id).update({
        'organizationCode': code,
        'isConnected': true,
      });
      
      // Cache organization code
      await _databaseHelper.cacheOrganizationCode(_user!.id, code, orgName);
      
      // Update local user
      _user = updatedUser;
      
      // Update cached user data
      await AuthCacheService.cacheUserData(_user!);
    } catch (e) {
      _error = e.toString();
      print('Error setting organization code: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _user?.role == 'admin';
  bool get isConnected => _user?.isConnected ?? false;

  UserProvider() {
    _initUser();
  }

  Future<void> _initUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadUser(currentUser.uid);
    }
  }

  Future<void> loadUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to get user from Firestore first
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (docSnapshot.exists) {
        _user = UserModel.fromFirestore(docSnapshot);
        
        // Cache user data for offline access
        await AuthCacheService.cacheUserData(_user!);
      } else {
        // If not in Firestore, try local database
        final isAdmin = await _databaseHelper.isUserAdmin(userId);
        final isConnected = await _databaseHelper.isUserConnected(userId);
        final orgCode = await _databaseHelper.getUserOrganizationCode(userId);
        
        // Get user details from Firebase Auth
        final authUser = _auth.currentUser;
        
        if (authUser != null) {
          _user = UserModel(
            id: userId,
            name: authUser.displayName ?? 'User',
            email: authUser.email ?? '',
            role: isAdmin ? 'admin' : 'user',
            photoUrl: authUser.photoURL,
            organizationCode: orgCode,
            isConnected: isConnected,
            createdAt: authUser.metadata.creationTime ?? DateTime.now(),
          );
          
          // Save to Firestore for future use
          await _firestore.collection('users').doc(userId).set(_user!.toMap());
          
          // Cache user data for offline access
          await AuthCacheService.cacheUserData(_user!);
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading user: $e');
      
      // Try to load from cache as fallback
      final cachedUser = await AuthCacheService.getCachedUserData();
      if (cachedUser != null && cachedUser.id == userId) {
        _user = cachedUser;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load user with offline fallback support
  /// This method prioritizes offline data when network is unavailable
  Future<void> loadUserWithFallback(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;
      
      if (isOnline) {
        // Try online first
        await loadUser(userId);
      } else {
        // Offline mode - load from cache
        final cachedUser = await AuthCacheService.getCachedUserData();
        
        if (cachedUser != null && cachedUser.id == userId) {
          _user = cachedUser;
          
          // Also try to get additional data from local database
          try {
            final isAdmin = await _databaseHelper.isUserAdmin(userId);
            final isConnected = await _databaseHelper.isUserConnected(userId);
            final orgCode = await _databaseHelper.getUserOrganizationCode(userId);
            
            // Update with local database info
            _user = UserModel(
              id: _user!.id,
              name: _user!.name,
              email: _user!.email,
              role: isAdmin ? 'admin' : _user!.role,
              photoUrl: _user!.photoUrl,
              organizationCode: orgCode ?? _user!.organizationCode,
              isConnected: isConnected,
              createdAt: _user!.createdAt,
              teamId: _user!.teamId,
              organizationId: _user!.organizationId,
            );
          } catch (e) {
            print('Error getting additional user data from local DB: $e');
            // Continue with cached data
          }
        } else {
          _error = 'No cached user data found and device is offline';
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error in loadUserWithFallback: $e');
      
      // Final fallback - try to get from cache
      final cachedUser = await AuthCacheService.getCachedUserData();
      if (cachedUser != null && cachedUser.id == userId) {
        _user = cachedUser;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
    } catch (e) {
      _error = e.toString();
      print('Error loading user: $_error');
      
      // Try to use cached user data if available
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data_$userId');
      
      if (userData != null) {
        try {
          final Map<String, dynamic> userMap = Map<String, dynamic>.from(
            Map.castFrom(
              Map<dynamic, dynamic>.from(
                Map.from(userData as Map)
              )
            )
          );
          _user = UserModel.fromMap(userMap);
        } catch (e) {
          print('Error parsing cached user data: $e');
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser({
    String? name,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    Map<String, dynamic>? settings,
  }) async {
    if (_user == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final updatedUser = _user!.copyWith(
        name: name,
        email: email,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        settings: settings,
      );
      
      // Update in Firestore
      await _firestore.collection('users').doc(_user!.id).update(updatedUser.toMap());
      
      // Update local user
      _user = updatedUser;
      
      // Cache user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_${_user!.id}', _user!.toMap().toString());
      
    } catch (e) {
      _error = e.toString();
      print('Error updating user: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectToOrganization(String orgCode) async {
    if (_user == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Verify organization code
      final orgData = await _databaseHelper.verifyOrganizationCode(orgCode);
      
      if (orgData != null) {
        // Connect user to organization
        await _databaseHelper.connectUserToOrganization(_user!.id, orgCode);
        
        // Update user model
        _user = _user!.copyWith(
          organizationCode: orgCode,
          isConnected: true,
        );
        
        // Update in Firestore
        await _firestore.collection('users').doc(_user!.id).update({
          'organizationCode': orgCode,
          'isConnected': true,
        });
        
        // Cache user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data_${_user!.id}', _user!.toMap().toString());
      } else {
        _error = 'Invalid organization code';
      }
    } catch (e) {
      _error = e.toString();
      print('Error connecting to organization: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _auth.signOut();
      _user = null;
    } catch (e) {
      _error = e.toString();
      print('Error signing out: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
