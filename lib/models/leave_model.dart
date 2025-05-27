import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String id;
  final String userId;
  final String? userName;
  final String organizationId;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;
  final String reason;
  final String status; // pending, approved, rejected
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LeaveModel({
    required this.id,
    required this.userId,
    this.userName,
    required this.organizationId,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
  });

  factory LeaveModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return LeaveModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'],
      organizationId: data['organizationId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      leaveType: data['leaveType'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      userName: map['userName'] ?? map['user_name'],
      organizationId: map['organizationId'] ?? map['organization_id'] ?? '',
      startDate: map['startDate'] is DateTime 
          ? map['startDate'] 
          : map['start_date'] is DateTime 
              ? map['start_date'] 
              : map['startDate'] != null 
                  ? DateTime.parse(map['startDate']) 
                  : DateTime.parse(map['start_date']),
      endDate: map['endDate'] is DateTime 
          ? map['endDate'] 
          : map['end_date'] is DateTime 
              ? map['end_date'] 
              : map['endDate'] != null 
                  ? DateTime.parse(map['endDate']) 
                  : DateTime.parse(map['end_date']),
      leaveType: map['leaveType'] ?? map['leave_type'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      approvedBy: map['approvedBy'] ?? map['approved_by'],
      approvedAt: map['approvedAt'] is DateTime 
          ? map['approvedAt'] 
          : map['approved_at'] is DateTime 
              ? map['approved_at'] 
              : map['approvedAt'] != null 
                  ? DateTime.parse(map['approvedAt']) 
                  : map['approved_at'] != null 
                      ? DateTime.parse(map['approved_at']) 
                      : null,
      rejectionReason: map['rejectionReason'] ?? map['rejection_reason'],
      createdAt: map['createdAt'] is DateTime 
          ? map['createdAt'] 
          : map['created_at'] is DateTime 
              ? map['created_at'] 
              : map['createdAt'] != null 
                  ? DateTime.parse(map['createdAt']) 
                  : DateTime.parse(map['created_at']),
      updatedAt: map['updatedAt'] is DateTime 
          ? map['updatedAt'] 
          : map['updated_at'] is DateTime 
              ? map['updated_at'] 
              : map['updatedAt'] != null 
                  ? DateTime.parse(map['updatedAt']) 
                  : map['updated_at'] != null 
                      ? DateTime.parse(map['updated_at']) 
                      : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'organizationId': organizationId,
      'startDate': startDate,
      'endDate': endDate,
      'leaveType': leaveType,
      'reason': reason,
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'organization_id': organizationId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'leave_type': leaveType,
      'reason': reason,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Get the duration of the leave in days
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1; // Include both start and end days
  }

  // Check if the leave request is pending
  bool get isPending => status == 'pending';

  // Check if the leave request is approved
  bool get isApproved => status == 'approved';

  // Check if the leave request is rejected
  bool get isRejected => status == 'rejected';

  // Check if the leave is currently active (today falls within the leave period)
  bool get isActive {
    final today = DateTime.now();
    return isApproved && 
           today.isAfter(startDate.subtract(Duration(days: 1))) && 
           today.isBefore(endDate.add(Duration(days: 1)));
  }

  // Create a copy of this leave with updated fields
  LeaveModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
    String? leaveType,
    String? reason,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      organizationId: organizationId ?? this.organizationId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
