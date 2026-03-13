import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/business_type_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../models/menu_item_model.dart';
import '../../models/offer_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import 'category_stores_screen.dart';
import 'restaurant_detail_screen.dart';
import 'store_detail_screen.dart';
import 'favorites_screen.dart';

// ─── Filter Options ───────────────────────────────────────────
enum BrowseFilter { all, openNow }

class DiscoverableItem {
  final bool isOffer;
  final MenuItemModel? item;
  final OfferModel? offer;
  final RestaurantModel store;

  DiscoverableItem({
    required this.isOffer,
    this.item,
    this.offer,
    required this.store,
  });
}

// ─── Browse Screen ────────────────────────────────────────────
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  BrowseFilter _activeFilter = BrowseFilter.all;

  // Discover Items State
  String _selectedItemCategory = 'All';
  List<MenuItemModel> _rawItems = [];
  bool _isLoadingItems = true;

  // Caching & Debounce
  List<DiscoverableItem> _cachedDiscoverableItems = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  Future<void> _loadAllItems() async {
    try {
      final items = await FirestoreService().getAllMenuItems();
      if (mounted) {
        _rawItems = items;
        _isLoadingItems = false;
        _updateDiscoverableItems();
      }
    } catch (e) {
      debugPrint('Error loading discover items: $e');
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchQuery != query) {
        setState(() => _searchQuery = query);
        _updateDiscoverableItems();
      }
    });
  }

  void _updateDiscoverableItems() {
    if (!mounted) return;
    final restaurantProv = context.read<RestaurantProvider>();
    final allTypes = restaurantProv.businessTypes
        .where((bt) => bt.isActive)
        .toList();

    final discoverableItems = <DiscoverableItem>[];
    if (!_isLoadingItems) {
      final validStores = _selectedItemCategory == 'All'
          ? restaurantProv.restaurants
          : restaurantProv.restaurantsOfType(
              allTypes
                  .firstWhere(
                    (t) => t.displayName == _selectedItemCategory,
                    orElse: () => allTypes.first,
                  )
                  .id,
            );

      final validStoreIds = validStores.map((e) => e.id).toSet();

      for (final item in _rawItems) {
        if (validStoreIds.contains(item.restaurantId) && item.isAvailable) {
          final store = validStores.firstWhere(
            (s) => s.id == item.restaurantId,
          );

          final matchesSearch =
              _searchQuery.isEmpty ||
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              store.name.toLowerCase().contains(_searchQuery.toLowerCase());

          if (matchesSearch) {
            discoverableItems.add(
              DiscoverableItem(isOffer: false, item: item, store: store),
            );
          }
        }
      }

      for (final offer in restaurantProv.allOffers) {
        if (validStoreIds.contains(offer.restaurantId) && offer.isActive) {
          final store = validStores.firstWhere(
            (s) => s.id == offer.restaurantId,
          );

          final matchesSearch =
              _searchQuery.isEmpty ||
              offer.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              offer.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              store.name.toLowerCase().contains(_searchQuery.toLowerCase());

          if (matchesSearch) {
            discoverableItems.add(
              DiscoverableItem(isOffer: true, offer: offer, store: store),
            );
          }
        }
      }

      // Consistent pseudo-random mix
      discoverableItems.sort((a, b) {
        final idA = a.isOffer ? 'offer_${a.offer!.id}' : 'item_${a.item!.id}';
        final idB = b.isOffer ? 'offer_${b.offer!.id}' : 'item_${b.item!.id}';
        return idA.hashCode.compareTo(idB.hashCode);
      });
      
      // OPTIMIZATION: Do not display all hundreds of items at once if not actively searching
      if (_searchQuery.isEmpty && discoverableItems.length > 40) {
        discoverableItems.length = 40;
      }
    }

    setState(() {
      _cachedDiscoverableItems = discoverableItems;
    });
  }

  /// Derive a two-colour gradient from the admin-set base colour
  static List<Color> _gradientForType(BusinessTypeModel bt) {
    final base = bt.cardColor;
    final hsl = HSLColor.fromColor(base);
    final darker = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();
    return [base, darker];
  }

  /// Time-aware greeting
  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! ☀️';
    if (hour < 17) return 'Good afternoon! 👋';
    if (hour < 21) return 'Good evening! 🌙';
    return 'Late night cravings? 🌙';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _navigate(
    BuildContext context,
    BusinessTypeModel bt,
    List<Color> gradient,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryStoresScreen(
          businessTypeId: bt.id,
          displayName: bt.displayName,
          iconData: bt.iconData,
          gradient: gradient,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name.split(' ').first ?? '';

    final allTypes = restaurantProv.businessTypes
        .where((bt) => bt.isActive)
        .toList();

    // Apply Open Now filter
    List<BusinessTypeModel> filteredTypes =
        _activeFilter == BrowseFilter.openNow
        ? allTypes
              .where(
                (bt) => restaurantProv
                    .restaurantsOfType(bt.id)
                    .any((s) => s.isOpen),
              )
              .toList()
        : allTypes;

    // Apply search filter
    final businessTypes = _searchQuery.isEmpty
        ? filteredTypes
        : filteredTypes
              .where(
                (bt) => bt.displayName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    // Top Picks or Matching Stores
    final displayStores = _searchQuery.isEmpty
        ? (List<RestaurantModel>.from(restaurantProv.restaurants)
              ..sort((a, b) => b.rating.compareTo(a.rating)))
            .where((r) => r.rating > 0)
            .take(6)
            .toList()
        : restaurantProv.restaurants
              .where(
                (r) =>
                    r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    r.description.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    // Layout: first card full-width, rest in 2-column pairs
    // Row 0          → businessTypes[0]            (full-width)
    // Row i (i ≥ 1)  → businessTypes[2i-1], [2i]   (pair)
    final int n = businessTypes.length;
    final int rowCount = n == 0 ? 0 : 1 + ((n - 1) / 2).ceil();

    final discoverableItems = _cachedDiscoverableItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName.isNotEmpty
                                ? 'Hi $userName, explore!'
                                : 'Explore Categories',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.favorite_outline_rounded,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavoritesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Search Bar ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for items, offers, or categories…',
                      hintStyle: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.textHint,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
            ),

            // ── Quick Filter Chips ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      icon: Icons.apps_rounded,
                      isSelected: _activeFilter == BrowseFilter.all,
                      onTap: () =>
                          setState(() => _activeFilter = BrowseFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Open Now',
                      icon: Icons.access_time_filled_rounded,
                      isSelected: _activeFilter == BrowseFilter.openNow,
                      onTap: () =>
                          setState(() => _activeFilter = BrowseFilter.openNow),
                      accentColor: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),

            // ── Top Picks / Stores Row ────────────────────────
            if (displayStores.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        _searchQuery.isEmpty ? 'Top Picks' : 'Stores',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_searchQuery.isEmpty)
                        const Text('⭐', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayStores.length,
                    itemBuilder: (context, i) {
                      final store = displayStores[i];
                      return _TopPickCard(
                        store: store,
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
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],

            // ── Section Label ─────────────────────────────────
            if (_searchQuery.isEmpty || businessTypes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '${businessTypes.length} result${businessTypes.length == 1 ? '' : 's'}'
                            : '${allTypes.length} available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category Grid (featured first + 2-col rest) ───
              if (businessTypes.isEmpty && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: AppColors.textHint.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No categories available yet',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (businessTypes.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, rowIndex) {
                    if (rowIndex == 0) {
                      // Featured full-width card
                      final bt = businessTypes[0];
                      final gradient = _gradientForType(bt);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SizedBox(
                          height: 160,
                          child: _CategoryCard(
                            businessType: bt,
                            storeCount: restaurantProv
                                .restaurantsOfType(bt.id)
                                .length,
                            gradient: gradient,
                            index: 0,
                            featured: true,
                            onTap: () => _navigate(context, bt, gradient),
                          ),
                        ),
                      );
                    }
                    // Pair row
                    final leftIdx = 2 * rowIndex - 1;
                    final rightIdx = 2 * rowIndex;
                    final leftBt = businessTypes[leftIdx];
                    final leftGrad = _gradientForType(leftBt);
                    final rightBt = rightIdx < n
                        ? businessTypes[rightIdx]
                        : null;
                    final rightGrad = rightBt != null
                        ? _gradientForType(rightBt)
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        height: 150,
                        child: Row(
                          children: [
                            Expanded(
                              child: _CategoryCard(
                                businessType: leftBt,
                                storeCount: restaurantProv
                                    .restaurantsOfType(leftBt.id)
                                    .length,
                                gradient: leftGrad,
                                index: leftIdx,
                                onTap: () =>
                                    _navigate(context, leftBt, leftGrad),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: rightBt != null
                                  ? _CategoryCard(
                                      businessType: rightBt,
                                      storeCount: restaurantProv
                                          .restaurantsOfType(rightBt.id)
                                          .length,
                                      gradient: rightGrad!,
                                      index: rightIdx,
                                      onTap: () => _navigate(
                                        context,
                                        rightBt,
                                        rightGrad,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: rowCount),
                ),
              ),
            ],

            if (_searchQuery.isEmpty || discoverableItems.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Item Discovery Section ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        _searchQuery.isEmpty ? 'Discover Items' : 'Items & Offers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Discover Item Filters ───────────────────────────
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: 'All',
                      icon: Icons.apps_rounded,
                      isSelected: _selectedItemCategory == 'All',
                      onTap: () {
                          if (_selectedItemCategory != 'All') {
                            setState(() => _selectedItemCategory = 'All');
                            _updateDiscoverableItems();
                          }
                      },
                    ),
                    const SizedBox(width: 8),
                    ...allTypes.map((bt) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: bt.displayName,
                          icon: bt.iconData,
                          isSelected: _selectedItemCategory == bt.displayName,
                          onTap: () {
                            if (_selectedItemCategory != bt.displayName) {
                              setState(() => _selectedItemCategory = bt.displayName);
                              _updateDiscoverableItems();
                            }
                          },
                          accentColor: bt.cardColor,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Discover Grid ───────────────────────────────────
            if (_isLoadingItems)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              )
            else if (discoverableItems.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No items found here 🌮',
                      style: TextStyle(color: AppColors.textHint, fontSize: 16),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.55,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final dItem = discoverableItems[index];
                    return _DiscoverCard(dItem: dItem);
                  }, childCount: discoverableItems.length),
                ),
              ),
            ],

            if (_searchQuery.isNotEmpty && businessTypes.isEmpty && displayStores.isEmpty && discoverableItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results for "$_searchQuery"',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try searching for categories, stores, or items',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Filter Chip ────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Pick Card ────────────────────────────────────────────
class _TopPickCard extends StatelessWidget {
  final RestaurantModel store;
  final VoidCallback onTap;

  const _TopPickCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Store image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 80,
                height: 120,
                child: store.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: store.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(store.name),
                      )
                    : _placeholder(store.name),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: store.isOpen
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String name) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Category Card (with entrance animation) ──────────────────
class _CategoryCard extends StatefulWidget {
  final BusinessTypeModel businessType;
  final int storeCount;
  final List<Color> gradient;
  final VoidCallback onTap;
  final int index;
  final bool featured;

  const _CategoryCard({
    required this.businessType,
    required this.storeCount,
    required this.gradient,
    required this.onTap,
    required this.index,
    this.featured = false,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    // Press animation
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));

    // Staggered entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));

    // Stagger delay based on index
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) =>
                Transform.scale(scale: _scaleAnim.value, child: child),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient.first.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Decorative circles
                  Positioned(
                    top: -24,
                    right: -24,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -15,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  if (widget.featured)
                    // Extra large icon for featured
                    Positioned(
                      right: 24,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Icon(
                          widget.businessType.iconData,
                          size: 90,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(widget.featured ? 22 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.businessType.iconData,
                            color: Colors.white,
                            size: widget.featured ? 30 : 26,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.businessType.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.featured ? 20 : 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.storeCount} ${widget.storeCount == 1 ? 'store' : 'stores'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.featured) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Featured',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Discover Card (Items & Offers) ───────────────────────────
class _DiscoverCard extends StatelessWidget {
  final DiscoverableItem dItem;

  const _DiscoverCard({required this.dItem});

  @override
  Widget build(BuildContext context) {
    if (dItem.isOffer) {
      return _buildOfferCard(context, dItem.offer!, dItem.store);
    } else {
      return _buildNormalItemCard(context, dItem.item!, dItem.store);
    }
  }

  Widget _buildOfferCard(
    BuildContext context,
    OfferModel offer,
    RestaurantModel store,
  ) {
    final cardColor = offer.color != null
        ? Color(offer.color!)
        : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final restProv = context.read<RestaurantProvider>();
            restProv.selectRestaurant(store);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoreDetailScreen()),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: offer.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: offer.imageUrl,
                                fit: BoxFit.cover,
                                height: double.infinity,
                                width: double.infinity,
                                color: Colors.black.withValues(alpha: 0.1),
                                colorBlendMode: BlendMode.darken,
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.auto_awesome,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black26,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            context.read<AuthProvider>().toggleFavoriteOffer(
                              offer.id,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              context
                                      .watch<AuthProvider>()
                                      .user!
                                      .favoriteOfferIds
                                      .contains(offer.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  context
                                      .watch<AuthProvider>()
                                      .user!
                                      .favoriteOfferIds
                                      .contains(offer.id)
                                  ? Colors.redAccent
                                  : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BUNDLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (offer.hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${offer.discountPercentage}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (offer.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.description,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (offer.itemNames.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.itemNames.join(', '),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'from ${store.name}',
                          style: TextStyle(
                            fontSize: 9,
                            color: cardColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (offer.hasDiscount) ...[
                            Text(
                              Helpers.formatPrice(offer.originalPrice),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.black38,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              Helpers.formatPrice(offer.bundlePrice),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: cardColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
    );
  }

  Widget _buildNormalItemCard(
    BuildContext context,
    MenuItemModel item,
    RestaurantModel store,
  ) {
    final cartProv = context.read<CartProvider>();
    final effectivePrice = item.hasDiscount ? item.discountedPrice : item.price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final restProv = context.read<RestaurantProvider>();
            restProv.selectRestaurant(store);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => store.businessType == 'restaurant'
                    ? const RestaurantDetailScreen()
                    : const StoreDetailScreen(),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: item.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                height: double.infinity,
                                width: double.infinity,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: AppColors.textHint,
                                    size: 32,
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.inventory_2,
                                color: AppColors.textHint,
                                size: 36,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black26,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            context.read<AuthProvider>().toggleFavoriteMenuItem(
                              item.id,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              context
                                      .watch<AuthProvider>()
                                      .user!
                                      .favoriteMenuItemIds
                                      .contains(item.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  context
                                      .watch<AuthProvider>()
                                      .user!
                                      .favoriteMenuItemIds
                                      .contains(item.id)
                                  ? Colors.redAccent
                                  : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (item.hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${(item.discount * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        'from ${store.name}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.hasDiscount) ...[
                                  Text(
                                    Helpers.formatPrice(item.price),
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.textHint,
                                      fontSize: 9,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  Helpers.formatPrice(effectivePrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                cartProv.addItem(item, store.id, store.name);
                                Helpers.showSnackBar(
                                  context,
                                  '${item.name} added',
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                            ),
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
    );
  }
}
