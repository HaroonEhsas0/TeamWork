import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/geofence_model.dart';
import '../database_helper.dart';
import '../services/service_locator.dart';
import '../services/notification_service.dart';

class GeofenceProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = locator<NotificationService>();
  
  List<GeofenceModel> _geofences = [];
  bool _isLoading = false;
  String? _error;
  
  List<GeofenceModel> get geofences => _geofences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load all geofences for an organization
  Future<void> loadGeofences(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('geofences')
          .where('organizationId', isEqualTo: organizationId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _geofences = querySnapshot.docs
            .map((doc) => GeofenceModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.query(
            'geofences',
            where: 'organization_id = ? AND is_active = ?',
            whereArgs: [organizationId, 1],
          );
        });
        
        _geofences = records
            .map((record) => GeofenceModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading geofences: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create a new geofence
  Future<bool> createGeofence(GeofenceModel geofence) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Save to Firestore
      final docRef = await _firestore
          .collection('geofences')
          .add(geofence.toMap());
      
      // Update with generated ID
      final updatedGeofence = geofence.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'geofences',
          updatedGeofence.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      // Add to local list
      _geofences.add(updatedGeofence);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating geofence: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update an existing geofence
  Future<bool> updateGeofence(GeofenceModel geofence) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Update in Firestore
      await _firestore
          .collection('geofences')
          .doc(geofence.id)
          .update(geofence.toMap());
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'geofences',
          geofence.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [geofence.id],
        );
      });
      
      // Update in local list
      final index = _geofences.indexWhere((g) => g.id == geofence.id);
      if (index >= 0) {
        _geofences[index] = geofence;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error updating geofence: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Delete a geofence (actually just mark as inactive)
  Future<bool> deleteGeofence(String geofenceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find the geofence
      final index = _geofences.indexWhere((g) => g.id == geofenceId);
      if (index < 0) {
        throw Exception('Geofence not found');
      }
      
      final geofence = _geofences[index];
      
      // Mark as inactive
      final updatedGeofence = geofence.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
      
      // Update in Firestore
      await _firestore
          .collection('geofences')
          .doc(geofenceId)
          .update(updatedGeofence.toMap());
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'geofences',
          updatedGeofence.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [geofenceId],
        );
      });
      
      // Remove from local list
      _geofences.removeAt(index);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error deleting geofence: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get a geofence by ID
  GeofenceModel? getGeofenceById(String geofenceId) {
    try {
      return _geofences.firstWhere((g) => g.id == geofenceId);
    } catch (e) {
      return null;
    }
  }
  
  // Check if a location is within any of the organization's geofences
  bool isLocationWithinAnyGeofence(double latitude, double longitude) {
    return _geofences.any((geofence) => 
      geofence.isLocationWithinGeofence(latitude, longitude)
    );
  }
  
  // Get all geofences that contain a specific location
  List<GeofenceModel> getGeofencesContainingLocation(double latitude, double longitude) {
    return _geofences.where((geofence) => 
      geofence.isLocationWithinGeofence(latitude, longitude)
    ).toList();
  }
  
  // Check if a user is allowed to check in at their current location
  Future<bool> canUserCheckInAtCurrentLocation(String userId, String? teamId) async {
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // If no geofences are defined, allow check-in from anywhere
      if (_geofences.isEmpty) {
        return true;
      }
      
      // Check if the location is within any geofence
      final containingGeofences = getGeofencesContainingLocation(
        position.latitude,
        position.longitude,
      );
      
      if (containingGeofences.isEmpty) {
        return false;
      }
      
      // If team ID is provided, check if any of the containing geofences apply to this team
      if (teamId != null) {
        return containingGeofences.any((geofence) => 
          geofence.teamIds == null || geofence.teamIds!.contains(teamId)
        );
      }
      
      // If no team ID is provided, any geofence is fine
      return true;
    } catch (e) {
      print('Error checking if user can check in: $e');
      // In case of error, default to allowing check-in
      return true;
    }
  }
  
  // Get the distance to the nearest geofence
  Future<double?> getDistanceToNearestGeofence() async {
    try {
      if (_geofences.isEmpty) {
        return null;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      double? minDistance;
      
      for (final geofence in _geofences) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
        );
        
        // Subtract the radius to get the distance to the edge of the geofence
        final distanceToEdge = distance - geofence.radius;
        
        // If we're inside the geofence, distance is 0
        final adjustedDistance = distanceToEdge > 0 ? distanceToEdge : 0;
        
        if (minDistance == null || adjustedDistance < minDistance) {
          minDistance = adjustedDistance;
        }
      }
      
      return minDistance;
    } catch (e) {
      print('Error getting distance to nearest geofence: $e');
      return null;
    }
  }
  
  // Get the nearest geofence
  Future<GeofenceModel?> getNearestGeofence() async {
    try {
      if (_geofences.isEmpty) {
        return null;
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      GeofenceModel? nearestGeofence;
      double? minDistance;
      
      for (final geofence in _geofences) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          geofence.latitude,
          geofence.longitude,
        );
        
        if (minDistance == null || distance < minDistance) {
          minDistance = distance;
          nearestGeofence = geofence;
        }
      }
      
      return nearestGeofence;
    } catch (e) {
      print('Error getting nearest geofence: $e');
      return null;
    }
  }
}
