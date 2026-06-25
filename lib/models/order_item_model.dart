import 'textbook_model.dart';

class OrderItemModel {
  final dynamic orderItemID;
  final dynamic orderID;
  final dynamic textbookID;
  final double priceAtPurchase;
  final TextbookModel? textbook;

  OrderItemModel({
    required this.orderItemID,
    required this.orderID,
    required this.textbookID,
    required this.priceAtPurchase,
    this.textbook,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      orderItemID: json['orderItemID'],
      orderID: json['orderID'],
      textbookID: json['textbookID'],
      priceAtPurchase: (json['priceAtPurchase'] ?? 0.0).toDouble(),
      textbook: json['TEXTBOOK'] != null ? TextbookModel.fromJson(json['TEXTBOOK']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderItemID != null) 'orderItemID': orderItemID,
      'orderID': orderID,
      'textbookID': textbookID,
      'priceAtPurchase': priceAtPurchase,
    };
  }
}
