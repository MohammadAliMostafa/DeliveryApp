import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../utils/theme.dart';
import 'restaurant_detail_screen.dart';
import 'store_detail_screen.dart';

enum StoreSortOption { nearest, topRated, aToZ }

class CategoryStoresScreen extends StatefulWidget {
  final String businessTypeId;
  final String displayName;
  final IconData iconData;
  final List<Color> gradient;

  const CategoryStoresScreen({
    super.key,
    required this.businessTypeId,
    required this.displayName,
    required this.iconData,
    required this.gradient,
  });

  @override
  State<CategoryStoresScreen> createState() => _CategoryStoresScreenState();
}

class _CategoryStoresScreenState extends State<CategoryStoresScreen> {
  StoreSortOption _selectedSort = StoreSortOption.nearest;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Get and filter the list
    final List<RestaurantModel> stores = restaurantProv
        .restaurantsOfType(widget.businessTypeId)
        .where((store) {
          if (_searchQuery.isEmpty) return true;
          return store.name.toLowerCase().contains(_searchQuery.toLowerCase());
        })
        .toList();

    // Apply sorting
    stores.sort((a, b) {
      if (_selectedSort == StoreSortOption.nearest &&
          user?.latitude != null &&
          user?.longitude != null) {
        // Nearest
        double distA = 0;
        double distB = 0;
        if (a.latitude != 0 && a.longitude != 0) {
          distA = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            a.latitude,
            a.longitude,
          );
        } else {
          distA = double.infinity;
        }
        if (b.latitude != 0 && b.longitude != 0) {
          distB = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            b.latitude,
            b.longitude,
          );
        } else {
          distB = double.infinity;
        }
        return distA.compareTo(distB);
      } else if (_selectedSort == StoreSortOption.topRated) {
        // Top Rated (descending)
        return b.rating.compareTo(a.rating);
      } else {
        // A to Z
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: 30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    // Center icon
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Icon(
                          widget.iconData,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Store count header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.gradient.first.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.iconData,
                      color: widget.gradient.first,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${stores.length} ${stores.length == 1 ? 'store' : 'stores'} available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sort Options
          if (stores.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Sort by:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: StoreSortOption.values.map((option) {
                            final isSelected = _selectedSort == option;
                            String label;
                            switch (option) {
                              case StoreSortOption.nearest:
                                label = 'Nearest';
                                break;
                              case StoreSortOption.topRated:
                                label = 'Top Rated';
                                break;
                              case StoreSortOption.aToZ:
                                label = 'A to Z';
                                break;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedSort = option;
                                    });
                                  }
                                },
                                selectedColor: widget.gradient.first.withValues(
                                  alpha: 0.15,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? widget.gradient.first
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? widget.gradient.first
                                      : AppColors.divider,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.displayName}...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textHint,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textHint,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Stores list
          if (stores.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.iconData,
                      size: 64,
                      color: AppColors.textHint.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No results for "$_searchQuery"'
                          : 'No ${widget.displayName} stores yet',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try adjusting your search'
                          : 'Check back later for new stores',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final store = stores[index];
                  return _StoreCard(
                    store: store,
                    accentColor: widget.gradient.first,
                    onTap: () {
                      restaurantProv.selectRestaurant(store);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => store.businessType == 'restaurant'
                              ? const RestaurantDetailScreen()
                              : const StoreDetailScreen(),
                        ),
                      );
                    },
                  );
                }, childCount: stores.length),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Store Card ──────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final RestaurantModel store;
  final Color accentColor;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: store.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: store.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: accentColor.withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              Icons.store,
                              color: accentColor.withValues(alpha: 0.4),
                              size: 32,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: accentColor.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              store.name.isNotEmpty
                                  ? store.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: accentColor.withValues(alpha: 0.1),
                        child: Center(
                          child: Text(
                            store.name.isNotEmpty
                                ? store.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (store.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        store.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Rating
                        if (store.rating > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            store.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Open/Closed status
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: store.isOpen
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            store.isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: store.isOpen
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
