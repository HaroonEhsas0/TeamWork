import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/organization_model.dart';
import '../database_helper.dart';

class OrganizationProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<OrganizationModel> _organizationCodes = [];
  bool _isLoading = false;
  String? _error;
  
  List<OrganizationModel> get organizationCodes => _organizationCodes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  OrganizationProvider() {
    _initOrganizationCodes();
  }
  
  Future<void> _initOrganizationCodes() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await loadOrganizationCodes(currentUser.uid);
    }
  }
  
  Future<void> loadOrganizationCodes(String adminId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get from Firestore first
      final querySnapshot = await _firestore
          .collection('organization_codes')
          .where('adminId', isEqualTo: adminId)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _organizationCodes = querySnapshot.docs
            .map((doc) => OrganizationModel.fromFirestore(doc))
            .toList();
      } else {
        // Try local database
        final records = await _databaseHelper.getAdminOrganizationCodes(adminId);
        
        _organizationCodes = records
            .map((record) => OrganizationModel.fromMap(record))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading organization codes: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<OrganizationModel?> generateOrganizationCode(String orgName, {int validDays = 30}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _error = 'User not logged in';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Generate code using database helper
      final result = await _databaseHelper.generateOrganizationCode(
        currentUser.uid, 
        orgName,
        validDays: validDays,
      );
      
      if (result == null) {
        _error = 'Failed to generate organization code';
        return null;
      }
      
      final orgModel = OrganizationModel.fromMap(result);
      
      // Save to Firestore
      await _firestore
          .collection('organization_codes')
          .doc(orgModel.id)
          .set(orgModel.toMap());
      
      // Add to list
      _organizationCodes.add(orgModel);
      
      return orgModel;
    } catch (e) {
      _error = e.toString();
      print('Error generating organization code: $_error');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> deactivateOrganizationCode(String codeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Update in Firestore
      await _firestore
          .collection('organization_codes')
          .doc(codeId)
          .update({'active': false});
      
      // Update in local database
      await _databaseHelper.deactivateOrganizationCode(int.parse(codeId));
      
      // Update in list
      final index = _organizationCodes.indexWhere((org) => org.id == codeId);
      if (index >= 0) {
        _organizationCodes[index] = _organizationCodes[index].copyWith(active: false);
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error deactivating organization code: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<OrganizationModel?> verifyOrganizationCode(String orgCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Verify using database helper
      final result = await _databaseHelper.verifyOrganizationCode(orgCode);
      
      if (result == null) {
        _error = 'Invalid organization code';
        return null;
      }
      
      return OrganizationModel.fromMap(result);
    } catch (e) {
      _error = e.toString();
      print('Error verifying organization code: $_error');
      return null;
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
