import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String adminId;
  final String? description;
  final DateTime createdAt;
  final List<String>? memberIds;

  TeamModel({
    required this.id,
    required this.name,
    required this.adminId,
    this.description,
    required this.createdAt,
    this.memberIds,
  });

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TeamModel(
      id: doc.id,
      name: data['name'] ?? '',
      adminId: data['adminId'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberIds: data['memberIds'] != null 
          ? List<String>.from(data['memberIds']) 
          : null,
    );
  }

  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      adminId: map['adminId'] ?? '',
      description: map['description'],
      createdAt: map['createdAt'] != null 
        ? (map['createdAt'] is DateTime 
            ? map['createdAt'] 
            : DateTime.parse(map['createdAt']))
        : DateTime.now(),
      memberIds: map['memberIds'] != null 
          ? List<String>.from(map['memberIds']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'adminId': adminId,
      'description': description,
      'createdAt': createdAt,
      'memberIds': memberIds,
    };
  }

  TeamModel copyWith({
    String? id,
    String? name,
    String? adminId,
    String? description,
    DateTime? createdAt,
    List<String>? memberIds,
  }) {
    return TeamModel(
      id: id ?? this.id,
      name: name ?? this.name,
      adminId: adminId ?? this.adminId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}
