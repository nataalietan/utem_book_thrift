class NotificationModel {
  final String id;
  final DateTime createdAt;
  final String? userId; // Null if general admin notification, but we will create rows per user
  final String title;
  final String message;
  final bool isRead;
  final String? type;
  final String? referenceId;

  NotificationModel({
    required this.id,
    required this.createdAt,
    this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    this.type,
    this.referenceId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      userId: json['userID'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      type: json['type'] as String?,
      referenceId: json['reference_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'created_at': createdAt.toIso8601String(),
      if (userId != null) 'userID': userId,
      'title': title,
      'message': message,
      'is_read': isRead,
      if (type != null) 'type': type,
      if (referenceId != null) 'reference_id': referenceId,
    };
  }
}