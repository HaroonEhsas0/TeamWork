import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GeofenceModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final String organizationId;
  final List<String>? teamIds; // If null, applies to all teams in the organization
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Color color;
  final String? address;
  final String? description;

  GeofenceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.organizationId,
    this.teamIds,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    required this.color,
    this.address,
    this.description,
  });

  factory GeofenceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse team IDs
    List<String>? teamIds;
    if (data['teamIds'] != null) {
      teamIds = List<String>.from(data['teamIds']);
    }
    
    // Parse color
    final colorValue = data['color'] as int;
    final color = Color(colorValue);
    
    return GeofenceModel(
      id: doc.id,
      name: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      radius: (data['radius'] as num).toDouble(),
      organizationId: data['organizationId'] as String,
      teamIds: teamIds,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] as bool? ?? true,
      color: color,
      address: data['address'] as String?,
      description: data['description'] as String?,
    );
  }

  factory GeofenceModel.fromMap(Map<String, dynamic> map) {
    // Parse team IDs
    List<String>? teamIds;
    if (map['teamIds'] != null) {
      teamIds = List<String>.from(map['teamIds']);
    } else if (map['team_ids'] != null) {
      teamIds = List<String>.from(map['team_ids']);
    }
    
    // Parse color
    Color color;
    if (map['color'] != null) {
      color = Color(map['color'] as int);
    } else {
      color = Colors.blue; // Default color
    }
    
    return GeofenceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      organizationId: map['organizationId'] as String? ?? map['organization_id'] as String,
      teamIds: teamIds,
      createdBy: map['createdBy'] as String? ?? map['created_by'] as String,
      createdAt: map['createdAt'] is DateTime 
          ? map['createdAt'] as DateTime 
          : map['created_at'] is DateTime 
              ? map['created_at'] as DateTime 
              : map['createdAt'] != null 
                  ? DateTime.parse(map['createdAt'] as String) 
                  : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updatedAt'] is DateTime 
          ? map['updatedAt'] as DateTime 
          : map['updated_at'] is DateTime 
              ? map['updated_at'] as DateTime 
              : map['updatedAt'] != null 
                  ? DateTime.parse(map['updatedAt'] as String) 
                  : map['updated_at'] != null 
                      ? DateTime.parse(map['updated_at'] as String) 
                      : null,
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
      color: color,
      address: map['address'] as String?,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'organizationId': organizationId,
      'teamIds': teamIds,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
      'isActive': isActive,
      'color': color.value,
      'address': address,
      'description': description,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'organization_id': organizationId,
      'team_ids': teamIds != null ? teamIds!.join(',') : null,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'color': color.value,
      'address': address,
      'description': description,
    };
  }

  // Check if a location is within this geofence
  bool isLocationWithinGeofence(double lat, double lng) {
    // Calculate distance between two points using Haversine formula
    const double earthRadius = 6371000; // in meters
    
    final double latDiff = _degreesToRadians(lat - latitude);
    final double lngDiff = _degreesToRadians(lng - longitude);
    
    final double a = 
        sin(latDiff / 2) * sin(latDiff / 2) +
        cos(_degreesToRadians(latitude)) * cos(_degreesToRadians(lat)) *
        sin(lngDiff / 2) * sin(lngDiff / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    final double distance = earthRadius * c;
    
    return distance <= radius;
  }
  
  // Helper method to convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  // Create a copy of this geofence with updated fields
  GeofenceModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    String? organizationId,
    List<String>? teamIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Color? color,
    String? address,
    String? description,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      organizationId: organizationId ?? this.organizationId,
      teamIds: teamIds ?? this.teamIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      address: address ?? this.address,
      description: description ?? this.description,
    );
  }
}

// Helper method to parse team IDs from SQLite string
List<String>? parseTeamIds(String? teamIdsString) {
  if (teamIdsString == null || teamIdsString.isEmpty) {
    return null;
  }
  
  return teamIdsString.split(',');
}

// Helper method to format team IDs for SQLite storage
String? formatTeamIds(List<String>? teamIds) {
  if (teamIds == null || teamIds.isEmpty) {
    return null;
  }
  
  return teamIds.join(',');
}

// Import missing dart:math functions
import 'dart:math';

double sin(double x) => math.sin(x);
double cos(double x) => math.cos(x);
double sqrt(double x) => math.sqrt(x);
double atan2(double y, double x) => math.atan2(y, x);
double pi = math.pi;
