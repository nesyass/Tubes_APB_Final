import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../location_access.dart';
import '../map_config.dart';
import '../models/branch.dart';
import '../widgets/map_tile_error_overlay.dart';

class NavigationScreen extends StatefulWidget {
  final Branch branch;
  final LatLng? userPosition;

  const NavigationScreen({
    super.key,
    required this.branch,
    required this.userPosition,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  double _distanceRemaining = 0;
  double _initialDistance = 0;
  double _zoom = 15;
  bool _hasArrived = false;
  bool _mapReady = false;
  bool _tilesUnavailable = false;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;
    _calculateDistance();
    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final access = await ensureLocationAccess();
    if (!mounted) return;
    if (!access.canUseLocation) {
      _showLocationAccessMessage(access);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _handlePosition(position, moveCamera: false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi awal belum bisa dibaca')),
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) => _handlePosition(position),
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking GPS terhenti. Periksa izin lokasi.')),
        );
      },
    );
  }

  void _handlePosition(Position position, {bool moveCamera = true}) {
    if (!mounted) return;

    final newPos = LatLng(position.latitude, position.longitude);
    final dist = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.branch.latitude,
      widget.branch.longitude,
    );

    setState(() {
      _currentPosition = newPos;
      _distanceRemaining = dist;
      if (_initialDistance == 0) _initialDistance = dist;
      _hasArrived = dist < 50;
    });

    if (moveCamera && _mapReady) _mapController.move(newPos, _zoom);
  }

  void _showLocationAccessMessage(LocationAccessResult access) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(access.message),
          action: access.canOpenLocationSettings || access.canOpenAppSettings
              ? SnackBarAction(
                  label: 'Pengaturan',
                  onPressed: () => openLocationSettingsFor(access),
                )
              : null,
        ),
      );
    });
  }

  void _handleTileError(Object error) {
    if (_tilesUnavailable) return;
    debugPrint('OpenStreetMap tile error: $error');
    if (!mounted) return;
    setState(() => _tilesUnavailable = true);
  }

  void _retryTiles() {
    setState(() => _tilesUnavailable = false);
  }

  void _calculateDistance() {
    final origin = _origin;
    if (origin == null) return;
    final dist = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      widget.branch.latitude,
      widget.branch.longitude,
    );
    _distanceRemaining = dist;
    _initialDistance = dist;
    _hasArrived = dist < 50;
  }

  List<LatLng> get _routePoints {
    final origin = _origin;
    if (origin == null) return [];
    return [
      origin,
      LatLng(widget.branch.latitude, widget.branch.longitude),
    ];
  }

  LatLng? get _origin {
    return _currentPosition ?? widget.userPosition;
  }

  List<Marker> get _markers {
    final destination = LatLng(widget.branch.latitude, widget.branch.longitude);
    final markers = <Marker>[
      Marker(
        point: destination,
        width: 44,
        height: 44,
        child: const Icon(Icons.location_on, size: 42, color: Color(0xFF3B4BC8)),
      ),
    ];

    final origin = _origin;
    if (origin != null) {
      markers.add(
        Marker(
          point: origin,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  String get _distanceText {
    if (_origin == null) return '-';
    if (_distanceRemaining < 1000) return '${_distanceRemaining.toStringAsFixed(0)} m';
    return '${(_distanceRemaining / 1000).toStringAsFixed(1)} km';
  }

  String get _etaText {
    if (_origin == null) return '-';
    final minutes = (_distanceRemaining / 1000 / 30 * 60).round();
    if (minutes < 1) return '< 1 mnt';
    return '$minutes mnt';
  }

  String get _arrivalTime {
    if (_origin == null) return '-';
    final now = DateTime.now();
    final minutes = (_distanceRemaining / 1000 / 30 * 60).round();
    final arrival = now.add(Duration(minutes: minutes));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _zoomBy(double delta) {
    setState(() => _zoom = (_zoom + delta).clamp(3, 18));
    final center = _origin ?? LatLng(widget.branch.latitude, widget.branch.longitude);
    if (_mapReady) _mapController.move(center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(widget.branch.latitude, widget.branch.longitude);
    final initialCenter = _origin ?? destination;
    final hasRoute = _origin != null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: _zoom,
                    onMapReady: () => _mapReady = true,
                  ),
                  children: [
                    if (!_tilesUnavailable)
                      TileLayer(
                        urlTemplate: mapTileUrl,
                        userAgentPackageName: mapUserAgent,
                        errorTileCallback: (tile, error, stackTrace) => _handleTileError(error),
                      ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: const Color(0xFF3B4BC8),
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                if (_tilesUnavailable) MapTileErrorOverlay(onRetry: _retryTiles),
                Positioned(
                  top: 44,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                  ),
                ),
                Positioned(
                  top: 44,
                  right: 12,
                  child: Column(
                    children: [
                      _MapButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                      const SizedBox(height: 6),
                      _MapButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  if (!hasRoute)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.storefront, color: Color(0xFF3B4BC8), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lokasi cabang',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'GPS perangkat belum terbaca',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_hasArrived && hasRoute)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EAFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.navigation, color: Color(0xFF3B4BC8), size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Menuju ke tujuan',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      widget.branch.name,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _initialDistance > 0
                                  ? (1 - (_distanceRemaining / _initialDistance)).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B4BC8)),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_hasArrived && hasRoute)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _EtaInfo(label: 'Jarak tersisa', value: _distanceText),
                          _EtaInfo(label: 'Estimasi', value: _etaText, center: true),
                          _EtaInfo(label: 'Tiba pukul', value: _arrivalTime, right: true),
                        ],
                      ),
                    ),
                  if (_hasArrived)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B4BC8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flag, color: Color(0xFF3B4BC8), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Anda telah tiba',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.branch.name,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_hasArrived)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B4BC8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _EtaInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool center;
  final bool right;

  const _EtaInfo({
    required this.label,
    required this.value,
    this.center = false,
    this.right = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = right
        ? CrossAxisAlignment.end
        : center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
