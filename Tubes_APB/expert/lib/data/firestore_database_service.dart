import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'time_utils.dart';

class ServicePageResult {
  final List<ServiceModel> services;
  final Object? cursor;
  final bool hasMore;

  const ServicePageResult({
    required this.services,
    required this.cursor,
    required this.hasMore,
  });
}

class FirestoreDatabaseService {
  FirestoreDatabaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String statusPending = 'Pending';
  static const String statusPrinting = 'Sedang Dicetak';
  static const String statusReady = 'Siap Diambil';
  static const String statusPickedUp = 'Sudah Diambil';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _branches =>
      _firestore.collection('branches');
  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('services');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  String? get _currentUserUid =>
      SessionManager.currentUserUid ?? _auth.currentUser?.uid;

  Future<List<BranchModel>> getAllBranches() async {
    final snapshot = await _branches.orderBy('id', descending: false).get();
    return snapshot.docs.map((doc) => BranchModel.fromMap(doc.data())).toList();
  }

  Future<int> insertBranch(BranchModel branch) async {
    final id = branch.id ?? await _nextId(_branches);
    await _branches.doc(id.toString()).set({
      ..._branchToFirestoreMap(branch),
      'id': id,
    });
    return id;
  }

  Future<int> updateBranch(BranchModel branch) async {
    final id = branch.id;
    if (id == null) return insertBranch(branch);
    await _branches
        .doc(id.toString())
        .set(_branchToFirestoreMap(branch), SetOptions(merge: true));
    return 1;
  }

  Future<int> deleteBranch(int id) async {
    await _branches.doc(id.toString()).delete();
    return 1;
  }

  Future<List<ServiceModel>> getAllServices() async {
    final snapshot = await _services.orderBy('id', descending: true).get();
    return snapshot.docs
        .map((doc) => ServiceModel.fromMap(doc.data()))
        .toList();
  }

  Future<List<ServiceModel>> getActiveServices() async {
    final services = await getAllServices();
    return services.where((service) => service.isActive).toList();
  }

  Future<List<ServiceModel>> getServicesForBranch(int branchId) async {
    final snapshot =
        await _services.where('branchIds', arrayContains: branchId).get();
    final services = snapshot.docs
        .map((doc) => ServiceModel.fromMap(doc.data()))
        .where((service) => service.isActive)
        .toList();
    services.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return services;
  }

