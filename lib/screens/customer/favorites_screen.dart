import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/restaurant_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/offer_model.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import 'restaurant_detail_screen.dart';
import 'store_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<RestaurantProvider>().loadFavoriteDishes(
          user.favoriteMenuItemIds,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final restaurantProv = context.watch<RestaurantProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final favoriteRestaurants = restaurantProv.restaurants
        .where((r) => user.favoriteRestaurantIds.contains(r.id))
        .toList();

    final favoriteOffers = restaurantProv.allOffers
        .where((o) => user.favoriteOfferIds.contains(o.id))
        .toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text(
            'My Favorites',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Brands'),
              Tab(text: 'Dishes'),
              Tab(text: 'Bundles'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
          ),
        ),
        body: TabBarView(
          children: [
            // Brands Tab
            favoriteRestaurants.isEmpty
                ? _emptyState(
                    Icons.storefront_rounded,
                    'No favorite brands yet',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favoriteRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = favoriteRestaurants[index];
                      return _buildStoreCard(context, restaurant, auth);
                    },
                  ),

            // Dishes Tab
            restaurantProv.favoriteDishes.isEmpty
                ? _emptyState(
                    Icons.restaurant_menu_rounded,
                    'No favorite dishes yet',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: restaurantProv.favoriteDishes.length,
                    itemBuilder: (context, index) {
                      final item = restaurantProv.favoriteDishes[index];
                      return _buildItemCard(
                        context,
                        item,
                        restaurantProv,
                        auth,
                      );
                    },
                  ),

            // Bundles Tab
            favoriteOffers.isEmpty
                ? _emptyState(
                    Icons.auto_awesome_rounded,
                    'No favorite bundles yet',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favoriteOffers.length,
                    itemBuilder: (context, index) {
                      final offer = favoriteOffers[index];
                      return _buildOfferCard(
                        context,
                        offer,
                        restaurantProv,
                        auth,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    RestaurantModel restaurant,
    AuthProvider auth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            context.read<RestaurantProvider>().selectRestaurant(restaurant);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => restaurant.businessType == 'restaurant'
                    ? const RestaurantDetailScreen()
                    : const StoreDetailScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.background,
                    child:
                        (restaurant.iconUrl.isNotEmpty ||
                            restaurant.imageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: restaurant.iconUrl.isNotEmpty
                                ? restaurant.iconUrl
                                : restaurant.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.store,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            restaurant.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time_rounded,
                            color: AppColors.textHint,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${restaurant.estimatedDeliveryMin} min',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: AppColors.primary),
                  onPressed: () => auth.toggleFavoriteRestaurant(restaurant.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    MenuItemModel item,
    RestaurantProvider restProv,
    AuthProvider auth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            try {
              final r = restProv.restaurants.firstWhere(
                (res) => res.id == item.restaurantId,
              );
              restProv.selectRestaurant(r);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => r.businessType == 'restaurant'
                      ? RestaurantDetailScreen(highlightItemId: item.id)
                      : StoreDetailScreen(highlightItemId: item.id),
                ),
              );
            } catch (_) {
              Helpers.showSnackBar(context, 'Store no longer available');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.background,
                    child: item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.restaurant,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.formatPrice(item.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: AppColors.primary),
                  onPressed: () async {
                    await auth.toggleFavoriteMenuItem(item.id);
                    if (mounted) {
                      restProv.loadFavoriteDishes(
                        auth.user!.favoriteMenuItemIds,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    OfferModel offer,
    RestaurantProvider restProv,
    AuthProvider auth,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            try {
              final r = restProv.restaurants.firstWhere(
                (res) => res.id == offer.restaurantId,
              );
              restProv.selectRestaurant(r);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => r.businessType == 'restaurant'
                      ? RestaurantDetailScreen(highlightOfferId: offer.id)
                      : StoreDetailScreen(highlightOfferId: offer.id),
                ),
              );
            } catch (_) {
              Helpers.showSnackBar(context, 'Store no longer available');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: AppColors.background,
                    child: offer.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: offer.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bundle from ${offer.itemNames.length} items',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Helpers.formatPrice(offer.bundlePrice),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: AppColors.primary),
                  onPressed: () => auth.toggleFavoriteOffer(offer.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
