import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/firestore_database_service.dart';
import '../../data/models.dart';
import '../location_access.dart';
import '../map_config.dart';
import '../models/branch.dart';
import '../widgets/map_tile_error_overlay.dart';
import 'branch_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final bool active;

  const MapScreen({super.key, this.active = true});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userPosition;
  double? _userAccuracyMeters;
  StreamSubscription<Position>? _positionStream;
  List<BranchModel> _branches = [];
  String _searchQuery = '';
  bool _mapReady = false;
  bool _tilesUnavailable = false;
  bool _hasCenteredOnUser = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;

    if (widget.active) {
      _positionStream?.resume();
      if (_userPosition == null) {
        _getUserLocation();
      }
    } else {
      _positionStream?.pause();
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = FirestoreDatabaseService();
    final branches = await db.getAllBranches();
    if (!mounted) return;
    setState(() => _branches = branches);
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final access = await ensureLocationAccess();
      if (!mounted) return;
      if (!access.canUseLocation) {
        _showLocationAccessMessage(access);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      _updateUserPosition(position, moveCamera: widget.active);
      if (widget.active) _startLocationStream();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi belum bisa dibaca saat ini')),
      );
    }
  }

  void _showLocationAccessMessage(LocationAccessResult access) {
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
  }

  void _startLocationStream() {
    if (_positionStream != null) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      _updateUserPosition,
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Update GPS terhenti. Periksa izin lokasi perangkat.')),
        );
      },
    );
  }

  void _updateUserPosition(Position position, {bool moveCamera = false}) {
    if (!mounted) return;

    final nextPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _userPosition = nextPosition;
      _userAccuracyMeters =
          position.accuracy.isFinite ? position.accuracy : null;
    });

    if (_mapReady && (moveCamera || !_hasCenteredOnUser)) {
      _mapController.move(nextPosition, 14);
      _hasCenteredOnUser = true;
    }
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

  List<Marker> get _markers {
    final markers = <Marker>[];

    for (final branch in _branches) {
      if (branch.latitude == 0 && branch.longitude == 0) continue;
      markers.add(
        Marker(
          point: LatLng(branch.latitude, branch.longitude),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _openBranchDetail(branch),
            child: Icon(
              Icons.location_on,
              size: 42,
              color: branch.isOpen
                  ? const Color(0xFF2E4CB9)
                  : const Color(0xFFC0144A),
            ),
          ),
        ),
      );
    }

    final userPosition = _userPosition;
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

  String _getDistance(BranchModel branch) {
    if (_userPosition == null) return '-';
    if (branch.latitude == 0 && branch.longitude == 0) return '-';
    final distanceInMeters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      branch.latitude,
      branch.longitude,
    );
    final km = distanceInMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  List<BranchModel> get _sortedBranches {
    if (_userPosition == null) return _filteredBySearch;
    final sorted = List<BranchModel>.from(_filteredBySearch);
    sorted.sort((a, b) {
      if (a.latitude == 0 || b.latitude == 0) return 0;
      final distA = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        a.latitude,
        a.longitude,
      );
      final distB = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }

  List<BranchModel> get _filteredBySearch {
    if (_searchQuery.isEmpty) return _branches;
    final query = _searchQuery.toLowerCase();
    return _branches
        .where((b) => b.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _openBranchDetail(BranchModel branch) async {
    final services = branch.id == null
        ? <ServiceModel>[]
        : await FirestoreDatabaseService().getServicesForBranch(branch.id!);

    if (!mounted) return;
    final oldBranch = Branch(
      id: branch.id.toString(),
      name: branch.name,
      address: branch.address,
      latitude: branch.latitude,
      longitude: branch.longitude,
      isOpen: branch.isOpen,
      openHours: branch.openHours,
      services: services
          .map(
            (service) => BranchService(
              name: service.name,
              price: 'Rp ${service.price}/${service.unit}',
            ),
          )
          .toList(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchDetailScreen(
          branch: oldBranch,
          userPosition: _userPosition,
        ),
      ),
    );
  }

  void _goToUserLocation() {
    if (_userPosition != null && _mapReady) {
      _mapController.move(_userPosition!, 14);
      return;
    }
    _getUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3B4BC8),
            padding:
                const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Surindo Printing',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text('Temukan cabang terdekat',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama cabang...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: bandungCenter,
                    initialZoom: 12,
                    onMapReady: () {
                      _mapReady = true;
                      final userPosition = _userPosition;
                      if (userPosition != null) {
                        _mapController.move(userPosition, 14);
                        _hasCenteredOnUser = true;
                      }
                    },
                  ),
                  children: [
                    if (!_tilesUnavailable)
                      TileLayer(
                        urlTemplate: mapTileUrl,
                        userAgentPackageName: mapUserAgent,
                        errorTileCallback: (tile, error, stackTrace) =>
                            _handleTileError(error),
                      ),
                    if (_userPosition != null && _userAccuracyMeters != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _userPosition!,
                            radius:
                                _userAccuracyMeters!.clamp(15, 500).toDouble(),
                            useRadiusInMeter: true,
                            color: const Color(0xFF2563EB).withAlpha(28),
                            borderColor: const Color(0xFF2563EB).withAlpha(90),
                            borderStrokeWidth: 1,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
                if (_tilesUnavailable)
                  MapTileErrorOverlay(onRetry: _retryTiles),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton.small(
                    onPressed: _goToUserLocation,
                    backgroundColor: Colors.white,
                    child:
                        const Icon(Icons.my_location, color: Color(0xFF3B4BC8)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _branches.isEmpty
                    ? 'Belum ada cabang'
                    : 'Cabang terdekat dari lokasi Anda',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
          Expanded(
            child: _sortedBranches.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada cabang. Admin belum menambahkan.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _sortedBranches.length,
                    itemBuilder: (context, index) {
                      final branch = _sortedBranches[index];
                      return _BranchCard(
                        branch: branch,
                        distance: _getDistance(branch),
                        onTap: () => _openBranchDetail(branch),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final BranchModel branch;
  final String distance;
  final VoidCallback onTap;

  const _BranchCard({
    required this.branch,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_print_shop,
                    color: Color(0xFF3B4BC8), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${branch.address} - $distance',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: branch.isOpen
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFE4EE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  branch.isOpen ? 'Buka' : 'Tutup',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: branch.isOpen
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFC0144A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
