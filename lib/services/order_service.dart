import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../models/textbook_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'notification_service.dart';

class OrderService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<OrderModel>> fetchUserOrders(String userId) async {
    final data = await _client
        .from('ORDER')
        .select('*, ORDER_ITEM(*, TEXTBOOK(*, USER:sellerID(*))), PAYMENT(*)')
        .eq('buyerID', userId)
        .order('orderedAt', ascending: false);
    return List<Map<String, dynamic>>.from(data).map((json) => OrderModel.fromJson(json)).toList();
  }

  Future<List<OrderModel>> fetchAllOrders() async {
    final data = await _client
        .from('ORDER')
        .select('*, ORDER_ITEM(*, TEXTBOOK(*, USER:sellerID(*))), PAYMENT(*)')
        .order('orderedAt', ascending: false);
    return List<Map<String, dynamic>>.from(data).map((json) => OrderModel.fromJson(json)).toList();
  }

  Future<void> updateOrderStatus(dynamic orderId, String status) async {
    await _client.from('ORDER').update({'status': status}).eq('orderID', orderId);
  }

  Future<void> updatePickupStatus(dynamic paymentId, String status) async {
    await _client.from('PAYMENT').update({'pickupStatus': status}).eq('paymentID', paymentId);
  }

  Future<void> requestOrderCancel(dynamic orderId, String reason) async {
    await _client.from('ORDER').update({
      'status': 'Cancel Requested',
      'cancelReason': reason,
    }).eq('orderID', orderId);

    try {
      final notificationService = NotificationService();
      await notificationService.sendAdminNotification(
        title: 'Order Cancellation Request',
        message: 'A user has requested to cancel Order #$orderId',
        type: 'order_cancel_request',
        referenceId: orderId.toString(),
      );
    } catch (e) {
      print('Failed to send admin notification for cancel request: $e');
    }
  }

  Future<void> approveOrderCancel(dynamic orderId, dynamic paymentId, List<dynamic> textbookIds, {String? receiptUrl, required String buyerId}) async {
    // 1. Update order status to Cancelled
    await updateOrderStatus(orderId, 'Cancelled');
    
    // 2. Update payment status to Refunded and attach receipt
    if (paymentId != null) {
      await _client.from('PAYMENT').update({
        'paymentStatus': 'Refunded',
        if (receiptUrl != null) 'refundReceiptUrl': receiptUrl,
      }).eq('paymentID', paymentId);
    }

    // 3. Revert textbooks to Available
    if (textbookIds.isNotEmpty) {
      for (var tbId in textbookIds) {
        await _client.from('TEXTBOOK').update({'status': 'Available'}).eq('textbookID', tbId);
      }
    }

    try {
      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: buyerId,
        title: 'Order Cancellation Approved',
        message: 'Your request to cancel Order #$orderId has been approved and refunded.',
        type: 'order_cancel_approved',
        referenceId: orderId.toString(),
      );
    } catch (e) {
      print('Failed to send notification for cancel approve: $e');
    }
  }

  Future<String> uploadRefundReceipt(String fileName, Uint8List imageBytes, String extension) async {
    await _client.storage.from('receipts').uploadBinary(
      fileName,
      imageBytes,
      fileOptions: FileOptions(contentType: 'image/$extension'),
    );
    return _client.storage.from('receipts').getPublicUrl(fileName);
  }

  Future<void> rejectOrderCancel(dynamic orderId, String reason, String buyerId) async {
    // Revert status to Placed and clear cancel reason
    await _client.from('ORDER').update({
      'status': 'Placed',
      'cancelReason': null,
    }).eq('orderID', orderId);

    try {
      final notificationService = NotificationService();
      await notificationService.sendNotification(
        userId: buyerId,
        title: 'Order Cancellation Rejected',
        message: 'Your request to cancel Order #$orderId was rejected. Reason: $reason',
        type: 'order_cancel_rejected',
        referenceId: orderId.toString(),
      );
    } catch (e) {
      print('Failed to send notification for cancel reject: $e');
    }
  }

  Future<void> placeOrder({
    required String buyerID,
    required List<TextbookModel> textbooks,
    required double totalPrice,
    required String paymentMethod,
  }) async {
    try {
      // Generate a random 4-digit PIN
      final pin = (1000 + Random().nextInt(9000)).toString();

      // 1. Insert Order
      final orderResponse = await _client.from('ORDER').insert({
        'buyerID': buyerID,
        'status': 'Placed',
        'totalPrice': totalPrice,
        'pickupPin': pin,
      }).select().single();
      
      final orderID = orderResponse['orderID'];

      // 2. Insert Order Items
      List<Map<String, dynamic>> orderItems = [];
      for (var book in textbooks) {
        orderItems.add({
          'orderID': orderID,
          'textbookID': book.textbookID,
          'priceAtPurchase': book.listingPrice,
        });
      }
      await _client.from('ORDER_ITEM').insert(orderItems);

      // 3. Insert Payment
      await _client.from('PAYMENT').insert({
        'orderID': orderID,
        'paymentMethod': paymentMethod,
        'pickupStatus': 'Pending',
        'paymentStatus': 'Paid',
      });

      // 4. Update Textbook Statuses
      for (var book in textbooks) {
        await _client.from('TEXTBOOK').update({'status': 'Sold'}).eq('textbookID', book.textbookID);
      }

      // 5. Remove from Cart & Wishlist
      for (var book in textbooks) {
        await _client.from('CART').delete().eq('textbookID', book.textbookID).eq('userID', buyerID);
        await _client.from('WISHLIST').delete().eq('textbookID', book.textbookID).eq('userID', buyerID);
      }

    } catch (e) {
      debugPrint('Error placing order: $e');
      rethrow;
    }
  }
}
