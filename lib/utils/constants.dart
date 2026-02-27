// Collection names
class FirestoreCollections {
  static const String users = 'users';
  static const String restaurants = 'restaurants';
  static const String menuItems = 'menu_items';
  static const String orders = 'orders';
  static const String offers = 'offers';
  static const String ratings = 'ratings';
}

// User roles
class UserRoles {
  static const String customer = 'customer';
  static const String driver = 'driver';
  static const String restaurant = 'restaurant';
}

// Order statuses
class OrderStatus {
  static const String placed = 'placed';
  static const String accepted = 'accepted';
  static const String preparing = 'preparing';
  static const String ready = 'ready';
  static const String pickedUp = 'pickedUp';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';

  static List<String> get allStatuses => [
    placed,
    accepted,
    preparing,
    ready,
    pickedUp,
    delivered,
    cancelled,
  ];

  static String displayName(String status) {
    switch (status) {
      case placed:
        return 'Order Placed';
      case accepted:
        return 'Accepted';
      case preparing:
        return 'Preparing';
      case ready:
        return 'Ready for Pickup';
      case pickedUp:
        return 'Picked Up';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

// Driver statuses
class DriverStatus {
  static const String idle = 'idle'; // offline
  static const String online = 'online'; // online, waiting for orders
  static const String pickingUp = 'pickingUp';
  static const String delivering = 'delivering';
}

// App defaults
class AppDefaults {
  static const double deliveryFee = 2.99;
  static const double serviceFee = 1.50;
  static const int defaultDeliveryTimeMin = 30;
  static const String currency = '\$';
}

// Google Maps configuration
class GoogleMapsConfig {
  // This key is used for server-side API calls (Directions, Geocoding, Places).
  // The Maps SDK key for Android/iOS/Web is configured in platform-specific files.
  static const String apiKey = 'AIzaSyCk15wm_sF8Fab0ubAcJzgyCqaAVPo_Vo4';
}
