import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/order_file_upload_service.dart';
import '../data/time_utils.dart';

class PilihCabangScreen extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final int totalHarga;

  const PilihCabangScreen({
    super.key,
    required this.cartItems,
    required this.totalHarga,
  });

  @override
  State<PilihCabangScreen> createState() => _PilihCabangScreenState();
}

class _PilihCabangScreenState extends State<PilihCabangScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final FirestoreDatabaseService _firestoreDb = FirestoreDatabaseService();
  final OrderFileUploadService _uploadService = OrderFileUploadService();
  List<BranchModel> _branches = [];
  int? _selectedBranchId;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final data = await _firestoreDb.getAllBranches();
    if (mounted) {
      setState(() {
        _branches = data;
        _loading = false;
      });
    }
  }

  Future<void> _checkout() async {
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih cabang terlebih dahulu.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      final ownerUid = SessionManager.currentUserUid;
      if (ownerUid == null || ownerUid.isEmpty) {
        throw StateError('Sesi akun tidak valid. Silakan login ulang.');
      }

      final selectedBranch =
          _branches.firstWhere((b) => b.id == _selectedBranchId);

      final orderId = AppDateTime.generateOrderId();
      final createdAt = AppDateTime.nowWibIsoString();

      // Create order
      final order = OrderModel(
        orderId: orderId,
        userId: SessionManager.currentUserId!,
        ownerUid: ownerUid,
        branchId: _selectedBranchId!,
        branchName: selectedBranch.name,
        status: 'Pending',
        totalPrice: widget.totalHarga,
        createdAt: createdAt,
        statusHistory: [
          OrderStatusHistoryModel(status: 'Pending', changedAt: createdAt),
        ],
      );

      final orderItems = <OrderItemModel>[];
      for (var index = 0; index < widget.cartItems.length; index++) {
        final cart = widget.cartItems[index];
        final upload = await _uploadService.uploadOrderFile(
          orderId: orderId,
          itemIndex: index + 1,
          filePath: cart.filePath,
          fileName: cart.fileName,
        );

        orderItems.add(
          OrderItemModel(
            orderId: orderId,
            serviceId: cart.serviceId,
            serviceName: cart.serviceName,
            quantity: cart.quantity,
            size: cart.size,
            filePath: cart.filePath,
            fileName: upload?.fileName ?? cart.fileName,
            fileUrl: upload?.downloadUrl,
            price: cart.totalPrice,
          ),
        );
      }

      // Insert order + items to DB
      await _firestoreDb.insertOrder(order, orderItems);
      await _db.insertOrder(order, orderItems);

      // Delete checked out cart items
      await _db.deleteCartItemsByIds(
        widget.cartItems.map((e) => e.id!).toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan $orderId berhasil dibuat!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to dashboard
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal checkout: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4CB9),
        foregroundColor: Colors.white,
        title: const Text('Pilih Cabang'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const Center(
                  child: Text('Belum ada cabang tersedia.',
                      style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _branches.length,
                        itemBuilder: (context, index) {
                          final branch = _branches[index];
                          final isSelected = _selectedBranchId == branch.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2E4CB9)
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1),
                            ),
                            child: RadioListTile<int>(
                              value: branch.id!,
                              groupValue: _selectedBranchId,
                              onChanged: branch.isOpen
                                  ? (val) =>
                                      setState(() => _selectedBranchId = val)
                                  : null,
                              title: Text(branch.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(branch.address,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                  const SizedBox(height: 4),
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
                                              : const Color(0xFFC0144A)),
                                    ),
                                  ),
                                ],
                              ),
                              activeColor: const Color(0xFF2E4CB9),
                            ),
                          );
                        },
                      ),
                    ),
                    // Bottom bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
                              offset: const Offset(0, -4))
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${widget.cartItems.length} item',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                                Text('Rp ${widget.totalHarga}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E4CB9))),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _processing ? null : _checkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E4CB9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _processing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('CHECKOUT',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
