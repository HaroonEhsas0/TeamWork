import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Check and request location permission
  Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }
  
  // Get current position with timeout
  Future<Position?> getCurrentPosition({
    int timeoutSeconds = 10,
    bool highAccuracy = true,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: Duration(seconds: timeoutSeconds),
      );
    } on TimeoutException {
      print('Location request timed out');
      return null;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
  
  // Get address from position
  Future<String?> getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
      }
      
      return null;
    } catch (e) {
      print('Error getting address from position: $e');
      return null;
    }
  }
  
  // Calculate distance between two positions in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
  
  // Check if user is within radius of a location
  bool isWithinRadius({
    required double userLatitude,
    required double userLongitude,
    required double targetLatitude,
    required double targetLongitude,
    required double radiusInMeters,
  }) {
    double distance = calculateDistance(
      userLatitude,
      userLongitude,
      targetLatitude,
      targetLongitude,
    );
    
    return distance <= radiusInMeters;
  }
  
  // Save work location
  Future<void> saveWorkLocation(LatLng location, String locationName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('work_location_lat', location.latitude);
      await prefs.setDouble('work_location_lng', location.longitude);
      await prefs.setString('work_location_name', locationName);
    } catch (e) {
      print('Error saving work location: $e');
    }
  }
  
  // Get saved work location
  Future<Map<String, dynamic>?> getSavedWorkLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('work_location_lat');
      final lng = prefs.getDouble('work_location_lng');
      final name = prefs.getString('work_location_name');
      
      if (lat != null && lng != null) {
        return {
          'latitude': lat,
          'longitude': lng,
          'name': name ?? 'Work Location',
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting saved work location: $e');
      return null;
    }
  }
  
  // Check if user is at work location
  Future<bool> isAtWorkLocation({double radiusInMeters = 100}) async {
    try {
      // Get saved work location
      final workLocation = await getSavedWorkLocation();
      if (workLocation == null) return false;
      
      // Get current position
      final position = await getCurrentPosition();
      if (position == null) return false;
      
      // Check if within radius
      return isWithinRadius(
        userLatitude: position.latitude,
        userLongitude: position.longitude,
        targetLatitude: workLocation['latitude'],
        targetLongitude: workLocation['longitude'],
        radiusInMeters: radiusInMeters,
      );
    } catch (e) {
      print('Error checking if at work location: $e');
      return false;
    }
  }
  
  // Get location updates stream
  Stream<Position> getPositionStream({
    int distanceFilterInMeters = 10,
    bool highAccuracy = true,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: distanceFilterInMeters,
      ),
    );
  }
  
  // Generate Google Maps URL for a location
  String generateMapsUrl(double latitude, double longitude, {String? label}) {
    final labelParam = label != null ? '&q=${Uri.encodeComponent(label)}' : '';
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude$labelParam';
  }
}
