import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'customer' | 'driver' | 'restaurant'
  final String phone;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? profileImageUrl;
  final String? driverStatus; // 'idle' | 'pickingUp' | 'delivering'
  final String? currentOrderId; // For drivers — active delivery
  final List<String> favoriteRestaurantIds;
  final List<String> favoriteMenuItemIds;
  final List<String> favoriteOfferIds;
  final bool isDisabled;
  final bool isApproved;
  final String? fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.latitude,
    this.longitude,
    this.address,
    this.profileImageUrl,
    this.driverStatus,
    this.currentOrderId,
    this.favoriteRestaurantIds = const [],
    this.favoriteMenuItemIds = const [],
    this.favoriteOfferIds = const [],
    this.isDisabled = false,
    this.isApproved = true,
    this.fcmToken,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'driverStatus': driverStatus,
      'currentOrderId': currentOrderId,
      'favoriteRestaurantIds': favoriteRestaurantIds,
      'favoriteMenuItemIds': favoriteMenuItemIds,
      'favoriteOfferIds': favoriteOfferIds,
      'isDisabled': isDisabled,
      'isApproved': isApproved,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'customer',
      phone: map['phone'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'],
      profileImageUrl: map['profileImageUrl'],
      driverStatus: map['driverStatus'],
      currentOrderId: map['currentOrderId'],
      favoriteRestaurantIds: List<String>.from(
        map['favoriteRestaurantIds'] ?? [],
      ),
      favoriteMenuItemIds: List<String>.from(map['favoriteMenuItemIds'] ?? []),
      favoriteOfferIds: List<String>.from(map['favoriteOfferIds'] ?? []),
      isDisabled: map['isDisabled'] ?? false,
      isApproved: map['isApproved'] ?? true,
      fcmToken: map['fcmToken'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? name,
    String? phone,
    double? latitude,
    double? longitude,
    String? address,
    String? profileImageUrl,
    String? driverStatus,
    String? currentOrderId,
    List<String>? favoriteRestaurantIds,
    List<String>? favoriteMenuItemIds,
    List<String>? favoriteOfferIds,
    bool? isDisabled,
    bool? isApproved,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      driverStatus: driverStatus ?? this.driverStatus,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      favoriteRestaurantIds:
          favoriteRestaurantIds ?? this.favoriteRestaurantIds,
      favoriteMenuItemIds: favoriteMenuItemIds ?? this.favoriteMenuItemIds,
      favoriteOfferIds: favoriteOfferIds ?? this.favoriteOfferIds,
      isDisabled: isDisabled ?? this.isDisabled,
      isApproved: isApproved ?? this.isApproved,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
