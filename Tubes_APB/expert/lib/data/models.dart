import 'dart:convert';

import 'time_utils.dart';

// Data models untuk Expert Printing App.
// Semua model punya toMap() untuk insert ke DB dan fromMap() untuk baca dari DB.

class UserModel {
  final int? id;
  final String? firebaseUid;
  final String name;
  final String email;
  final String password;
  final String phone;

  UserModel({
    this.id,
    this.firebaseUid,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'firebaseUid': firebaseUid,
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'],
        firebaseUid: map['firebaseUid'] ?? map['uid'],
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        password: map['password'] ?? '',
        phone: map['phone'] ?? '',
      );
}

class ServiceModel {
  final int? id;
  final String name;
  final int price;
  final String unit;
  final String options; // comma-separated: "BW,Berwarna"
  final String description;
  final bool isActive;
  final String icon; // icon name string
  final String imageUrl;

  ServiceModel({
    this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.options = '',
    this.description = '',
    this.isActive = true,
    this.icon = 'print_outlined',
    this.imageUrl = '',
  });

  List<String> get optionsList =>
      options.isEmpty ? [] : options.split(',').map((e) => e.trim()).toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'unit': unit,
        'options': options,
        'description': description,
        'isActive': isActive ? 1 : 0,
        'icon': icon,
        'imageUrl': imageUrl,
      };

  factory ServiceModel.fromMap(Map<String, dynamic> map) => ServiceModel(
        id: map['id'],
        name: map['name'] ?? '',
        price: map['price'] ?? 0,
        unit: map['unit'] ?? '',
        options: map['options'] ?? '',
        description: map['description'] ?? '',
        isActive: _boolFromMapValue(map['isActive'], fallback: true),
        icon: map['icon'] ?? 'print_outlined',
        imageUrl: map['imageUrl'] ?? '',
      );

  ServiceModel copyWith({
    int? id,
    String? name,
    int? price,
    String? unit,
    String? options,
    String? description,
    bool? isActive,
    String? icon,
    String? imageUrl,
  }) =>
      ServiceModel(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        options: options ?? this.options,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        icon: icon ?? this.icon,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

class BranchModel {
  final int? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool _storedIsOpen;
  final String openHours;
  final String operationalMode;
  final double rating;

  BranchModel({
    this.id,
    required this.name,
    required this.address,
    this.latitude = 0.0,
    this.longitude = 0.0,
    bool isOpen = true,
    this.openHours = '08.00 - 20.00',
    this.operationalMode = BranchOperationalMode.automatic,
    this.rating = 0.0,
  }) : _storedIsOpen = isOpen;

  bool get isOpen => BranchSchedule.effectiveIsOpen(
        openHours: openHours,
        operationalMode: operationalMode,
        fallbackIsOpen: _storedIsOpen,
      );

  bool get isAutomatic =>
      BranchOperationalMode.normalize(operationalMode) ==
      BranchOperationalMode.automatic;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'isOpen': isOpen ? 1 : 0,
        'openHours': openHours,
        'operationalMode': BranchOperationalMode.normalize(operationalMode),
        'rating': rating,
      };

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    final openHours = BranchSchedule.normalizeOpenHours(
        '${map['openHours'] ?? '08.00 - 20.00'}');
    return BranchModel(
      id: map['id'],
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      isOpen: _boolFromMapValue(map['isOpen'], fallback: true),
      openHours: openHours,
      operationalMode: BranchOperationalMode.normalize(map['operationalMode']),
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }
}

bool _boolFromMapValue(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return fallback;
}

class CartItemModel {
  final int? id;
  final int userId;
  final int serviceId;
  final String serviceName;
  final int quantity;
  final String size;
  final String? filePath;
  final String? fileName;
  final int unitPrice;
  final int totalPrice;

  CartItemModel({
    this.id,
    required this.userId,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    this.size = '',
    this.filePath,
    this.fileName,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'quantity': quantity,
        'size': size,
        'filePath': filePath,
        'fileName': fileName,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
      };

  factory CartItemModel.fromMap(Map<String, dynamic> map) => CartItemModel(
        id: map['id'],
        userId: map['userId'] ?? 0,
        serviceId: map['serviceId'] ?? 0,
        serviceName: map['serviceName'] ?? '',
        quantity: map['quantity'] ?? 1,
        size: map['size'] ?? '',
        filePath: map['filePath'],
        fileName: map['fileName'],
        unitPrice: map['unitPrice'] ?? 0,
        totalPrice: map['totalPrice'] ?? 0,
      );
}

class OrderStatusHistoryModel {
  final String status;
  final String changedAt;
  final String? note;

  const OrderStatusHistoryModel({
    required this.status,
    required this.changedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'status': status,
        'changedAt': changedAt,
        if (note != null && note!.trim().isNotEmpty) 'note': note,
      };

  factory OrderStatusHistoryModel.fromMap(Map<String, dynamic> map) =>
      OrderStatusHistoryModel(
        status: map['status'] ?? '',
        changedAt: _dateStringFromMapValue(map['changedAt']),
        note: map['note'],
      );
}

class OrderModel {
  final String orderId;
  final int userId;
  final String? ownerUid;
  final int branchId;
  final String branchName;
  final String status; // Pending, Sedang Dicetak, Siap Diambil, Sudah Diambil
  final int totalPrice;
  final String createdAt;
  final String? readyAt;
  final String? completedAt;
  final List<OrderStatusHistoryModel> statusHistory;

