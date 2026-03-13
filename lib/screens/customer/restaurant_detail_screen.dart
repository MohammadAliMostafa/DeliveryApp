import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_item_model.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import 'cart_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String? highlightOfferId;
  final String? highlightItemId;
  const RestaurantDetailScreen({
    super.key,
    this.highlightOfferId,
    this.highlightItemId,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  String? _tempHighlightId;
  String? _tempHighlightOfferId;
  String _menuSearch = '';
  String _selectedCategory = 'All';
  int _selectedTab = 0; // 0 = Menu, 1 = Offers
  // Offer search + sort
  String _offerSearch = '';
  String _offerSort = 'All'; // All | Discounted | Low→High | High→Low
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tempHighlightId = widget.highlightItemId;
    _tempHighlightOfferId = widget.highlightOfferId;

    if (_tempHighlightOfferId != null) {
      _selectedTab = 1;
    }

    if (_tempHighlightId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final restaurantProv = context.read<RestaurantProvider>();
        final item = restaurantProv.menuItems
            .where((i) => i.id == _tempHighlightId)
            .firstOrNull;

        if (item != null) {
          if (item.category.isNotEmpty) {
            setState(() => _selectedCategory = item.category);
          }
        }
      });
    }

    // Clear highlight after 2 seconds
    if (_tempHighlightId != null || _tempHighlightOfferId != null) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _tempHighlightId = null;
            _tempHighlightOfferId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final restaurant = restaurantProv.selectedRestaurant;
    final menuItems = restaurantProv.menuItems;

    if (restaurant == null) return const SizedBox.shrink();

    // Derive brand colour from admin-set business type colour (default red)
    final brandType = restaurantProv.businessTypes
        .where((bt) => bt.id == restaurant.businessType)
        .firstOrNull;
    final brandColor = brandType?.cardColor ?? const Color(0xFFE53935);

    // Build category chips
    final categorySet = <String>{'All'};
    for (final item in menuItems) {
      if (item.category.isNotEmpty) {
        categorySet.add(item.category);
      }
    }
    final categories = categorySet.toList();

    // Group by category & apply search and category filters
    final grouped = <String, List<MenuItemModel>>{};
    for (final item in menuItems) {
      if (_menuSearch.isNotEmpty &&
          !item.name.toLowerCase().contains(_menuSearch.toLowerCase()) &&
          !item.category.toLowerCase().contains(_menuSearch.toLowerCase())) {
        continue;
      }
      if (_selectedCategory != 'All' && item.category != _selectedCategory) {
        continue;
      }
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero Banner ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (restaurant.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: restaurant.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.restaurant,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.8),
                            AppColors.primary.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 72,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  // Gradient overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Restaurant info overlay
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${restaurant.rating.toStringAsFixed(1)} (${restaurant.totalRatings})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.schedule,
                              color: Colors.white70,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${restaurant.estimatedDeliveryMin} min',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Restaurant Details Bar ──────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (restaurant.description.isNotEmpty) ...[
                    Text(
                      restaurant.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        Icons.star_outline,
                        'Rate',
                        onTap: () {
                          _showRatingDialog(context, restaurant.id);
                        },
                      ),
                      if (restaurant.address.isNotEmpty)
                        _infoChip(
                          Icons.location_on_outlined,
                          restaurant.address,
                        ),
                      _infoChip(
                        Icons.access_time,
                        '${restaurant.openTime} - ${restaurant.closeTime}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),

          // ── Menu / Offers Tab Switcher ────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu,
                                size: 18,
                                color: _selectedTab == 0
                                    ? brandColor
                                    : AppColors.textHint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Menu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _selectedTab == 0
                                      ? brandColor
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 18,
                                color: _selectedTab == 1
                                    ? const Color(0xFFFF6B35)
                                    : AppColors.textHint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Offers',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _selectedTab == 1
                                      ? const Color(0xFFFF6B35)
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ══════════════════════════════════════════════════
          // ── MENU TAB CONTENT ──────────────────────────────
          // ══════════════════════════════════════════════════
          if (_selectedTab == 0) ...[
            // ── Sticky Search Bar ───────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchDelegate(
                onChanged: (value) {
                  setState(() {
                    _menuSearch = value;
                    _selectedCategory = 'All';
                  });
                },
              ),
            ),

            // ── Category Tabs ───────────────────────────────
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isActive = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isActive,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                          selectedColor: brandColor,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isActive
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Menu Sections ───────────────────────────────
            if (grouped.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No items found',
                      style: TextStyle(color: AppColors.textHint, fontSize: 16),
                    ),
                  ),
                ),
              )
            else
              ...grouped.keys.toList().asMap().entries.expand((entry) {
                final category = entry.value;
                final items = grouped[category]!;
                return [
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${items.length} items',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Items in category
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _DoorDashMenuItem(
                          item: items[index],
                          restaurantId: restaurant.id,
                          restaurantName: restaurant.name,
                          isHighlighted: items[index].id == _tempHighlightId,
                        );
                      }, childCount: items.length),
                    ),
                  ),
                ];
              }),
          ],

          // ══════════════════════════════════════════════════
          // ── OFFERS TAB CONTENT ────────────────────────────
          // ══════════════════════════════════════════════════
          if (_selectedTab == 1)
            _buildOffersTab(
              context,
              restaurant.id,
              restaurant.name,
              restaurantProv,
              brandColor,
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ── Floating Cart Button ────────────────────────────
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
              backgroundColor: brandColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.shopping_bag, color: Colors.white),
              label: Text(
                '${cart.itemCount} items • ${Helpers.formatPrice(cart.total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _infoChip(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab(
    BuildContext context,
    String restaurantId,
    String restaurantName,
    RestaurantProvider restaurantProv,
    Color brandColor,
  ) {
    var offers = restaurantProv.allOffers
        .where((o) => o.restaurantId == restaurantId)
        .toList();

    // Sort highlighted offer to top first
    if (widget.highlightOfferId != null) {
      offers.sort((a, b) {
        if (a.id == widget.highlightOfferId) return -1;
        if (b.id == widget.highlightOfferId) return 1;
        return 0;
      });
    }

    if (offers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(60),
            child: Column(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 48,
                  color: AppColors.textHint,
                ),
                SizedBox(height: 12),
                Text(
                  'No offers available',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Apply search + sort filter
    var filteredOffers = offers.where((o) {
      final matchSearch =
          _offerSearch.isEmpty ||
          o.title.toLowerCase().contains(_offerSearch.toLowerCase()) ||
          o.description.toLowerCase().contains(_offerSearch.toLowerCase());
      final matchDiscount = _offerSort != 'Discounted' || o.hasDiscount;
      return matchSearch && matchDiscount;
    }).toList();
    if (_offerSort == 'Low→High') {
      filteredOffers.sort((a, b) => a.bundlePrice.compareTo(b.bundlePrice));
    } else if (_offerSort == 'High→Low') {
      filteredOffers.sort((a, b) => b.bundlePrice.compareTo(a.bundlePrice));
    }

    return SliverMainAxisGroup(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _offerSearch = v),
              decoration: InputDecoration(
                hintText: 'Search offers...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        // Sort chips
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final opt in ['All', 'Discounted', 'Low→High', 'High→Low'])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: ChoiceChip(
                      label: Text(opt),
                      selected: _offerSort == opt,
                      onSelected: (_) => setState(() => _offerSort = opt),
                      selectedColor: brandColor,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: _offerSort == opt
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        // Offers list or empty
        if (filteredOffers.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: AppColors.textHint.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _offerSearch.isNotEmpty
                          ? 'No offers match "$_offerSearch"'
                          : 'No offers match this filter',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final offer = filteredOffers[index];
                // Use custom color or fallback
                final cardColor = offer.color != null
                    ? Color(offer.color!)
                    : const Color(0xFFFF6B35);

                // Compute luminance for text visibility
                final isDarkBackground = cardColor.computeLuminance() < 0.5;

                // Resolve item names from menuItems
                final includedItems = restaurantProv.menuItems
                    .where((m) => offer.itemIds.contains(m.id))
                    .toList();

                final isHighlighted = offer.id == _tempHighlightOfferId;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Colors.grey.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: isHighlighted
                        ? Border.all(
                            color: Colors.grey.shade300,
                            width: 2.5)
                        : Border.all(color: Colors.transparent, width: 2.5),
                    boxShadow: [
                      if (isHighlighted)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Decorative icons
                        Positioned(
                          right: -25,
                          top: -25,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 120,
                            color: isDarkBackground
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        Positioned(
                          left: -15,
                          bottom: -15,
                          child: Icon(
                            Icons.local_offer,
                            size: 80,
                            color: cardColor.withValues(alpha: 0.05),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image + Title row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Offer image
                                  if (offer.imageUrl.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.grey.shade100,
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: SizedBox(
                                            width: 110,
                                            height: 110,
                                            child: CachedNetworkImage(
                                              imageUrl: offer.imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: Colors.grey.shade100,
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Colors.grey.shade100,
                                                child: const Icon(
                                                  Icons.fastfood,
                                                  color: Colors.black26,
                                                  size: 32,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Title + description
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          offer.title,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                            height: 1.15,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (offer.description.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            offer.description,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Included items
                              if (includedItems.isNotEmpty) ...[
                                const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: cardColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 16,
                                            color: cardColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Includes ${offer.itemNames.length} items',
                                            style: TextStyle(
                                              color: cardColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...offer.itemNames.map(
                                        (name) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6,
                                                  right: 8,
                                                ),
                                                child: Icon(
                                                  Icons.circle,
                                                  size: 6,
                                                  color: cardColor,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: cardColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
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
                              ],
                              const SizedBox(height: 14),
                              // Price + Add Bundle button
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (offer.hasDiscount) ...[
                                          Row(
                                            children: [
                                              Text(
                                                Helpers.formatPrice(
                                                  offer.originalPrice,
                                                ),
                                                style: const TextStyle(
                                                  decoration:
                                                      TextDecoration.lineThrough,
                                                  color: Colors.black38,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: cardColor.withValues(
                                                      alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '-${offer.discountPercentage}%',
                                                  style: TextStyle(
                                                    color: cardColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor.withValues(
                                                alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            Helpers.formatPrice(
                                              offer.bundlePrice,
                                            ),
                                            style: TextStyle(
                                              color: cardColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        if (offer.hasDiscount) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Save ${Helpers.formatPrice(offer.savedAmount)}',
                                            style: TextStyle(
                                              color: cardColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      final cart = context.read<CartProvider>();
                                      cart.addOffer(
                                        offer,
                                        includedItems,
                                        restaurantId,
                                        restaurantName,
                                      );
                                      Helpers.showSnackBar(
                                        context,
                                        '${offer.title} bundle added to cart!',
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                    ),
                                    label: const Text('Add Bundle'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cardColor,
                                      foregroundColor: isDarkBackground
                                          ? Colors.white
                                          : Colors.black87,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
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
              }, childCount: filteredOffers.length),
            ),
          ),
      ],
    );
  }

  void _showRatingDialog(BuildContext context, String restaurantId) {
    showDialog(
      context: context,
      builder: (context) => _RatingDialog(restaurantId: restaurantId),
    );
  }
}

// ── Sticky Search Bar Delegate ──────────────────────────────
class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final ValueChanged<String> onChanged;

  _StickySearchDelegate({required this.onChanged});

  @override
  double get minExtent => 64;
  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search this menu',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchDelegate oldDelegate) => false;
}

// ── Rating Dialog ───────────────────────────────────────────
class _RatingDialog extends StatefulWidget {
  final String restaurantId;

  const _RatingDialog({required this.restaurantId});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rate Restaurant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How would you rate your experience?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1.0),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '${_rating.toInt()} Stars',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    final userId = context.read<AuthProvider>().user?.uid;
                    if (userId == null) {
                      throw Exception("User not authenticated");
                    }

                    await context.read<RestaurantProvider>().rateRestaurant(
                      userId,
                      widget.restaurantId,
                      _rating,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      Helpers.showSnackBar(
                        context,
                        'Thank you for your rating!',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                      Helpers.showSnackBar(
                        context,
                        'Failed to submit rating. Please try again.',
                        isError: true,
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _DoorDashMenuItem extends StatelessWidget {
  final MenuItemModel item;
  final String restaurantId;
  final String restaurantName;
  final bool isHighlighted;

  const _DoorDashMenuItem({
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.grey.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: Colors.grey.shade300, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        color: Colors
            .transparent, // Make Material transparent to show Container's color
        child: InkWell(
          onTap: () => _showItemDetail(context),
          borderRadius: BorderRadius.circular(0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.hasDiscount) ...[
                            Text(
                              Helpers.formatPrice(item.price),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            Helpers.formatPrice(
                              item.hasDiscount
                                  ? item.discountedPrice
                                  : item.price,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (item.prepTime != null)
                            Text(
                              '${item.prepTime} min',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right: image + add button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.background,
                      ),
                      child: item.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.fastfood,
                                  color: AppColors.textHint,
                                  size: 32,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.fastfood,
                                color: AppColors.textHint,
                                size: 36,
                              ),
                            ),
                    ),
                    // Discount Badge
                    if (item.hasDiscount)
                      Positioned(
                        top: 8,
                        left: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '-${(item.discount * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    // Add button
                    if (item.isAvailable)
                      Positioned(
                        bottom: -8,
                        right: 8,
                        left: 8,
                        child: Center(
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                cart.addItem(
                                  item,
                                  restaurantId,
                                  restaurantName,
                                );
                                Helpers.showSnackBar(
                                  context,
                                  '${item.name} added to cart',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        bottom: -8,
                        right: 8,
                        left: 8,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Sold Out',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }

  void _showItemDetail(BuildContext context) {
    final cart = context.read<CartProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item image
                  if (item.imageUrl.isNotEmpty)
                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.hasDiscount) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '-${(item.discount * 100).round()}% OFF',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item.description.isNotEmpty)
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (item.hasDiscount) ...[
                              Text(
                                Helpers.formatPrice(item.price),
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textHint,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              Helpers.formatPrice(
                                item.hasDiscount
                                    ? item.discountedPrice
                                    : item.price,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        if (item.hasDiscount) ...[
                          const SizedBox(height: 6),
                          Text(
                            'You save ${Helpers.formatPrice(item.price - item.discountedPrice)}!',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: item.isAvailable
                                ? () {
                                    cart.addItem(
                                      item,
                                      restaurantId,
                                      restaurantName,
                                    );
                                    Navigator.pop(ctx);
                                    Helpers.showSnackBar(
                                      context,
                                      '${item.name} added to cart',
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            child: Text(
                              item.isAvailable
                                  ? 'Add to Cart — ${Helpers.formatPrice(item.hasDiscount ? item.discountedPrice : item.price)}'
                                  : 'Currently Unavailable',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
