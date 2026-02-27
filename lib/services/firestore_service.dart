import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/offer_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ───────────────────────── RESTAURANTS ─────────────────────────

  /// Get all restaurants
  Stream<List<RestaurantModel>> getRestaurants() {
    return _db
        .collection(FirestoreCollections.restaurants)
        .orderBy('rating', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RestaurantModel.fromMap(d.data())).toList(),
        );
  }

  /// Get restaurant by ID
  Future<RestaurantModel> getRestaurant(String id) async {
    final doc = await _db
        .collection(FirestoreCollections.restaurants)
        .doc(id)
        .get();
    return RestaurantModel.fromMap(doc.data()!);
  }

  /// Get restaurant by owner ID
  Future<RestaurantModel?> getRestaurantByOwner(String ownerId) async {
    final snap = await _db
        .collection(FirestoreCollections.restaurants)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return RestaurantModel.fromMap(snap.docs.first.data());
  }

  /// Create or update restaurant
  Future<void> saveRestaurant(RestaurantModel restaurant) async {
    await _db
        .collection(FirestoreCollections.restaurants)
        .doc(restaurant.id)
        .set(restaurant.toMap());
  }

  /// Update restaurant fields
  Future<void> updateRestaurantFields(
    String id,
    Map<String, dynamic> fields,
  ) async {
    await _db
        .collection(FirestoreCollections.restaurants)
        .doc(id)
        .update(fields);
  }

  /// Add or update a rating to a restaurant (Atomic update)
  Future<void> addRestaurantRating(
    String userId,
    String restaurantId,
    double rating,
  ) async {
    final restaurantRef = _db
        .collection(FirestoreCollections.restaurants)
        .doc(restaurantId);
    final ratingId = '${userId}_$restaurantId';
    final ratingRef = _db
        .collection(FirestoreCollections.ratings)
        .doc(ratingId);

    await _db.runTransaction((transaction) async {
      final restaurantSnap = await transaction.get(restaurantRef);
      if (!restaurantSnap.exists) {
        throw Exception("Restaurant does not exist!");
      }

      final ratingSnap = await transaction.get(ratingRef);
      final restaurantData = restaurantSnap.data()!;
      final double currentRating =
          (restaurantData['rating'] as num?)?.toDouble() ?? 0.0;
      final int totalRatings =
          (restaurantData['totalRatings'] as num?)?.toInt() ?? 0;

      double newRating;
      int newTotal;

      if (ratingSnap.exists) {
        // Update existing rating
        final double oldRatingValue = (ratingSnap.data()!['rating'] as num)
            .toDouble();
        newTotal = totalRatings;
        // Calculation: ((Sum - oldRating) + newRating) / total
        final currentSum = currentRating * totalRatings;
        newRating = (currentSum - oldRatingValue + rating) / newTotal;
      } else {
        // Add new rating
        newTotal = totalRatings + 1;
        newRating = ((currentRating * totalRatings) + rating) / newTotal;
      }

      transaction.update(restaurantRef, {
        'rating': newRating,
        'totalRatings': newTotal,
      });

      transaction.set(ratingRef, {
        'userId': userId,
        'restaurantId': restaurantId,
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ───────────────────────── MENU ITEMS ─────────────────────────

  /// Get menu items for a restaurant
  Stream<List<MenuItemModel>> getMenuItems(String restaurantId) {
    return _db
        .collection(FirestoreCollections.menuItems)
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => MenuItemModel.fromMap(d.data())).toList(),
        );
  }

  /// Get featured menu items (random/top rated)
  Future<List<MenuItemModel>> getFeaturedMenuItems({int limit = 50}) async {
    final snap = await _db
        .collection(FirestoreCollections.menuItems)
        .limit(limit)
        .get();
    return snap.docs.map((d) => MenuItemModel.fromMap(d.data())).toList();
  }

  /// Search menu items (prefix search)
  Future<List<MenuItemModel>> searchMenuItems(String query) async {
    if (query.isEmpty) return [];

    final end = '$query\uf8ff';
    final snap = await _db
        .collection(FirestoreCollections.menuItems)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: end)
        .limit(20)
        .get();

    return snap.docs.map((d) => MenuItemModel.fromMap(d.data())).toList();
  }

  /// Fetch all menu items for client-side search
  Future<List<MenuItemModel>> getAllMenuItems() async {
    final snap = await _db
        .collection(FirestoreCollections.menuItems)
        .limit(500)
        .get();
    return snap.docs.map((d) => MenuItemModel.fromMap(d.data())).toList();
  }

  /// Create or update menu item
  Future<void> saveMenuItem(MenuItemModel item) async {
    await _db
        .collection(FirestoreCollections.menuItems)
        .doc(item.id)
        .set(item.toMap());
  }

  /// Delete menu item
  Future<void> deleteMenuItem(String id) async {
    await _db.collection(FirestoreCollections.menuItems).doc(id).delete();
  }

  /// Get multiple menu items by their IDs
  Future<List<MenuItemModel>> getMenuItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    // Firestore whereIn has a limit of 30 items
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }

    final allItems = <MenuItemModel>[];
    for (final chunk in chunks) {
      final snap = await _db
          .collection(FirestoreCollections.menuItems)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      allItems.addAll(
        snap.docs.map((d) => MenuItemModel.fromMap(d.data())).toList(),
      );
    }

    return allItems;
  }

  // ───────────────────────── ORDERS ─────────────────────────

  /// Place a new order
  Future<void> placeOrder(OrderModel order) async {
    await _db
        .collection(FirestoreCollections.orders)
        .doc(order.id)
        .set(order.toMap());
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection(FirestoreCollections.orders).doc(orderId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Assign driver to order using a Firestore Transaction.
  /// Returns `true` if this driver successfully claimed the order,
  /// `false` if another driver already claimed it (race-condition safe).
  Future<bool> assignDriver(
    String orderId,
    String driverId,
    String driverName,
    String? driverPhone,
  ) async {
    final docRef = _db.collection(FirestoreCollections.orders).doc(orderId);
    return _db.runTransaction<bool>((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return false;
      final data = snap.data()!;
      // Already claimed by another driver → abort
      if (data['driverId'] != null) return false;
      txn.update(docRef, {
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'status': OrderStatus.pickedUp,
        'updatedAt': Timestamp.now(),
      });
      return true;
    });
  }

  /// Update driver location on an order
  Future<void> updateDriverLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    await _db.collection(FirestoreCollections.orders).doc(orderId).update({
      'driverLatitude': lat,
      'driverLongitude': lng,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Soft delete an order (hide from customer)
  Future<void> deleteOrder(String orderId) async {
    await _db.collection(FirestoreCollections.orders).doc(orderId).update({
      'hiddenByCustomer': true,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Stream orders for a customer
  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _db
        .collection(FirestoreCollections.orders)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
          final orders = snap.docs
              .map((d) {
                final map = d.data();
                if (!map.containsKey('id')) map['id'] = d.id;
                return OrderModel.fromMap(map);
              })
              .where((o) => !o.hiddenByCustomer)
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  /// Stream orders for a restaurant
  Stream<List<OrderModel>> getRestaurantOrders(String restaurantId) {
    return _db
        .collection(FirestoreCollections.orders)
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => OrderModel.fromMap(d.data())).toList(),
        );
  }

  /// Stream available orders for drivers (status = 'ready')
  Stream<List<OrderModel>> getAvailableOrdersForDriver() {
    return _db
        .collection(FirestoreCollections.orders)
        .where('status', isEqualTo: OrderStatus.ready)
        .where('driverId', isNull: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => OrderModel.fromMap(d.data())).toList(),
        );
  }

  /// Stream active orders for a driver
  Stream<List<OrderModel>> getDriverActiveOrders(String driverId) {
    return _db
        .collection(FirestoreCollections.orders)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [OrderStatus.pickedUp])
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => OrderModel.fromMap(d.data())).toList(),
        );
  }

  /// Stream delivered orders for a driver (for earnings/history)
  Stream<List<OrderModel>> getDriverDeliveredOrders(String driverId) {
    return _db
        .collection(FirestoreCollections.orders)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: OrderStatus.delivered)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => OrderModel.fromMap(d.data())).toList(),
        );
  }

  /// Stream a single order
  Stream<OrderModel> getOrderStream(String orderId) {
    return _db
        .collection(FirestoreCollections.orders)
        .doc(orderId)
        .snapshots()
        .map((doc) => OrderModel.fromMap(doc.data()!));
  }

  // ───────────────────────── DRIVERS ─────────────────────────

  /// Update driver status
  Future<void> updateDriverStatus(String uid, String status) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'driverStatus': status,
    });
  }

  /// Update driver current order
  Future<void> updateDriverCurrentOrder(String uid, String? orderId) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'currentOrderId': orderId,
    });
  }

  /// Update driver location in user profile
  Future<void> updateUserLocation(String uid, double lat, double lng) async {
    await _db.collection(FirestoreCollections.users).doc(uid).update({
      'latitude': lat,
      'longitude': lng,
    });
  }

  /// Stream all online idle drivers (for top-5 routing)
  Stream<List<Map<String, dynamic>>> getOnlineIdleDrivers() {
    return _db
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'driver')
        .where('driverStatus', isEqualTo: DriverStatus.online)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // ───────────────────────── OFFERS ─────────────────────────

  /// Save an offer (create or update)
  Future<void> saveOffer(OfferModel offer) async {
    await _db
        .collection(FirestoreCollections.offers)
        .doc(offer.id)
        .set(offer.toMap());
  }

  /// Delete an offer
  Future<void> deleteOffer(String id) async {
    await _db.collection(FirestoreCollections.offers).doc(id).delete();
  }

  /// Stream offers for a restaurant
  Stream<List<OfferModel>> getOffers(String restaurantId) {
    return _db
        .collection(FirestoreCollections.offers)
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snap) {
          final docs = snap.docs
              .map((d) => OfferModel.fromMap(d.data()))
              .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  /// Stream ALL active offers from all restaurants
  Stream<List<OfferModel>> getAllOffers() {
    return _db
        .collection(FirestoreCollections.offers)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final docs = snap.docs
              .map((d) => OfferModel.fromMap(d.data()))
              .toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }
}
