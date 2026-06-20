import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../user/dashboard.dart';
import '../map_config.dart';
import '../models/branch.dart';
import '../widgets/map_tile_error_overlay.dart';
import 'navigation_screen.dart';

class BranchDetailScreen extends StatefulWidget {
  final Branch branch;
  final LatLng? userPosition;

  const BranchDetailScreen({
    super.key,
    required this.branch,
    required this.userPosition,
  });

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  final MapController _mapController = MapController();
  bool _tilesUnavailable = false;

  LatLng? get _realUserPosition => widget.userPosition;

  List<Marker> get _markers {
    final markers = <Marker>[
      Marker(
        point: LatLng(widget.branch.latitude, widget.branch.longitude),
        width: 44,
        height: 44,
        child:
            const Icon(Icons.location_on, size: 42, color: Color(0xFF2E4CB9)),
      ),
    ];

    final userPosition = _realUserPosition;
    if (userPosition != null) {
      markers.add(
        Marker(
          point: userPosition,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  String _getDistanceText() {
    final userPosition = _realUserPosition;
    if (userPosition == null) return '-';
    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      widget.branch.latitude,
      widget.branch.longitude,
    );
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _getEtaText() {
    final userPosition = _realUserPosition;
    if (userPosition == null) return '-';
    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      widget.branch.latitude,
      widget.branch.longitude,
    );
    final minutes = (meters / 1000 / 30 * 60).round();
    if (minutes < 1) return '< 1 mnt';
    return '~$minutes mnt';
  }

  void _openInAppNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          branch: widget.branch,
          userPosition: _realUserPosition,
        ),
      ),
    );
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

  void _selectBranchForOrder() {
    final branchId = int.tryParse(widget.branch.id);
    if (branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cabang ini belum bisa dipakai untuk pesanan')),
      );
      return;
    }

    SessionManager.selectBranch(
      BranchModel(
        id: branchId,
        name: widget.branch.name,
        address: widget.branch.address,
        latitude: widget.branch.latitude,
        longitude: widget.branch.longitude,
        isOpen: widget.branch.isOpen,
        openHours: widget.branch.openHours,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(branch.latitude, branch.longitude),
                    initialZoom: 15,
                  ),
                  children: [
                    if (!_tilesUnavailable)
                      TileLayer(
                        urlTemplate: mapTileUrl,
                        userAgentPackageName: mapUserAgent,
                        errorTileCallback: (tile, error, stackTrace) =>
                            _handleTileError(error),
                      ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                if (_tilesUnavailable)
                  MapTileErrorOverlay(onRetry: _retryTiles),
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
                if (_realUserPosition != null)
                  Positioned(
                    top: 44,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        '${_getDistanceText()} - ${_getEtaText()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B4BC8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          branch.address,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(
                              label: branch.isOpen
                                  ? 'Buka - ${branch.openHours}'
                                  : 'Tutup - ${branch.openHours}',
                              color: branch.isOpen
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFFE4EE),
                              textColor: branch.isOpen
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFC0144A),
                            ),
                            _Chip(
                              label: _getDistanceText(),
                              color: const Color(0xFFE8EAFF),
                              textColor: const Color(0xFF2A38A0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openInAppNavigation,
                            icon: const Icon(Icons.navigation, size: 16),
                            label: const Text(
                              'Navigasi',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B4BC8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                branch.isOpen ? _selectBranchForOrder : null,
                            icon: const Icon(Icons.shopping_cart_outlined,
                                size: 16),
                            label: const Text(
                              'Pesan di sini',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Layanan tersedia',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (branch.services.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        'Belum ada layanan di cabang ini.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    )
                  else
                    ...branch.services.map(
                      (svc) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                svc.name,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              svc.price,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2A38A0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
