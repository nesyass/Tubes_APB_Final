import 'package:flutter/material.dart';
import '../data/firestore_database_service.dart';
import '../data/models.dart';
import '../data/time_utils.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  final FirestoreDatabaseService _db = FirestoreDatabaseService();
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = SessionManager.currentUserId;
    final userUid = SessionManager.currentUserUid;
    if (userId == null || userUid == null || userUid.isEmpty) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _loading = false;
        });
      }
      return;
    }

    final data = await _db.getNotificationsForUser(userId);
    if (mounted) {
      setState(() {
        _notifications = data;
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notif) async {
    final firestoreId = notif.firestoreId;
    if (!notif.isRead && firestoreId != null) {
      await _db.markNotificationAsRead(firestoreId);
      _loadNotifications();
    }
  }

  String _formatDate(String isoDate) {
    return AppDateTime.formatRelativeWib(isoDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4CB9),
        foregroundColor: Colors.white,
        title: const Text('Notifikasi'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text('Belum ada notifikasi.',
                      style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      return GestureDetector(
                        onTap: () => _markAsRead(notif),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: notif.isRead
                                ? Colors.white
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: notif.isRead
                                  ? Colors.grey.shade200
                                  : const Color(0xFF2E4CB9).withAlpha(50),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: notif.isRead
                                      ? Colors.grey.shade100
                                      : const Color(0xFF2E4CB9).withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.notifications,
                                  color: notif.isRead
                                      ? Colors.grey
                                      : const Color(0xFF2E4CB9),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notif.title,
                                        style: TextStyle(
                                          fontWeight: notif.isRead
                                              ? FontWeight.w500
                                              : FontWeight.bold,
                                          fontSize: 14,
                                        )),
                                    const SizedBox(height: 4),
                                    Text(notif.message,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                    const SizedBox(height: 6),
                                    Text(_formatDate(notif.createdAt),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[400])),
                                  ],
                                ),
                              ),
                              if (!notif.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF2E4CB9),
                                      shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
