import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({Key? key}) : super(key: key);

  @override
  _OrganizationScreenState createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _databaseHelper = DatabaseHelper();
  final _orgNameController = TextEditingController();
  final _validDaysController = TextEditingController(text: '30');
  
  bool _isLoading = false;
  bool _isGeneratingCode = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _orgCodes = [];
  String? _currentOrgName;
  
  @override
  void initState() {
    super.initState();
    _loadOrganizationData();
  }
  
  @override
  void dispose() {
    _orgNameController.dispose();
    _validDaysController.dispose();
    super.dispose();
  }
  
  Future<void> _loadOrganizationData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Check if user is admin
      final isAdmin = await _databaseHelper.isUserAdmin(userId);
      if (!isAdmin) {
        setState(() {
          _errorMessage = 'You do not have administrator privileges';
        });
        return;
      }
      
      // Load organization codes
      _orgCodes = await _databaseHelper.getOrganizationCodes(userId);
      
      // Get current organization name
      if (_orgCodes.isNotEmpty) {
        _currentOrgName = _orgCodes.first['org_name'] as String?;
        _orgNameController.text = _currentOrgName ?? 'My Organization';
      } else {
        _orgNameController.text = 'My Organization';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load organization data: ${e.toString()}';
      });
      print('Error loading organization data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _generateOrganizationCode() async {
    // Validate input
    final orgName = _orgNameController.text.trim();
    if (orgName.isEmpty) {
      setState(() {
        _errorMessage = 'Organization name cannot be empty';
      });
      return;
    }
    
    int validDays;
    try {
      validDays = int.parse(_validDaysController.text.trim());
      if (validDays <= 0 || validDays > 365) {
        throw FormatException('Valid days must be between 1 and 365');
      }
    } on FormatException {
      setState(() {
        _errorMessage = 'Please enter a valid number of days (1-365)';
      });
      return;
    }
    
    setState(() {
      _isGeneratingCode = true;
      _errorMessage = null;
    });
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Generate new organization code
      final codeData = await _databaseHelper.generateOrganizationCode(
        userId,
        orgName,
        validDays: validDays,
      );
      
      // Update organization name in Firestore
      await FirebaseFirestore.instance.collection('organizations').doc(userId).set({
        'name': orgName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Update current organization name
      setState(() {
        _currentOrgName = orgName;
      });
      
      // Reload organization codes
      await _loadOrganizationData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organization code generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate organization code: ${e.toString()}';
      });
      print('Error generating organization code: $e');
    } finally {
      setState(() {
        _isGeneratingCode = false;
      });
    }
  }
  
  Future<void> _deactivateOrganizationCode(String codeId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _databaseHelper.deactivateOrganizationCode(codeId);
      
      // Reload organization codes
      await _loadOrganizationData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organization code deactivated'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to deactivate organization code: ${e.toString()}';
      });
      print('Error deactivating organization code: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _copyCodeToClipboard(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  Widget _buildCodeCard(Map<String, dynamic> codeData) {
    final orgCode = codeData['org_code'] as String? ?? '';
    final createdAt = codeData['created_at'] != null 
        ? DateTime.parse(codeData['created_at'] as String)
        : DateTime.now();
    final expiresAt = codeData['expires_at'] != null 
        ? DateTime.parse(codeData['expires_at'] as String)
        : DateTime.now().add(Duration(days: 30));
    final isActive = (codeData['active'] as int? ?? 0) == 1;
    final codeId = codeData['id'] as int? ?? 0;
    
    final isExpired = expiresAt.isBefore(DateTime.now());
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive && !isExpired 
              ? Colors.green.shade200 
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive && !isExpired 
                        ? Colors.green.shade100 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive && !isExpired ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive && !isExpired 
                          ? Colors.green.shade800 
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Spacer(),
                if (isActive && !isExpired) ...[
                  Text(
                    daysLeft > 0 
                        ? '$daysLeft days left' 
                        : 'Expires today',
                    style: TextStyle(
                      color: daysLeft < 5 
                          ? Colors.orange.shade800 
                          : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ] else if (isExpired) ...[
                  Text(
                    'Expired',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          orgCode,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: isActive && !isExpired 
                                ? Colors.blue.shade800 
                                : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, size: 18),
                          onPressed: isActive && !isExpired 
                              ? () => _copyCodeToClipboard(orgCode)
                              : null,
                          tooltip: 'Copy code',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 4),
                Text(
                  'Created: ${DateFormat('MMM d, yyyy').format(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(width: 16),
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 4),
                Text(
                  'Expires: ${DateFormat('MMM d, yyyy').format(expiresAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired 
                        ? Colors.red.shade800 
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (isActive && !isExpired) ...[
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _deactivateOrganizationCode(codeId.toString()),
                icon: Icon(Icons.block_outlined, size: 16),
                label: Text('Deactivate Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 36),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Organization Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrganizationData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null && _orgCodes.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadOrganizationData,
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Organization Name
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organization Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: _orgNameController,
                                decoration: InputDecoration(
                                  labelText: 'Organization Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                enabled: !_isGeneratingCode,
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: _validDaysController,
                                decoration: InputDecoration(
                                  labelText: 'Code Valid Days',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                  helperText: 'Number of days the code will be valid (1-365)',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                enabled: !_isGeneratingCode,
                              ),
                              SizedBox(height: 16),
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade800),
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              ElevatedButton.icon(
                                onPressed: _isGeneratingCode ? null : _generateOrganizationCode,
                                icon: Icon(Icons.add),
                                label: _isGeneratingCode
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Generating...'),
                                        ],
                                      )
                                    : Text('Generate New Code'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Organization Codes List
                      Text(
                        'Organization Codes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Share these codes with your team members to connect them to your organization.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      if (_orgCodes.isEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 48,
                                    color: Colors.blue.shade300,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No organization codes found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Generate a new code to connect team members to your organization.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        ...(_orgCodes.map((codeData) => _buildCodeCard(codeData)).toList()),
                      ],
                      
                      SizedBox(height: 24),
                      
                      // Help Section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How Organization Codes Work',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Organization codes connect users to your organization, allowing them to access team data.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.security_outlined,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Codes expire after the specified number of days for security.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Share codes with your team members via email, messaging, or in person.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.block_outlined,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You can deactivate codes at any time to prevent new users from joining.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
