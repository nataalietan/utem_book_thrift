class UserModel {
  final String userID;
  final String email;
  final String fullName;
  final String role;
  final String? faculty;
  final String? studyLevel;
  final String? gender;
  final String? createdAt;

  UserModel({
    required this.userID,
    required this.email,
    required this.fullName,
    required this.role,
    this.faculty,
    this.studyLevel,
    this.gender,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userID: json['userID'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'Student',
      faculty: json['faculty'],
      studyLevel: json['study_level'],
      gender: json['gender'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'email': email,
      'fullName': fullName,
      'role': role,
      if (faculty != null) 'faculty': faculty,
      if (studyLevel != null) 'study_level': studyLevel,
      if (gender != null) 'gender': gender,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}
