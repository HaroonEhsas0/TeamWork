import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'
  final String? photoUrl;
  final String? phoneNumber;
  final String? organizationCode;
  final bool isConnected;
  final DateTime createdAt;
  final Map<String, dynamic>? settings;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    this.phoneNumber,
    this.organizationCode,
    this.isConnected = false,
    required this.createdAt,
    this.settings,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'user',
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      organizationCode: data['organizationCode'],
      isConnected: data['isConnected'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: data['settings'],
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      organizationCode: map['organizationCode'],
      isConnected: map['isConnected'] ?? false,
      createdAt: map['createdAt'] != null 
        ? (map['createdAt'] is DateTime 
            ? map['createdAt'] 
            : DateTime.parse(map['createdAt']))
        : DateTime.now(),
      settings: map['settings'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'organizationCode': organizationCode,
      'isConnected': isConnected,
      'createdAt': createdAt,
      'settings': settings,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? photoUrl,
    String? phoneNumber,
    String? organizationCode,
    bool? isConnected,
    DateTime? createdAt,
    Map<String, dynamic>? settings,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      organizationCode: organizationCode ?? this.organizationCode,
      isConnected: isConnected ?? this.isConnected,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
    );
  }
}
