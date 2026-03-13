import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../shared/offers_carousel.dart';
import 'package:geolocator/geolocator.dart';
import '../shared/whats_new_carousel.dart';
import 'restaurant_detail_screen.dart';
import 'store_detail_screen.dart';
import 'all_offers_screen.dart';
import 'fastest_restaurants_screen.dart';
import 'cart_screen.dart';
import 'search_screen.dart';
import '../shared/map_picker_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building CustomerHomeScreen...');
    final auth = context.watch<AuthProvider>();
    final restaurantProv = context.watch<RestaurantProvider>();
    final cartProv = context.watch<CartProvider>();

    // Prepare fastest restaurants (restaurant type only)
    final user = auth.user;
    final restaurantTypeStores = restaurantProv.restaurantsOfType('restaurant');
    final openRestaurants = restaurantTypeStores
        .where((r) => r.isOpen)
        .toList();

    openRestaurants.sort((a, b) {
      double timeA = a.estimatedDeliveryMin.toDouble();
      double timeB = b.estimatedDeliveryMin.toDouble();

      if (user?.latitude != null && user?.longitude != null) {
        if (a.latitude != 0 && a.longitude != 0) {
          final distA = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            a.latitude,
            a.longitude,
          );
          // Assuming roughly 400 meters per minute (24 km/h) for city delivery travel time
          timeA += (distA / 400);
        }
        if (b.latitude != 0 && b.longitude != 0) {
          final distB = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            b.latitude,
            b.longitude,
          );
          timeB += (distB / 400);
        }
      }
      return timeA.compareTo(timeB);
    });

    final fastestRestaurants = openRestaurants.take(8).toList();
    final fastestRestaurantIds = fastestRestaurants.map((r) => r.id).toSet();

    final fastItems = restaurantProv.featuredItems
        .where(
          (item) =>
              fastestRestaurantIds.contains(item.restaurantId) &&
              item.prepTime != null,
        )
        .toList();

    fastItems.sort((a, b) {
      final indexA = fastestRestaurants.indexWhere(
        (r) => r.id == a.restaurantId,
      );
      final indexB = fastestRestaurants.indexWhere(
        (r) => r.id == b.restaurantId,
      );
      return indexA.compareTo(indexB);
    });

    final displayFastItems = fastItems.take(8).toList();

    // Prepare offers
    final restaurantTypeOffers = restaurantProv.allOffers.where((offer) {
      final restaurant = restaurantProv.restaurants.firstWhere(
        (r) => r.id == offer.restaurantId,
        orElse: () => RestaurantModel(
          id: '',
          name: '',
          imageUrl: '',
          rating: 0,
          categories: [],
          ownerId: '',
        ),
      );
      return restaurant.businessType == 'restaurant' &&
          restaurant.id.isNotEmpty;
    }).toList();

    final storeBundles = restaurantProv.allOffers.where((offer) {
      final restaurant = restaurantProv.restaurants.firstWhere(
        (r) => r.id == offer.restaurantId,
        orElse: () => RestaurantModel(
          id: '',
          name: '',
          imageUrl: '',
          rating: 0,
          categories: [],
          ownerId: '',
        ),
      );
      return restaurant.businessType != 'restaurant' &&
          restaurant.id.isNotEmpty;
    }).toList();

    // Prepare What's New items (Articles + Newest Shops interleaved)
    final whatsNewItems = <dynamic>[];
    final articles = restaurantProv.articles.take(5).toList();
    
    // Filter shops added in the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final newShops = restaurantProv.newestRestaurants
        .where((s) => s.createdAt.isAfter(thirtyDaysAgo))
        .take(5)
        .toList();
    
    int aIdx = 0;
    int sIdx = 0;
    while (aIdx < articles.length || sIdx < newShops.length) {
      if (aIdx < articles.length) whatsNewItems.add(articles[aIdx++]);
      if (sIdx < newShops.length) whatsNewItems.add(newShops[sIdx++]);
    }
    final displayWhatsNew = whatsNewItems.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.white, // DoorDash style clean background
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar with Address
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final user = auth.user;
                          final result = await Navigator.push<MapPickerResult>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapPickerScreen(
                                title: 'Delivery Address',
                                initialLatitude: user?.latitude,
                                initialLongitude: user?.longitude,
                                initialAddress: user?.address,
                              ),
                            ),
                          );
                          if (result != null &&
                              user != null &&
                              context.mounted) {
                            auth.updateProfile(
                              user.copyWith(
                                latitude: result.latitude,
                                longitude: result.longitude,
                                address: result.address,
                              ),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deliver to',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  auth.user?.address ?? 'Set Address',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar (Pill Shape)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchBarDelegate(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
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
                        const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchScreen(),
                                ),
                              );
                            },
                            child: Container(
                              color: Colors.transparent, // Hit test
                              height: 48,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Search stores, dishes, products',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Brands / Categories (all store types)
            if (restaurantProv.restaurants.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Text(
                        'Brands',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: restaurantProv.restaurants.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final restaurant = restaurantProv.restaurants[index];
                          return _BrandItem(
                            restaurant: restaurant,
                            onTap: () {
                              restaurantProv.selectRestaurant(restaurant);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      restaurant.businessType == 'restaurant'
                                      ? const RestaurantDetailScreen()
                                      : const StoreDetailScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // What's New Carousel
            if (displayWhatsNew.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: WhatsNewCarousel(items: displayWhatsNew),
                ),
              ),

            // Featured Items (Fastest Near You)
            if (displayFastItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Fastest Near You',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const FastestRestaurantsScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'VIEW ALL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: displayFastItems.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final item = displayFastItems[index];

                          return FeaturedItemCard(item: item);
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // ── 🔥 Special Offers (Horizontal) — restaurant type only ──
            if (restaurantTypeOffers.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF1744)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Special Offers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllOffersScreen(),
                          ),
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: OffersCarousel(
                  offers: restaurantTypeOffers,
                  restaurantProv: restaurantProv,
                ),
              ),
            ],

            // ── 🛍️ Store Bundles (Horizontal) — non-restaurant types ──
            if (storeBundles.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'DEALS',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Store Bundles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllOffersScreen(),
                          ),
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: OffersCarousel(
                  offers: storeBundles,
                  restaurantProv: restaurantProv,
                ),
              ),
            ],

            // ── Dynamic Business Type Sections ──
            ...restaurantProv.businessTypes.expand((bt) {
              final storesOfType = restaurantProv.restaurantsOfType(bt.id);
              if (storesOfType.isEmpty) return <Widget>[];

              return [
                // Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            bt.iconData,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          bt.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${storesOfType.length} stores',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Store Cards (vertical list)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final restaurant = storesOfType[index];
                      return _RestaurantCard(
                        restaurant: restaurant,
                        onTap: () {
                          restaurantProv.selectRestaurant(restaurant);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  restaurant.businessType == 'restaurant'
                                  ? const RestaurantDetailScreen()
                                  : const StoreDetailScreen(),
                            ),
                          );
                        },
                      );
                    }, childCount: storesOfType.length),
                  ),
                ),
              ];
            }),

            // Bottom Padding
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: cartProv.itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.shopping_bag),
              label: Text('${cartProv.itemCount} Items'),
            )
          : null,
    );
  }
}

