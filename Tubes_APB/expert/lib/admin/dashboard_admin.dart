import 'dart:async';

import 'package:flutter/material.dart';
import 'catalog_service.dart';
import 'branch_management_page.dart';
import 'order_management_page.dart';
import '../auth/splash_screen.dart';
import '../data/app_session_service.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  static const Duration _notificationDuration = Duration(seconds: 2);

  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  final AppSessionService _sessionService = AppSessionService();
  final Set<String> _seenNotificationIds = {};
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  bool _notificationListenerReady = false;

  @override
  void initState() {
    super.initState();
    _listenForAdminNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForAdminNotifications() {
    _notificationSubscription =
        _db.watchUnreadAdminNotifications().listen((notifications) {
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
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderManagementPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            const CustomHeader(title: 'Dashboard Admin'),
            const SizedBox(height: 28),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    MenuCard(
                      icon: Icons.design_services_outlined,
                      title: 'Layanan',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CatalogServicePage()),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    MenuCard(
                      icon: Icons.location_on_outlined,
                      title: 'Cabang',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BranchManagementPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    MenuCard(
                      icon: Icons.check_box_outlined,
                      title: 'Pesanan',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrderManagementPage()),
                        );
                      },
                    ),
                    const Spacer(),
                    // Tombol Logout
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            messenger.clearSnackBars();
                            await _sessionService.clear();
                            if (!mounted) return;
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const SplashScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Logout',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS — dipakai oleh admin pages lain
// ═══════════════════════════════════════════════════════════════════════════════

class AppColors {
  static const primary = Color(0xFF2848C7);
  static const primarySoft = Color(0xFFDCE3FF);
  static const border = Color(0xFF9CB0FF);
  static const card = Color(0xFFF2F4FB);
  static const text = Color(0xFF3B3B45);
}

class CustomHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBack;

  const CustomHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 34),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.text),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
