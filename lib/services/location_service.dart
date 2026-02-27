import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus { granted, serviceDisabled, permissionDenied }

/// Utility service for GPS access and distance calculations.
class LocationService {
  /// Check and request location permissions. Returns true if granted.
  static Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Get the device's current GPS position.
  /// Returns null if permission denied or service unavailable.
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Calculate distance between two points (in meters).
  double getDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculate distance as a human-readable string.
  String getDistanceString(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final meters = getDistance(startLat, startLng, endLat, endLng);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  /// Request strictly "Always On" permission and status for drivers.
  static Future<LocationPermissionStatus>
  requestAlwaysPermissionStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // If we only have WhileInUse, try to request Always
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always) {
      return LocationPermissionStatus.granted;
    } else {
      return LocationPermissionStatus.permissionDenied;
    }
  }

  static Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();
  static Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Stream of location updates for live tracking
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
}
