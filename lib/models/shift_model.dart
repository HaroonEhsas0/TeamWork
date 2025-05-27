import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShiftModel {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<String> workDays; // 1-7 representing Monday-Sunday
  final String? description;
  final String organizationId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Color color;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.workDays,
    this.description,
    required this.organizationId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    required this.color,
  });

  factory ShiftModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse start time
    final startTimeMap = data['startTime'] as Map<String, dynamic>;
    final startTime = TimeOfDay(
      hour: startTimeMap['hour'] as int,
      minute: startTimeMap['minute'] as int,
    );
    
    // Parse end time
    final endTimeMap = data['endTime'] as Map<String, dynamic>;
    final endTime = TimeOfDay(
      hour: endTimeMap['hour'] as int,
      minute: endTimeMap['minute'] as int,
    );
    
    // Parse work days
    final workDaysData = data['workDays'] as List<dynamic>;
    final workDays = workDaysData.map((day) => day.toString()).toList();
    
    // Parse color
    final colorValue = data['color'] as int;
    final color = Color(colorValue);
    
    return ShiftModel(
      id: doc.id,
      name: data['name'] as String,
      startTime: startTime,
      endTime: endTime,
      workDays: workDays,
      description: data['description'] as String?,
      organizationId: data['organizationId'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] as bool? ?? true,
      color: color,
    );
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    // Parse start time
    TimeOfDay startTime;
    if (map['startTime'] is Map) {
      final startTimeMap = map['startTime'] as Map<String, dynamic>;
      startTime = TimeOfDay(
        hour: startTimeMap['hour'] as int,
        minute: startTimeMap['minute'] as int,
      );
    } else if (map['start_time'] is String) {
      final timeParts = (map['start_time'] as String).split(':');
      startTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    } else {
      startTime = TimeOfDay(hour: 9, minute: 0); // Default
    }
    
    // Parse end time
    TimeOfDay endTime;
    if (map['endTime'] is Map) {
      final endTimeMap = map['endTime'] as Map<String, dynamic>;
      endTime = TimeOfDay(
        hour: endTimeMap['hour'] as int,
        minute: endTimeMap['minute'] as int,
      );
    } else if (map['end_time'] is String) {
      final timeParts = (map['end_time'] as String).split(':');
      endTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    } else {
      endTime = TimeOfDay(hour: 17, minute: 0); // Default
    }
    
    // Parse work days
    List<String> workDays;
    if (map['workDays'] is List) {
      final workDaysData = map['workDays'] as List<dynamic>;
      workDays = workDaysData.map((day) => day.toString()).toList();
    } else if (map['work_days'] is String) {
      workDays = (map['work_days'] as String).split(',');
    } else {
      workDays = ['1', '2', '3', '4', '5']; // Default Mon-Fri
    }
    
    // Parse color
    Color color;
    if (map['color'] is int) {
      color = Color(map['color'] as int);
    } else if (map['color'] is String) {
      color = Color(int.parse(map['color'] as String));
    } else {
      color = Colors.blue; // Default
    }
    
    return ShiftModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? map['shift_name'] as String? ?? 'Default Shift',
      startTime: startTime,
      endTime: endTime,
      workDays: workDays,
      description: map['description'] as String? ?? map['shift_description'] as String?,
      organizationId: map['organizationId'] as String? ?? map['organization_id'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? map['created_by'] as String? ?? '',
      createdAt: map['createdAt'] is DateTime 
          ? map['createdAt'] as DateTime 
          : map['created_at'] is String 
              ? DateTime.parse(map['created_at'] as String) 
              : DateTime.now(),
      updatedAt: map['updatedAt'] is DateTime 
          ? map['updatedAt'] as DateTime 
          : map['updated_at'] is String 
              ? DateTime.parse(map['updated_at'] as String) 
              : null,
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
      color: color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': {
        'hour': startTime.hour,
        'minute': startTime.minute,
      },
      'endTime': {
        'hour': endTime.hour,
        'minute': endTime.minute,
      },
      'workDays': workDays,
      'description': description,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
      'isActive': isActive,
      'color': color.value,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'shift_name': name,
      'start_time': '${startTime.hour}:${startTime.minute}',
      'end_time': '${endTime.hour}:${endTime.minute}',
      'work_days': workDays.join(','),
      'shift_description': description,
      'organization_id': organizationId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'color': color.value.toString(),
    };
  }

  // Format start time as string (e.g., "09:00 AM")
  String get formattedStartTime {
    final hour = startTime.hour;
    final minute = startTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $period';
  }

  // Format end time as string (e.g., "05:00 PM")
  String get formattedEndTime {
    final hour = endTime.hour;
    final minute = endTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $period';
  }

  // Get shift duration in hours
  double get durationInHours {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    // Handle overnight shifts
    final durationMinutes = endMinutes >= startMinutes 
        ? endMinutes - startMinutes 
        : (24 * 60 - startMinutes) + endMinutes;
    
    return durationMinutes / 60.0;
  }

  // Get formatted work days (e.g., "Mon, Tue, Wed, Thu, Fri")
  String get formattedWorkDays {
    final dayNames = {
      '1': 'Mon',
      '2': 'Tue',
      '3': 'Wed',
      '4': 'Thu',
      '5': 'Fri',
      '6': 'Sat',
      '7': 'Sun',
    };
    
    return workDays.map((day) => dayNames[day] ?? day).join(', ');
  }

  // Check if a given date falls on a work day for this shift
  bool isWorkDay(DateTime date) {
    // Convert DateTime day of week (1-7, where 1 is Monday) to our format
    final dayOfWeek = date.weekday.toString();
    return workDays.contains(dayOfWeek);
  }

  // Create a copy of this shift with updated fields
  ShiftModel copyWith({
    String? id,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<String>? workDays,
    String? description,
    String? organizationId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Color? color,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workDays: workDays ?? this.workDays,
      description: description ?? this.description,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
    );
  }
}
