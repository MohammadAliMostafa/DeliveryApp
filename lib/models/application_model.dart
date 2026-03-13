import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String requestedRole; // 'driver' or 'restaurant'
  final String status; // 'pending', 'approved', 'rejected'
  final Map<String, dynamic> formData;
  final DateTime createdAt;

  ApplicationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.requestedRole,
    required this.status,
    required this.formData,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'requestedRole': requestedRole,
      'status': status,
      'formData': formData,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    return ApplicationModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userPhone: map['userPhone'] ?? '',
      requestedRole: map['requestedRole'] ?? '',
      status: map['status'] ?? 'pending',
      formData: Map<String, dynamic>.from(map['formData'] ?? {}),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  ApplicationModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? requestedRole,
    String? status,
    Map<String, dynamic>? formData,
    DateTime? createdAt,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      requestedRole: requestedRole ?? this.requestedRole,
      status: status ?? this.status,
      formData: formData ?? this.formData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
