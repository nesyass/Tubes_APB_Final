import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_admin.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/time_utils.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key});

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  static const String _statusPending = 'Pending';
  static const String _statusPrinting = 'Sedang Dicetak';
  static const String _statusReady = 'Siap Diambil';
  static const String _statusPickedUp = 'Sudah Diambil';

  String selectedFilter = 'Semua';
  final List<String> filters = [
    'Semua',
    _statusPending,
    _statusPrinting,
    _statusReady,
    _statusPickedUp,
  ];
  final List<String> _statuses = [
    _statusPending,
    _statusPrinting,
    _statusReady,
    _statusPickedUp,
  ];
  final FirestoreDatabaseService _db = FirestoreDatabaseService();

  List<OrderModel> orders = [];
  Map<String, List<OrderItemModel>> orderItems = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final data = await _db.getAllOrders();
    final itemEntries = await Future.wait(
      data.map((order) async =>
          MapEntry(order.orderId, await _db.getOrderItems(order.orderId))),
    );
    if (mounted) {
      setState(() {
        orders = data;
        orderItems = Map.fromEntries(itemEntries);
        _loading = false;
      });
    }
  }

  List<OrderModel> get filteredOrders {
    if (selectedFilter == 'Semua') return orders;
    return orders.where((o) => o.status == selectedFilter).toList();
  }

  Future<void> _updateStatus(OrderModel order, String newStatus) async {
    if (order.status == _statusPickedUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Pesanan sudah diambil dan tidak bisa diedit lagi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (order.status == _statusReady && newStatus != _statusPickedUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text(
              'Pesanan sudah siap diambil. Hanya bisa ditandai sudah selesai.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newStatus == _statusReady) {
      final confirmed = await _confirmReadyOrder(order);
      if (confirmed != true) return;
    }

    if (newStatus == _statusPickedUp) {
      final confirmed = await _confirmFinishOrder(order);
      if (confirmed != true) return;
    }

    try {
      await _db.updateOrderStatus(order.orderId, newStatus);
      await _loadOrders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(_statusUpdateMessage(order, newStatus)),
          backgroundColor: Colors.green,
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(error.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Gagal memperbarui status pesanan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _statusUpdateMessage(OrderModel order, String newStatus) {
    if (newStatus == _statusReady) {
      return 'Pesanan ${order.orderId} siap diambil dan pelanggan diberi notifikasi.';
    }
    if (newStatus == _statusPickedUp) {
      return 'Pesanan ${order.orderId} sudah selesai.';
    }
    return 'Status pesanan ${order.orderId} diperbarui.';
  }

  List<String> _statusOptionsForOrder(OrderModel order) {
    if (order.status == _statusPickedUp) return _statuses;
    return [_statusPending, _statusPrinting, _statusReady];
  }

  Future<bool?> _confirmReadyOrder(OrderModel order) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pesanan siap diambil?'),
          content: Text(
            'Pesanan ${order.orderId} akan diberi status siap diambil. Pelanggan juga akan menerima notifikasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, siap diambil'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmFinishOrder(OrderModel order) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tandai sudah selesai?'),
          content: Text(
            'Pesanan ${order.orderId} akan ditandai sudah selesai dan dicatat di riwayat status.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, sudah selesai'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFile(OrderItemModel item) async {
    final rawUrl = item.fileUrl;
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('File upload belum tersedia.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('URL file tidak valid.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('File belum bisa dibuka di perangkat ini.'),
            backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case _statusPending:
        return const Color(0xFFFF9800);
      case _statusPrinting:
        return const Color(0xFF2196F3);
      case _statusReady:
        return const Color(0xFF4CAF50);
      case _statusPickedUp:
        return const Color(0xFF7C7C88);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            CustomHeader(
                title: 'Pesanan',
                showBack: true,
                onBack: () => Navigator.pop(context)),
            const SizedBox(height: 12),
            // Filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: filters.map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selectedFilter == filter,
                      onSelected: (selected) {
                        if (selected) setState(() => selectedFilter = filter);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selectedFilter == filter
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredOrders.isEmpty
                      ? const Center(
                          child: Text('Belum ada pesanan.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final items = orderItems[order.orderId] ??
                                const <OrderItemModel>[];
                            final isReady = order.status == _statusReady;
                            final isFinal = order.status == _statusPickedUp;
                            final statusColor = _getStatusColor(order.status);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(order.orderId,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(order.status,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: statusColor)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Cabang: ${order.branchName}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  Text('Total: Rp ${order.totalPrice}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  Text(
                                      'Dibuat: ${AppDateTime.formatShortWib(order.createdAt)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  if (order.readyAt != null)
                                    Text(
                                        'Siap: ${AppDateTime.formatShortWib(order.readyAt!)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  if (order.completedAt != null)
                                    Text(
                                        'Selesai: ${AppDateTime.formatShortWib(order.completedAt!)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  if (items.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Text('Item (${items.length})',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    ...items.map((item) => _OrderItemRow(
                                          item: item,
                                          onOpenFile: () => _openFile(item),
                                          fileActionsEnabled: true,
                                        )),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Ubah Status:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: DropdownButton<String>(
                                          value: order.status,
                                          underline: const SizedBox(),
                                          icon: const Icon(
                                              Icons.arrow_drop_down,
                                              size: 18),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold),
                                          onChanged: (isReady || isFinal)
                                              ? null
                                              : (String? newValue) {
                                                  if (newValue != null) {
                                                    _updateStatus(
                                                        order, newValue);
                                                  }
                                                },
                                          items:
                                              _statusOptionsForOrder(order).map(
                                            (String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            },
                                          ).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isReady) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _updateStatus(
                                            order, _statusPickedUp),
                                        icon: const Icon(Icons.done_all,
                                            size: 18),
                                        label: const Text('Sudah Selesai'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItemModel item;
  final VoidCallback onOpenFile;
  final bool fileActionsEnabled;

  const _OrderItemRow({
    required this.item,
    required this.onOpenFile,
    this.fileActionsEnabled = true,
  });

  bool get _canOpenFile =>
      fileActionsEnabled && (item.fileUrl ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final fileLabel = item.displayFileName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.serviceName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Rp ${item.price}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ukuran: ${item.size} - Qty: ${item.quantity}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF7C7C88)),
          ),
          if (item.fileName != null ||
              item.filePath != null ||
              item.fileUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileLabel,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF7C7C88)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _canOpenFile ? onOpenFile : null,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Buka File'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
