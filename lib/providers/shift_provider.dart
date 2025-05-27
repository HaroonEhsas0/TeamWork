import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shift_model.dart';
import '../database_helper.dart';

class ShiftProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ShiftModel> _shifts = [];
  bool _isLoading = false;
  String? _error;
  
  List<ShiftModel> get shifts => _shifts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load all shifts for the current organization
  Future<void> loadShifts(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('shifts')
          .where('organizationId', isEqualTo: organizationId)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _shifts = querySnapshot.docs
            .map((doc) => ShiftModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.query(
            'shifts',
            where: 'organization_id = ? AND is_active = ?',
            whereArgs: [organizationId, 1],
            orderBy: 'shift_name',
          );
        });
        
        _shifts = records
            .map((record) => ShiftModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading shifts: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create a new shift
  Future<bool> createShift(ShiftModel shift) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Save to Firestore
      final docRef = await _firestore
          .collection('shifts')
          .add(shift.toMap());
      
      // Update with generated ID
      final updatedShift = shift.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'shifts',
          updatedShift.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      // Add to local list
      _shifts.add(updatedShift);
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating shift: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update an existing shift
  Future<bool> updateShift(ShiftModel shift) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Update in Firestore
      await _firestore
          .collection('shifts')
          .doc(shift.id)
          .update(shift.toMap());
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'shifts',
          shift.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [shift.id],
        );
      });
      
      // Update in local list
      final index = _shifts.indexWhere((s) => s.id == shift.id);
      if (index >= 0) {
        _shifts[index] = shift;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error updating shift: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Delete a shift (mark as inactive)
  Future<bool> deleteShift(String shiftId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Mark as inactive in Firestore
      await _firestore
          .collection('shifts')
          .doc(shiftId)
          .update({
            'isActive': false,
            'updatedAt': DateTime.now(),
          });
      
      // Mark as inactive in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'shifts',
          {
            'is_active': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [shiftId],
        );
      });
      
      // Remove from local list
      _shifts.removeWhere((shift) => shift.id == shiftId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error deleting shift: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get a shift by ID
  ShiftModel? getShiftById(String shiftId) {
    return _shifts.firstWhere(
      (shift) => shift.id == shiftId,
      orElse: () => throw Exception('Shift not found'),
    );
  }
  
  // Assign a shift to an employee
  Future<bool> assignShiftToEmployee(String shiftId, String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Create employee-shift mapping
      final mapping = {
        'employeeId': employeeId,
        'shiftId': shiftId,
        'assignedAt': DateTime.now(),
        'assignedBy': _auth.currentUser?.uid,
        'isActive': true,
      };
      
      // Save to Firestore
      await _firestore
          .collection('employee_shifts')
          .add(mapping);
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'employee_shifts',
          {
            'employee_id': employeeId,
            'shift_id': shiftId,
            'assigned_at': DateTime.now().toIso8601String(),
            'assigned_by': _auth.currentUser?.uid,
            'is_active': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error assigning shift to employee: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Remove a shift assignment from an employee
  Future<bool> removeShiftFromEmployee(String shiftId, String employeeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find the mapping in Firestore
      final querySnapshot = await _firestore
          .collection('employee_shifts')
          .where('employeeId', isEqualTo: employeeId)
          .where('shiftId', isEqualTo: shiftId)
          .where('isActive', isEqualTo: true)
          .get();
      
      // Update all matching documents
      for (var doc in querySnapshot.docs) {
        await doc.reference.update({
          'isActive': false,
          'removedAt': DateTime.now(),
          'removedBy': _auth.currentUser?.uid,
        });
      }
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'employee_shifts',
          {
            'is_active': 0,
            'removed_at': DateTime.now().toIso8601String(),
            'removed_by': _auth.currentUser?.uid,
          },
          where: 'employee_id = ? AND shift_id = ? AND is_active = ?',
          whereArgs: [employeeId, shiftId, 1],
        );
      });
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error removing shift from employee: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get all shifts assigned to an employee
  Future<List<ShiftModel>> getEmployeeShifts(String employeeId) async {
    try {
      // Get shift assignments from Firestore
      final querySnapshot = await _firestore
          .collection('employee_shifts')
          .where('employeeId', isEqualTo: employeeId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Get shift IDs
        final shiftIds = querySnapshot.docs
            .map((doc) => doc.data()['shiftId'] as String)
            .toList();
        
        // Get shifts by IDs
        final shifts = <ShiftModel>[];
        for (var shiftId in shiftIds) {
          final shiftDoc = await _firestore
              .collection('shifts')
              .doc(shiftId)
              .get();
          
          if (shiftDoc.exists) {
            shifts.add(ShiftModel.fromFirestore(shiftDoc));
          }
        }
        
        return shifts;
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.rawQuery('''
            SELECT s.* FROM shifts s
            INNER JOIN employee_shifts es ON s.id = es.shift_id
            WHERE es.employee_id = ? AND es.is_active = 1 AND s.is_active = 1
          ''', [employeeId]);
        });
        
        return records
            .map((record) => ShiftModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error getting employee shifts: $_error');
      return [];
    }
  }
  
  // Check if an employee is currently in their shift
  Future<bool> isEmployeeInShift(String employeeId) async {
    try {
      // Get employee's shifts
      final shifts = await getEmployeeShifts(employeeId);
      
      // Get current time
      final now = TimeOfDay.now();
      final today = DateTime.now();
      
      // Check if any shift is active now
      for (var shift in shifts) {
        // Check if today is a work day for this shift
        if (shift.isWorkDay(today)) {
          // Convert TimeOfDay to minutes for comparison
          final currentMinutes = now.hour * 60 + now.minute;
          final startMinutes = shift.startTime.hour * 60 + shift.startTime.minute;
          final endMinutes = shift.endTime.hour * 60 + shift.endTime.minute;
          
          // Handle overnight shifts
          if (endMinutes < startMinutes) {
            // Shift spans midnight
            if (currentMinutes >= startMinutes || currentMinutes <= endMinutes) {
              return true;
            }
          } else {
            // Normal shift
            if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      _error = e.toString();
      print('Error checking if employee is in shift: $_error');
      return false;
    }
  }
}
