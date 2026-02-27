import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final double discount; // 0.0 to 1.0 (e.g. 0.2 = 20% off)
  final int? prepTime; // Optional preparation time in minutes
  final DateTime createdAt;

  MenuItemModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl = '',
    String category = 'Main',
    this.isAvailable = true,
    this.discount = 0.0,
    this.prepTime, // Null means no prep time defined
    DateTime? createdAt,
  }) : category = _normalizeCategory(category),
       createdAt = createdAt ?? DateTime.now();

  double get discountedPrice => price * (1 - discount);
  bool get hasDiscount => discount > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
      'discount': discount,
      'prepTime': prepTime, // Can be null
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'] ?? '',
      restaurantId: map['restaurantId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
      category: _normalizeCategory(map['category'] as String?),
      isAvailable: map['isAvailable'] ?? true,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      prepTime: (map['prepTime'] as num?)?.toInt(), // Null if missing/null
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  static String _normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Main';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Main';
    // Capitalize the first letter and lowercase the rest, or just capitalize the first letter of each word.
    // simpler approach: Title Case (e.g. "drinks" -> "Drinks")
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  MenuItemModel copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    double? discount,
    int?
    prepTime, // Note: To clear prepTime, you'd need a specific value or just avoid using copyWith to remove it
  }) {
    return MenuItemModel(
      id: id,
      restaurantId: restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category != null ? _normalizeCategory(category) : this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      discount: discount ?? this.discount,
      prepTime: prepTime ?? this.prepTime,
      createdAt: createdAt,
    );
  }
}
