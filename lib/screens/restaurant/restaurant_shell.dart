import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/order_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/offer_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../shared/map_picker_screen.dart';
import '../shared/help_support_screen.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key});

  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final restProv = context.read<RestaurantProvider>();
      restProv.loadOwnedRestaurant(auth.user!.uid);
      restProv.seedBusinessTypes();
      restProv.listenToBusinessTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();

    // If no restaurant created yet, show setup
    if (restaurantProv.ownedRestaurant == null && !restaurantProv.isLoading) {
      return _RestaurantSetupScreen();
    }

    if (restaurantProv.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final restaurant = restaurantProv.ownedRestaurant!;

    return Scaffold(
      body: Row(
        children: [
          // Side navigation (desktop style)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.darkSurface,
            useIndicator: true,
            indicatorColor: AppColors.primary.withValues(alpha: 0.15),
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
            leading: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Column(
                children: [
                  const Icon(Icons.store, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Orders'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: Text('Menu'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer),
                label: Text('Offers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),

          // Content area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                RepaintBoundary(child: _DashboardTab(restaurant: restaurant)),
                RepaintBoundary(child: _OrdersTab(restaurantId: restaurant.id)),
                RepaintBoundary(child: _MenuTab(restaurantId: restaurant.id)),
                RepaintBoundary(child: _OffersTab()),
                RepaintBoundary(child: _SettingsTab(restaurant: restaurant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restaurant Setup ──────────────────────────────────────
class _RestaurantSetupScreen extends StatefulWidget {
  @override
  State<_RestaurantSetupScreen> createState() => _RestaurantSetupScreenState();
}

class _RestaurantSetupScreenState extends State<_RestaurantSetupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.store, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Set Up Your Shop',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in your shop details to get started',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRestaurant,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Shop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createRestaurant() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final restProv = context.read<RestaurantProvider>();

    final restaurant = RestaurantModel(
      id: const Uuid().v4(),
      ownerId: auth.user!.uid,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      address: _addressController.text.trim(),
      categories: ['Main'],
    );

    await restProv.saveRestaurant(restaurant);
    setState(() => _isLoading = false);
  }
}

// ─── Dashboard Tab ──────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final RestaurantModel restaurant;
  const _DashboardTab({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    final activeOrders = orders
        .where(
          (o) =>
              o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled,
        )
        .toList();
    final todayOrders = orders
        .where(
          (o) =>
              o.status != OrderStatus.cancelled &&
              o.createdAt.day == DateTime.now().day &&
              o.createdAt.month == DateTime.now().month &&
              o.createdAt.year == DateTime.now().year,
        )
        .toList();
    // Calculate today's revenue (only delivered orders, using subtotal since delivery fee goes to driver)
    final todayRevenue = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard — ${restaurant.name}'),
        actions: [
          Switch(
            value: restaurant.isOpen,
            onChanged: (val) {
              final restProv = context.read<RestaurantProvider>();
              restProv.saveRestaurant(restaurant.copyWith(isOpen: val));
            },
            activeThumbColor: AppColors.success,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                restaurant.isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  color: restaurant.isOpen
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                _StatCard(
                  title: 'Active Orders',
                  value: '${activeOrders.length}',
                  icon: Icons.receipt,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Today\'s Orders',
                  value: '${todayOrders.length}',
                  icon: Icons.today,
                  color: AppColors.info,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  title: 'Today\'s Revenue',
                  value: Helpers.formatPrice(todayRevenue),
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Recent orders
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No orders yet. They will appear here in real-time.',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ),
              )
            else
              ...orders
                  .take(10)
                  .map(
                    (order) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${order.items.length} items • ${Helpers.formatPrice(order.total)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              OrderStatus.displayName(order.status),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Orders Tab ──────────────────────────────────────────
class _OrdersTab extends StatefulWidget {
  final String restaurantId;
  const _OrdersTab({required this.restaurantId});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();
  bool _listeningStarted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final orderProv = context.watch<OrderProvider>();

    // Start listening if not already
    if (!_listeningStarted) {
      _listeningStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        orderProv.listenToRestaurantOrders(widget.restaurantId);
      });
    }

    final orders = orderProv.orders;

    // Apply multi-word search filter
    final queryWords = _searchQuery
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final filteredOrders = queryWords.isEmpty
        ? orders
        : orders.where((order) {
            final searchable =
                '${order.customerName} ${order.id} ${order.items.map((i) => i.name).join(' ')}'
                    .toLowerCase();
            return queryWords.every((word) => searchable.contains(word));
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Management')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by customer, order ID, or item...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          // Orders list
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Text(
                      queryWords.isEmpty
                          ? 'No orders yet'
                          : 'No matching orders',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _HoverContainer(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  Helpers.formatPrice(order.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order #${order.id.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map(
                              (item) => Text(
                                '  ${item.quantity}x ${item.name}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              Helpers.formatDateTime(order.createdAt),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _OrderActionButtons(
                              order: order,
                              firestoreService: _firestoreService,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderActionButtons extends StatelessWidget {
  final OrderModel order;
  final FirestoreService firestoreService;

  const _OrderActionButtons({
    required this.order,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    Widget? actionButton;

    switch (order.status) {
      case OrderStatus.placed:
        actionButton = ElevatedButton.icon(
          onPressed: () => firestoreService.updateOrderStatus(
            order.id,
            OrderStatus.accepted,
          ),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Accept'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        );
        break;
      case OrderStatus.accepted:
        actionButton = ElevatedButton.icon(
          onPressed: () => firestoreService.updateOrderStatus(
            order.id,
            OrderStatus.preparing,
          ),
          icon: const Icon(Icons.restaurant, size: 18),
          label: const Text('Start Preparing'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
        );
        break;
      case OrderStatus.preparing:
        actionButton = ElevatedButton.icon(
          onPressed: () =>
              firestoreService.updateOrderStatus(order.id, OrderStatus.ready),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark Ready'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
        );
        break;
      default:
        actionButton = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            OrderStatus.displayName(order.status),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );
    }

    return Row(
      children: [
        if (order.status == OrderStatus.placed)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: () => firestoreService.updateOrderStatus(
                order.id,
                OrderStatus.cancelled,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('Decline'),
            ),
          ),
        actionButton,
      ],
    );
  }
}

// ─── Hover Container (smooth desktop hover effect) ──────────
class _HoverContainer extends StatefulWidget {
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const _HoverContainer({
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
  });

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white : AppColors.cardBg,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── Menu Tab ──────────────────────────────────────────
class _MenuTab extends StatefulWidget {
  final String restaurantId;
  const _MenuTab({required this.restaurantId});

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> with AutomaticKeepAliveClientMixin {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final restProv = context.watch<RestaurantProvider>();
    final allItems = restProv.menuItems;

    // Gather unique categories
    final categories = <String>{'All'};
    for (final item in allItems) {
      if (item.category.isNotEmpty) categories.add(item.category);
    }

    // Filter items
    final items = allItems.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery) ||
          item.description.toLowerCase().contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          FilledButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) =>
                  _AddItemDialog(restaurantId: widget.restaurantId),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Category filter chips
          if (categories.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 0, 4),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          // Items list
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allItems.isEmpty
                              ? 'No menu items yet'
                              : 'No items match your search',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: item.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        width: 60,
                                        height: 60,
                                        placeholder: (ctx, url) => const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        errorWidget: (ctx, url, err) =>
                                            const Icon(
                                              Icons.fastfood,
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.fastfood,
                                      color: AppColors.textHint,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.hasDiscount)
                                    Row(
                                      children: [
                                        Text(
                                          Helpers.formatPrice(item.price),
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: AppColors.textHint,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.category} • ${Helpers.formatPrice(item.discountedPrice)}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '-${(item.discount * 100).round()}%',
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '${item.category} • ${Helpers.formatPrice(item.price)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.primary,
                              ),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _AddItemDialog(
                                  restaurantId: item.restaurantId,
                                  existingItem: item,
                                ),
                              ),
                            ),
                            Switch(
                              value: item.isAvailable,
                              onChanged: (val) {
                                restProv.saveMenuItem(
                                  item.copyWith(isAvailable: val),
                                );
                              },
                              activeThumbColor: AppColors.success,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () => restProv.deleteMenuItem(item.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final String restaurantId;
  final MenuItemModel? existingItem;
  const _AddItemDialog({required this.restaurantId, this.existingItem});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _catCtl;
  late final TextEditingController _prepTimeCtl;
  late final TextEditingController _discountCtl;
  XFile? _pickedImage;
  bool _isSaving = false;
  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    _nameCtl = TextEditingController(text: e?.name ?? '');
    _descCtl = TextEditingController(text: e?.description ?? '');
    _priceCtl = TextEditingController(
      text: e != null ? e.price.toString() : '',
    );
    _catCtl = TextEditingController(text: e?.category ?? 'Main');
    _prepTimeCtl = TextEditingController(
      text: e != null && e.prepTime != null ? e.prepTime.toString() : '',
    );
    _discountCtl = TextEditingController(
      text: e != null && e.discount > 0
          ? (e.discount * 100).round().toString()
          : '',
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _save() async {
    if (_nameCtl.text.isEmpty || _priceCtl.text.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final itemId = _isEditing ? widget.existingItem!.id : const Uuid().v4();
      String imageUrl = _isEditing ? widget.existingItem!.imageUrl : '';

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final storage = StorageService();
        imageUrl = await storage.uploadImageBytes(
          'menu_items/$itemId/photo.jpg',
          bytes,
        );
      }

      final discountPct = double.tryParse(_discountCtl.text) ?? 0;
      final item = MenuItemModel(
        id: itemId,
        restaurantId: widget.restaurantId,
        name: _nameCtl.text.trim(),
        description: _descCtl.text.trim(),
        price: double.tryParse(_priceCtl.text) ?? 0,
        prepTime: int.tryParse(_prepTimeCtl.text),
        category: _catCtl.text.trim(),
        imageUrl: imageUrl,
        discount: (discountPct.clamp(0, 99)) / 100,
      );

      if (!mounted) return;
      await context.read<RestaurantProvider>().saveMenuItem(item);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error: $e', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Menu Item' : 'Add Menu Item'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: _pickedImage != null
                      ? FutureBuilder<Uint8List>(
                          future: _pickedImage!.readAsBytes(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                snap.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            );
                          },
                        )
                      : (_isEditing && widget.existingItem!.imageUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.existingItem!.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (\$)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _catCtl,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount % (optional)',
                  hintText: 'e.g., 20 for 20% off',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prepTimeCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Preparation Time (mins, optional)',
                  hintText: 'e.g., 15 or leave blank',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ─── Offers Tab ──────────────────────────────────────────
class _OffersTab extends StatefulWidget {
  @override
  State<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<_OffersTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final restaurant = context.read<RestaurantProvider>().ownedRestaurant;
      if (restaurant != null) {
        context.read<RestaurantProvider>().listenToOffers(restaurant.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final restProv = context.watch<RestaurantProvider>();
    final allOffers = restProv.offers;
    final restaurant = restProv.ownedRestaurant;

    if (restaurant == null) return const SizedBox.shrink();

    final offers = allOffers.where((o) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          o.title.toLowerCase().contains(_searchQuery) ||
          o.description.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Active' && o.isActive) ||
          (_statusFilter == 'Inactive' && !o.isActive);
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Promotions'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showAddBundleDialog(context, restaurant.id),
            icon: const Icon(Icons.add),
            label: const Text('Add Bundle'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search offers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Status filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 0, 4),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All', 'Active', 'Inactive'].map((status) {
                  final isSelected = status == _statusFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _statusFilter = status),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Offers list
          Expanded(
            child: offers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allOffers.isEmpty
                              ? 'No offers yet'
                              : 'No offers match your search',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: offer.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: offer.imageUrl,
                                        fit: BoxFit.cover,
                                        width: 64,
                                        height: 64,
                                        placeholder: (ctx, url) => const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        errorWidget: (ctx, url, err) =>
                                            const Icon(
                                              Icons.auto_awesome,
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.primary,
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (offer.hasDiscount)
                                    Row(
                                      children: [
                                        Text(
                                          Helpers.formatPrice(
                                            offer.originalPrice,
                                          ),
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: AppColors.textHint,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${offer.itemIds.length} items • ${Helpers.formatPrice(offer.bundlePrice)}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '-${offer.discountPercentage}%',
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '${offer.itemIds.length} items • ${Helpers.formatPrice(offer.bundlePrice)}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.primary,
                              ),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _AddBundleDialog(
                                  restaurantId: restaurant.id,
                                  existingOffer: offer,
                                ),
                              ),
                            ),
                            Switch(
                              value: offer.isActive,
                              onChanged: (val) {
                                restProv.saveOffer(
                                  offer.copyWith(isActive: val),
                                );
                              },
                              activeThumbColor: AppColors.success,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () => restProv.deleteOffer(offer.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddBundleDialog(BuildContext context, String restaurantId) {
    showDialog(
      context: context,
      builder: (ctx) => _AddBundleDialog(restaurantId: restaurantId),
    );
  }
}

class _AddBundleDialog extends StatefulWidget {
  final String restaurantId;
  final OfferModel? existingOffer;
  const _AddBundleDialog({required this.restaurantId, this.existingOffer});

  @override
  State<_AddBundleDialog> createState() => _AddBundleDialogState();
}

class _AddBundleDialogState extends State<_AddBundleDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final List<String> _selectedItemIds;
  int _selectedColor = 0xFFE91E63; // Default Pink
  XFile? _pickedImage;
  bool _isLoading = false;
  bool get _isEditing => widget.existingOffer != null;
  final _itemSearchCtl = TextEditingController();
  String _itemSearchQuery = '';
  String _itemCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    final e = widget.existingOffer;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _priceController = TextEditingController(
      text: e != null ? e.bundlePrice.toString() : '',
    );
    _originalPriceController = TextEditingController(
      text: e != null && e.originalPrice > 0 ? e.originalPrice.toString() : '',
    );
    _selectedItemIds = List<String>.from(e?.itemIds ?? []);
    if (e?.color != null) {
      _selectedColor = e!.color!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = context.watch<RestaurantProvider>().menuItems;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Bundle' : 'Create New Bundle'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image picker
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 800,
                    maxHeight: 600,
                    imageQuality: 85,
                  );
                  if (picked != null) setState(() => _pickedImage = picked);
                },
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: _pickedImage != null
                      ? FutureBuilder<Uint8List>(
                          future: _pickedImage!.readAsBytes(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                snap.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            );
                          },
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add offer photo',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Bundle Title',
                  hintText: 'e.g. Lunch Special, Family Pack',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bundle Price (Sale Price)',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _originalPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Original Price (Optional)',
                        hintText: 'Sum of regular item prices',
                        prefixText: '\$ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      final menuItems = context
                          .read<RestaurantProvider>()
                          .menuItems;
                      double sum = 0;
                      for (final id in _selectedItemIds) {
                        final item = menuItems
                            .where((m) => m.id == id)
                            .firstOrNull;
                        if (item != null) sum += item.price;
                      }
                      _originalPriceController.text = sum.toStringAsFixed(2);
                    },
                    icon: const Icon(Icons.calculate, size: 16),
                    label: const Text('Auto-calc'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Color Picker
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Card Color',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final existingOffers = context
                      .read<RestaurantProvider>()
                      .offers;
                  final uniqueColors = existingOffers
                      .map((o) => o.color)
                      .where((c) => c != null)
                      .cast<int>()
                      .toSet()
                      .toList();

                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Pick a color'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ColorPicker(
                                pickerColor: Color(_selectedColor),
                                onColorChanged: (Color color) {
                                  setState(() => _selectedColor = color.value);
                                },
                                pickerAreaHeightPercent: 0.8,
                              ),
                              if (uniqueColors.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Saved Colors',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: uniqueColors.map((colorValue) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedColor = colorValue,
                                        );
                                        Navigator.of(dialogContext).pop();
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Color(colorValue),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.divider,
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Done'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(_selectedColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tap to pick a color',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.colorize,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Items to Include',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              // Item search bar
              TextField(
                controller: _itemSearchCtl,
                onChanged: (v) =>
                    setState(() => _itemSearchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _itemSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _itemSearchCtl.clear();
                            setState(() => _itemSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              // Category filter chips
              Builder(
                builder: (context) {
                  final cats = <String>{'All'};
                  for (final item in menuItems) {
                    if (item.category.isNotEmpty) cats.add(item.category);
                  }
                  if (cats.length <= 1) return const SizedBox.shrink();
                  return SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: cats.map((cat) {
                        final sel = cat == _itemCategoryFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _itemCategoryFilter = cat),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // Filtered item list
              Builder(
                builder: (context) {
                  final filtered = menuItems.where((item) {
                    final matchesSearch =
                        _itemSearchQuery.isEmpty ||
                        item.name.toLowerCase().contains(_itemSearchQuery);
                    final matchesCat =
                        _itemCategoryFilter == 'All' ||
                        item.category == _itemCategoryFilter;
                    return matchesSearch && matchesCat;
                  }).toList();
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              menuItems.isEmpty
                                  ? 'No menu items available'
                                  : 'No items match your search',
                              style: const TextStyle(color: AppColors.textHint),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isSelected = _selectedItemIds.contains(
                                item.id,
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemIds.add(item.id);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                                title: Text(item.name),
                                subtitle: Text(
                                  '${item.category} \u2022 ${Helpers.formatPrice(item.price)}',
                                ),
                                activeColor: AppColors.primary,
                                dense: true,
                              );
                            },
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveBundle,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create Bundle'),
        ),
      ],
    );
  }

  void _saveBundle() async {
    if (_titleController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedItemIds.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please fill all required fields and select items',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final offerId = _isEditing ? widget.existingOffer!.id : const Uuid().v4();
      String imageUrl = _isEditing ? widget.existingOffer!.imageUrl : '';

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final storage = StorageService();
        imageUrl = await storage.uploadImageBytes(
          'offers/$offerId/photo.jpg',
          bytes,
        );
      }

      // Resolve item names from provider
      final menuItems = context.read<RestaurantProvider>().menuItems;
      final itemNames = menuItems
          .where((item) => _selectedItemIds.contains(item.id))
          .map((item) => item.name)
          .toList();

      final offer = OfferModel(
        id: offerId,
        restaurantId: widget.restaurantId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        bundlePrice: double.tryParse(_priceController.text) ?? 0.0,
        originalPrice: double.tryParse(_originalPriceController.text) ?? 0.0,
        itemIds: _selectedItemIds,
        itemNames: itemNames,
        imageUrl: imageUrl,
        color: _selectedColor,
      );

      await context.read<RestaurantProvider>().saveOffer(offer);
      if (mounted) {
        Navigator.pop(context);
        Helpers.showSnackBar(
          context,
          _isEditing ? 'Bundle updated!' : 'Bundle offer created successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error creating bundle: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Settings Tab ──────────────────────────────────────────
class _SettingsTab extends StatefulWidget {
  final RestaurantModel restaurant;
  const _SettingsTab({required this.restaurant});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab>
    with AutomaticKeepAliveClientMixin {
  bool _uploadingIcon = false;
  bool _uploadingCover = false;
  bool _savingInfo = false;

  late final TextEditingController _nameCtl;
  late final TextEditingController _descCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _openTimeCtl;
  late final TextEditingController _closeTimeCtl;
  late final TextEditingController _deliveryMinCtl;
  late bool _isOpen;
  double? _pickedLat;
  double? _pickedLng;
  late String _selectedBusinessType;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameCtl = TextEditingController(text: r.name);
    _descCtl = TextEditingController(text: r.description);
    _phoneCtl = TextEditingController(text: r.phone);
    _addressCtl = TextEditingController(text: r.address);
    _openTimeCtl = TextEditingController(text: r.openTime);
    _closeTimeCtl = TextEditingController(text: r.closeTime);
    _deliveryMinCtl = TextEditingController(
      text: r.estimatedDeliveryMin.toString(),
    );
    _isOpen = r.isOpen;
    _selectedBusinessType = r.businessType;
  }

  Future<void> _pickAndUploadImage({
    required String storagePath,
    required String fieldName,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: fieldName == 'iconUrl' ? 256 : 1200,
      maxHeight: fieldName == 'iconUrl' ? 256 : 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      if (fieldName == 'iconUrl') {
        _uploadingIcon = true;
      } else {
        _uploadingCover = true;
      }
    });

    try {
      final bytes = await picked.readAsBytes();
      final storageService = StorageService();
      final url = await storageService.uploadImageBytes(storagePath, bytes);

      if (!mounted) return;
      await context.read<RestaurantProvider>().updateRestaurantField(
        widget.restaurant.id,
        {fieldName: url},
      );
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          if (fieldName == 'iconUrl') {
            _uploadingIcon = false;
          } else {
            _uploadingCover = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    final restaurant =
        context.watch<RestaurantProvider>().ownedRestaurant ??
        widget.restaurant;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand Icon Upload ───────────────────────────
          const Text(
            'Brand Icon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shown in the Brands section on the home screen',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: restaurant.iconUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: restaurant.iconUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (ctx, url, err) => const Icon(
                              Icons.store,
                              size: 40,
                              color: AppColors.textHint,
                            ),
                          ),
                        )
                      : !_uploadingIcon
                      ? const Icon(
                          Icons.store,
                          size: 40,
                          color: AppColors.textHint,
                        )
                      : null,
                ),
                if (_uploadingIcon)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _uploadingIcon
                          ? null
                          : () => _pickAndUploadImage(
                              storagePath:
                                  'restaurants/${restaurant.id}/icon.jpg',
                              fieldName: 'iconUrl',
                            ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Cover Photo Upload ─────────────────────────
          const Text(
            'Cover Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Banner image on your restaurant page',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _uploadingCover
                ? null
                : () => _pickAndUploadImage(
                    storagePath: 'restaurants/${restaurant.id}/cover.jpg',
                    fieldName: 'imageUrl',
                  ),
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _uploadingCover
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : restaurant.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: restaurant.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 180,
                            placeholder: (ctx, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (ctx, url, err) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load',
                                  style: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload cover photo',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const Divider(height: 48),

          // ── Restaurant Info (Editable) ─────────────────
          const Text(
            'Store Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Shop Name',
              prefixIcon: Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtl,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          // ── Business Type Dropdown ──
          Consumer<RestaurantProvider>(
            builder: (context, prov, _) {
              final types = prov.businessTypes;
              return DropdownButtonFormField<String>(
                value: types.any((t) => t.id == _selectedBusinessType)
                    ? _selectedBusinessType
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Business Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: types.map((bt) {
                  return DropdownMenuItem(
                    value: bt.id,
                    child: Row(
                      children: [
                        Icon(bt.iconData, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(bt.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBusinessType = val);
                },
              );
            },
          ),
          TextField(
            controller: _phoneCtl,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressCtl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final result = await Navigator.push<MapPickerResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPickerScreen(
                        title: 'Store Location',
                        initialLatitude: widget.restaurant.latitude != 0
                            ? widget.restaurant.latitude
                            : null,
                        initialLongitude: widget.restaurant.longitude != 0
                            ? widget.restaurant.longitude
                            : null,
                        initialAddress: _addressCtl.text,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _addressCtl.text = result.address;
                      _pickedLat = result.latitude;
                      _pickedLng = result.longitude;
                    });
                  }
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Map'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _openTimeCtl,
                  readOnly: true,
                  onTap: () async {
                    final parts = _openTimeCtl.text.split(':');
                    final initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 8,
                      minute:
                          int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                    );
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (picked != null) {
                      _openTimeCtl.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Opens At',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _closeTimeCtl,
                  readOnly: true,
                  onTap: () async {
                    final parts = _closeTimeCtl.text.split(':');
                    final initial = TimeOfDay(
                      hour: int.tryParse(parts[0]) ?? 22,
                      minute:
                          int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
                    );
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (picked != null) {
                      _closeTimeCtl.text =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Closes At',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _deliveryMinCtl,
            decoration: const InputDecoration(
              labelText: 'Estimated Delivery (minutes)',
              prefixIcon: Icon(Icons.delivery_dining_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Store Open'),
            subtitle: Text(_isOpen ? 'Accepting orders' : 'Currently closed'),
            value: _isOpen,
            onChanged: (val) => setState(() => _isOpen = val),
            activeColor: AppColors.success,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingInfo
                  ? null
                  : () async {
                      if (_nameCtl.text.trim().isEmpty) {
                        Helpers.showSnackBar(
                          context,
                          'Shop name is required',
                          isError: true,
                        );
                        return;
                      }
                      setState(() => _savingInfo = true);
                      try {
                        await context
                            .read<RestaurantProvider>()
                            .updateRestaurantField(widget.restaurant.id, {
                              'name': _nameCtl.text.trim(),
                              'description': _descCtl.text.trim(),
                              'phone': _phoneCtl.text.trim(),
                              'address': _addressCtl.text.trim(),
                              'latitude':
                                  _pickedLat ?? widget.restaurant.latitude,
                              'longitude':
                                  _pickedLng ?? widget.restaurant.longitude,
                              'openTime': _openTimeCtl.text.trim(),
                              'closeTime': _closeTimeCtl.text.trim(),
                              'estimatedDeliveryMin':
                                  int.tryParse(_deliveryMinCtl.text) ?? 30,
                              'isOpen': _isOpen,
                              'businessType': _selectedBusinessType,
                            });
                        if (mounted)
                          Helpers.showSnackBar(context, 'Settings saved!');
                      } catch (e) {
                        if (mounted)
                          Helpers.showSnackBar(
                            context,
                            'Save failed: $e',
                            isError: true,
                          );
                      } finally {
                        if (mounted) setState(() => _savingInfo = false);
                      }
                    },
              icon: _savingInfo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const Divider(height: 40),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HelpSupportScreen(userType: 'Store Owner'),
                  ),
                );
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('Help & Support'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => auth.signOut(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
