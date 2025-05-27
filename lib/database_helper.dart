import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'attendance.db');
      return await openDatabase(
        path,
        version: 8, // Version 8 includes shifts and leaves tables
        onCreate: (db, version) async {
          // This is called when the database is first created
          await _createDatabase(db, version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // This is called when the database needs to be upgraded
          if (oldVersion < 7) {
            // Add new tables for version 7
            await _upgradeToV7(db);
          }
          if (oldVersion < 8) {
            // Add new tables for version 8
            await _upgradeToV8(db);
          }
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          // Handle downgrade if needed
          print('Downgrading database from $oldVersion to $newVersion');
        }
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }
  
  Future<void> _upgradeToV7(Database db) async {
    // Create teams table with new structure
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teams (
        id TEXT PRIMARY KEY,
        name TEXT,
        admin_id TEXT,
        created_at TEXT,
        description TEXT
      )
    ''');
    
    // Create team_members table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS team_members (
        id TEXT PRIMARY KEY,
        team_id TEXT,
        user_id TEXT,
        joined_at TEXT,
        role TEXT,
        FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
      )
    ''');
    
    // Create attendance table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        date TEXT,
        check_in_time TEXT,
        check_out_time TEXT,
        check_in_location TEXT,
        check_out_location TEXT,
        check_in_verified INTEGER,
        check_out_verified INTEGER,
        notes TEXT
      )
    ''');
  }
  
  Future<void> _upgradeToV8(Database db) async {
    print('Upgrading database to version 8');
    
    // Create shifts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        work_days TEXT NOT NULL,
        description TEXT,
        organization_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_active INTEGER DEFAULT 1,
        color INTEGER NOT NULL
      )
    ''');
    
    // Create shift assignments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_assignments (
        id TEXT PRIMARY KEY,
        shift_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        assigned_by TEXT NOT NULL,
        assigned_at TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
      )
    ''');
    
    // Create leaves table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaves (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        user_name TEXT,
        organization_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        leave_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        approved_by TEXT,
        approved_at TEXT,
        rejection_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // Create geofences table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS geofences (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL NOT NULL,
        organization_id TEXT NOT NULL,
        team_ids TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_active INTEGER DEFAULT 1,
        color INTEGER NOT NULL,
        address TEXT,
        description TEXT
      )
    ''');
    
    // Create employees table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        position TEXT,
        department TEXT,
        organization_id TEXT NOT NULL,
        team_id TEXT,
        fingerprint_registered INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // Create employee_credentials table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_credentials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        credential_id TEXT NOT NULL,
        public_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
  }
  
  Future<void> _createDatabase(Database db, int version) async {
          print('Creating database from scratch at version $version');
          
          // Create teams table
          await db.execute('''
            CREATE TABLE teams (
              id TEXT PRIMARY KEY,
              name TEXT,
              admin_id TEXT,
              created_at TEXT,
              description TEXT
            )
          ''');
          
          // Create team_members table
          await db.execute('''
            CREATE TABLE team_members (
              id TEXT PRIMARY KEY,
              team_id TEXT,
              user_id TEXT,
              joined_at TEXT,
              role TEXT,
              FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
            )
          ''');
          
          // Create attendance table
          await db.execute('''
            CREATE TABLE attendance (
              id TEXT PRIMARY KEY,
              user_id TEXT,
              date TEXT,
              check_in_time TEXT,
              check_out_time TEXT,
              check_in_location TEXT,
              check_out_location TEXT,
              check_in_verified INTEGER,
              check_out_verified INTEGER,
              notes TEXT
            )
          ''');
          
          // Create shifts table
          await db.execute('''
            CREATE TABLE shifts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              start_time TEXT NOT NULL,
              end_time TEXT NOT NULL,
              work_days TEXT NOT NULL,
              description TEXT,
              organization_id TEXT NOT NULL,
              created_by TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT,
              is_active INTEGER DEFAULT 1,
              color INTEGER NOT NULL
            )
          ''');
          
          // Create shift assignments table
          await db.execute('''
            CREATE TABLE shift_assignments (
              id TEXT PRIMARY KEY,
              shift_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              assigned_by TEXT NOT NULL,
              assigned_at TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT,
              is_active INTEGER DEFAULT 1,
              FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE
            )
          ''');
          
          // Create leaves table
          await db.execute('''
            CREATE TABLE leaves (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              user_name TEXT,
              organization_id TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              leave_type TEXT NOT NULL,
              reason TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              approved_by TEXT,
              approved_at TEXT,
              rejection_reason TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          
          // Create geofences table
          await db.execute('''
            CREATE TABLE geofences (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              radius REAL NOT NULL,
              organization_id TEXT NOT NULL,
              team_ids TEXT,
              created_by TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT,
              is_active INTEGER DEFAULT 1,
              color INTEGER NOT NULL,
              address TEXT,
              description TEXT
            )
          ''');
          
          // Create employees table
          await db.execute('''
            CREATE TABLE employees (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              email TEXT,
              phone TEXT,
              position TEXT,
              department TEXT,
              organization_id TEXT NOT NULL,
              team_id TEXT,
              fingerprint_registered INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT
            )
          ''');
          
          // Create employee_credentials table
          await db.execute('''
            CREATE TABLE employee_credentials (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER NOT NULL,
              user_id TEXT NOT NULL,
              credential_id TEXT NOT NULL,
              public_key TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            CREATE TABLE teams (
              id TEXT PRIMARY KEY,
              name TEXT,
              admin_id TEXT,
              created_at TEXT,
              description TEXT
            )
          ''');
          
          await db.execute('''
            CREATE TABLE team_members (
              id TEXT PRIMARY KEY,
              team_id TEXT,
              user_id TEXT,
              joined_at TEXT,
              role TEXT,
              FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
            )
          ''');
          
          await db.execute('''
            CREATE TABLE attendance (
              id TEXT PRIMARY KEY,
              user_id TEXT,
              date TEXT,
              check_in_time TEXT,
              check_out_time TEXT,
              check_in_location TEXT,
              check_out_location TEXT,
              check_in_verified INTEGER,
              check_out_verified INTEGER,
              notes TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              team_id INTEGER,
              title TEXT,
              description TEXT,
              deadline TEXT,
              FOREIGN KEY (team_id) REFERENCES teams(id)
            )
          ''');

          await db.execute('''
            CREATE TABLE shifts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              start_time TEXT,
              end_time TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sender_id INTEGER,
              receiver_id INTEGER,
              content TEXT,
              timestamp TEXT
            )
          ''');
          
          // Attendance system tables
          await db.execute('''
            CREATE TABLE attendance_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER,
              check_in TEXT,
              check_out TEXT,
              date TEXT,
              status TEXT,
              fingerprint_verified BOOLEAN DEFAULT 0,
              check_in_location TEXT,
              check_out_location TEXT
            )
          ''');
          
          await db.execute('''
            CREATE TABLE employee_credentials (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              employee_id INTEGER,
              user_id TEXT,
              credential_id TEXT,
              public_key TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          
          // Create user_roles table for role-based access control
          await db.execute('''
            CREATE TABLE user_roles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT UNIQUE,
              role TEXT DEFAULT 'user',
              permissions TEXT,
              org_code TEXT,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP,
              updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          
          // Create employees table
          await db.execute('''
            CREATE TABLE employees (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              employee_id TEXT UNIQUE,
              name TEXT,
              email TEXT,
              department TEXT,
              role TEXT DEFAULT 'user',
              org_code TEXT,
              fingerprint_registered BOOLEAN DEFAULT 0
            )
          ''');
          
          // Create organization_codes table
          await db.execute('''
            CREATE TABLE organization_codes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              admin_id TEXT NOT NULL,
              org_name TEXT NOT NULL,
              org_code TEXT NOT NULL,
              active INTEGER DEFAULT 1,
              created_at TEXT,
              expires_at TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('Upgrading database from version $oldVersion to $newVersion');
          
          // Handle migrations based on old version
          if (oldVersion < 6) {
            // Add organization_codes table in version 6
            await db.execute('''
              CREATE TABLE IF NOT EXISTS organization_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                admin_id TEXT NOT NULL,
                org_name TEXT NOT NULL,
                org_code TEXT NOT NULL,
                active INTEGER DEFAULT 1,
                created_at TEXT,
                expires_at TEXT
              )
            ''');
            
            // Add org_code field to employees table
            await db.execute('ALTER TABLE employees ADD COLUMN org_code TEXT');
            
            // Add org_code field to user_roles table
            await db.execute('ALTER TABLE user_roles ADD COLUMN org_code TEXT');
          }
          
          // Add location columns in version 5
          if (oldVersion < 5) {
            try {
              await db.execute('ALTER TABLE attendance_records ADD COLUMN check_in_location TEXT');
              await db.execute('ALTER TABLE attendance_records ADD COLUMN check_out_location TEXT');
              print('Added location columns to attendance_records table');
            } catch (e) {
              print('Error adding location columns: $e');
            }
          }
        },
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }
  
  // -------------------- USER ROLES --------------------
  Future<Map<String, dynamic>?> getUserRole(String userId) async {
    try {
      final db = await database;
      
      // Check if user exists in user_roles table
      final roles = await db.query(
        'user_roles',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (roles.isNotEmpty) {
        return roles.first;
      }
      
      // If not found in user_roles, check employees table
      final employees = await db.query(
        'employees',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (employees.isNotEmpty) {
        final role = employees.first['role'] as String? ?? 'user';
        return {'user_id': userId, 'role': role};
      }
      
      // Default to user role if not found
      return {'user_id': userId, 'role': 'user'};
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
  
  Future<bool> setUserRole(String userId, String role) async {
    try {
      final db = await database;
      
      // Check if user exists in user_roles table
      final roles = await db.query(
        'user_roles',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (roles.isNotEmpty) {
        // Update existing role
        await db.update(
          'user_roles',
          {
            'role': role,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      } else {
        // Insert new role
        await db.insert(
          'user_roles',
          {
            'user_id': userId,
            'role': role,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Also update role in employees table if exists
      final employees = await db.query(
        'employees',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (employees.isNotEmpty) {
        await db.update(
          'employees',
          {'role': role},
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
      
      return true;
    } catch (e) {
      print('Error setting user role: $e');
      return false;
    }
  }
  
  Future<bool> isUserAdmin(String userId) async {
    try {
      final userRole = await getUserRole(userId);
      return userRole != null && userRole['role'] == 'admin';
    } catch (e) {
      print('Error checking if user is admin: $e');
      return false;
    }
  }

  // -------------------- ATTENDANCE --------------------
  Future<Map<String, dynamic>?> getEmployeeByUserId(String userId) async {
    try {
      final db = await database;
      
      final employees = await db.query(
        'employees',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      return employees.isNotEmpty ? employees.first : null;
    } catch (e) {
      print('Error getting employee: $e');
      return null;
    }
  }
  
  Future<int> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      final db = await database;
      return await db.insert('employees', employeeData);
    } catch (e) {
      print('Error creating employee: $e');
      return -1;
    }
  }
  
  Future<Map<String, dynamic>?> getTodayAttendance(int employeeId) async {
    try {
      final db = await database;
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final records = await db.query(
        'attendance_records',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, today],
      );
      
      return records.isNotEmpty ? records.first : null;
    } catch (e) {
      print('Error getting today attendance: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>> getAttendanceHistory(int employeeId) async {
    try {
      final db = await database;
      
      return await db.query(
        'attendance_records',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'date DESC',
      );
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }
  
  Future<int> checkIn(int employeeId, bool verified, {String? location}) async {
    try {
      final db = await database;
      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      
      // Check if already checked in today
      final existing = await db.query(
        'attendance_records',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, today],
      );
      
      if (existing.isNotEmpty) {
        // Already checked in, update if check_out is null
        final record = existing.first;
        if (record['check_out'] == null) {
          return record['id'] as int;
        } else {
          // Already checked out, can't check in again
          return -1;
        }
      }
      
      // New check-in
      return await db.insert(
        'attendance_records',
        {
          'employee_id': employeeId,
          'check_in': now.toIso8601String(),
          'date': today,
          'status': 'checked-in',
          'fingerprint_verified': verified ? 1 : 0,
          'check_in_location': location,
        },
      );
    } catch (e) {
      print('Error checking in: $e');
      return -1;
    }
  }
  
  Future<bool> checkOut(int recordId, bool verified, {String? location}) async {
    try {
      final db = await database;
      final now = DateTime.now();
      
      // Update record
      final count = await db.update(
        'attendance_records',
        {
          'check_out': now.toIso8601String(),
          'status': 'checked-out',
          'fingerprint_verified': verified ? 1 : 0,
          'check_out_location': location,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );
      
      return count > 0;
    } catch (e) {
      print('Error checking out: $e');
      return false;
    }
  }
  
  // -------------------- FINGERPRINT --------------------
  Future<bool> isFingerprintRegistered(int employeeId) async {
    try {
      final db = await database;
      
      final employees = await db.query(
        'employees',
        columns: ['fingerprint_registered'],
        where: 'id = ?',
        whereArgs: [employeeId],
      );
      
      if (employees.isEmpty) {
        return false;
      }
      
      return employees.first['fingerprint_registered'] == 1;
    } catch (e) {
      print('Error checking fingerprint registration: $e');
      return false;
    }
  }
  
  Future<bool> registerFingerprint(int employeeId, String userId, String credentialId, String publicKey) async {
    try {
      final db = await database;
      
      // Insert credential
      await db.insert(
        'employee_credentials',
        {
          'employee_id': employeeId,
          'user_id': userId,
          'credential_id': credentialId,
          'public_key': publicKey,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      
      // Update employee
      await db.update(
        'employees',
        {'fingerprint_registered': 1},
        where: 'id = ?',
        whereArgs: [employeeId],
      );
      
      return true;
    } catch (e) {
      print('Error registering fingerprint: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>?> getCredential(int employeeId) async {
    try {
      final db = await database;
      
      final credentials = await db.query(
        'employee_credentials',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      
      return credentials.isNotEmpty ? credentials.first : null;
    } catch (e) {
      print('Error getting credential: $e');
      return null;
    }
  }

  // -------------------- ORGANIZATION CODES --------------------
  
  // Generate a new organization code for an admin
  Future<Map<String, dynamic>> generateOrganizationCode(String adminId, String orgName, {int validDays = 30}) async {
    try {
      // Generate a random 6-character alphanumeric code
      final random = Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      String orgCode = '';
      for (int i = 0; i < 6; i++) {
        orgCode += chars[random.nextInt(chars.length)];
      }
      
      // Set expiration date
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: validDays));
      
      // Insert into database with timeout protection
      return await Future.timeout(Duration(seconds: 10), () async {
        try {
          final db = await database;
          
          // Insert the code
          final id = await db.insert('organization_codes', {
            'admin_id': adminId,
            'org_name': orgName,
            'org_code': orgCode,
            'active': 1,
            'created_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
          });
          
          // Return the created code data
          return {
            'id': id,
            'admin_id': adminId,
            'org_name': orgName,
            'org_code': orgCode,
            'active': 1,
            'created_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
          };
        } catch (e) {
          print('Error generating organization code: $e');
          return {};
        }
      }).catchError((error) {
        print('Timeout generating organization code: $error');
        return {};
      });
    } catch (e) {
      print('Error generating organization code: $e');
      return {};
    }
  }
  
  // Verify if an organization code is valid
  Future<Map<String, dynamic>?> verifyOrganizationCode(String orgCode) async {
    if (orgCode.isEmpty) return null;
    
    try {
      // Check network connectivity
      bool hasNetwork = await _checkNetworkConnectivity();
      
      if (!hasNetwork) {
        // Try to use cached verification if offline
        return await _getCachedVerification(orgCode);
      }
      
      // Online verification with timeout
      return await _verifyOrganizationCodeWithTimeout(orgCode);
    } catch (e) {
      print('Error verifying organization code: $e');
      return null;
    }
  }
  
  // Helper method with timeout for network operations
  Future<Map<String, dynamic>?> _verifyOrganizationCodeWithTimeout(String orgCode) async {
    try {
      return await Future.timeout(Duration(seconds: 10), () async {
        final db = await database;
        
        // Query the database for the code
        final codes = await db.query(
          'organization_codes',
          where: 'org_code = ? AND active = 1',
          whereArgs: [orgCode],
        );
        
        if (codes.isEmpty) {
          print('Organization code not found or inactive: $orgCode');
          return null;
        }
        
        final codeData = codes.first;
        
        // Check if code has expired
        final expiresAt = DateTime.parse(codeData['expires_at'] as String);
        final now = DateTime.now();
        
        if (now.isAfter(expiresAt)) {
          print('Organization code expired: $orgCode');
          return null;
        }
        
        // Code is valid, cache it for offline use
        await _cacheVerifiedOrganization(codeData);
        
        return codeData;
      }).catchError((error) {
        print('Timeout verifying organization code: $error');
        return null;
      });
    } catch (e) {
      print('Error in verification with timeout: $e');
      return null;
    }
  }
  
  // Cache verified organization for offline access
  Future<void> _cacheVerifiedOrganization(Map<String, dynamic> orgData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgCode = orgData['org_code'] as String;
      
      // Cache the organization data
      await prefs.setString('verified_org_$orgCode', jsonEncode(orgData));
      
      // Cache the verification timestamp
      await prefs.setString('verified_org_${orgCode}_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching verified organization: $e');
    }
  }
  
  // Get all active organization codes for an admin
  Future<List<Map<String, dynamic>>> getAdminOrganizationCodes(String adminId) async {
    try {
      final db = await database;
      
      return await db.query(
        'organization_codes',
        where: 'admin_id = ? AND active = 1',
        whereArgs: [adminId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('Error getting admin organization codes: $e');
      return [];
    }
  }
  
  // Deactivate an organization code
  Future<bool> deactivateOrganizationCode(int codeId) async {
    try {
      final db = await database;
      
      final count = await db.update(
        'organization_codes',
        {'active': 0},
        where: 'id = ?',
        whereArgs: [codeId],
      );
      
      return count > 0;
    } catch (e) {
      print('Error deactivating organization code: $e');
      return false;
    }
  }
  
  // Connect user to organization using code
  Future<bool> connectUserToOrganization(String userId, String orgCode) async {
    try {
      // Add a timeout to prevent UI freezing during network issues
      return await Future.timeout(Duration(seconds: 10), () async {
        try {
          // Verify the code
          final codeData = await verifyOrganizationCode(orgCode);
          if (codeData == null) {
            print('Connection failed: Invalid or expired organization code');
            return false; // Invalid or expired code
          }
          
          final db = await database;
          
          // Update the user's organization code
          await db.update(
            'employees',
            {'org_code': orgCode},
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          
          // Update user_roles table if it exists
          try {
            await db.update(
              'user_roles',
              {'org_code': orgCode},
              where: 'user_id = ?',
              whereArgs: [userId],
            );
          } catch (e) {
            // Table might not exist yet, that's okay
            print('Note: user_roles table might not exist yet: $e');
          }
          
          // Cache the organization code for offline use
          final orgName = codeData['org_name'] as String;
          await cacheOrganizationCode(userId, orgCode, orgName);
          
          print('Successfully connected user to organization: $orgName');
          return true;
        } catch (e) {
          print('Error in connection process: $e');
          return false;
        }
      }).catchError((error) {
        if (error is TimeoutException) {
          print('Organization connection timed out after 10 seconds');
        } else {
          print('Error during organization connection: $error');
        }
        return false;
      });
    } catch (e) {
      print('Error connecting user to organization: $e');
      return false;
    }
  }
  
  // Cache organization code for offline use
  Future<void> cacheOrganizationCode(String userId, String orgCode, String orgName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache the organization code and name
      await prefs.setString('user_org_code_$userId', orgCode);
      await prefs.setString('user_org_name_$userId', orgName);
      
      // Cache connection status
      await prefs.setBool('user_connected_$userId', true);
    } catch (e) {
      print('Error caching organization code: $e');
    }
  }
  
  // Get cached organization code
  Future<String?> getCachedOrganizationCode(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_org_code_$userId');
    } catch (e) {
      print('Error getting cached organization code: $e');
      return null;
    }
  }
  
  // Get cached organization name
  Future<String?> getCachedOrganizationName(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_org_name_$userId');
    } catch (e) {
      print('Error getting cached organization name: $e');
      return null;
    }
  }
  
  // Check if user is connected from cache
  Future<bool> isCachedUserConnected(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('user_connected_$userId') ?? false;
    } catch (e) {
      print('Error checking cached connection status: $e');
      return false;
    }
  }
  
  // Check if user is connected to an organization
  Future<bool> isUserConnected(String userId) async {
    try {
      // Try to get from database first
      final db = await database;
      
      // Check if user exists in employees table with org_code
      final employees = await db.query(
        'employees',
        columns: ['org_code'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (employees.isNotEmpty) {
        final orgCode = employees.first['org_code'] as String?;
        if (orgCode != null && orgCode.isNotEmpty) {
          // Verify if the code is still valid
          final isValid = await verifyOrganizationCode(orgCode) != null;
          
          // Cache the result
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('user_connected_$userId', isValid);
          
          return isValid;
        }
      }
      
      // Check user_roles table as fallback
      final roles = await db.query(
        'user_roles',
        columns: ['org_code'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (roles.isNotEmpty) {
        final orgCode = roles.first['org_code'] as String?;
        if (orgCode != null && orgCode.isNotEmpty) {
          // Verify if the code is still valid
          final isValid = await verifyOrganizationCode(orgCode) != null;
          
          // Cache the result
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('user_connected_$userId', isValid);
          
          return isValid;
        }
      }
      
      // If we get here, user is not connected
      // Cache the result
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_connected_$userId', false);
      
      return false;
    } catch (e) {
      print('Error checking if user is connected: $e');
      
      // Try to use cached value as fallback
      try {
        return await isCachedUserConnected(userId);
      } catch (e) {
        print('Error getting cached connection status: $e');
        return false;
      }
    }
  }
  
  // Get user's organization code
  Future<String?> getUserOrganizationCode(String userId) async {
    try {
      final db = await database;
      
      // Check employees table
      final employees = await db.query(
        'employees',
        columns: ['org_code'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (employees.isNotEmpty) {
        return employees.first['org_code'] as String?;
      }
      
      // Check user_roles table as fallback
      final roles = await db.query(
        'user_roles',
        columns: ['org_code'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      
      if (roles.isNotEmpty) {
        return roles.first['org_code'] as String?;
      }
      
      return null;
    } catch (e) {
      print('Error getting user organization code: $e');
      
      // Try to use cached value as fallback
      return await getCachedOrganizationCode(userId);
    }
  }
  
  // Get organization admin id from code
  Future<String?> getOrganizationAdminId(String orgCode) async {
    try {
      final db = await database;
      
      final codes = await db.query(
        'organization_codes',
        columns: ['admin_id'],
        where: 'org_code = ? AND active = 1',
        whereArgs: [orgCode],
      );
      
      return codes.isNotEmpty ? codes.first['admin_id'] as String? : null;
    } catch (e) {
      print('Error getting organization admin id: $e');
      return null;
    }
  }
  
  // Helper method to check network connectivity
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      print('Error checking network connectivity: $e');
      return false;
    }
  }
  
  // Helper method to get cached verification
  Future<Map<String, dynamic>?> _getCachedVerification(String orgCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('verified_org_$orgCode');
      
      if (cachedData == null) {
        return null;
      }
      
      // Check if verification is not too old (7 days max)
      final timestampStr = prefs.getString('verified_org_${orgCode}_timestamp');
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();
        final difference = now.difference(timestamp).inDays;
        
        if (difference > 7) {
          // Too old, clear cache
          await prefs.remove('verified_org_$orgCode');
          await prefs.remove('verified_org_${orgCode}_timestamp');
          return null;
        }
      }
      
      return jsonDecode(cachedData) as Map<String, dynamic>;
    } catch (e) {
      print('Error getting cached verification: $e');
      return null;
    }
  }
  
  // Methods for attendance reports
  Future<List<Map<String, dynamic>>> getAttendanceInRange(String userId, String startDate, String endDate) async {
    final db = await database;
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT * FROM attendance 
      WHERE user_id = ? AND date BETWEEN ? AND ? 
      ORDER BY date DESC
    ''', [userId, startDate, endDate]);
    
    return results;
  }
  
  Future<List<Map<String, dynamic>>> getTeamAttendanceInRange(String teamId, String startDate, String endDate) async {
    final db = await database;
    
    // First get all team members
    final List<Map<String, dynamic>> members = await db.rawQuery('''
      SELECT user_id FROM team_members 
      WHERE team_id = ?
    ''', [teamId]);
    
    if (members.isEmpty) {
      return [];
    }
    
    // Extract user IDs
    final List<String> userIds = members.map((m) => m['user_id'] as String).toList();
    
    // Build the query with placeholders for all user IDs
    final String placeholders = userIds.map((id) => '?').join(',');
    
    // Get attendance records for all team members
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT a.*, u.name as user_name 
      FROM attendance a 
      JOIN users u ON a.user_id = u.id 
      WHERE a.user_id IN ($placeholders) AND a.date BETWEEN ? AND ? 
      ORDER BY a.date DESC, u.name ASC
    ''', [...userIds, startDate, endDate]);
    
    return results;
  }
  
  Future<List<Map<String, dynamic>>> getTeams(String adminId) async {
    final db = await database;
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT * FROM teams 
      WHERE admin_id = ? 
      ORDER BY name ASC
    ''', [adminId]);
    
    return results;
  }
  
  Future<List<Map<String, dynamic>>> getTeamMembersByTeam(String teamId) async {
    final db = await database;
    
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT tm.*, u.name, u.email, u.role 
      FROM team_members tm 
      JOIN users u ON tm.user_id = u.id 
      WHERE tm.team_id = ? 
      ORDER BY u.name ASC
    ''', [teamId]);
    
    return results;
  }
}