  OrderModel({
    required this.orderId,
    required this.userId,
    this.ownerUid,
    required this.branchId,
    this.branchName = '',
    this.status = 'Pending',
    required this.totalPrice,
    required this.createdAt,
    this.readyAt,
    this.completedAt,
    this.statusHistory = const [],
  });

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'userId': userId,
        'ownerUid': ownerUid,
        'branchId': branchId,
        'branchName': branchName,
        'status': status,
        'totalPrice': totalPrice,
        'createdAt': createdAt,
        'readyAt': readyAt,
        'completedAt': completedAt,
        'statusHistory': statusHistory.map((entry) => entry.toMap()).toList(),
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final status = map['status'] ?? 'Pending';
    final createdAt = _dateStringFromMapValue(map['createdAt']);
    final history = _statusHistoryFromMapValue(map['statusHistory']);
    final effectiveHistory = history.isNotEmpty
        ? history
        : [
            OrderStatusHistoryModel(
              status: status,
              changedAt: createdAt,
            )
          ];

    return OrderModel(
      orderId: map['orderId'] ?? '',
      userId: map['userId'] ?? 0,
      ownerUid: map['ownerUid'] ?? map['uid'],
      branchId: map['branchId'] ?? 0,
      branchName: map['branchName'] ?? '',
      status: status,
      totalPrice: map['totalPrice'] ?? 0,
      createdAt: createdAt,
      readyAt: _nullableDateStringFromMapValue(map['readyAt']) ??
          _historyTimeForStatus(effectiveHistory, 'Siap Diambil'),
      completedAt: _nullableDateStringFromMapValue(map['completedAt']) ??
          _historyTimeForStatus(effectiveHistory, 'Sudah Diambil'),
      statusHistory: effectiveHistory,
    );
  }
}

class OrderItemModel {
  final int? id;
  final String orderId;
  final int serviceId;
  final String serviceName;
  final int quantity;
  final String size;
  final String? filePath;
  final String? fileName;
  final String? fileUrl;
  final int price;

  OrderItemModel({
    this.id,
    required this.orderId,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    this.size = '',
    this.filePath,
    this.fileName,
    this.fileUrl,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'quantity': quantity,
        'size': size,
        'filePath': filePath,
        'fileName': fileName,
        'fileUrl': fileUrl,
        'price': price,
      };

  String get displayFileName {
    final explicitName = fileName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) return explicitName;

    final localPath = filePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return localPath.split(RegExp(r'[\\/]')).last;
    }

    final remoteUrl = fileUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      final uri = Uri.tryParse(remoteUrl);
      final lastSegment =
          uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : null;
      if (lastSegment != null && lastSegment.isNotEmpty) {
        return Uri.decodeComponent(lastSegment);
      }
    }

    return 'File upload';
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) => OrderItemModel(
        id: map['id'],
        orderId: map['orderId'] ?? '',
        serviceId: map['serviceId'] ?? 0,
        serviceName: map['serviceName'] ?? '',
        quantity: map['quantity'] ?? 1,
        size: map['size'] ?? '',
        filePath: map['filePath'],
        fileName: map['fileName'],
        fileUrl: map['fileUrl'],
        price: map['price'] ?? 0,
      );
}

class NotificationModel {
  final int? id;
  final String? firestoreId;
  final String? targetUid;
  final int userId;
  final String title;
  final String message;
  final String createdAt;
  final bool isRead;

  NotificationModel({
    this.id,
    this.firestoreId,
    this.targetUid,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'targetUid': targetUid,
        'userId': userId,
        'title': title,
        'message': message,
        'createdAt': createdAt,
        'isRead': isRead ? 1 : 0,
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel(
        id: map['id'],
        firestoreId: map['firestoreId'],
        targetUid: map['targetUid'] ?? map['uid'],
        userId: map['userId'] ?? 0,
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        createdAt: _dateStringFromMapValue(map['createdAt']),
        isRead: _boolFromMapValue(map['isRead'], fallback: false),
      );
}

String _dateStringFromMapValue(dynamic value) {
  return AppDateTime.normalizeIsoString(value);
}

String? _nullableDateStringFromMapValue(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return AppDateTime.normalizeIsoString(value);
}

List<OrderStatusHistoryModel> _statusHistoryFromMapValue(dynamic value) {
  if (value == null) return const [];

  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return _statusHistoryFromMapValue(decoded);
    } catch (_) {
      return const [];
    }
  }

  if (value is List) {
    return value
        .whereType<Map>()
        .map((entry) => OrderStatusHistoryModel.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .where((entry) => entry.status.trim().isNotEmpty)
        .toList();
  }

  return const [];
}

String? _historyTimeForStatus(
  List<OrderStatusHistoryModel> history,
  String status,
) {
  for (final entry in history) {
    if (entry.status == status) return entry.changedAt;
  }
  return null;
}

/// Helper class: menyimpan session user yang sedang login
class SessionManager {
  static int? currentUserId;
  static String? currentUserUid;
  static String? currentUserName;
  static String? currentUserEmail;
  static int? selectedBranchId;
  static String? selectedBranchName;
  static String? selectedBranchAddress;

  static void login(UserModel user) {
    currentUserId = user.id;
    currentUserUid = user.firebaseUid;
    currentUserName = user.name;
    currentUserEmail = user.email;
  }

  static void updateProfile(UserModel user) {
    currentUserId = user.id;
    currentUserUid = user.firebaseUid;
    currentUserName = user.name;
    currentUserEmail = user.email;
  }

  static void logout() {
    currentUserId = null;
    currentUserUid = null;
    currentUserName = null;
    currentUserEmail = null;
    clearSelectedBranch();
  }

  static bool get isLoggedIn => currentUserId != null;

  static void selectBranch(BranchModel branch) {
    selectedBranchId = branch.id;
    selectedBranchName = branch.name;
    selectedBranchAddress = branch.address;
  }

  static void clearSelectedBranch() {
    selectedBranchId = null;
    selectedBranchName = null;
    selectedBranchAddress = null;
  }
}
