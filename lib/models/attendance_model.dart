import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInLocation;
  final String? checkOutLocation;
  final bool checkInVerified;
  final bool checkOutVerified;
  final String? notes;
  final String? userName; // Optional, for display purposes

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInVerified = false,
    this.checkOutVerified = false,
    this.notes,
    this.userName,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return AttendanceModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
      checkOutTime: (data['checkOutTime'] as Timestamp?)?.toDate(),
      checkInLocation: data['checkInLocation'],
      checkOutLocation: data['checkOutLocation'],
      checkInVerified: data['checkInVerified'] ?? false,
      checkOutVerified: data['checkOutVerified'] ?? false,
      notes: data['notes'],
      userName: data['userName'],
    );
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      date: map['date'] != null 
        ? (map['date'] is DateTime 
            ? map['date'] 
            : DateTime.parse(map['date']))
        : DateTime.now(),
      checkInTime: map['checkInTime'] != null || map['check_in_time'] != null
        ? (map['checkInTime'] is DateTime 
            ? map['checkInTime'] 
            : map['check_in_time'] is DateTime
                ? map['check_in_time']
                : map['checkInTime'] != null
                    ? DateTime.parse(map['checkInTime'])
                    : DateTime.parse(map['check_in_time']))
        : null,
      checkOutTime: map['checkOutTime'] != null || map['check_out_time'] != null
        ? (map['checkOutTime'] is DateTime 
            ? map['checkOutTime'] 
            : map['check_out_time'] is DateTime
                ? map['check_out_time']
                : map['checkOutTime'] != null
                    ? DateTime.parse(map['checkOutTime'])
                    : DateTime.parse(map['check_out_time']))
        : null,
      checkInLocation: map['checkInLocation'] ?? map['check_in_location'],
      checkOutLocation: map['checkOutLocation'] ?? map['check_out_location'],
      checkInVerified: map['checkInVerified'] ?? map['check_in_verified'] ?? false,
      checkOutVerified: map['checkOutVerified'] ?? map['check_out_verified'] ?? false,
      notes: map['notes'],
      userName: map['userName'] ?? map['user_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'checkInVerified': checkInVerified,
      'checkOutVerified': checkOutVerified,
      'notes': notes,
      'userName': userName,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0], // Just the date part
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'check_in_location': checkInLocation,
      'check_out_location': checkOutLocation,
      'check_in_verified': checkInVerified ? 1 : 0,
      'check_out_verified': checkOutVerified ? 1 : 0,
      'notes': notes,
    };
  }

  // Calculate duration between check-in and check-out
  Duration? get duration {
    if (checkInTime != null && checkOutTime != null) {
      return checkOutTime!.difference(checkInTime!);
    }
    return null;
  }

  // Check if user is currently checked in
  bool get isCheckedIn => checkInTime != null && checkOutTime == null;

  // Check if attendance is complete for the day
  bool get isComplete => checkInTime != null && checkOutTime != null;

  // Check if user was late
  bool isLate(TimeOfDay workStartTime) {
    if (checkInTime == null) return false;
    
    final checkInTimeOfDay = TimeOfDay.fromDateTime(checkInTime!);
    return checkInTimeOfDay.hour > workStartTime.hour || 
           (checkInTimeOfDay.hour == workStartTime.hour && 
            checkInTimeOfDay.minute > workStartTime.minute + 15); // 15 min grace period
  }

  // Check if user left early
  bool leftEarly(TimeOfDay workEndTime) {
    if (checkOutTime == null) return false;
    
    final checkOutTimeOfDay = TimeOfDay.fromDateTime(checkOutTime!);
    return checkOutTimeOfDay.hour < workEndTime.hour || 
           (checkOutTimeOfDay.hour == workEndTime.hour && 
            checkOutTimeOfDay.minute < workEndTime.minute);
  }

  AttendanceModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? checkInLocation,
    String? checkOutLocation,
    bool? checkInVerified,
    bool? checkOutVerified,
    String? notes,
    String? userName,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLocation: checkInLocation ?? this.checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      checkInVerified: checkInVerified ?? this.checkInVerified,
      checkOutVerified: checkOutVerified ?? this.checkOutVerified,
      notes: notes ?? this.notes,
      userName: userName ?? this.userName,
    );
  }
}
