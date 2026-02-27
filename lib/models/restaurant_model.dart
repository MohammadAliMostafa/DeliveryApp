import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String imageUrl;
  final String iconUrl;
  final double rating;
  final int totalRatings;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final bool isOpen;
  final List<String> categories;
  final String openTime;
  final String closeTime;
  final int estimatedDeliveryMin;
  final DateTime createdAt;

  RestaurantModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.iconUrl = '',
    this.rating = 0.0,
    this.totalRatings = 0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.address = '',
    this.phone = '',
    this.isOpen = true,
    this.categories = const [],
    this.openTime = '08:00',
    this.closeTime = '22:00',
    this.estimatedDeliveryMin = 30,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'iconUrl': iconUrl,
      'rating': rating,
      'totalRatings': totalRatings,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'isOpen': isOpen,
      'categories': categories,
      'openTime': openTime,
      'closeTime': closeTime,
      'estimatedDeliveryMin': estimatedDeliveryMin,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> map) {
    return RestaurantModel(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      iconUrl: map['iconUrl'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: map['totalRatings'] ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      isOpen: map['isOpen'] ?? true,
      categories: List<String>.from(map['categories'] ?? []),
      openTime: map['openTime'] ?? '08:00',
      closeTime: map['closeTime'] ?? '22:00',
      estimatedDeliveryMin: map['estimatedDeliveryMin'] ?? 30,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  RestaurantModel copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? iconUrl,
    double? rating,
    int? totalRatings,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    bool? isOpen,
    List<String>? categories,
    String? openTime,
    String? closeTime,
    int? estimatedDeliveryMin,
  }) {
    return RestaurantModel(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isOpen: isOpen ?? this.isOpen,
      categories: categories ?? this.categories,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      estimatedDeliveryMin: estimatedDeliveryMin ?? this.estimatedDeliveryMin,
      createdAt: createdAt,
    );
  }
}
