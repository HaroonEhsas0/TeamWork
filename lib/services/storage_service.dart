import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Shared Preferences Methods
  
  // Save data to shared preferences
  Future<bool> saveData(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value is String) {
      return await prefs.setString(key, value);
    } else if (value is int) {
      return await prefs.setInt(key, value);
    } else if (value is double) {
      return await prefs.setDouble(key, value);
    } else if (value is bool) {
      return await prefs.setBool(key, value);
    } else if (value is List<String>) {
      return await prefs.setStringList(key, value);
    } else {
      // For complex objects, convert to JSON string
      try {
        final jsonString = json.encode(value);
        return await prefs.setString(key, jsonString);
      } catch (e) {
        print('Error saving data: $e');
        return false;
      }
    }
  }
  
  // Read data from shared preferences
  Future<dynamic> readData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key);
  }
  
  // Read string data from shared preferences
  Future<String?> readStringData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
  
  // Read int data from shared preferences
  Future<int?> readIntData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }
  
  // Read bool data from shared preferences
  Future<bool?> readBoolData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }
  
  // Read complex object from shared preferences
  Future<Map<String, dynamic>?> readJsonData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) return null;
    
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading JSON data: $e');
      return null;
    }
  }
  
  // Delete data from shared preferences
  Future<bool> deleteData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(key);
  }
  
  // Clear all data from shared preferences
  Future<bool> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.clear();
  }
  
  // Secure Storage Methods
  
  // Save data to secure storage
  Future<void> saveSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }
  
  // Read data from secure storage
  Future<String?> readSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }
  
  // Delete data from secure storage
  Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }
  
  // Clear all data from secure storage
  Future<void> clearAllSecureData() async {
    await _secureStorage.deleteAll();
  }
  
  // File Storage Methods
  
  // Get application documents directory
  Future<Directory> get _appDocumentsDirectory async {
    return await getApplicationDocumentsDirectory();
  }
  
  // Save file to documents directory
  Future<File> saveFile(String fileName, List<int> bytes) async {
    final directory = await _appDocumentsDirectory;
    final file = File('${directory.path}/$fileName');
    return await file.writeAsBytes(bytes);
  }
  
  // Read file from documents directory
  Future<List<int>?> readFile(String fileName) async {
    try {
      final directory = await _appDocumentsDirectory;
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      
      return null;
    } catch (e) {
      print('Error reading file: $e');
      return null;
    }
  }
  
  // Delete file from documents directory
  Future<bool> deleteFile(String fileName) async {
    try {
      final directory = await _appDocumentsDirectory;
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
  
  // Check if file exists in documents directory
  Future<bool> fileExists(String fileName) async {
    final directory = await _appDocumentsDirectory;
    final file = File('${directory.path}/$fileName');
    return await file.exists();
  }
  
  // Get file size in bytes
  Future<int?> getFileSize(String fileName) async {
    try {
      final directory = await _appDocumentsDirectory;
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        return await file.length();
      }
      
      return null;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }
  
  // List all files in documents directory
  Future<List<FileSystemEntity>> listFiles() async {
    final directory = await _appDocumentsDirectory;
    return directory.listSync();
  }
}
