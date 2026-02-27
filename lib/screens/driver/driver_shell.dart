import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../shared/help_support_screen.dart';
import 'active_order_map.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _DriverHomeTab(),
      const _DriverEarningsTab(),
      const _DriverProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─── Driver Home Tab ─────────────────────────────────────────
class _DriverHomeTab extends StatefulWidget {
  const _DriverHomeTab();

  @override
  State<_DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<_DriverHomeTab>
    with WidgetsBindingObserver {
  final FirestoreService _fs = FirestoreService();

  StreamSubscription? _ordersSub;
  StreamSubscription? _driversSub;
  StreamSubscription? _locationSub;
  Timer? _offlineTimer;

  List<OrderModel> _availableOrders = [];
  List<Map<String, dynamic>> _onlineDrivers = [];
  bool _isOnline = false;
  bool _toggling = false;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer initialization slightly to ensure AuthProvider is fully populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDriverState();
    });
  }

  void _initDriverState() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      if (user.driverStatus == DriverStatus.pickingUp ||
          user.driverStatus == DriverStatus.delivering) {
        // Driver has an active order -> keep online and continue tracking
        setState(() => _isOnline = true);
        _startListening();
        _startLocationStream(user.uid);
      } else if (user.driverStatus == DriverStatus.online) {
        // Driver was online but has no active order -> explicitly force offline on restart
        setState(() => _isOnline = false);
        await _fs.updateDriverStatus(user.uid, DriverStatus.idle);
        final updated = user.copyWith(driverStatus: DriverStatus.idle);
        if (mounted) {
          await context.read<AuthProvider>().updateProfile(updated);
        }
      } else {
        // Driver is already idle
        setState(() => _isOnline = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ordersSub?.cancel();
    _driversSub?.cancel();
    _locationSub?.cancel();
    _offlineTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // User requested 1-minute grace period before taking driver offline
      _offlineTimer?.cancel();
      _offlineTimer = Timer(const Duration(minutes: 1), () {
        _goOfflineQuietly();
      });
    } else if (state == AppLifecycleState.resumed) {
      // Driver came back before 1 minute elapsed
      _offlineTimer?.cancel();
    }
  }

  /// Silently set the driver offline in Firestore (fire-and-forget).
  void _goOfflineQuietly() {
    if (!_isOnline) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // Do not force offline if the driver is currently handling an order
    if (user.driverStatus == DriverStatus.pickingUp ||
        user.driverStatus == DriverStatus.delivering) {
      return;
    }

    _fs.updateDriverStatus(user.uid, DriverStatus.idle);
    _isOnline = false;
    _stopListening();
  }

  void _startLocationStream(String uid) {
    _locationSub?.cancel();
    _locationSub = LocationService.getPositionStream().listen((pos) {
      if (!_isOnline) return;

      // Update our online location
      _fs.updateUserLocation(uid, pos.latitude, pos.longitude);

      // If we are actively assigned to an order, push the location there too
      final user = context.read<AuthProvider>().user;
      if (user != null && user.currentOrderId != null) {
        try {
          _fs.updateDriverLocation(
            user.currentOrderId!,
            pos.latitude,
            pos.longitude,
          );
        } catch (e) {
          // If this fails (e.g., permission-denied because order was deleted/hidden),
          // gracefully reset the driver's state to idle to prevent endless crashing.
          debugPrint('Failed to update driver location: $e');
          _fs.updateDriverStatus(user.uid, DriverStatus.idle);
          final resetUser = user.copyWith(
            driverStatus: DriverStatus.idle,
            currentOrderId: null,
          );
          if (mounted) {
            context.read<AuthProvider>().updateProfile(resetUser);
          }
        }
      }
    });
  }

  void _startListening() {
    _ordersSub?.cancel();
    _driversSub?.cancel();

    _ordersSub = _fs.getAvailableOrdersForDriver().listen((orders) {
      if (mounted) setState(() => _availableOrders = orders);
    });

    _driversSub = _fs.getOnlineIdleDrivers().listen((drivers) {
      if (mounted) setState(() => _onlineDrivers = drivers);
    });
  }

  void _stopListening() {
    _ordersSub?.cancel();
    _driversSub?.cancel();
    _locationSub?.cancel();
    _ordersSub = null;
    _driversSub = null;
    _locationSub = null;
    if (mounted) {
      setState(() {
        _availableOrders = [];
        _onlineDrivers = [];
      });
    }
  }

  /// Filter orders: only show if this driver is among the top 5 closest.
  List<OrderModel> get _filteredOrders {
    final user = context.read<AuthProvider>().user;
    if (user == null || user.latitude == null || user.longitude == null) {
      return _availableOrders; // No driver location → show all
    }
    final myUid = user.uid;
    final myLat = user.latitude!;
    final myLng = user.longitude!;

    return _availableOrders.where((order) {
      // Orders without delivery coords → show to everyone
      if (order.deliveryLatitude == null || order.deliveryLongitude == null) {
        return true;
      }
      final orderLat = order.deliveryLatitude!;
      final orderLng = order.deliveryLongitude!;

      // Build list of (driverId, distance) for all online drivers
      final driverDistances = <_DriverDist>[];
      for (final d in _onlineDrivers) {
        final dLat = (d['latitude'] as num?)?.toDouble();
        final dLng = (d['longitude'] as num?)?.toDouble();
        if (dLat == null || dLng == null) continue;
        final dist = Geolocator.distanceBetween(dLat, dLng, orderLat, orderLng);
        driverDistances.add(_DriverDist(d['uid'] as String? ?? '', dist));
      }

      // Add self if not in the online drivers list
      if (!driverDistances.any((dd) => dd.uid == myUid)) {
        final myDist = Geolocator.distanceBetween(
          myLat,
          myLng,
          orderLat,
          orderLng,
        );
        driverDistances.add(_DriverDist(myUid, myDist));
      }

      // Sort by distance ascending
      driverDistances.sort((a, b) => a.meters.compareTo(b.meters));

      // Am I in the top 5?
      final top5 = driverDistances.take(5).map((dd) => dd.uid);
      return top5.contains(myUid);
    }).toList();
  }

  Future<void> _toggleOnline(bool goOnline) async {
    if (_toggling) return;
    setState(() => _toggling = true);

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      setState(() => _toggling = false);
      return;
    }

    // Prevent going offline if currently handling an order
    if (!goOnline &&
        (user.driverStatus == DriverStatus.pickingUp ||
            user.driverStatus == DriverStatus.delivering)) {
      setState(() => _toggling = false);
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'You cannot go offline while delivering an active order.',
          isError: true,
        );
      }
      return;
    }

    try {
      if (goOnline) {
        // Enforce Always On permission before allowing online state
        final status = await LocationService.requestAlwaysPermissionStatus();
        if (status != LocationPermissionStatus.granted) {
          if (mounted) {
            setState(() => _toggling = false);
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Location Required'),
                content: Text(
                  status == LocationPermissionStatus.serviceDisabled
                      ? 'Please turn on your device\'s location services to go online.'
                      : 'You must grant "Always" location access to receive orders and track deliveries.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (status == LocationPermissionStatus.serviceDisabled) {
                        LocationService.openLocationSettings();
                      } else {
                        LocationService.openAppSettings();
                      }
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        // Get GPS and save coords before going online
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          await _fs.updateUserLocation(
            auth.user!.uid,
            pos.latitude,
            pos.longitude,
          );
        }
        await _fs.updateDriverStatus(auth.user!.uid, DriverStatus.online);
        final updated = auth.user!.copyWith(
          driverStatus: DriverStatus.online,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
        );
        await auth.updateProfile(updated);
        _startListening();
        _startLocationStream(auth.user!.uid);
      } else {
        await _fs.updateDriverStatus(auth.user!.uid, DriverStatus.idle);
        final updated = auth.user!.copyWith(driverStatus: DriverStatus.idle);
        await auth.updateProfile(updated);
        _stopListening();
      }
      setState(() => _isOnline = goOnline);
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Failed to update status', isError: true);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _acceptOrder(OrderModel order) async {
    if (_accepting) return;
    setState(() => _accepting = true);

    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      setState(() => _accepting = false);
      return;
    }

    try {
      // Transaction-based claim (race-safe)
      final success = await _fs.assignDriver(
        order.id,
        auth.user!.uid,
        auth.user!.name,
        auth.user!.phone.isNotEmpty ? auth.user!.phone : null,
      );

      if (!success) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Order already taken by another driver',
            isError: true,
          );
        }
        setState(() => _accepting = false);
        return;
      }

      // Update driver status
      await _fs.updateDriverStatus(auth.user!.uid, DriverStatus.pickingUp);
      await _fs.updateDriverCurrentOrder(auth.user!.uid, order.id);

      final updated = auth.user!.copyWith(
        driverStatus: DriverStatus.pickingUp,
        currentOrderId: order.id,
      );
      await auth.updateProfile(updated);

      if (mounted) {
        Helpers.showSnackBar(context, 'Order accepted! Head to restaurant.');
      }
    } catch (_) {
      // Connection errors (offline) are caught here
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Cannot accept order — check your connection',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  double _distanceToOrder(OrderModel order) {
    final user = context.read<AuthProvider>().user;
    if (user?.latitude == null || user?.longitude == null) return -1;
    if (order.deliveryLatitude == null || order.deliveryLongitude == null)
      return -1;
    return Geolocator.distanceBetween(
      user!.latitude!,
      user.longitude!,
      order.deliveryLatitude!,
      order.deliveryLongitude!,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 0) return '';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  Future<void> _confirmPickup(OrderModel order) async {
    setState(() => _accepting = true);
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      await _fs.updateOrderStatus(order.id, 'delivering');
      await _fs.updateDriverStatus(auth.user!.uid, DriverStatus.delivering);
      final updated = auth.user!.copyWith(
        driverStatus: DriverStatus.delivering,
      );
      await auth.updateProfile(updated);
      if (mounted)
        Helpers.showSnackBar(context, 'Order picked up! Head to customer.');
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _confirmDelivery(OrderModel order) async {
    setState(() => _accepting = true);
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    try {
      await _fs.updateOrderStatus(order.id, 'delivered');
      await _fs.updateDriverStatus(auth.user!.uid, DriverStatus.idle);
      final updated = auth.user!.copyWith(
        driverStatus: DriverStatus.idle,
        currentOrderId: null,
      );
      await auth.updateProfile(updated);
      if (mounted)
        Helpers.showSnackBar(context, 'Order delivered successfully!');
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _forceResetState() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    try {
      await _fs.updateDriverStatus(user.uid, DriverStatus.idle);
      final resetUser = user.copyWith(
        driverStatus: DriverStatus.idle,
        currentOrderId: null,
      );
      await auth.updateProfile(resetUser);

      setState(() => _isOnline = false);
      _stopListening();

      if (mounted) {
        Helpers.showSnackBar(context, 'Driver state manually reset to Idle.');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Reset failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final status = user?.driverStatus ?? DriverStatus.idle;
    final hasActiveOrder =
        status == DriverStatus.pickingUp || status == DriverStatus.delivering;
    final orders = _filteredOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(user?.name ?? 'Driver', status, hasActiveOrder),
            const SizedBox(height: 8),

            // ── Active Order Banner ──
            if (hasActiveOrder && user?.currentOrderId != null)
              Expanded(
                child: StreamBuilder<OrderModel>(
                  stream: _fs.getOrderStream(user!.currentOrderId!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildActiveOrderBanner(status, snapshot.data!),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'Available Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_isOnline && orders.isNotEmpty)
                      Text(
                        '${orders.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Order List ──
              Expanded(
                child: !_isOnline
                    ? _buildOfflineState()
                    : orders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: orders.length,
                        itemBuilder: (_, i) {
                          final order = orders[i];
                          final dist = _distanceToOrder(order);
                          return _OrderCard(
                            order: order,
                            distance: dist >= 0 ? _formatDistance(dist) : null,
                            onAccept: () => _acceptOrder(order),
                            accepting: _accepting,
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String status, bool hasActiveOrder) {
    final bool isActive = _isOnline;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [AppColors.primary, AppColors.accent]
              : [const Color(0xFF4B5563), const Color(0xFF374151)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.primary : Colors.grey).withValues(
              alpha: 0.3,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasActiveOrder)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Force Reset Status',
                  onPressed: _forceResetState,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActive ? 'Receiving orders' : 'Go online to receive orders',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              _toggling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Switch(
                      value: isActive,
                      onChanged: hasActiveOrder
                          ? null
                          : (val) => _toggleOnline(val),
                      activeColor: Colors.white,
                      activeTrackColor: AppColors.success,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderBanner(String status, OrderModel? activeOrder) {
    if (activeOrder == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Name
          Row(
            children: [
              const Icon(Icons.storefront, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: activeOrder.restaurantName,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Text(
                    activeOrder.restaurantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Banner part
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  status == DriverStatus.pickingUp
                      ? Icons.store
                      : Icons.delivery_dining,
                  color: AppColors.info,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status == DriverStatus.pickingUp
                        ? 'Head to restaurant for pickup'
                        : 'Delivering to customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Map part
          ActiveOrderMap(order: activeOrder),
          const SizedBox(height: 12),
          // Receipt part
          _buildOrderReceipt(status, activeOrder),
        ],
      ),
    );
  }

  Widget _buildOrderReceipt(String status, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Order for ${order.customerName}',
                  triggerMode: TooltipTriggerMode.tap,
                  child: Text(
                    'Order for ${order.customerName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.phone,
                  color:
                      (order.customerPhone != null &&
                          order.customerPhone!.isNotEmpty)
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
                tooltip:
                    (order.customerPhone != null &&
                        order.customerPhone!.isNotEmpty)
                    ? 'Call Customer'
                    : 'No Phone Number',
                onPressed:
                    (order.customerPhone != null &&
                        order.customerPhone!.isNotEmpty)
                    ? () async {
                        final uri = Uri.parse('tel:${order.customerPhone}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          try {
                            await launchUrl(uri);
                          } catch (e) {
                            if (context.mounted) {
                              Helpers.showSnackBar(
                                context,
                                'Could not launch dialer.',
                                isError: true,
                              );
                            }
                          }
                        }
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '#${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total to Collect',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _accepting
                  ? null
                  : () {
                      if (status == DriverStatus.pickingUp) {
                        _confirmPickup(order);
                      } else {
                        _confirmDelivery(order);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _accepting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      status == DriverStatus.pickingUp
                          ? 'Confirm Picked Up'
                          : 'Confirm Delivered',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'You\'re Offline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toggle the switch above to start\nreceiving delivery orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No orders nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New orders will appear here automatically',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case DriverStatus.online:
        return 'Online';
      case DriverStatus.pickingUp:
        return 'Picking Up';
      case DriverStatus.delivering:
        return 'Delivering';
      default:
        return 'Offline';
    }
  }
}

class _DriverDist {
  final String uid;
  final double meters;
  const _DriverDist(this.uid, this.meters);
}

// ─── Order Card ─────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final String? distance;
  final VoidCallback onAccept;
  final bool accepting;

  const _OrderCard({
    required this.order,
    this.distance,
    required this.onAccept,
    this.accepting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant + Price
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tooltip(
                        message: order.restaurantName,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Text(
                          order.restaurantName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Helpers.formatPrice(order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.phone,
                        color:
                            (order.restaurantPhone != null &&
                                order.restaurantPhone!.isNotEmpty)
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      tooltip:
                          (order.restaurantPhone != null &&
                              order.restaurantPhone!.isNotEmpty)
                          ? 'Call Restaurant'
                          : 'No Phone Number',
                      onPressed:
                          (order.restaurantPhone != null &&
                              order.restaurantPhone!.isNotEmpty)
                          ? () async {
                              final uri = Uri.parse(
                                'tel:${order.restaurantPhone}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                try {
                                  await launchUrl(uri);
                                } catch (e) {
                                  if (context.mounted) {
                                    Helpers.showSnackBar(
                                      context,
                                      'Could not launch dialer.',
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Info chips
                Row(
                  children: [
                    _infoChip(
                      Icons.shopping_bag_outlined,
                      '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                    ),
                    if (distance != null) ...[
                      const SizedBox(width: 8),
                      _infoChip(Icons.near_me_outlined, distance!),
                    ],
                  ],
                ),
                if (order.deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Tooltip(
                        message: order.customerName,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Text(
                          order.customerName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.phone,
                        color:
                            (order.customerPhone != null &&
                                order.customerPhone!.isNotEmpty)
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                      tooltip:
                          (order.customerPhone != null &&
                              order.customerPhone!.isNotEmpty)
                          ? 'Call Customer'
                          : 'No Phone Number',
                      onPressed:
                          (order.customerPhone != null &&
                              order.customerPhone!.isNotEmpty)
                          ? () async {
                              final uri = Uri.parse(
                                'tel:${order.customerPhone}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                try {
                                  await launchUrl(uri);
                                } catch (e) {
                                  if (context.mounted) {
                                    Helpers.showSnackBar(
                                      context,
                                      'Could not launch dialer.',
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Accept button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FilledButton(
              onPressed: accepting ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: accepting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Accept Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Earnings Tab ─────────────────────────────────────────
class _DriverEarningsTab extends StatefulWidget {
  const _DriverEarningsTab();

  @override
  State<_DriverEarningsTab> createState() => _DriverEarningsTabState();
}

class _DriverEarningsTabState extends State<_DriverEarningsTab> {
  final FirestoreService _fs = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: Text('User not found.'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Earnings & History')),
      body: StreamBuilder<List<OrderModel>>(
        stream: _fs.getDriverDeliveredOrders(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allOrders = snapshot.data ?? [];

          double totalEarnings = 0;
          double todayEarnings = 0;
          final now = DateTime.now();

          for (final order in allOrders) {
            totalEarnings += order.deliveryFee;
            if (order.updatedAt.year == now.year &&
                order.updatedAt.month == now.month &&
                order.updatedAt.day == now.day) {
              todayEarnings += order.deliveryFee;
            }
          }

          // Filter by search query
          final filteredOrders = allOrders.where((order) {
            final q = _searchQuery.toLowerCase();
            return order.id.toLowerCase().contains(q) ||
                order.restaurantName.toLowerCase().contains(q) ||
                order.customerName.toLowerCase().contains(q);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _EarningsCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Earnings',
                      value: '\$${totalEarnings.toStringAsFixed(2)}',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EarningsCard(
                      icon: Icons.today_outlined,
                      label: 'Today',
                      value: '\$${todayEarnings.toStringAsFixed(2)}',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _EarningsCard(
                icon: Icons.delivery_dining_outlined,
                label: 'Total Deliveries',
                value: '${allOrders.length}',
                color: AppColors.info,
                fullWidth: true,
              ),

              const SizedBox(height: 24),

              // History Header & Search
              const Text(
                'Order History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by ID, Restaurant, or Customer',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textHint,
                  ),
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
              const SizedBox(height: 16),

              // Orders List
              if (filteredOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      'No deliveries found',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _OrderHistoryCard(order: filteredOrders[index]);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final OrderModel order;
  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    // Simple date formatting
    final date = order.updatedAt;
    final dateString = '${date.month}/${date.day}/${date.year}';
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final rawHour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minuteStr = date.minute.toString().padLeft(2, '0');
    final timeString = '$rawHour:$minuteStr $amPm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dateString at $timeString',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '+\$${order.deliveryFee.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.storefront, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${order.id.substring(0, 8)}',
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _EarningsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Driver Profile Tab ─────────────────────────────────────
class _DriverProfileTab extends StatelessWidget {
  const _DriverProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                Helpers.getInitials(user?.name ?? '?'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Driver',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),

            // Edit Name
            _profileTile(
              icon: Icons.person_outline,
              title: 'Name',
              subtitle: user?.name ?? 'Set your name',
              onTap: () =>
                  _editProfile(context, 'Name', user?.name ?? '', (val) {
                    if (user != null) {
                      auth.updateProfile(user.copyWith(name: val));
                    }
                  }),
            ),

            // Edit Phone
            _profileTile(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              subtitle: user?.phone ?? 'Add phone number',
              onTap: () => _editProfile(
                context,
                'Phone Number',
                user?.phone ?? '',
                (val) {
                  if (user != null) {
                    auth.updateProfile(user.copyWith(phone: val));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Help & Support
            _profileTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help from our team',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpSupportScreen(userType: 'Driver'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Sign out
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile(
    BuildContext context,
    String field,
    String currentValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: field,
            hintText: 'Enter new $field',
          ),
          autofocus: true,
          keyboardType: field == 'Phone Number'
              ? TextInputType.phone
              : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}
