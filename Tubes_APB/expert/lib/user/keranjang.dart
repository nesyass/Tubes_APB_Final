import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/order_file_upload_service.dart';
import '../data/time_utils.dart';

class KeranjangScreen extends StatefulWidget {
  const KeranjangScreen({super.key});

  @override
  State<KeranjangScreen> createState() => _KeranjangScreenState();
}

class _KeranjangScreenState extends State<KeranjangScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final FirestoreDatabaseService _firestoreDb = FirestoreDatabaseService();
  final OrderFileUploadService _uploadService = OrderFileUploadService();
  List<CartItemModel> _items = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    if (SessionManager.currentUserId == null) return;
    final items = await _db.getCartItems(SessionManager.currentUserId!);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  int get _totalHarga {
    return _items
        .where((item) => _selectedIds.contains(item.id))
        .fold(0, (sum, item) => sum + item.totalPrice);
  }

  Future<void> _deleteItem(CartItemModel item) async {
    await _db.deleteCartItem(item.id!);
    _selectedIds.remove(item.id);
    _loadCart();
  }

  Future<void> _checkout() async {
    if (_checkingOut) return;

    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih minimal 1 item untuk checkout.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final branchId = SessionManager.selectedBranchId;
    final branchName = SessionManager.selectedBranchName;
    if (branchId == null || branchName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih cabang dari dashboard terlebih dahulu.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final selectedItems =
        _items.where((item) => _selectedIds.contains(item.id)).toList();
    final availableServices = await _firestoreDb.getServicesForBranch(branchId);
    final availableServiceIds =
        availableServices.map((service) => service.id).toSet();
    final unavailableItems = selectedItems
        .where((item) => !availableServiceIds.contains(item.serviceId))
        .map((item) => item.serviceName)
        .toList();

    if (unavailableItems.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${unavailableItems.first} tidak tersedia di $branchName.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _checkingOut = true);

    try {
      final ownerUid = SessionManager.currentUserUid;
      if (ownerUid == null || ownerUid.isEmpty) {
        throw StateError('Sesi akun tidak valid. Silakan login ulang.');
      }

      final orderId = AppDateTime.generateOrderId();
      final createdAt = AppDateTime.nowWibIsoString();
      final order = OrderModel(
        orderId: orderId,
        userId: SessionManager.currentUserId!,
        ownerUid: ownerUid,
        branchId: branchId,
        branchName: branchName,
        status: 'Pending',
        totalPrice: _totalHarga,
        createdAt: createdAt,
        statusHistory: [
          OrderStatusHistoryModel(status: 'Pending', changedAt: createdAt),
        ],
      );

      final orderItems = <OrderItemModel>[];
      for (var index = 0; index < selectedItems.length; index++) {
        final cart = selectedItems[index];
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

      await _firestoreDb.insertOrder(order, orderItems);
      await _db.insertOrder(order, orderItems);
      await _db.deleteCartItemsByIds(selectedItems.map((e) => e.id!).toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Pesanan $orderId berhasil dibuat di $branchName.'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Checkout gagal: $error'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4CB9),
        foregroundColor: Colors.white,
        title: Text(SessionManager.selectedBranchName ?? 'Keranjang'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                      'Keranjang kosong.\nTambahkan layanan dari dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isSelected = _selectedIds.contains(item.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2E4CB9)
                                      : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(item.id!);
                                      } else {
                                        _selectedIds.remove(item.id!);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF2E4CB9),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.serviceName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                          'Ukuran: ${item.size}  ·  Qty: ${item.quantity}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                      if (item.filePath != null)
                                        Text(
                                            'File: ${item.fileName ?? item.filePath!.split(RegExp(r'[\\/]')).last}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('Rp ${item.totalPrice}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E4CB9))),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteItem(item),
                                ),
                              ],
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
                                Text('${_selectedIds.length} item dipilih',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                                Text('Rp $_totalHarga',
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
                              onPressed: _checkingOut ? null : _checkout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E4CB9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                _checkingOut ? 'MEMPROSES...' : 'CHECKOUT',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
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
