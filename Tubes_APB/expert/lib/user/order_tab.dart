import 'package:flutter/material.dart';
import 'order_detail.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/time_utils.dart';

class OrderTab extends StatefulWidget {
  const OrderTab({super.key});

  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  static const String _statusReady = 'Siap Diambil';
  static const String _statusPickedUp = 'Sudah Diambil';

  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final userId = SessionManager.currentUserId;
    final userUid = SessionManager.currentUserUid;
    if (userId == null || userUid == null || userUid.isEmpty) {
      if (mounted) {
        setState(() {
          _orders = [];
          _loading = false;
        });
      }
      return;
    }

    final data = await _db.getOrdersByUser(userId);
    if (mounted) {
      setState(() {
        _orders = data;
        _loading = false;
      });
    }
  }

  bool _isReadyForPickup(OrderModel order) => order.status == _statusReady;

  bool _isFinalOrder(OrderModel order) => order.status == _statusPickedUp;

  Future<void> _markOrderPickedUp(OrderModel order) async {
    final confirmed = await _confirmPickedUp(order);
    if (confirmed != true) return;

    try {
      await _db.updateOrderStatus(order.orderId, _statusPickedUp);
      await _loadOrders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Pesanan ${order.orderId} sudah ditandai diambil.'),
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
          content: Text('Gagal menandai pesanan sudah diambil.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _confirmPickedUp(OrderModel order) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pesanan sudah diambil?'),
          content: Text(
            'Pesanan ${order.orderId} akan ditandai sudah selesai. Detail dan riwayatnya tetap bisa dilihat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E4CB9),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, sudah diambil'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFF9800);
      case 'Sedang Dicetak':
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
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2E4CB9),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Text('Pesanan Saya',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(
                        child: Text(
                            'Belum ada pesanan.\nCheckout dari keranjang untuk membuat pesanan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final isReady = _isReadyForPickup(order);
                            final isFinal = _isFinalOrder(order);
                            final statusColor = _getStatusColor(order.status);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
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
                                  const SizedBox(height: 6),
                                  Text('Cabang: ${order.branchName}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  Text('Total: Rp ${order.totalPrice}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  Text(
                                      'Dibuat: ${AppDateTime.formatShortWib(order.createdAt)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  if (isFinal && order.completedAt != null)
                                    Text(
                                        'Selesai: ${AppDateTime.formatShortWib(order.completedAt!)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OrderDetailScreen(
                                                  order: order),
                                            ));
                                        _loadOrders();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                          isFinal ? 'Lihat Detail' : 'Detail',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  if (isReady) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _markOrderPickedUp(order),
                                        icon: const Icon(Icons.done_all,
                                            size: 18),
                                        label: const Text('Sudah Diambil'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2E4CB9),
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
          ),
        ],
      ),
    );
  }
}
