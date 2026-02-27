import 'dart:async';
import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../models/offer_model.dart';
import '../services/firestore_service.dart';

class RestaurantProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<RestaurantModel> _restaurants = [];
  List<MenuItemModel> _menuItems = [];
  List<MenuItemModel> _featuredItems = [];
  RestaurantModel? _selectedRestaurant;
  RestaurantModel? _ownedRestaurant; // For restaurant owners
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  StreamSubscription? _restaurantsSub;
  StreamSubscription? _menuSub;

  List<RestaurantModel> get restaurants {
    var list = _restaurants;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    if (_selectedCategory != 'All') {
      list = list
          .where((r) => r.categories.contains(_selectedCategory))
          .toList();
    }
    return list;
  }

  List<MenuItemModel> get menuItems => _menuItems;
  List<MenuItemModel> get featuredItems => _featuredItems;
  RestaurantModel? get selectedRestaurant => _selectedRestaurant;
  RestaurantModel? get ownedRestaurant => _ownedRestaurant;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get allCategories {
    final cats = <String>{'All'};
    for (final r in _restaurants) {
      cats.addAll(r.categories);
    }
    return cats.toList();
  }

  /// Start listening to all restaurants
  void listenToRestaurants() {
    _restaurantsSub?.cancel();
    _restaurantsSub = _firestoreService.getRestaurants().listen(
      (list) {
        _restaurants = list;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error loading restaurants: $e');
        _restaurants = [];
        notifyListeners();
      },
    );
  }

  Future<void> loadFeaturedItems() async {
    try {
      _featuredItems = await _firestoreService.getFeaturedMenuItems();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading featured items: $e');
    }
  }

  /// Select a restaurant & load its menu
  void selectRestaurant(RestaurantModel restaurant) {
    _selectedRestaurant = restaurant;
    _loadMenu(restaurant.id);
    notifyListeners();
  }

  /// Load menu for restaurant owner
  Future<void> loadOwnedRestaurant(String ownerId) async {
    _isLoading = true;
    notifyListeners();

    _ownedRestaurant = await _firestoreService.getRestaurantByOwner(ownerId);
    if (_ownedRestaurant != null) {
      _loadMenu(_ownedRestaurant!.id);
    }

    _isLoading = false;
    notifyListeners();
  }

  void _loadMenu(String restaurantId) {
    _menuSub?.cancel();
    _menuSub = _firestoreService.getMenuItems(restaurantId).listen((items) {
      _menuItems = items;
      notifyListeners();
    });
  }

  /// Save a restaurant (create or update)
  Future<void> saveRestaurant(RestaurantModel restaurant) async {
    await _firestoreService.saveRestaurant(restaurant);
    _ownedRestaurant = restaurant;
    notifyListeners();
  }

  /// Save a menu item
  Future<void> saveMenuItem(MenuItemModel item) async {
    await _firestoreService.saveMenuItem(item);
  }

  /// Delete a menu item
  Future<void> deleteMenuItem(String id) async {
    await _firestoreService.deleteMenuItem(id);
  }

  /// Update specific fields on a restaurant (e.g. iconUrl, imageUrl)
  Future<void> updateRestaurantField(
    String restaurantId,
    Map<String, dynamic> fields,
  ) async {
    await _firestoreService.updateRestaurantFields(restaurantId, fields);
    // Refresh owned restaurant locally
    if (_ownedRestaurant != null && _ownedRestaurant!.id == restaurantId) {
      final updated = await _firestoreService.getRestaurant(restaurantId);
      _ownedRestaurant = updated;
      notifyListeners();
    }
  }

  /// Rate a restaurant
  Future<void> rateRestaurant(
    String userId,
    String restaurantId,
    double rating,
  ) async {
    await _firestoreService.addRestaurantRating(userId, restaurantId, rating);
    // Optionally refresh the restaurant data locally
    // For now, the stream listing all restaurants might update,
    // but the selected restaurant is an object.
    // If we are listening to a stream of the specific restaurant, it would update.
    // But we are passing 'restaurant' object to the screen.
    // We might want to reload the selected restaurant.
    final updated = await _firestoreService.getRestaurant(restaurantId);
    _selectedRestaurant = updated;
    notifyListeners();
  }

  /// Update search
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update category filter
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  List<MenuItemModel> _favoriteDishes = [];
  List<OfferModel> _offers = []; // Owned restaurant offers
  List<OfferModel> _allOffers = []; // Global active offers
  StreamSubscription? _offersSub;
  StreamSubscription? _allOffersSub;

  List<MenuItemModel> get favoriteDishes => _favoriteDishes;
  List<OfferModel> get offers => _offers;
  List<OfferModel> get allOffers => _allOffers;

  void listenToOffers(String restaurantId) {
    _offersSub?.cancel();
    _offersSub = _firestoreService
        .getOffers(restaurantId)
        .listen(
          (list) {
            _offers = list;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error loading restaurant offers: $e');
            _offers = [];
            notifyListeners();
          },
        );
  }

  void listenToAllOffers() {
    _allOffersSub?.cancel();
    _allOffersSub = _firestoreService.getAllOffers().listen(
      (list) {
        _allOffers = list;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error loading all offers: $e');
        _allOffers = [];
        notifyListeners();
      },
    );
  }

  Future<void> saveOffer(OfferModel offer) async {
    await _firestoreService.saveOffer(offer);
  }

  Future<void> deleteOffer(String id) async {
    await _firestoreService.deleteOffer(id);
  }

  Future<void> loadFavoriteDishes(List<String> ids) async {
    if (ids.isEmpty) {
      _favoriteDishes = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      _favoriteDishes = await _firestoreService.getMenuItemsByIds(ids);
    } catch (e) {
      debugPrint('Error loading favorite dishes: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSelection() {
    _selectedRestaurant = null;
    _menuItems = [];
    _menuSub?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _restaurantsSub?.cancel();
    _menuSub?.cancel();
    _offersSub?.cancel();
    _allOffersSub?.cancel();
    super.dispose();
  }
}
