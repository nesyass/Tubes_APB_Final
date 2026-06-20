import 'package:flutter/material.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/time_utils.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  List<OrderItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await _db.getOrderItems(widget.order.orderId);
    if (mounted) {
      setState(() {
        _items = data;
        _loading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFF9800);
      case 'Sedang Dicetak':
        return const Color(0xFF2196F3);
      case 'Siap Diambil':
        return const Color(0xFF4CAF50);
      case 'Sudah Diambil':
        return const Color(0xFF7C7C88);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Siap Diambil':
        return Icons.check_circle;
      case 'Sudah Diambil':
        return Icons.lock_outline;
      default:
        return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4CB9),
        foregroundColor: Colors.white,
        title: Text(order.orderId),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getStatusColor(order.status).withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          color: _getStatusColor(order.status),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status Pesanan',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(order.status,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(order.status))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info pesanan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Info Pesanan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(),
                        _infoRow('Order ID', order.orderId),
                        _infoRow('Cabang', order.branchName),
                        _infoRow('Tanggal', _formatDate(order.createdAt)),
                        if (order.readyAt != null)
                          _infoRow('Siap Diambil', _formatDate(order.readyAt!)),
                        if (order.completedAt != null)
                          _infoRow('Selesai', _formatDate(order.completedAt!)),
                        _infoRow('Total', 'Rp ${order.totalPrice}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Riwayat status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Riwayat Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(),
                        ...order.statusHistory.asMap().entries.map((entry) {
                          final index = entry.key;
                          final history = entry.value;
                          return _historyRow(
                            history,
                            isLast: index == order.statusHistory.length - 1,
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Item pesanan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Item Pesanan (${_items.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(),
                        ..._items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.print,
                                        size: 20, color: Color(0xFF2E4CB9)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.serviceName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            'Ukuran: ${item.size}  ·  Qty: ${item.quantity}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                        if (item.fileName != null ||
                                            item.filePath != null ||
                                            item.fileUrl != null)
                                          Text('File: ${item.displayFileName}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  Text('Rp ${item.price}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E4CB9))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _historyRow(OrderStatusHistoryModel history, {required bool isLast}) {
    final color = _getStatusColor(history.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(_getStatusIcon(history.status), size: 16, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(history.status,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(_formatDate(history.changedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    return AppDateTime.formatShortWib(isoDate);
  }
}
