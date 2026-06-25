import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'admin_home_page.dart';
import 'seller_dashboard_page.dart';
import 'order_tracking_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.fetchNotifications(_userId);
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading notifications: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    
    try {
      await _notificationService.markAsRead(notification.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: notification.id,
            createdAt: notification.createdAt,
            userId: notification.userId,
            title: notification.title,
            message: notification.message,
            isRead: true,
            type: notification.type,
            referenceId: notification.referenceId,
          );
        }
      });
    } catch (e) {
      print('Failed to mark read: $e');
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // Mark as read immediately
    _markAsRead(notification);

    final String? type = notification.type;
    final String titleStr = notification.title.toLowerCase();
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    final bool isAdmin = currentUser?.userMetadata?['role'] == 'Admin';
    
    // Admin notifications
    if (isAdmin) {
      int initialIndex = 0; // Default to Dashboard
      if (type == 'order_placed' || type == 'order_cancel_request' || titleStr.contains('order')) {
        initialIndex = 4; // Orders
      } else if (type == 'listing_submitted' || type == 'listing_resubmitted' || type == 'delete_request' || 
          titleStr.contains('submit') || titleStr.contains('cancel') || titleStr.contains('delete')) {
        initialIndex = 2; // Approvals
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminHomePage(initialIndex: initialIndex)),
      );
    } 
    // Student/Staff notifications
    else {
      if (type == 'order_cancel_approved' || type == 'order_cancel_rejected' || titleStr.contains('order cancellation')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OrderTrackingPage()),
        );
        return;
      }

      String initialTab = 'Available';
      
      if (titleStr.contains('approved')) {
        initialTab = 'Pending Drop-off';
      } else if ((titleStr.contains('delete') || titleStr.contains('cancel')) && (titleStr.contains('reject') || titleStr.contains('denied'))) {
        initialTab = 'Pending Drop-off';
      } else if (titleStr.contains('delet') || titleStr.contains('remov')) {
        initialTab = 'Removed'; 
      } else if (titleStr.contains('reject') || titleStr.contains('denied')) {
        initialTab = 'Rejected';
      } else if (titleStr.contains('available')) {
        initialTab = 'Available';
      } else if (titleStr.contains('order')) {
        initialTab = 'History';
      } else {
        // Fallback if title doesn't match expected keywords
        if (type == 'listing_approved' || type == 'delete_request_rejected') {
          initialTab = 'Pending Drop-off';
        } else if (type == 'listing_rejected') {
          initialTab = 'Rejected';
        } else if (type == 'listing_removed') {
          initialTab = 'Removed';
        } else if (type == 'book_available') {
          initialTab = 'Available';
        } else if (type == 'drop_off_success') {
          initialTab = 'My Income';
        }
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SellerDashboardPage(initialTab: initialTab)),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead(_userId);
      setState(() {
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            createdAt: n.createdAt,
            userId: n.userId,
            title: n.title,
            message: n.message,
            isRead: true,
            type: n.type,
            referenceId: n.referenceId,
          );
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error marking all as read: $e')));
      }
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'listing_approved':
        return Icons.check_circle_outline;
      case 'listing_rejected':
        return Icons.cancel_outlined;

      case 'order_placed':
        return Icons.shopping_bag_outlined;
      case 'drop_off_success':
        return Icons.check_circle_outline;
      case 'book_available':
        return Icons.public;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 800 ? 60.0 : 20.0, vertical: 10.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text('Mark all as read', style: TextStyle(color: Color(0xFF023E8A), fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return InkWell(
                      onTap: () => _handleNotificationTap(notification),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: notification.isRead ? Colors.transparent : const Color(0xFFE8F0FE).withOpacity(0.5),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: notification.isRead ? Colors.grey.shade100 : const Color(0xFF023E8A).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(notification.type),
                                color: notification.isRead ? Colors.grey.shade600 : const Color(0xFF023E8A),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: TextStyle(
                                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        timeago.format(notification.createdAt),
                                        style: TextStyle(
                                          color: notification.isRead ? Colors.grey.shade500 : const Color(0xFF023E8A),
                                          fontSize: 12,
                                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.message,
                                    style: TextStyle(
                                      color: notification.isRead ? Colors.grey.shade600 : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!notification.isRead) ...[
                              const SizedBox(width: 16),
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF023E8A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}