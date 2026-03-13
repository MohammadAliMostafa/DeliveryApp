import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';

class AdminDriverMap extends StatefulWidget {
  const AdminDriverMap({super.key});

  @override
  State<AdminDriverMap> createState() => _AdminDriverMapState();
}

class _AdminDriverMapState extends State<AdminDriverMap> {
  final FirestoreService _firestore = FirestoreService();
  final MapController _mapController = MapController();

  List<UserModel> _onlineDrivers = [];
  StreamSubscription? _driversSub;
  bool _isMapReady = false;

  // Default center if no drivers are active (NYC for example, or could use geolocation)
  final LatLng _defaultCenter = const LatLng(40.7128, -74.0060);

  @override
  void initState() {
    super.initState();
    _listenToDrivers();
  }

  void _listenToDrivers() {
    // Only fetch drivers. We'll filter the online ones in the listener to avoid
    // needing a complex composite index if one isn't perfectly set up.
    _driversSub = _firestore.getAllUsers().listen((users) {
      if (!mounted) return;

      final drivers = users
          .where(
            (u) =>
                u.role == UserRoles.driver &&
                u.driverStatus != null &&
                u.driverStatus != DriverStatus.idle &&
                u.latitude != null &&
                u.longitude != null,
          )
          .toList();

      setState(() {
        _onlineDrivers = drivers;
      });

      // Auto zoom to fit all drivers if there are any
      if (drivers.isNotEmpty) {
        _fitMapToBounds(drivers);
      }
    });
  }

  void _fitMapToBounds(List<UserModel> drivers) {
    if (drivers.isEmpty || !_isMapReady) return;

    if (drivers.length == 1) {
      _mapController.move(
        LatLng(drivers.first.latitude!, drivers.first.longitude!),
        14.0,
      );
      return;
    }

    // Find bounding box
    double minLat = drivers.first.latitude!;
    double maxLat = drivers.first.latitude!;
    double minLng = drivers.first.longitude!;
    double maxLng = drivers.first.longitude!;

    for (var d in drivers) {
      if (d.latitude! < minLat) minLat = d.latitude!;
      if (d.latitude! > maxLat) maxLat = d.latitude!;
      if (d.longitude! < minLng) minLng = d.longitude!;
      if (d.longitude! > maxLng) maxLng = d.longitude!;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Only set camera if bounds are valid and map is ready
    try {
      // Pad the bounds so markers aren't right on the edge
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    } catch (e) {
      // Map might not be fully initialized yet on the very first tick
    }
  }

  @override
  void dispose() {
    _driversSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case DriverStatus.online:
        return AppColors.success;
      case DriverStatus.pickingUp:
        return AppColors.warning;
      case DriverStatus.delivering:
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12.0,
                onMapReady: () {
                  _isMapReady = true;
                  if (_onlineDrivers.isNotEmpty) {
                    _fitMapToBounds(_onlineDrivers);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                  userAgentPackageName: 'com.deliveryapp.adminmap',
                ),
                MarkerLayer(
                  markers: _onlineDrivers.map((driver) {
                    return Marker(
                      point: LatLng(driver.latitude!, driver.longitude!),
                      width: 120,
                      height: 80,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              driver.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.delivery_dining,
                            color: _getStatusColor(driver.driverStatus),
                            size: 32,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delivery_dining,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_onlineDrivers.length} Active',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
