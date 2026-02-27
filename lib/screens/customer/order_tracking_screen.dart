import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/helpers.dart';
import '../../services/firestore_service.dart';
import '../../services/route_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapCtl;
  final FirestoreService _fs = FirestoreService();

  List<LatLng> _routePoints = [];
  LatLng? _restaurantPos;
  bool _isLoadingRoute = false;
  LatLng?
  _lastFetchedDriverPos; // To avoid refetching route if driver hasn't moved much

  @override
  void initState() {
    super.initState();
    context.read<OrderProvider>().listenToOrder(widget.orderId);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    setState(() => _isLoadingRoute = true);
    final pts = await RouteService.getRoute(startLat, startLng, endLat, endLng);
    if (mounted) {
      setState(() => _routePoints = pts);
      _fitBounds(pts, LatLng(startLat, startLng), LatLng(endLat, endLng));
    }
  }

  void _fitBounds(List<LatLng> pts, LatLng start, LatLng end) {
    if (pts.isEmpty || _mapCtl == null) return;
    final allPoints = [...pts, start, end];
    final bounds = _boundsFromPoints(allPoints);
    _mapCtl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _loadRestaurant(String restId) async {
    if (_restaurantPos != null) return;
    final rest = await _fs.getRestaurant(restId);
    if (mounted) {
      setState(() {
        _restaurantPos = LatLng(rest.latitude, rest.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order')),
      body: Consumer<OrderProvider>(
        builder: (context, orderProv, _) {
          final order = orderProv.activeOrder;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final steps = [
            OrderStatus.placed,
            OrderStatus.accepted,
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.pickedUp,
            OrderStatus.delivered,
          ];
          final currentIdx = steps.indexOf(order.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Map visualization
                Builder(
                  builder: (context) {
                    final lat = order.driverLatitude;
                    final lng = order.driverLongitude;
                    final custLat = order.deliveryLatitude;
                    final custLng = order.deliveryLongitude;

                    LatLng? driverPos;
                    if (lat != null && lng != null) {
                      driverPos = LatLng(lat, lng);

                      // Trigger route calculation if needed
                      bool shouldFetch = false;
                      if (_lastFetchedDriverPos == null) {
                        shouldFetch = true;
                      } else {
                        final dist = Geolocator.distanceBetween(
                          _lastFetchedDriverPos!.latitude,
                          _lastFetchedDriverPos!.longitude,
                          driverPos.latitude,
                          driverPos.longitude,
                        );
                        if (dist > 50) {
                          shouldFetch = true;
                        }
                      }

                      if (shouldFetch) {
                        _lastFetchedDriverPos = driverPos;

                        if (order.status == OrderStatus.pickedUp ||
                            order.status == OrderStatus.accepted ||
                            order.status == OrderStatus.preparing ||
                            order.status == OrderStatus.ready) {
                          _loadRestaurant(order.restaurantId).then((_) {
                            if (_restaurantPos != null) {
                              _fetchRoute(
                                lat,
                                lng,
                                _restaurantPos!.latitude,
                                _restaurantPos!.longitude,
                              );
                            }
                          });
                        } else if (custLat != null && custLng != null) {
                          // Delivering
                          _fetchRoute(lat, lng, custLat, custLng);
                        }
                      }
                    }

                    // Fallback to customer pos if driver not found
                    LatLng centerPos =
                        driverPos ??
                        (custLat != null && custLng != null
                            ? LatLng(custLat, custLng)
                            : const LatLng(31.9539, 35.9106));

                    // Build markers
                    final markers = <Marker>{};
                    if (custLat != null && custLng != null) {
                      markers.add(
                        Marker(
                          markerId: const MarkerId('customer'),
                          position: LatLng(custLat, custLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'Delivery Location',
                          ),
                        ),
                      );
                    }
                    if (order.status == OrderStatus.pickedUp &&
                        _restaurantPos != null) {
                      markers.add(
                        Marker(
                          markerId: const MarkerId('restaurant'),
                          position: _restaurantPos!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: InfoWindow(title: order.restaurantName),
                        ),
                      );
                    }
                    if (driverPos != null) {
                      markers.add(
                        Marker(
                          markerId: const MarkerId('driver'),
                          position: driverPos,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: InfoWindow(
                            title: order.driverName ?? 'Driver',
                          ),
                        ),
                      );
                    }

                    // Build polylines
                    final polylines = <Polyline>{};
                    if (_routePoints.isNotEmpty) {
                      // Google Maps default route blue
                      const googleBlue = Color(0xFF4285F4);
                      polylines.add(
                        Polyline(
                          polylineId: const PolylineId('route_shadow'),
                          points: _routePoints,
                          color: googleBlue.withValues(alpha: 0.3),
                          width: 8,
                        ),
                      );
                      polylines.add(
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routePoints,
                          color: googleBlue,
                          width: 5,
                        ),
                      );
                    }

                    return Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: centerPos,
                              zoom: 15,
                            ),
                            onMapCreated: (controller) {
                              _mapCtl = controller;
                            },
                            markers: markers,
                            polylines: polylines,
                            myLocationEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            scrollGesturesEnabled: true,
                            zoomGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                          ),
                          if (_isLoadingRoute)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Status card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OrderStatus.displayName(order.status),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'From ${order.restaurantName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
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
                      if (order.driverName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Driver: ${order.driverName}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.phone,
                                color:
                                    (order.driverPhone != null &&
                                        order.driverPhone!.isNotEmpty)
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                size: 20,
                              ),
                              tooltip:
                                  (order.driverPhone != null &&
                                      order.driverPhone!.isNotEmpty)
                                  ? 'Call Driver'
                                  : 'No Phone Number',
                              onPressed:
                                  (order.driverPhone != null &&
                                      order.driverPhone!.isNotEmpty)
                                  ? () async {
                                      final uri = Uri.parse(
                                        'tel:${order.driverPhone}',
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
                      const SizedBox(height: 20),

                      // Step indicator
                      ...List.generate(steps.length, (i) {
                        final isCompleted = i <= currentIdx;
                        final isCurrent = i == currentIdx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCompleted
                                          ? AppColors.primary
                                          : AppColors.divider,
                                      border: isCurrent
                                          ? Border.all(
                                              color: AppColors.primary,
                                              width: 3,
                                            )
                                          : null,
                                    ),
                                    child: isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  if (i < steps.length - 1)
                                    Container(
                                      width: 2,
                                      height: 24,
                                      color: isCompleted
                                          ? AppColors.primary
                                          : AppColors.divider,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Text(
                                OrderStatus.displayName(steps[i]),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isCompleted
                                      ? AppColors.textPrimary
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Order summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.quantity}x ${item.name}'),
                              Text(
                                '\$${item.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '\$${order.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
