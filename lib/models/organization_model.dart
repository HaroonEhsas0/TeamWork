import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String name;
  final String adminId;
  final String orgCode;
  final bool active;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? description;
  final String? logoUrl;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.adminId,
    required this.orgCode,
    required this.active,
    required this.createdAt,
    required this.expiresAt,
    this.description,
    this.logoUrl,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return OrganizationModel(
      id: doc.id,
      name: data['name'] ?? '',
      adminId: data['adminId'] ?? data['admin_id'] ?? '',
      orgCode: data['orgCode'] ?? data['org_code'] ?? '',
      active: data['active'] == 1 || data['active'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? 
                 (data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now()),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? 
                 (data['expires_at'] != null ? DateTime.parse(data['expires_at']) : DateTime.now().add(Duration(days: 30))),
      description: data['description'],
      logoUrl: data['logoUrl'],
    );
  }

  factory OrganizationModel.fromMap(Map<String, dynamic> map) {
    return OrganizationModel(
      id: map['id'] ?? '',
      name: map['name'] ?? map['org_name'] ?? '',
      adminId: map['adminId'] ?? map['admin_id'] ?? '',
      orgCode: map['orgCode'] ?? map['org_code'] ?? '',
      active: map['active'] == 1 || map['active'] == true,
      createdAt: map['createdAt'] != null 
        ? (map['createdAt'] is DateTime 
            ? map['createdAt'] 
            : DateTime.parse(map['createdAt']))
        : map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
      expiresAt: map['expiresAt'] != null 
        ? (map['expiresAt'] is DateTime 
            ? map['expiresAt'] 
            : DateTime.parse(map['expiresAt']))
        : map['expires_at'] != null
            ? DateTime.parse(map['expires_at'])
            : DateTime.now().add(Duration(days: 30)),
      description: map['description'],
      logoUrl: map['logoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'adminId': adminId,
      'orgCode': orgCode,
      'active': active,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'description': description,
      'logoUrl': logoUrl,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'org_name': name,
      'admin_id': adminId,
      'org_code': orgCode,
      'active': active ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'description': description,
      'logo_url': logoUrl,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get isValid => active && !isExpired;

  OrganizationModel copyWith({
    String? id,
    String? name,
    String? adminId,
    String? orgCode,
    bool? active,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? description,
    String? logoUrl,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      adminId: adminId ?? this.adminId,
      orgCode: orgCode ?? this.orgCode,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
