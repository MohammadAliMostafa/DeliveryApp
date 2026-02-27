import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

class OrderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<OrderModel> _orders = [];
  OrderModel? _activeOrder;
  bool _isLoading = false;
  StreamSubscription? _ordersSub;
  StreamSubscription? _activeOrderSub;

  String? _errorMessage;

  List<OrderModel> get orders => _orders;
  OrderModel? get activeOrder => _activeOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Listen to customer orders
  void listenToCustomerOrders(String customerId) {
    _ordersSub?.cancel();
    _errorMessage = null;
    notifyListeners();

    _ordersSub = _firestoreService
        .getCustomerOrders(customerId)
        .listen(
          (orders) {
            _orders = orders;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading customer orders: $e');
            _errorMessage = e.toString();
            _orders = [];
            notifyListeners();
          },
        );
  }

  /// Listen to restaurant orders
  void listenToRestaurantOrders(String restaurantId) {
    _ordersSub?.cancel();
    _ordersSub = _firestoreService
        .getRestaurantOrders(restaurantId)
        .listen(
          (orders) {
            _orders = orders;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading restaurant orders: $e');
            _orders = [];
            notifyListeners();
          },
        );
  }

  /// Listen to a single order (for tracking)
  void listenToOrder(String orderId) {
    _activeOrderSub?.cancel();
    _activeOrderSub = _firestoreService
        .getOrderStream(orderId)
        .listen(
          (order) {
            _activeOrder = order;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading active order: $e');
            _activeOrder = null;
            notifyListeners();
          },
        );
  }

  /// Place a new order
  Future<void> placeOrder(OrderModel order) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.placeOrder(order);
      _activeOrder = order;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update order status
  Future<void> updateStatus(String orderId, String status) async {
    await _firestoreService.updateOrderStatus(orderId, status);
  }

  /// Cancel order
  Future<void> cancelOrder(String orderId) async {
    await updateStatus(orderId, 'cancelled');
  }

  /// Assign driver (transaction-safe, returns false if already claimed)
  Future<bool> assignDriver(
    String orderId,
    String driverId,
    String driverName,
    String? driverPhone,
  ) async {
    return await _firestoreService.assignDriver(
      orderId,
      driverId,
      driverName,
      driverPhone,
    );
  }

  /// Delete multiple orders
  Future<void> deleteOrders(List<String> orderIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      for (final id in orderIds) {
        await _firestoreService.deleteOrder(id);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearActiveOrder() {
    _activeOrderSub?.cancel();
    _activeOrder = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _activeOrderSub?.cancel();
    super.dispose();
  }
}
