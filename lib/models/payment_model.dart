class PaymentModel {
  final dynamic paymentID;
  final dynamic orderID;
  final String paymentMethod;
  final double amountPaid;
  final String? pickupStatus;
  final String paymentDate;
  final String paymentStatus;
  final String? refundReceiptUrl;

  PaymentModel({
    required this.paymentID,
    required this.orderID,
    required this.paymentMethod,
    required this.amountPaid,
    this.pickupStatus,
    required this.paymentDate,
    required this.paymentStatus,
    this.refundReceiptUrl,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentID: json['paymentID'],
      orderID: json['orderID'],
      paymentMethod: json['paymentMethod'] ?? '',
      amountPaid: (json['amountPaid'] ?? 0.0).toDouble(),
      pickupStatus: json['pickupStatus'],
      paymentDate: json['paymentDate'] ?? '',
      paymentStatus: json['paymentStatus'] ?? 'Paid',
      refundReceiptUrl: json['refundReceiptUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (paymentID != null) 'paymentID': paymentID,
      'orderID': orderID,
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
      'pickupStatus': pickupStatus,
      'paymentStatus': paymentStatus,
      if (refundReceiptUrl != null) 'refundReceiptUrl': refundReceiptUrl,
    };
  }
}
