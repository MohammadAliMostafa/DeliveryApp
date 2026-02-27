import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_item_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import 'restaurant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedFilter = 'All'; // All, Restaurants, Dishes
  List<RestaurantModel> _restaurantResults = [];
  List<MenuItemModel> _dishResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns true if every word in [queryWords] appears somewhere in [text].
  bool _matchesAllWords(String text, List<String> queryWords) {
    final lowerText = text.toLowerCase();
    return queryWords.every((word) => lowerText.contains(word));
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _restaurantResults = [];
        _dishResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Split query into individual words for order-independent matching
      final queryWords = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      // 1. Search Restaurants — match if every query word appears in name or any category
      final allRestaurants = context.read<RestaurantProvider>().restaurants;

      final restaurants = allRestaurants.where((r) {
        final combined = '${r.name} ${r.categories.join(' ')}'.toLowerCase();
        return queryWords.every((word) => combined.contains(word));
      }).toList();

      // 2. Search Dishes — fetch all items and filter client-side for full
      //    word-order-independent matching (e.g. "zinger" matches "Crunchy Zinger")
      final allDishes = await _firestoreService.getAllMenuItems();
      final dishes = allDishes
          .where((d) => _matchesAllWords(d.name, queryWords))
          .toList();

      if (mounted) {
        setState(() {
          _restaurantResults = restaurants;
          _dishResults = dishes;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search for stores or dishes',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AppColors.textHint),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (value) {
                        // Debounce could be added here
                        _performSearch(value);
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textHint),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    ),
                ],
              ),
            ),

            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Restaurants',
                    isSelected: _selectedFilter == 'Restaurants',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Restaurants'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Dishes',
                    isSelected: _selectedFilter == 'Dishes',
                    onTap: () => setState(() => _selectedFilter = 'Dishes'),
                  ),
                ],
              ),
            ),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Search for your favorite food',
              style: TextStyle(color: AppColors.textHint, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final showRestaurants =
        _selectedFilter == 'All' || _selectedFilter == 'Restaurants';
    final showDishes = _selectedFilter == 'All' || _selectedFilter == 'Dishes';

    if (_restaurantResults.isEmpty && _dishResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: AppColors.textHint, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (showRestaurants && _restaurantResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Restaurants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._restaurantResults.map(
            (r) => _RestaurantSearchResult(restaurant: r),
          ),
        ],

        if (showDishes && _dishResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Dishes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._dishResults.map((item) => _DishSearchResult(item: item)),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _RestaurantSearchResult extends StatelessWidget {
  final RestaurantModel restaurant;

  const _RestaurantSearchResult({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isFavorite =
        auth.user?.favoriteRestaurantIds.contains(restaurant.id) ?? false;

    return GestureDetector(
      onTap: () {
        context.read<RestaurantProvider>().selectRestaurant(restaurant);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantDetailScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: restaurant.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: restaurant.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.store,
                            color: AppColors.textHint,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => auth.toggleFavoriteRestaurant(restaurant.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.primary : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${restaurant.categories.join(', ')} • ${restaurant.rating.toStringAsFixed(2)} ★',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishSearchResult extends StatelessWidget {
  final MenuItemModel item;

  const _DishSearchResult({required this.item});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isFavorite =
        auth.user?.favoriteMenuItemIds.contains(item.id) ?? false;

    // We need to find the restaurant to navigate to it, or at least show its name?
    // The MenuItemModel has restaurantId. Use it to find the restaurant name from provider if possible.
    final restaurants = context.read<RestaurantProvider>().restaurants;
    final restaurant = restaurants.firstWhere(
      (r) => r.id == item.restaurantId,
      orElse: () => RestaurantModel(
        id: '',
        name: 'Unknown Restaurant',
        ownerId: '',
        categories: [],
        rating: 0,
        totalRatings: 0,
        estimatedDeliveryMin: 0,
        imageUrl: '',
        address: '',
        latitude: 0,
        longitude: 0,
      ),
    );

    return GestureDetector(
      onTap: () {
        if (restaurant.id.isNotEmpty) {
          context.read<RestaurantProvider>().selectRestaurant(restaurant);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantDetailScreen()),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.fastfood,
                            color: AppColors.textHint,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => auth.toggleFavoriteMenuItem(item.id),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.primary : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${restaurant.name} • ${Helpers.formatPrice(item.price)}${item.prepTime != null ? ' • ${item.prepTime} min' : ''}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
