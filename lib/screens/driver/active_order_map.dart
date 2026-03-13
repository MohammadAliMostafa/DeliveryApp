import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

class ActiveOrderMap extends StatefulWidget {
  final OrderModel order;
  const ActiveOrderMap({super.key, required this.order});

  @override
  State<ActiveOrderMap> createState() => _ActiveOrderMapState();
}

class _ActiveOrderMapState extends State<ActiveOrderMap> {
  GoogleMapController? _mapCtl;
  final FirestoreService _fs = FirestoreService();

  LatLng? _driverPos;
  LatLng? _restaurantPos;
  LatLng? _customerPos;

  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  StreamSubscription? _locSub;
  LatLng? _lastFetchedDriverPos;

  @override
  void initState() {
    super.initState();
    _initPositions();
    _listenToLocation();
  }

  @override
  void didUpdateWidget(ActiveOrderMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.status != widget.order.status) {
      // Re-fetch route if status changes from pickingUp to delivering
      _fetchRoute();
    }
  }

  void _initPositions() {
    final user = context.read<AuthProvider>().user;
    if (user?.latitude != null && user?.longitude != null) {
      _driverPos = LatLng(user!.latitude!, user.longitude!);
    }

    if (widget.order.deliveryLatitude != null &&
        widget.order.deliveryLongitude != null) {
      _customerPos = LatLng(
        widget.order.deliveryLatitude!,
        widget.order.deliveryLongitude!,
      );
    }

    _fetchRoute();
  }

  void _listenToLocation() {
    _locSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;

      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _driverPos = newPos;
      });

      // Recalculate route if driver has moved more than 50 meters
      if (_lastFetchedDriverPos != null) {
        final dist = Geolocator.distanceBetween(
          _lastFetchedDriverPos!.latitude,
          _lastFetchedDriverPos!.longitude,
          newPos.latitude,
          newPos.longitude,
        );
        if (dist > 50) {
          _fetchRoute();
        }
      } else {
        // Initial fetch
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_driverPos == null) return;

    setState(() => _isLoadingRoute = true);

    LatLng? target;
    final isPickingUp = widget.order.status == OrderStatus.ready;

    if (isPickingUp) {
      // Fetch restaurant location first since it's not in OrderModel directly
      final restDoc = await _fs.getRestaurant(widget.order.restaurantId);

      target = LatLng(restDoc.latitude, restDoc.longitude);
      _restaurantPos = target;
    } else {
      target = _customerPos;
    }

    if (target != null) {
      final pts = await RouteService.getRoute(
        _driverPos!.latitude,
        _driverPos!.longitude,
        target.latitude,
        target.longitude,
      );
      if (mounted) {
        setState(() {
          _routePoints = pts;
          _lastFetchedDriverPos = _driverPos;
        });
        _fitBounds();
      }
    }

    if (mounted) setState(() => _isLoadingRoute = false);
  }

  void _fitBounds() {
    if (_routePoints.isEmpty && _driverPos == null) return;
    if (_mapCtl == null) return;

    final points = <LatLng>[
      if (_driverPos != null) _driverPos!,
      if (_restaurantPos != null) _restaurantPos!,
      if (_customerPos != null) _customerPos!,
      ..._routePoints,
    ];

    if (points.isEmpty) return;

    final bounds = _boundsFromPoints(points);
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

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  // Google Maps default route blue color
  static const _googleBlue = Color(0xFF4285F4);

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final driverStatus = context.read<AuthProvider>().user?.driverStatus;

    // Driver position is shown via the native blue dot (myLocationEnabled)
    // so we don't add a manual driver marker.

    if (_restaurantPos != null && driverStatus == DriverStatus.pickingUp) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Store'),
        ),
      );
    }

    if (_customerPos != null && driverStatus != DriverStatus.pickingUp) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Customer'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route_shadow'),
        points: _routePoints,
        color: _googleBlue.withValues(alpha: 0.3),
        width: 8,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: _googleBlue,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverPos ?? const LatLng(31.9539, 35.9106),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapCtl = controller;
              // Fit bounds once map is ready
              Future.delayed(const Duration(milliseconds: 300), _fitBounds);
            },
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
          ),
          if (_isLoadingRoute)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Floating Re-center Button
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_driver_map',
              onPressed: _fitBounds,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.center_focus_strong,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
