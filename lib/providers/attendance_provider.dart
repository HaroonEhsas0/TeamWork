import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../database_helper.dart';

class AttendanceProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<AttendanceModel> _attendanceRecords = [];
  AttendanceModel? _todayAttendance;
  bool _isLoading = false;
  String? _error;
  
  List<AttendanceModel> get attendanceRecords => _attendanceRecords;
  AttendanceModel? get todayAttendance => _todayAttendance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCheckedIn => _todayAttendance?.isCheckedIn ?? false;
  bool get isCheckedOut => _todayAttendance?.isComplete ?? false;
  
  AttendanceProvider() {
    _initAttendance();
  }
  
  Future<void> _initAttendance() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadTodayAttendance(currentUser.uid);
    }
  }
  
  Future<void> loadTodayAttendance(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);
      
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _todayAttendance = AttendanceModel.fromFirestore(querySnapshot.docs.first);
      } else {
        // Try local database
        final records = await _databaseHelper.getAttendanceInRange(userId, dateStr, dateStr);
        
        if (records.isNotEmpty) {
          _todayAttendance = AttendanceModel.fromMap(records.first);
        } else {
          _todayAttendance = null;
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading today\'s attendance: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadAttendanceHistory(String userId, {int days = 30}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _attendanceRecords = querySnapshot.docs
            .map((doc) => AttendanceModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.getAttendanceInRange(userId, startDateStr, endDateStr);
        
        _attendanceRecords = records
            .map((record) => AttendanceModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading attendance history: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> checkIn({bool biometricVerified = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _error = 'User not logged in';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        print('Error getting location: $e');
        // Continue without location if there's an error
      }
      
      final locationStr = position != null 
          ? '${position.latitude},${position.longitude}' 
          : null;
      
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final id = '${currentUser.uid}_$dateStr';
      
      // Create attendance record
      final attendance = AttendanceModel(
        id: id,
        userId: currentUser.uid,
        date: now,
        checkInTime: now,
        checkInLocation: locationStr,
        checkInVerified: biometricVerified,
      );
      
      // Save to Firestore
      await _firestore
          .collection('attendance')
          .doc(id)
          .set(attendance.toMap());
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'attendance',
          attendance.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      _todayAttendance = attendance;
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error checking in: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> checkOut({bool biometricVerified = false}) async {
    if (_todayAttendance == null) {
      _error = 'No check-in record found for today';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        print('Error getting location: $e');
        // Continue without location if there's an error
      }
      
      final locationStr = position != null 
          ? '${position.latitude},${position.longitude}' 
          : null;
      
      final now = DateTime.now();
      
      // Update attendance record
      final updatedAttendance = _todayAttendance!.copyWith(
        checkOutTime: now,
        checkOutLocation: locationStr,
        checkOutVerified: biometricVerified,
      );
      
      // Update in Firestore
      await _firestore
          .collection('attendance')
          .doc(_todayAttendance!.id)
          .update({
            'checkOutTime': now,
            'checkOutLocation': locationStr,
            'checkOutVerified': biometricVerified,
          });
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'attendance',
          {
            'check_out_time': now.toIso8601String(),
            'check_out_location': locationStr,
            'check_out_verified': biometricVerified ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [_todayAttendance!.id],
        );
      });
      
      _todayAttendance = updatedAttendance;
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error checking out: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> getAttendanceStats(String userId, {int days = 30}) async {
    try {
      await loadAttendanceHistory(userId, days: days);
      
      final Map<String, dynamic> stats = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'earlyCheckout': 0,
        'totalHours': 0.0,
        'avgHoursPerDay': 0.0,
      };
      
      // Define work hours (9 AM to 5 PM)
      final workStartTime = TimeOfDay(hour: 9, minute: 0);
      final workEndTime = TimeOfDay(hour: 17, minute: 0);
      
      // Count days in date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      final totalDays = endDate.difference(startDate).inDays + 1;
      
      // Count present days
      final presentDays = _attendanceRecords.length;
      
      // Count absent days
      stats['absent'] = totalDays - presentDays;
      stats['present'] = presentDays;
      
      // Calculate total hours and check for late/early
      double totalHours = 0.0;
      
      for (var record in _attendanceRecords) {
        // Check if late
        if (record.isLate(workStartTime)) {
          stats['late'] = (stats['late'] as int) + 1;
        }
        
        // Check if early checkout
        if (record.leftEarly(workEndTime)) {
          stats['earlyCheckout'] = (stats['earlyCheckout'] as int) + 1;
        }
        
        // Calculate hours
        if (record.duration != null) {
          final hours = record.duration!.inMinutes / 60.0;
          totalHours += hours;
        }
      }
      
      stats['totalHours'] = totalHours;
      stats['avgHoursPerDay'] = presentDays > 0 ? totalHours / presentDays : 0.0;
      
      return stats;
    } catch (e) {
      print('Error calculating attendance stats: $e');
      return {
        'present': 0,
        'absent': 0,
        'late': 0,
        'earlyCheckout': 0,
        'totalHours': 0.0,
        'avgHoursPerDay': 0.0,
      };
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