  Future<ServicePageResult> getServicesForBranchPage({
    required int branchId,
    int limit = 6,
    Object? startAfter,
  }) async {
    Query<Map<String, dynamic>> query =
        _services.where('branchIds', arrayContains: branchId).limit(limit);

    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final services = snapshot.docs
        .map((doc) => ServiceModel.fromMap(doc.data()))
        .where((service) => service.isActive)
        .toList();
    services.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    return ServicePageResult(
      services: services,
      cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<int> insertService(ServiceModel service) async {
    final id = service.id ?? await _nextId(_services);
    await _services.doc(id.toString()).set({
      ...service.toMap(),
      'id': id,
      'branchIds': <int>[],
    }, SetOptions(merge: true));
    return id;
  }

  Future<int> updateService(ServiceModel service) async {
    final id = service.id;
    if (id == null) return insertService(service);
    await _services
        .doc(id.toString())
        .set(service.toMap(), SetOptions(merge: true));
    return 1;
  }

  Future<int> deleteService(int id) async {
    await _services.doc(id.toString()).delete();
    return 1;
  }

  Future<void> setServiceBranches(int serviceId, List<int> branchIds) async {
    await _services.doc(serviceId.toString()).set({
      'branchIds': branchIds,
    }, SetOptions(merge: true));
  }

  Future<List<int>> getBranchIdsForService(int serviceId) async {
    final snapshot = await _services.doc(serviceId.toString()).get();
    final data = snapshot.data();
    final rawBranchIds = data?['branchIds'];
    if (rawBranchIds is! List) return [];
    return rawBranchIds.whereType<num>().map((id) => id.toInt()).toList();
  }

  Future<int> _nextId(
      CollectionReference<Map<String, dynamic>> collection) async {
    final snapshot =
        await collection.orderBy('id', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return 1;
    final id = snapshot.docs.first.data()['id'];
    if (id is num) return id.toInt() + 1;
    return 1;
  }

  Future<void> insertOrder(OrderModel order, List<OrderItemModel> items) async {
    final ownerUid = order.ownerUid ?? _currentUserUid;
    final createdAt = AppDateTime.normalizeIsoString(order.createdAt);
    final history = order.statusHistory.isNotEmpty
        ? order.statusHistory
        : [
            OrderStatusHistoryModel(
              status: order.status,
              changedAt: createdAt,
            ),
          ];

    await _orders.doc(order.orderId).set({
      ...order.toMap(),
      'ownerUid': ownerUid,
      'createdAt': createdAt,
      'statusHistory': history.map((entry) => entry.toMap()).toList(),
      'items': items.map(_orderItemToFirestoreMap).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtWib': createdAt,
    }, SetOptions(merge: true));
    await createAdminOrderNotification(OrderModel.fromMap({
      ...order.toMap(),
      'ownerUid': ownerUid,
      'createdAt': createdAt,
      'statusHistory': history.map((entry) => entry.toMap()).toList(),
    }));
  }

  Future<List<OrderModel>> getAllOrders() async {
    final snapshot = await _orders.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
  }

  Future<List<OrderModel>> getOrdersByUser(int userId) async {
    final userUid = _currentUserUid;
    final snapshot = userUid == null || userUid.isEmpty
        ? await _orders.where('userId', isEqualTo: userId).get()
        : await _orders.where('ownerUid', isEqualTo: userUid).get();
    final orders =
        snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
    orders.sort((a, b) => _compareDateDesc(a.createdAt, b.createdAt));
    return orders;
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    final snapshot = await _orders.doc(orderId).get();
    final data = snapshot.data();
    final rawItems = data?['items'];
    if (rawItems is! List) return [];

    return rawItems
        .whereType<Map>()
        .map((item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<int> updateOrderStatus(String orderId, String newStatus) async {
    OrderModel? updatedOrder;
    OrderModel? readyOrder;
    final changedAt = AppDateTime.nowWibIsoString();

    await _firestore.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final snapshot = await transaction.get(orderRef);
      final data = snapshot.data();
      if (data == null) return;

      final currentStatus = data['status'] as String? ?? statusPending;
      if (currentStatus == newStatus) return;
      if (currentStatus == statusPickedUp) {
        throw StateError('Pesanan sudah diambil dan tidak bisa diedit lagi.');
      }
      if (currentStatus == statusReady && newStatus != statusPickedUp) {
        throw StateError(
            'Pesanan sudah siap diambil. Hanya bisa ditandai sudah diambil.');
      }
      if (newStatus == statusPickedUp && currentStatus != statusReady) {
        throw StateError(
            'Pesanan hanya bisa ditandai sudah diambil setelah siap diambil.');
      }

      final currentOrder = OrderModel.fromMap({
        ...data,
        'orderId': orderId,
      });
      final history = [
        ...currentOrder.statusHistory,
        OrderStatusHistoryModel(status: newStatus, changedAt: changedAt),
      ];
      final updates = <String, Object?>{
        'status': newStatus,
        'statusHistory': history.map((entry) => entry.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtWib': changedAt,
      };
      if (newStatus == statusReady) {
        updates['readyAt'] = changedAt;
      }
      if (newStatus == statusPickedUp) {
        updates['completedAt'] = changedAt;
      }

      transaction.update(orderRef, {
        ...updates,
      });

      updatedOrder = OrderModel.fromMap({
        ...data,
        'orderId': orderId,
        'status': newStatus,
        'statusHistory': updates['statusHistory'],
        'readyAt': updates['readyAt'] ?? data['readyAt'],
        'completedAt': updates['completedAt'] ?? data['completedAt'],
      });

      if (newStatus == statusReady) {
        readyOrder = updatedOrder;
      }
    });

    if (readyOrder != null) {
      await createUserOrderReadyNotification(readyOrder!);
    }
    if (updatedOrder != null) {
      await _syncOrderNotificationsForStatus(updatedOrder!);
    }

    return 1;
  }

  Future<void> createAdminOrderNotification(OrderModel order) async {
    final notificationId = _adminOrderNotificationId(order.orderId);
    await _notifications.doc(notificationId).set({
      'targetRole': 'admin',
      'targetUserId': null,
      'orderId': order.orderId,
      'type': 'order_created',
      'title': 'Order baru masuk',
      'message':
          'Pesanan ${order.orderId} dari ${order.branchName} menunggu diproses.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    }, SetOptions(merge: true));
  }

  Future<void> createUserOrderReadyNotification(OrderModel order) async {
    final notificationId = _userOrderReadyNotificationId(order);
    await _notifications.doc(notificationId).set({
      'targetRole': 'user',
      'targetUid': order.ownerUid,
      'targetUserId': order.userId,
      'userId': order.userId,
      'orderId': order.orderId,
      'type': 'order_ready',
      'title': 'Pesanan siap diambil',
      'message':
          'Pesanan ${order.orderId} sudah siap diambil di ${order.branchName}.',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    }, SetOptions(merge: true));
  }

  Future<List<NotificationModel>> getNotificationsForUser(int userId) async {
    final userUid = _currentUserUid;
    final snapshot = userUid == null || userUid.isEmpty
        ? await _notifications.where('targetUserId', isEqualTo: userId).get()
        : await _notifications.where('targetUid', isEqualTo: userUid).get();
    final notifications = <NotificationModel>[];
    for (final doc in snapshot.docs) {
      final stillRelevant = await _isNotificationStillRelevant(doc.data());
      if (!stillRelevant) {
        await _markNotificationAsReadIfExists(doc.id);
        continue;
      }
      notifications.add(_notificationFromFirestoreDoc(doc));
    }
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Stream<List<NotificationModel>> watchUnreadUserNotifications(int userId) {
    final userUid = _currentUserUid;
    final query = userUid == null || userUid.isEmpty
        ? _notifications.where('targetUserId', isEqualTo: userId)
        : _notifications.where('targetUid', isEqualTo: userUid);

    return query.snapshots().asyncMap((snapshot) async {
      final notifications = <NotificationModel>[];
      for (final doc in snapshot.docs) {
        final notification = _notificationFromFirestoreDoc(doc);
        if (notification.isRead) continue;
        final stillRelevant = await _isNotificationStillRelevant(doc.data());
        if (!stillRelevant) {
          await _markNotificationAsReadIfExists(doc.id);
          continue;
        }
        notifications.add(notification);
      }
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  Stream<List<NotificationModel>> watchUnreadAdminNotifications() {
    return _notifications
        .where('targetRole', isEqualTo: 'admin')
        .snapshots()
        .asyncMap((snapshot) async {
      final notifications = <NotificationModel>[];
      for (final doc in snapshot.docs) {
        final notification = _notificationFromFirestoreDoc(doc);
        if (notification.isRead) continue;
        final stillRelevant = await _isNotificationStillRelevant(doc.data());
        if (!stillRelevant) {
          await _markNotificationAsReadIfExists(doc.id);
          continue;
        }
        notifications.add(notification);
      }
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _notifications.doc(notificationId).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncOrderNotificationsForStatus(OrderModel order) async {
    if (order.status != statusPending) {
      await _markNotificationAsReadIfExists(
          _adminOrderNotificationId(order.orderId));
    }
    if (order.status != statusReady) {
      await _markNotificationAsReadIfExists(
          _userOrderReadyNotificationId(order));
    }
  }

  Future<bool> _isNotificationStillRelevant(
      Map<String, dynamic> notificationData) async {
    final type = notificationData['type'] as String? ?? '';
    final orderId = notificationData['orderId'] as String? ?? '';
    if (orderId.isEmpty) return true;

    final orderSnapshot = await _orders.doc(orderId).get();
    final orderData = orderSnapshot.data();
    if (orderData == null) return false;

    final status = orderData['status'] as String? ?? statusPending;
    if (type == 'order_created') return status == statusPending;
    if (type == 'order_ready') return status == statusReady;
    return true;
  }

  Future<void> _markNotificationAsReadIfExists(String notificationId) async {
    final ref = _notifications.doc(notificationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    await ref.set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _orderItemToFirestoreMap(OrderItemModel item) {
    final data = item.toMap();
    data.remove('id');
    data.remove('filePath');
    return data;
  }

  Map<String, dynamic> _branchToFirestoreMap(BranchModel branch) {
    return {
      ...branch.toMap(),
      'openHours': BranchSchedule.normalizeOpenHours(branch.openHours),
      'operationalMode':
          BranchOperationalMode.normalize(branch.operationalMode),
    };
  }

  NotificationModel _notificationFromFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NotificationModel.fromMap({
      ...doc.data(),
      'firestoreId': doc.id,
      'targetUid': doc.data()['targetUid'],
      'userId': doc.data()['targetUserId'] ?? 0,
    });
  }

  String _safeDocId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  }

  String _adminOrderNotificationId(String orderId) {
    return 'admin_order_created_${_safeDocId(orderId)}';
  }

  String _userOrderReadyNotificationId(OrderModel order) {
    final ownerKey = order.ownerUid?.trim().isNotEmpty == true
        ? order.ownerUid!
        : order.userId.toString();
    return 'user_${_safeDocId(ownerKey)}_order_ready_${_safeDocId(order.orderId)}';
  }

  int _compareDateDesc(String left, String right) {
    final leftDate = AppDateTime.parseToWib(left);
    final rightDate = AppDateTime.parseToWib(right);
    if (leftDate == null || rightDate == null) return right.compareTo(left);
    return rightDate.compareTo(leftDate);
  }
}
