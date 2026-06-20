import 'dart:async';

import 'package:flutter/material.dart';

import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../maps/screens/map_screen.dart';
import 'account_tab.dart';
import 'detailProduct.dart';
import 'keranjang.dart';
import 'notifikasi.dart';
import 'order_tab.dart';
import 'product_image.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _servicePageSize = 6;
  static const Duration _notificationDuration = Duration(seconds: 2);

  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _productScrollController = ScrollController();
  String _searchQuery = '';

  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  List<ServiceModel> _services = [];
  final Map<int, _PagedServicesCache> _servicesByBranchId = {};
  final Set<int> _visitedTabs = {0};
  final Set<String> _seenNotificationIds = {};
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  Object? _servicePageCursor;
  bool _loadingBranches = true;
  bool _loadingServices = false;
  bool _loadingMoreServices = false;
  bool _hasMoreServices = true;
  bool _notificationListenerReady = false;

  @override
  void initState() {
    super.initState();
    _productScrollController.addListener(_onProductScroll);
    _loadBranches();
    _listenForOrderNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _searchController.dispose();
    _productScrollController.dispose();
    super.dispose();
  }

  void _onProductScroll() {
    if (!_productScrollController.hasClients) return;
    final position = _productScrollController.position;
    if (position.extentAfter < 280) {
      _loadMoreServicesForSelectedBranch();
    }
  }

  void _listenForOrderNotifications() {
    final userId = SessionManager.currentUserId;
    final userUid = SessionManager.currentUserUid;
    if (userId == null || userUid == null || userUid.isEmpty) return;

    _notificationSubscription =
        _db.watchUnreadUserNotifications(userId).listen((notifications) {
      final freshNotifications = notifications.where((notification) {
        final id = notification.firestoreId;
        return id != null && !_seenNotificationIds.contains(id);
      }).toList();

      for (final notification in notifications) {
        final id = notification.firestoreId;
        if (id != null) _seenNotificationIds.add(id);
      }

      if (!_notificationListenerReady) {
        _notificationListenerReady = true;
      }

      if (freshNotifications.isNotEmpty) {
        _showOrderNotification(freshNotifications.first);
      }
    });
  }

  void _showOrderNotification(NotificationModel notification) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: _notificationDuration,
        content: Text('${notification.title}: ${notification.message}'),
        backgroundColor: const Color(0xFF2E4CB9),
        action: SnackBarAction(
          label: 'Order',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            setState(() {
              _selectedIndex = 2;
              _visitedTabs.add(2);
            });
          },
        ),
      ),
    );
  }

  Future<void> _loadBranches() async {
    final branches = await _db.getAllBranches();
    if (!mounted) return;

    final selectedId = SessionManager.selectedBranchId;
    BranchModel? selectedBranch;
    if (selectedId != null) {
      for (final branch in branches) {
        if (branch.id == selectedId) {
          selectedBranch = branch;
          break;
        }
      }
    }

    setState(() {
      _branches = branches;
      _selectedBranch = selectedBranch;
      _loadingBranches = false;
    });

    await _loadServicesForSelectedBranch();
  }

  Future<void> _loadServicesForSelectedBranch(
      {bool forceRefresh = false}) async {
    final branch = _selectedBranch;
    final branchId = branch?.id;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _services = [];
          _servicePageCursor = null;
          _hasMoreServices = false;
          _loadingMoreServices = false;
          _loadingServices = false;
        });
      }
      return;
    }

    final cachedServices = _servicesByBranchId[branchId];
    if (!forceRefresh && cachedServices != null) {
      setState(() {
        _services = cachedServices.services;
        _servicePageCursor = cachedServices.cursor;
        _hasMoreServices = cachedServices.hasMore;
        _loadingMoreServices = false;
        _loadingServices = false;
      });
      return;
    }

    setState(() {
      _services = [];
      _servicePageCursor = null;
      _hasMoreServices = true;
      _loadingMoreServices = false;
      _loadingServices = true;
    });

    try {
      final page = await _db.getServicesForBranchPage(
        branchId: branchId,
        limit: _servicePageSize,
      );
      if (!mounted) return;
      if (_selectedBranch?.id != branchId) return;

      _servicesByBranchId[branchId] = _PagedServicesCache(
        services: page.services,
        cursor: page.cursor,
        hasMore: page.hasMore,
      );

      setState(() {
        _services = page.services;
        _servicePageCursor = page.cursor;
        _hasMoreServices = page.hasMore;
        _loadingServices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingServices = false;
        _hasMoreServices = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat etalase produk.')),
      );
    }
  }

  Future<void> _loadMoreServicesForSelectedBranch() async {
    final branchId = _selectedBranch?.id;
    if (branchId == null ||
        _loadingBranches ||
        _loadingServices ||
        _loadingMoreServices ||
        !_hasMoreServices) {
      return;
    }

    setState(() => _loadingMoreServices = true);

    try {
      final page = await _db.getServicesForBranchPage(
        branchId: branchId,
        limit: _servicePageSize,
        startAfter: _servicePageCursor,
      );
      if (!mounted) return;
      if (_selectedBranch?.id != branchId) return;

      final existingIds = _services.map((service) => service.id).toSet();
      final newServices = page.services
          .where((service) =>
              service.id == null || !existingIds.contains(service.id))
          .toList();
      final updatedServices = [..._services, ...newServices];

      _servicesByBranchId[branchId] = _PagedServicesCache(
        services: updatedServices,
        cursor: page.cursor,
        hasMore: page.hasMore,
      );

      setState(() {
        _services = updatedServices;
        _servicePageCursor = page.cursor;
        _hasMoreServices = page.hasMore;
        _loadingMoreServices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoreServices = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat produk berikutnya.')),
      );
    }
  }

  Future<void> _refreshServicesForSelectedBranch() async {
    final branchId = _selectedBranch?.id;
    if (branchId != null) {
      _servicesByBranchId.remove(branchId);
    }
    await _loadServicesForSelectedBranch(forceRefresh: true);
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Future<void> _selectBranch(BranchModel branch) async {
    if (!branch.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cabang ini sedang tutup.')),
      );
      return;
    }

    SessionManager.selectBranch(branch);
    _searchController.clear();
    if (_productScrollController.hasClients) {
      _productScrollController.jumpTo(0);
    }
    setState(() {
      _selectedBranch = branch;
      _searchQuery = '';
    });
    await _loadServicesForSelectedBranch();
  }

  void _showBranchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih Cabang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.62,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _branches.length,
                    itemBuilder: (context, index) {
                      final branch = _branches[index];
                      final selected = _selectedBranch?.id == branch.id;
                      return _BranchOption(
                        branch: branch,
                        selected: selected,
                        onTap: () async {
                          Navigator.pop(context);
                          await _selectBranch(branch);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ServiceModel> get _filteredServices {
    if (_searchQuery.trim().isEmpty) return _services;
    final query = _searchQuery.toLowerCase();
    return _services
        .where((s) => s.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _buildLazyTabs(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (_selectedIndex == index) return;
            setState(() {
              _selectedIndex = index;
              _visitedTabs.add(index);
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2E4CB9),
          unselectedItemColor: Colors.grey,
          elevation: 0,
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Order'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _buildLazyTabs() {
    return Stack(
      children: List.generate(4, (index) {
        if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
        return Offstage(
          offstage: _selectedIndex != index,
          child: TickerMode(
            enabled: _selectedIndex == index,
            child: KeyedSubtree(
              key: ValueKey(index),
              child: _buildTab(index),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return _buildHomeTab();
      case 1:
        return MapScreen(active: _selectedIndex == 1);
      case 2:
        return const OrderTab();
      case 3:
        return const AccountTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Hello, ${SessionManager.currentUserName ?? 'User'}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const KeranjangScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotifikasiScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBranchSelector(),
            const SizedBox(height: 12),
            if (_selectedBranch != null) _buildSearchBar(),
            if (_selectedBranch != null) const SizedBox(height: 16),
            Expanded(
              child: _loadingBranches
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedBranch == null
                      ? _buildBranchFirstState()
                      : _buildProductGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    final branch = _selectedBranch;
    return InkWell(
      onTap: _branches.isEmpty ? null : _showBranchPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront,
                  color: Color(0xFF2E4CB9), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch?.name ?? 'Pilih cabang',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    branch?.address ??
                        'Layanan akan mengikuti cabang yang dipilih',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: _searchController,
        onChanged: _updateSearchQuery,
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.black54),
          border: InputBorder.none,
          hintText: 'Cari layanan...',
          hintStyle: TextStyle(color: Colors.black38),
        ),
      ),
    );
  }

  Widget _buildBranchFirstState() {
    if (_branches.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada cabang tersedia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _branches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Cabang tersedia',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
            ),
          );
        }

        final branch = _branches[index - 1];
        return _BranchOption(
          branch: branch,
          selected: false,
          onTap: () => _selectBranch(branch),
        );
      },
    );
  }

  Widget _buildProductGrid() {
    if (_loadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredServices = _filteredServices;

    if (_services.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshServicesForSelectedBranch,
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Center(
              child: Text(
                'Belum ada layanan tersedia di cabang ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (filteredServices.isEmpty) {
      return const Center(
          child:
              Text('Tidak ditemukan.', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _refreshServicesForSelectedBranch,
      child: CustomScrollView(
        controller: _productScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 280,
        slivers: [
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(filteredServices[index]),
              childCount: filteredServices.length,
            ),
          ),
          SliverToBoxAdapter(child: _buildLoadMoreFooter()),
        ],
      ),
    );
  }

  Widget _buildProductCard(ServiceModel service) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailProductScreen(service: service),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ProductImage(service: service),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  service.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Rp ${service.price}/${service.unit}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (!_hasMoreServices && !_loadingMoreServices) {
      return const SizedBox(height: 16);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: _loadingMoreServices
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const SizedBox(height: 22),
      ),
    );
  }
}

class _PagedServicesCache {
  final List<ServiceModel> services;
  final Object? cursor;
  final bool hasMore;

  const _PagedServicesCache({
    required this.services,
    required this.cursor,
    required this.hasMore,
  });
}

class _BranchOption extends StatelessWidget {
  final BranchModel branch;
  final bool selected;
  final VoidCallback onTap;

  const _BranchOption({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF2E4CB9) : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: branch.isOpen ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2E4CB9)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E4CB9),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      branch.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: branch.isOpen
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFFE4EE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        branch.isOpen
                            ? 'Buka - ${branch.openHours}'
                            : 'Tutup - ${branch.openHours}',
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
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
