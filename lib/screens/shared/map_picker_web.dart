// Web implementation: interactive Google Maps via inline JS + postMessage
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Builds a draggable Google Map for web using the Maps JavaScript API.
Widget buildWebMap({
  required double initialLat,
  required double initialLng,
  required int zoom,
  required void Function(double lat, double lng) onCameraMove,
  required VoidCallback onCameraIdle,
}) {
  return _WebMapView(
    initialLat: initialLat,
    initialLng: initialLng,
    zoom: zoom,
    onCameraMove: onCameraMove,
    onCameraIdle: onCameraIdle,
  );
}

class _WebMapView extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final int zoom;
  final void Function(double lat, double lng) onCameraMove;
  final VoidCallback onCameraIdle;

  const _WebMapView({
    required this.initialLat,
    required this.initialLng,
    required this.zoom,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  @override
  State<_WebMapView> createState() => _WebMapViewState();
}

class _WebMapViewState extends State<_WebMapView> {
  late final String _viewType;
  late final String _mapId;
  Timer? _idleTimer;
  web.EventListener? _messageListener;

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _viewType = 'google-map-$ts';
    _mapId = 'gmap-$ts';

    // Listen for postMessage from the inline script
    _messageListener = ((web.Event event) {
      final msgEvent = event as web.MessageEvent;
      try {
        // msgEvent.data is JSAny?, NOT JSString — must convert safely
        final rawData = msgEvent.data;
        if (rawData == null) return;
        final dataStr = rawData.dartify();
        if (dataStr is! String) return;

        final data = json.decode(dataStr) as Map<String, dynamic>;
        if (data['type'] == 'map_center' && data['mapId'] == _mapId) {
          final lat = (data['lat'] as num).toDouble();
          final lng = (data['lng'] as num).toDouble();
          widget.onCameraMove(lat, lng);

          _idleTimer?.cancel();
          _idleTimer = Timer(const Duration(milliseconds: 300), () {
            widget.onCameraIdle();
          });
        }
      } catch (e) {
        // Not our message, or parse error — ignore
        debugPrint('Map message listener error: $e');
      }
    }).toJS;
    web.window.addEventListener('message', _messageListener!);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      container.style.setProperty('width', '100%');
      container.style.setProperty('height', '100%');

      // Create the map div
      final mapDiv = web.document.createElement('div') as web.HTMLDivElement;
      mapDiv.id = _mapId;
      mapDiv.style.setProperty('width', '100%');
      mapDiv.style.setProperty('height', '100%');
      container.appendChild(mapDiv);

      // Inject a <script> that creates the Google Map
      final script =
          web.document.createElement('script') as web.HTMLScriptElement;
      script.type = 'text/javascript';
      script.textContent = _buildMapScript();

      // Wait for the DOM to be ready, then initialize
      Future.delayed(const Duration(milliseconds: 300), () {
        web.document.body?.appendChild(script);
      });

      return container;
    });
  }

  String _buildMapScript() {
    return '''
(function() {
  function initMap() {
    var el = document.getElementById("$_mapId");
    if (!el) { setTimeout(initMap, 100); return; }
    if (!window.google || !window.google.maps) {
      console.error("Google Maps JS API not loaded");
      return;
    }
    var map = new google.maps.Map(el, {
      center: { lat: ${widget.initialLat}, lng: ${widget.initialLng} },
      zoom: ${widget.zoom},
      disableDefaultUI: true,
      zoomControl: true,
      gestureHandling: "greedy"
    });
    google.maps.event.addListener(map, "center_changed", function() {
      var c = map.getCenter();
      if (c) {
        window.postMessage(JSON.stringify({
          type: "map_center",
          mapId: "$_mapId",
          lat: c.lat(),
          lng: c.lng()
        }), "*");
      }
    });
  }
  initMap();
})();
''';
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
