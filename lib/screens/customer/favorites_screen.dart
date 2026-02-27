import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import 'restaurant_detail_screen.dart';

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

    if (user == null)
      return const Scaffold(body: Center(child: Text('Please log in')));

    final favoriteRestaurants = restaurantProv.restaurants
        .where((r) => user.favoriteRestaurantIds.contains(r.id))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Favorites'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Brands'),
              Tab(text: 'Dishes'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
          ),
        ),
        body: TabBarView(
          children: [
            // Brands Tab
            favoriteRestaurants.isEmpty
                ? _emptyState(
                    Icons.storefront_outlined,
                    'No favorite brands yet',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: favoriteRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = favoriteRestaurants[index];
                      return _buildFavoriteCard(
                        context: context,
                        imageUrl: restaurant.iconUrl.isNotEmpty
                            ? restaurant.iconUrl
                            : restaurant.imageUrl,
                        title: restaurant.name,
                        subtitle:
                            '${restaurant.rating.toStringAsFixed(1)} ★  •  ${restaurant.estimatedDeliveryMin} min',
                        isFavorite: true,
                        onFavoriteTap: () =>
                            auth.toggleFavoriteRestaurant(restaurant.id),
                        onTap: () {
                          restaurantProv.selectRestaurant(restaurant);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RestaurantDetailScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),

            // Dishes Tab
            restaurantProv.favoriteDishes.isEmpty
                ? _emptyState(
                    Icons.restaurant_menu_outlined,
                    'No favorite dishes yet',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: restaurantProv.favoriteDishes.length,
                    itemBuilder: (context, index) {
                      final item = restaurantProv.favoriteDishes[index];
                      return _buildFavoriteCard(
                        context: context,
                        imageUrl: item.imageUrl,
                        title: item.name,
                        subtitle: Helpers.formatPrice(item.price),
                        isFavorite: true,
                        onFavoriteTap: () async {
                          await auth.toggleFavoriteMenuItem(item.id);
                          if (mounted) {
                            restaurantProv.loadFavoriteDishes(
                              auth.user!.favoriteMenuItemIds,
                            );
                          }
                        },
                        onTap: () {
                          try {
                            // Find restaurant and navigate
                            final r = restaurantProv.restaurants.firstWhere(
                              (res) => res.id == item.restaurantId,
                            );
                            restaurantProv.selectRestaurant(r);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RestaurantDetailScreen(),
                              ),
                            );
                          } catch (e) {
                            Helpers.showSnackBar(
                              context,
                              'Restaurant no longer available',
                            );
                          }
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard({
    required BuildContext context,
    required String? imageUrl,
    required String title,
    required String subtitle,
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.background,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            color: AppColors.textHint,
                          ),
                        )
                      : const Icon(
                          Icons.store,
                          color: AppColors.primary,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Favorite Button
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? AppColors.primary : AppColors.textHint,
                  ),
                  onPressed: onFavoriteTap,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
