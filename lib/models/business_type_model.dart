import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BusinessTypeModel {
  final String id; // e.g. 'restaurant', 'supermarket'
  final String displayName; // e.g. 'Restaurants', 'Supermarkets'
  final String icon; // Material icon name string
  final int sortOrder; // Display order on home screen
  final bool isActive;
  final int? color; // Stored as ARGB int, e.g. 0xFFFF6B35
  final DateTime createdAt;

  BusinessTypeModel({
    required this.id,
    required this.displayName,
    this.icon = 'store',
    this.sortOrder = 0,
    this.isActive = true,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns the admin-set color, or falls back to the primary app color
  Color get cardColor =>
      color != null ? Color(color!) : const Color(0xFFE53935);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BusinessTypeModel.fromMap(Map<String, dynamic> map) {
    return BusinessTypeModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      icon: map['icon'] ?? 'store',
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      color: map['color'] as int?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  BusinessTypeModel copyWith({
    String? displayName,
    String? icon,
    int? sortOrder,
    bool? isActive,
    int? color,
  }) {
    return BusinessTypeModel(
      id: id,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  /// Map icon name strings to Material Icons
  IconData get iconData {
    switch (icon) {
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'coffee':
        return Icons.coffee;
      case 'liquor':
        return Icons.liquor;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.store;
    }
  }
}
