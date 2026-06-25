import 'user_model.dart';

class TextbookModel {
  final dynamic textbookID; // Usually int or string
  final String sellerID;
  final String title;
  final String domain;
  final String? faculty;
  final String? studyLevel;
  final int? edition;
  final int conditionScore;
  final double originalPrice;
  final double listingPrice;
  final bool isLatestEdition;
  final String status;
  final String? description;
  final String? imageUrl;
  final String createdAt;
  final String? rejectionReason;
  final String? dropOffPin;
  final String? deleteRequestReason;
  final bool isDeleteRequested;
  final double? sellerEarnings;
  final bool isArchived;
  final UserModel? seller;

  TextbookModel({
    required this.textbookID,
    required this.sellerID,
    required this.title,
    required this.domain,
    this.faculty,
    this.studyLevel,
    this.edition,
    required this.conditionScore,
    required this.originalPrice,
    required this.listingPrice,
    required this.isLatestEdition,
    required this.status,
    this.description,
    this.imageUrl,
    required this.createdAt,
    this.rejectionReason,
    this.dropOffPin,
    this.deleteRequestReason,
    this.isDeleteRequested = false,
    this.sellerEarnings,
    this.isArchived = false,
    this.seller,
  });

  factory TextbookModel.fromJson(Map<String, dynamic> json) {
    return TextbookModel(
      textbookID: json['textbookID'],
      sellerID: json['sellerID'] ?? '',
      title: json['title'] ?? '',
      domain: json['domain'] ?? '',
      faculty: json['faculty'],
      studyLevel: json['studyLevel'],
      edition: json['edition'],
      conditionScore: json['conditionScore'] ?? 0,
      originalPrice: (json['originalPrice'] ?? 0.0).toDouble(),
      listingPrice: (json['listingPrice'] ?? 0.0).toDouble(),
      isLatestEdition: json['isLatestEdition'] ?? false,
      status: json['status'] ?? 'Available',
      description: json['description'],
      imageUrl: json['image_url'],
      createdAt: json['created_at'] ?? '',
      rejectionReason: json['rejectionReason'],
      dropOffPin: json['dropOffPin'],
      deleteRequestReason: json['deleteRequestReason'],
      isDeleteRequested: json['isDeleteRequested'] ?? false,
      sellerEarnings: json['sellerEarnings'] != null ? (json['sellerEarnings'] as num).toDouble() : null,
      isArchived: json['isArchived'] ?? false,
      seller: json['USER'] != null ? UserModel.fromJson(json['USER']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (textbookID != null) 'textbookID': textbookID,
      'sellerID': sellerID,
      'title': title,
      'domain': domain,
      if (faculty != null) 'faculty': faculty,
      if (studyLevel != null) 'studyLevel': studyLevel,
      if (edition != null) 'edition': edition,
      'conditionScore': conditionScore,
      'originalPrice': originalPrice,
      'listingPrice': listingPrice,
      'isLatestEdition': isLatestEdition,
      'status': status,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (dropOffPin != null) 'dropOffPin': dropOffPin,
      if (deleteRequestReason != null) 'deleteRequestReason': deleteRequestReason,
      'isDeleteRequested': isDeleteRequested,
      if (sellerEarnings != null) 'sellerEarnings': sellerEarnings,
      'isArchived': isArchived,
    };
  }
}
