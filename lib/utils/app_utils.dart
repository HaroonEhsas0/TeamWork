import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'constants.dart';

class AppUtils {
  // Check internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking internet connection: $e');
      return false;
    }
  }
  
  // Get app version
  static Future<String> getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      print('Error getting app version: $e');
      return AppConstants.appVersion;
    }
  }
  
  // Get device info
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final Map<String, dynamic> deviceData = <String, dynamic>{};
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData['platform'] = 'Android';
        deviceData['version'] = androidInfo.version.release;
        deviceData['model'] = androidInfo.model;
        deviceData['manufacturer'] = androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData['platform'] = 'iOS';
        deviceData['version'] = iosInfo.systemVersion;
        deviceData['model'] = iosInfo.model;
        deviceData['name'] = iosInfo.name;
      }
      
      return deviceData;
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      };
    }
  }
  
  // Launch URL
  static Future<bool> launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await url_launcher.launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Error launching URL: $e');
      return false;
    }
  }
  
  // Launch email
  static Future<bool> launchEmail({
    required String email,
    String? subject,
    String? body,
  }) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: _encodeQueryParameters({
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        }),
      );
      
      return await url_launcher.launchUrl(emailUri);
    } catch (e) {
      print('Error launching email: $e');
      return false;
    }
  }
  
  // Launch phone call
  static Future<bool> launchPhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      
      return await url_launcher.launchUrl(phoneUri);
    } catch (e) {
      print('Error launching phone call: $e');
      return false;
    }
  }
  
  // Launch SMS
  static Future<bool> launchSms(String phoneNumber, {String? message}) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        query: message != null ? _encodeQueryParameters({'body': message}) : null,
      );
      
      return await url_launcher.launchUrl(smsUri);
    } catch (e) {
      print('Error launching SMS: $e');
      return false;
    }
  }
  
  // Launch maps
  static Future<bool> launchMaps(double latitude, double longitude, {String? label}) async {
    try {
      final Uri mapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${label != null ? '&query_place_id=$label' : ''}',
      );
      
      return await url_launcher.launchUrl(mapsUri);
    } catch (e) {
      print('Error launching maps: $e');
      return false;
    }
  }
  
  // Check and request permission
  static Future<bool> checkAndRequestPermission(Permission permission) async {
    try {
      final status = await permission.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isDenied) {
        final result = await permission.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        return false;
      }
      
      return false;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }
  
  // Get app directory size
  static Future<int> getAppDirectorySize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return await _getDirectorySize(appDir);
    } catch (e) {
      print('Error getting app directory size: $e');
      return 0;
    }
  }
  
  // Format bytes to human-readable size
  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    final i = (log(bytes) / log(1024)).floor();
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  
  // Clear app cache
  static Future<bool> clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error clearing app cache: $e');
      return false;
    }
  }
  
  // Generate random string
  static String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
  
  // Generate random code
  static String generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
  
  // Helper method to encode query parameters
  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
  
  // Helper method to get directory size
  static Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;
    
    try {
      final files = directory.listSync(recursive: true, followLinks: false);
      
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error calculating directory size: $e');
      return 0;
    }
  }
}