class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickySearchBarDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: child);
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _BrandItem extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _BrandItem({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child:
                (restaurant.iconUrl.isNotEmpty ||
                    restaurant.imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: restaurant.iconUrl.isNotEmpty
                          ? restaurant.iconUrl
                          : restaurant.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.storefront, color: Colors.grey),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      restaurant.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 64,
            child: Text(
              restaurant.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedItemCard extends StatelessWidget {
  final MenuItemModel item;

  const FeaturedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isFavorite = user?.favoriteMenuItemIds.contains(item.id) ?? false;

    return GestureDetector(
      onTap: () {
        final restProv = context.read<RestaurantProvider>();
        final restaurant = restProv.restaurants.firstWhere(
          (r) => r.id == item.restaurantId,
          orElse: () => RestaurantModel(
            id: '',
            name: 'Unknown',
            imageUrl: '',
            rating: 0,
            categories: [],
            ownerId: '',
          ),
        );
        if (restaurant.id.isNotEmpty) {
          restProv.selectRestaurant(restaurant);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantDetailScreen()),
          );
        }
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: item.imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  Icons.fastfood,
                                  size: 48,
                                  color: AppColors.textHint.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 48,
                              color: AppColors.textHint.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.primary : Colors.white,
                        size: 20,
                      ),
                      onPressed: () => auth.toggleFavoriteMenuItem(item.id),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category} • ${Helpers.formatPrice(item.price)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: item.prepTime != null
                            ? Text(
                                '${item.prepTime} min',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            : const SizedBox.shrink(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          final restProv = context.read<RestaurantProvider>();
                          final cartProv = context.read<CartProvider>();
                          final restaurant = restProv.restaurants.firstWhere(
                            (r) => r.id == item.restaurantId,
                            orElse: () => RestaurantModel(
                              id: '',
                              name: 'Unknown',
                              imageUrl: '',
                              rating: 0,
                              categories: [],
                              ownerId: '',
                            ),
                          );

                          if (restaurant.id.isNotEmpty) {
                            cartProv.addItem(
                              item,
                              restaurant.id,
                              restaurant.name,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${item.name} to cart'),
                                backgroundColor: AppColors.primary,
                                duration: const Duration(seconds: 1),
                                action: SnackBarAction(
                                  label: 'VIEW',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CartScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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

class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isFavorite =
        auth.user?.favoriteRestaurantIds.contains(restaurant.id) ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.background,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  restaurant.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: restaurant.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Center(child: Icon(Icons.error)),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.store,
                            size: 48,
                            color: AppColors.textHint,
                          ),
                        ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.primary : Colors.white,
                      ),
                      onPressed: () =>
                          auth.toggleFavoriteRestaurant(restaurant.id),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    restaurant.rating.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (restaurant.categories.isNotEmpty)
                  Text(
                    restaurant.categories.first,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.circle, size: 4, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  '${restaurant.estimatedDeliveryMin} min',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.circle, size: 4, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  restaurant.isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: restaurant.isOpen
                        ? AppColors.success
                        : AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
