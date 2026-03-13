import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/menu_item_model.dart';
import '../../models/offer_model.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import 'cart_screen.dart';

/// Detail screen for non-restaurant stores (supermarkets, etc.)
/// Displays items in a product-grid layout instead of a menu list.
class StoreDetailScreen extends StatefulWidget {
  final String? highlightOfferId;
  final String? highlightItemId;
  const StoreDetailScreen({
    super.key,
    this.highlightOfferId,
    this.highlightItemId,
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  String? _tempHighlightId;
  String? _tempHighlightOfferId;
  String _search = '';
  String _selectedCategory = 'All';
  bool _showBundles = false;

  // Bundle search + sort
  String _bundleSearch = '';
  String _bundleSort = 'All'; // All | Discounted | Low→High | High→Low

  @override
  void initState() {
    super.initState();
    _tempHighlightId = widget.highlightItemId;
    _tempHighlightOfferId = widget.highlightOfferId;

    if (_tempHighlightOfferId != null) {
      _showBundles = true;
    }

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
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final store = restaurantProv.selectedRestaurant;
    final allItems = restaurantProv.menuItems;

    if (store == null) return const SizedBox.shrink();

    // Derive brand colour from admin-set business type colour (default red)
    final brandType = restaurantProv.businessTypes
        .where((bt) => bt.id == store.businessType)
        .firstOrNull;
    final brandColor = brandType?.cardColor ?? const Color(0xFFE53935);

    final storeOffers = restaurantProv.allOffers
        .where((o) => o.restaurantId == store.id && o.isActive)
        .toList();

    // Gather categories
    final categories = <String>{'All'};
    for (final item in allItems) {
      if (item.category.isNotEmpty) categories.add(item.category);
    }

    // Filter items
    final filtered = allItems.where((item) {
      final matchCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchSearch =
          _search.isEmpty ||
          item.name.toLowerCase().contains(_search.toLowerCase()) ||
          item.category.toLowerCase().contains(_search.toLowerCase());
      return matchCategory && matchSearch;
    }).toList();

    // Filtered + sorted bundles
    var filteredBundles = storeOffers.where((o) {
      final matchSearch =
          _bundleSearch.isEmpty ||
          o.title.toLowerCase().contains(_bundleSearch.toLowerCase()) ||
          o.description.toLowerCase().contains(_bundleSearch.toLowerCase());
      final matchDiscount = _bundleSort != 'Discounted' || o.hasDiscount;
      return matchSearch && matchDiscount;
    }).toList();
    if (_bundleSort == 'Low→High') {
      filteredBundles.sort((a, b) => a.bundlePrice.compareTo(b.bundlePrice));
    } else if (_bundleSort == 'High→Low') {
      filteredBundles.sort((a, b) => b.bundlePrice.compareTo(a.bundlePrice));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero Banner ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
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
                  if (store.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: store.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.storefront,
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
                            const Color(0xFF2E7D32).withValues(alpha: 0.85),
                            const Color(0xFF66BB6A).withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.storefront,
                          size: 72,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  // Gradient overlay
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
                  // Store info
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
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
                              '${store.rating.toStringAsFixed(1)} (${store.totalRatings})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.schedule,
                              color: Colors.white70,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${store.estimatedDeliveryMin} min',
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

          // ── Store Details ───────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (store.description.isNotEmpty) ...[
                    Text(
                      store.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        Icons.star_outline,
                        'Rate',
                        onTap: () {
                          _showRatingDialog(context, store.id);
                        },
                      ),
                      if (store.address.isNotEmpty)
                        _chip(Icons.location_on_outlined, store.address),
                      _chip(
                        Icons.access_time,
                        '${store.openTime} - ${store.closeTime}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),

          // ── Toggle Items / Bundles ────────────────────────
          if (storeOffers.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showBundles = false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: !_showBundles
                                  ? brandColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_showBundles
                                  ? [
                                      BoxShadow(
                                        color: brandColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Products',
                                style: TextStyle(
                                  color: !_showBundles
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showBundles = true),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _showBundles
                                  ? brandColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _showBundles
                                  ? [
                                      BoxShadow(
                                        color: brandColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                'Store Bundles',
                                style: TextStyle(
                                  color: _showBundles
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
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

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          if (!_showBundles) ...[
            // ── Search Bar ──────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textHint,
                    ),
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

            // ── Category Chips ──────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories.elementAt(index);
                    final isActive = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isActive,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
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

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Products Grid ───────────────────────────────
            if (filtered.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No products found',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = filtered[index];
                    return _ProductCard(
                      item: item,
                      storeId: store.id,
                      storeName: store.name,
                      isHighlighted: item.id == _tempHighlightId,
                    );
                  }, childCount: filtered.length),
                ),
              ),
          ] else ...[
            // ── Bundles View ────────────────────────────────

            // Bundle Search Bar
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (val) => setState(() => _bundleSearch = val),
                  decoration: InputDecoration(
                    hintText: 'Search bundles...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textHint,
                    ),
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

            // Bundle Sort Chips
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final opt in [
                      'All',
                      'Discounted',
                      'Low→High',
                      'High→Low',
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: ChoiceChip(
                          label: Text(opt),
                          selected: _bundleSort == opt,
                          onSelected: (_) => setState(() => _bundleSort = opt),
                          selectedColor: brandColor,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: _bundleSort == opt
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

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Filtered Bundles List
            if (filteredBundles.isEmpty)
              const SliverToBoxAdapter(
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
                          'No bundles found',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              _buildBundlesSliver(
                filteredBundles,
                allItems,
                store.id,
                store.name,
              ),
          ],

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
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
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

  Widget _chip(IconData icon, String label, {VoidCallback? onTap}) {
    final chip = Container(
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
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: chip);
    }
    return chip;
  }

  Widget _buildBundlesSliver(
    List<OfferModel> offers,
    List<MenuItemModel> allItems,
    String storeId,
    String storeName,
  ) {
    if (offers.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final offer = offers[index];
          final cardColor = offer.color != null
              ? Color(offer.color!)
              : const Color(0xFFFF6B35);
          final isDarkBackground = cardColor.computeLuminance() < 0.5;

          final includedItems = allItems
              .where((m) => offer.itemIds.contains(m.id))
              .toList();

          final isHighlighted = offer.id == _tempHighlightOfferId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
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
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offer.title,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (offer.description.isNotEmpty)
                                      Text(
                                        offer.description,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                          height: 1.3,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (offer.itemNames.isNotEmpty) ...[
                            const SizedBox(height: 16),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cardColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius: BorderRadius.circular(
                                                6,
                                              ),
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
                                    const Text(
                                      'Bundle Price',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      Helpers.formatPrice(offer.bundlePrice),
                                      style: TextStyle(
                                        color: cardColor,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (offer.hasDiscount) ...[
                                      const SizedBox(height: 2),
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
                              ElevatedButton(
                                onPressed: () {
                                  final cart = context.read<CartProvider>();
                                  if (cart.restaurantId != null &&
                                      cart.restaurantId != offer.restaurantId) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Cannot add items from different stores.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (includedItems.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Bundle items not found.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  cart.addOffer(
                                    offer,
                                    includedItems,
                                    offer.restaurantId,
                                    storeName,
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${offer.title} bundle added!',
                                      ),
                                      backgroundColor: AppColors.success,
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cardColor,
                                  foregroundColor: isDarkBackground
                                      ? Colors.white
                                      : Colors.black87,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Add Bundle',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
          );
        }, childCount: offers.length),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String storeId) {
    showDialog(
      context: context,
      builder: (context) => _RatingDialog(restaurantId: storeId),
    );
  }
}

// ── Product Card (Supermarket Grid Style) ────────────────────
class _ProductCard extends StatelessWidget {
  final MenuItemModel item;
  final String storeId;
  final String storeName;
  final bool isHighlighted;

  const _ProductCard({
    required this.item,
    required this.storeId,
    required this.storeName,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final effectivePrice = item.hasDiscount ? item.discountedPrice : item.price;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.grey.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: Colors.grey.shade300, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: item.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
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
                    // Discount badge
                    if (item.hasDiscount)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    // Sold-out overlay
                    if (!item.isAvailable)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Sold Out',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Product info
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      // Price row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    if (item.hasDiscount) ...[
                                      Text(
                                        Helpers.formatPrice(item.price),
                                        style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: AppColors.textHint,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      Helpers.formatPrice(effectivePrice),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.hasDiscount)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Save ${Helpers.formatPrice(item.price - item.discountedPrice)}',
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Add button
                          if (item.isAvailable)
                            Material(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  cart.addItem(item, storeId, storeName);
                                  Helpers.showSnackBar(
                                    context,
                                    '${item.name} added',
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
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

  void _showDetail(BuildContext context) {
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
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
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
                      height: 160,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.category.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
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
                                color: Color(0xFF2E7D32),
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
                                    cart.addItem(item, storeId, storeName);
                                    Navigator.pop(ctx);
                                    Helpers.showSnackBar(
                                      context,
                                      '${item.name} added to cart',
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
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
      title: const Text('Rate Store'),
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
