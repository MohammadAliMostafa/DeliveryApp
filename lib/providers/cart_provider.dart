import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/menu_item_model.dart';
import '../models/offer_model.dart';
import '../utils/constants.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _restaurantId;
  String? _restaurantName;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get restaurantId => _restaurantId;
  String? get restaurantName => _restaurantName;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => _items.isEmpty ? 0 : AppDefaults.deliveryFee;
  double get total => subtotal + deliveryFee;

  /// Add item to cart. Clears cart if different restaurant.
  void addItem(
    MenuItemModel menuItem,
    String restaurantId,
    String restaurantName,
  ) {
    // If switching restaurants, clear the cart
    if (_restaurantId != null && _restaurantId != restaurantId) {
      _items.clear();
    }

    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final existing = _items.indexWhere(
      (item) => item.menuItemId == menuItem.id,
    );

    if (existing >= 0) {
      _items[existing] = _items[existing].copyWith(
        quantity: _items[existing].quantity + 1,
      );
    } else {
      _items.add(
        CartItem(
          menuItemId: menuItem.id,
          name: menuItem.name,
          price: menuItem.hasDiscount
              ? menuItem.discountedPrice
              : menuItem.price,
          imageUrl: menuItem.imageUrl,
        ),
      );
    }

    notifyListeners();
  }

  /// Add offer to cart
  void addOffer(
    OfferModel offer,
    List<MenuItemModel> includedItems,
    String restaurantId,
    String restaurantName,
  ) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      _items.clear();
    }

    _restaurantId = restaurantId;
    _restaurantName = restaurantName;

    final existing = _items.indexWhere((item) => item.menuItemId == offer.id);

    if (existing >= 0) {
      _items[existing] = _items[existing].copyWith(
        quantity: _items[existing].quantity + 1,
      );
    } else {
      final description = includedItems.map((i) => i.name).join(', ');
      _items.add(
        CartItem(
          menuItemId: offer.id,
          name: offer.title,
          price: offer.bundlePrice,
          imageUrl: offer.imageUrl,
          specialInstructions: description.isNotEmpty
              ? 'Includes: $description'
              : null,
        ),
      );
    }
    notifyListeners();
  }

  /// Remove one quantity of an item
  void decrementItem(String menuItemId) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index < 0) return;

    if (_items[index].quantity > 1) {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity - 1,
      );
    } else {
      _items.removeAt(index);
    }

    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }

    notifyListeners();
  }

  /// Remove item entirely
  void removeItem(String menuItemId) {
    _items.removeWhere((item) => item.menuItemId == menuItemId);
    if (_items.isEmpty) {
      _restaurantId = null;
      _restaurantName = null;
    }
    notifyListeners();
  }

  /// Update special instructions
  void updateInstructions(String menuItemId, String instructions) {
    final index = _items.indexWhere((item) => item.menuItemId == menuItemId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(specialInstructions: instructions);
      notifyListeners();
    }
  }

  /// Clear the cart
  void clearCart() {
    _items.clear();
    _restaurantId = null;
    _restaurantName = null;
    notifyListeners();
  }
}
