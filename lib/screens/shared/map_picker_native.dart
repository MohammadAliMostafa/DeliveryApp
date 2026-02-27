// Native stub: never called on non-web platforms.
// The map_picker_screen.dart uses GoogleMap widget directly for native.
import 'package:flutter/material.dart';

Widget buildWebMap({
  required double initialLat,
  required double initialLng,
  required int zoom,
  required void Function(double lat, double lng) onCameraMove,
  required VoidCallback onCameraIdle,
}) {
  // This should never be called on native platforms since
  // map_picker_screen.dart checks kIsWeb before calling this.
  return const Center(child: Text('Map not available on this platform'));
}
