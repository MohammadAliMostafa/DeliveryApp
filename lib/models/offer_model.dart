import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String restaurantId;
  final String title;
  final String description;
  final List<String> itemNames;
  final List<String> itemIds;
  final double bundlePrice;
  final double originalPrice; // Sum of individual item prices before discount
  final String imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final int? color;

  OfferModel({
    required this.id,
    required this.restaurantId,
    required this.title,
    this.description = '',
    this.itemIds = const [],
    this.itemNames = const [],
    this.bundlePrice = 0.0,
    this.originalPrice = 0.0,
    this.imageUrl = '',
    this.isActive = true,
    DateTime? createdAt,
    this.color,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasDiscount => originalPrice > 0 && originalPrice > bundlePrice;
  int get discountPercentage => hasDiscount
      ? ((originalPrice - bundlePrice) / originalPrice * 100).round()
      : 0;
  double get savedAmount => hasDiscount ? originalPrice - bundlePrice : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'title': title,
      'description': description,
      'itemIds': itemIds,
      'itemNames': itemNames,
      'bundlePrice': bundlePrice,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'color': color,
    };
  }

  factory OfferModel.fromMap(Map<String, dynamic> map) {
    return OfferModel(
      id: map['id'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      itemIds: List<String>.from(map['itemIds'] ?? []),
      itemNames: List<String>.from(map['itemNames'] ?? []),
      bundlePrice: (map['bundlePrice'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      color: map['color'] != null ? (map['color'] as num).toInt() : null,
    );
  }

  OfferModel copyWith({
    String? title,
    String? description,
    List<String>? itemIds,
    List<String>? itemNames,
    double? bundlePrice,
    double? originalPrice,
    String? imageUrl,
    bool? isActive,
    int? color,
  }) {
    return OfferModel(
      id: id,
      restaurantId: restaurantId,
      title: title ?? this.title,
      description: description ?? this.description,
      itemIds: itemIds ?? this.itemIds,
      itemNames: itemNames ?? this.itemNames,
      bundlePrice: bundlePrice ?? this.bundlePrice,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      color: color ?? this.color,
    );
  }
}
