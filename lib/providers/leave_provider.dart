import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leave_model.dart';
import '../database_helper.dart';
import '../services/service_locator.dart';
import '../services/notification_service.dart';

class LeaveProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = locator<NotificationService>();
  
  List<LeaveModel> _leaves = [];
  bool _isLoading = false;
  String? _error;
  
  List<LeaveModel> get leaves => _leaves;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Get pending leaves
  List<LeaveModel> get pendingLeaves => _leaves.where((leave) => leave.isPending).toList();
  
  // Get approved leaves
  List<LeaveModel> get approvedLeaves => _leaves.where((leave) => leave.isApproved).toList();
  
  // Get rejected leaves
  List<LeaveModel> get rejectedLeaves => _leaves.where((leave) => leave.isRejected).toList();
  
  // Load all leaves for the current user
  Future<void> loadUserLeaves(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('leaves')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _leaves = querySnapshot.docs
            .map((doc) => LeaveModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.query(
            'leaves',
            where: 'user_id = ?',
            whereArgs: [userId],
            orderBy: 'created_at DESC',
          );
        });
        
        _leaves = records
            .map((record) => LeaveModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading leaves: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load all leaves for a team or organization
  Future<void> loadTeamLeaves(String organizationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('leaves')
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('createdAt', descending: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _leaves = querySnapshot.docs
            .map((doc) => LeaveModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.query(
            'leaves',
            where: 'organization_id = ?',
            whereArgs: [organizationId],
            orderBy: 'created_at DESC',
          );
        });
        
        _leaves = records
            .map((record) => LeaveModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading team leaves: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create a new leave request
  Future<bool> createLeaveRequest(LeaveModel leave) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Save to Firestore
      final docRef = await _firestore
          .collection('leaves')
          .add(leave.toMap());
      
      // Update with generated ID
      final updatedLeave = leave.copyWith(id: docRef.id);
      await docRef.update({'id': docRef.id});
      
      // Save to local database
      await _databaseHelper.database.then((db) async {
        await db.insert(
          'leaves',
          updatedLeave.toSqliteMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      
      // Add to local list
      _leaves.add(updatedLeave);
      
      // Send notification to admin
      await _notifyAdminOfNewLeaveRequest(updatedLeave);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error creating leave request: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Approve a leave request
  Future<bool> approveLeaveRequest(String leaveId, String approverUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find the leave
      final leaveIndex = _leaves.indexWhere((leave) => leave.id == leaveId);
      if (leaveIndex < 0) {
        throw Exception('Leave request not found');
      }
      
      final leave = _leaves[leaveIndex];
      
      // Update leave status
      final updatedLeave = leave.copyWith(
        status: 'approved',
        approvedBy: approverUserId,
        approvedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Update in Firestore
      await _firestore
          .collection('leaves')
          .doc(leaveId)
          .update(updatedLeave.toMap());
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'leaves',
          updatedLeave.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [leaveId],
        );
      });
      
      // Update in local list
      _leaves[leaveIndex] = updatedLeave;
      
      // Notify the user
      await _notifyUserOfLeaveApproval(updatedLeave);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error approving leave request: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Reject a leave request
  Future<bool> rejectLeaveRequest(String leaveId, String approverUserId, String rejectionReason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find the leave
      final leaveIndex = _leaves.indexWhere((leave) => leave.id == leaveId);
      if (leaveIndex < 0) {
        throw Exception('Leave request not found');
      }
      
      final leave = _leaves[leaveIndex];
      
      // Update leave status
      final updatedLeave = leave.copyWith(
        status: 'rejected',
        approvedBy: approverUserId,
        approvedAt: DateTime.now(),
        rejectionReason: rejectionReason,
        updatedAt: DateTime.now(),
      );
      
      // Update in Firestore
      await _firestore
          .collection('leaves')
          .doc(leaveId)
          .update(updatedLeave.toMap());
      
      // Update in local database
      await _databaseHelper.database.then((db) async {
        await db.update(
          'leaves',
          updatedLeave.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [leaveId],
        );
      });
      
      // Update in local list
      _leaves[leaveIndex] = updatedLeave;
      
      // Notify the user
      await _notifyUserOfLeaveRejection(updatedLeave);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error rejecting leave request: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Cancel a leave request
  Future<bool> cancelLeaveRequest(String leaveId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Find the leave
      final leaveIndex = _leaves.indexWhere((leave) => leave.id == leaveId);
      if (leaveIndex < 0) {
        throw Exception('Leave request not found');
      }
      
      // Delete from Firestore
      await _firestore
          .collection('leaves')
          .doc(leaveId)
          .delete();
      
      // Delete from local database
      await _databaseHelper.database.then((db) async {
        await db.delete(
          'leaves',
          where: 'id = ?',
          whereArgs: [leaveId],
        );
      });
      
      // Remove from local list
      _leaves.removeAt(leaveIndex);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error canceling leave request: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get a leave by ID
  LeaveModel? getLeaveById(String leaveId) {
    try {
      return _leaves.firstWhere((leave) => leave.id == leaveId);
    } catch (e) {
      return null;
    }
  }
  
  // Check if user has any active leaves
  bool hasActiveLeave(String userId) {
    final today = DateTime.now();
    return _leaves.any((leave) => 
      leave.userId == userId && 
      leave.isApproved && 
      today.isAfter(leave.startDate.subtract(Duration(days: 1))) && 
      today.isBefore(leave.endDate.add(Duration(days: 1)))
    );
  }
  
  // Get user's active leave
  LeaveModel? getUserActiveLeave(String userId) {
    final today = DateTime.now();
    try {
      return _leaves.firstWhere((leave) => 
        leave.userId == userId && 
        leave.isApproved && 
        today.isAfter(leave.startDate.subtract(Duration(days: 1))) && 
        today.isBefore(leave.endDate.add(Duration(days: 1)))
      );
    } catch (e) {
      return null;
    }
  }
  
  // Check if a date range overlaps with any existing approved leaves
  bool hasOverlappingLeave(String userId, DateTime startDate, DateTime endDate) {
    return _leaves.any((leave) => 
      leave.userId == userId && 
      leave.isApproved && 
      ((startDate.isAfter(leave.startDate.subtract(Duration(days: 1))) && 
        startDate.isBefore(leave.endDate.add(Duration(days: 1)))) || 
       (endDate.isAfter(leave.startDate.subtract(Duration(days: 1))) && 
        endDate.isBefore(leave.endDate.add(Duration(days: 1)))) ||
       (startDate.isBefore(leave.startDate) && 
        endDate.isAfter(leave.endDate)))
    );
  }
  
  // Helper method to notify admin of new leave request
  Future<void> _notifyAdminOfNewLeaveRequest(LeaveModel leave) async {
    try {
      // Get admin user IDs for the organization
      final adminIds = await _getOrganizationAdminIds(leave.organizationId);
      
      // Send notification to each admin
      for (final adminId in adminIds) {
        await _notificationService.sendNotificationToUser(
          userId: adminId,
          title: 'New Leave Request',
          body: '${leave.userName ?? 'A user'} has requested leave from ${_formatDate(leave.startDate)} to ${_formatDate(leave.endDate)}',
          data: {
            'type': 'leave_request',
            'leaveId': leave.id,
          },
        );
      }
    } catch (e) {
      print('Error notifying admin of new leave request: $e');
    }
  }
  
  // Helper method to notify user of leave approval
  Future<void> _notifyUserOfLeaveApproval(LeaveModel leave) async {
    try {
      await _notificationService.sendNotificationToUser(
        userId: leave.userId,
        title: 'Leave Request Approved',
        body: 'Your leave request from ${_formatDate(leave.startDate)} to ${_formatDate(leave.endDate)} has been approved',
        data: {
          'type': 'leave_approved',
          'leaveId': leave.id,
        },
      );
    } catch (e) {
      print('Error notifying user of leave approval: $e');
    }
  }
  
  // Helper method to notify user of leave rejection
  Future<void> _notifyUserOfLeaveRejection(LeaveModel leave) async {
    try {
      await _notificationService.sendNotificationToUser(
        userId: leave.userId,
        title: 'Leave Request Rejected',
        body: 'Your leave request from ${_formatDate(leave.startDate)} to ${_formatDate(leave.endDate)} has been rejected',
        data: {
          'type': 'leave_rejected',
          'leaveId': leave.id,
        },
      );
    } catch (e) {
      print('Error notifying user of leave rejection: $e');
    }
  }
  
  // Helper method to get organization admin IDs
  Future<List<String>> _getOrganizationAdminIds(String organizationId) async {
    try {
      // Try Firestore first
      final querySnapshot = await _firestore
          .collection('user_roles')
          .where('organizationId', isEqualTo: organizationId)
          .where('role', isEqualTo: 'admin')
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs
            .map((doc) => doc.data()['userId'] as String)
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.database.then((db) async {
          return await db.query(
            'user_roles',
            where: 'organization_id = ? AND role = ?',
            whereArgs: [organizationId, 'admin'],
          );
        });
        
        return records
            .map((record) => record['user_id'] as String)
            .toList();
      }
    } catch (e) {
      print('Error getting organization admin IDs: $e');
      return [];
    }
  }
  
  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
