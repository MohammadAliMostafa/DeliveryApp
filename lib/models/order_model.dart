import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String menuItemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? specialInstructions;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl = '',
    this.specialInstructions,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'specialInstructions': specialInstructions,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      menuItemId: map['menuItemId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] ?? 1,
      imageUrl: map['imageUrl'] ?? '',
      specialInstructions: map['specialInstructions'],
    );
  }

  CartItem copyWith({int? quantity, String? specialInstructions}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String restaurantId;
  final String restaurantName;
  final String? restaurantPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String status;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String deliveryAddress;
  final double? driverLatitude;
  final double? driverLongitude;
  final bool hiddenByCustomer;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.status = 'placed',
    required this.items,
    required this.subtotal,
    this.deliveryFee = 2.99,
    required this.total,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAddress = '',
    this.driverLatitude,
    this.driverLongitude,
    this.hiddenByCustomer = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantPhone': restaurantPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'status': status,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryAddress': deliveryAddress,
      'driverLatitude': driverLatitude,
      'driverLongitude': driverLongitude,
      'hiddenByCustomer': hiddenByCustomer,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'],
      restaurantId: map['restaurantId'] ?? '',
      restaurantName: map['restaurantName'] ?? '',
      restaurantPhone: map['restaurantPhone'],
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      status: map['status'] ?? 'placed',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => CartItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      deliveryLatitude: (map['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (map['deliveryLongitude'] as num?)?.toDouble(),
      deliveryAddress: map['deliveryAddress'] ?? '',
      driverLatitude: (map['driverLatitude'] as num?)?.toDouble(),
      driverLongitude: (map['driverLongitude'] as num?)?.toDouble(),
      hiddenByCustomer: map['hiddenByCustomer'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  OrderModel copyWith({
    String? driverId,
    String? driverName,
    String? status,
    double? driverLatitude,
    double? driverLongitude,
    bool? hiddenByCustomer,
    DateTime? updatedAt,
    double? deliveryFee,
    double? total,
  }) {
    return OrderModel(
      id: id,
      customerId: customerId,
      customerName: customerName,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      status: status ?? this.status,
      items: items,
      subtotal: subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryAddress: deliveryAddress,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      hiddenByCustomer: hiddenByCustomer ?? this.hiddenByCustomer,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
