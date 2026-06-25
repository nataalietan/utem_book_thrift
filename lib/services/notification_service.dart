import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<NotificationModel>> fetchNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('NOTIFICATIONS')
          .select()
          .eq('userID', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('NOTIFICATIONS')
          .count(CountOption.exact)
          .eq('userID', userId)
          .eq('is_read', false);
      return response;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('NOTIFICATIONS')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      throw Exception('Failed to mark as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('NOTIFICATIONS')
          .update({'is_read': true})
          .eq('userID', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all as read: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? referenceId,
  }) async {
    try {
      await _supabase.from('NOTIFICATIONS').insert({
        'userID': userId,
        'title': title,
        'message': message,
        if (type != null) 'type': type,
        if (referenceId != null) 'reference_id': referenceId,
      });
    } catch (e) {
      print('Error sending notification: $e');
      // Non-blocking error, so we don't necessarily want to throw and break the main flow
    }
  }

  Future<void> sendAdminNotification({
    required String title,
    required String message,
    String? type,
    String? referenceId,
  }) async {
    try {
      // Find all admin users
      final admins = await _supabase.from('USER').select('userID').eq('role', 'Admin');
      
      if (admins.isEmpty) return;

      // Insert a notification for each admin
      final List<Map<String, dynamic>> inserts = (admins as List).map((admin) {
        return {
          'userID': admin['userID'],
          'title': title,
          'message': message,
          if (type != null) 'type': type,
          if (referenceId != null) 'reference_id': referenceId,
        };
      }).toList();

      await _supabase.from('NOTIFICATIONS').insert(inserts);
    } catch (e) {
      print('Error sending admin notification: $e');
    }
  }
}