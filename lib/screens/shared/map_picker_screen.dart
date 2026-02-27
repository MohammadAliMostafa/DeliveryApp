import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../utils/theme.dart';

// Conditional import for web platform
import 'map_picker_web.dart'
    if (dart.library.io) 'map_picker_native.dart'
    as platform_map;

/// Result returned from the map picker.
class MapPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// A full-screen map picker using Google Maps.
/// Automatically requests GPS access and centers on the user's location.
/// Uses native GoogleMap on mobile, and a JS-backed map on web.
class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String title;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.title = 'Pick Location',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  late final TextEditingController _addressCtl;
  late LatLng _center;
  bool _isMoving = false;
  bool _locating = true;

  // Default: Amman, Jordan
  static const _defaultLat = 31.9539;
  static const _defaultLng = 35.9106;

  @override
  void initState() {
    super.initState();
    _addressCtl = TextEditingController(text: widget.initialAddress ?? '');

    // Use provided initial location or default
    _center = LatLng(
      widget.initialLatitude ?? _defaultLat,
      widget.initialLongitude ?? _defaultLng,
    );

    // Auto-locate: if no saved location is provided, request GPS
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
    } else {
      // On web, skip GPS auto-locate (often blocked by browsers)
      _locating = false;
    }
  }

  Future<void> _autoLocate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null && mounted) {
        final gpsCenter = LatLng(position.latitude, position.longitude);
        setState(() {
          _center = gpsCenter;
          _locating = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: gpsCenter, zoom: 16),
          ),
        );
      } else {
        if (mounted) {
          setState(() => _locating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not get location. Please check permissions.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _addressCtl.dispose();
    super.dispose();
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      MapPickerResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        address: _addressCtl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: Stack(
        children: [
          // ── Map (platform-adaptive) ──
          kIsWeb
              ? platform_map.buildWebMap(
                  initialLat: _center.latitude,
                  initialLng: _center.longitude,
                  zoom: 15,
                  onCameraMove: (lat, lng) {
                    _center = LatLng(lat, lng);
                    if (!_isMoving) {
                      setState(() => _isMoving = true);
                    }
                  },
                  onCameraIdle: () {
                    if (_isMoving) {
                      setState(() => _isMoving = false);
                    }
                  },
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (position) {
                    _center = position.target;
                    if (!_isMoving) {
                      setState(() => _isMoving = true);
                    }
                  },
                  onCameraIdle: () {
                    if (_isMoving) {
                      setState(() => _isMoving = false);
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

          // ── Center Pin ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.translationValues(0, _isMoving ? -12 : 0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppColors.primary,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    // Pin shadow dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isMoving ? 6 : 4,
                      height: _isMoving ? 6 : 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Locating indicator ──
          if (_locating)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Getting your location...',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom Panel ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Address input
                    TextField(
                      controller: _addressCtl,
                      decoration: InputDecoration(
                        labelText: 'Address / Notes',
                        hintText: 'e.g. Building 5, Floor 3',
                        prefixIcon: const Icon(Icons.edit_location_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 1,
                    ),

                    const SizedBox(height: 14),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── My Location Button (mobile only) ──
          if (!kIsWeb)
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'locate_me',
                onPressed: _autoLocate,
                backgroundColor: Colors.white,
                child: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
