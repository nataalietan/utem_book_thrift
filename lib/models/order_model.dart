import 'order_item_model.dart';
import 'payment_model.dart';
import 'user_model.dart';

class OrderModel {
  final dynamic orderID;
  final String buyerID;
  final String status;
  final double totalPrice;
  final String orderedAt;
  final String? pickupPin;
  final String? cancelReason;
  final List<OrderItemModel>? items;
  final List<PaymentModel>? payments;
  final UserModel? buyer;

  OrderModel({
    required this.orderID,
    required this.buyerID,
    required this.status,
    required this.totalPrice,
    required this.orderedAt,
    this.pickupPin,
    this.cancelReason,
    this.items,
    this.payments,
    this.buyer,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<PaymentModel> parsedPayments = [];
    if (json['PAYMENT'] != null) {
      if (json['PAYMENT'] is List) {
        parsedPayments = (json['PAYMENT'] as List).map((p) => PaymentModel.fromJson(p)).toList();
      }
    }

    List<OrderItemModel> parsedItems = [];
    if (json['ORDER_ITEM'] != null) {
      if (json['ORDER_ITEM'] is List) {
        parsedItems = (json['ORDER_ITEM'] as List).map((i) => OrderItemModel.fromJson(i)).toList();
      }
    }

    return OrderModel(
      orderID: json['orderID'],
      buyerID: json['buyerID'] ?? '',
      status: json['status'] ?? 'Placed',
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      orderedAt: json['orderedAt'] ?? '',
      pickupPin: json['pickupPin'],
      cancelReason: json['cancelReason'],
      items: parsedItems,
      payments: parsedPayments,
      buyer: json['USER'] != null ? UserModel.fromJson(json['USER']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderID != null) 'orderID': orderID,
      'buyerID': buyerID,
      'status': status,
      'totalPrice': totalPrice,
      if (pickupPin != null) 'pickupPin': pickupPin,
      if (cancelReason != null) 'cancelReason': cancelReason,
    };
  }
}
