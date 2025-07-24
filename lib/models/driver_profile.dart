class DriverProfile {
  final String id;
  final String? userId;
  final String name;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final String? phoneNumber;
  final String? email;
  final DateTime? lastMedicalCheck;
  final List<String> certifications;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? slackUserId;
  final String? slackRealName;
  final String? slackDisplayName;

  DriverProfile({
    required this.id,
    this.userId,
    required this.name,
    this.licenseNumber,
    this.licenseExpiry,
    this.phoneNumber,
    this.email,
    this.lastMedicalCheck,
    this.certifications = const [],
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.slackUserId,
    this.slackRealName,
    this.slackDisplayName,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['driver_name'] as String? ?? json['name'] as String? ?? 'Unknown Driver',
      licenseNumber: json['license_number'] as String?,
      licenseExpiry: json['license_expiry'] != null
          ? DateTime.parse(json['license_expiry'] as String)
          : null,
      phoneNumber: json['phone'] as String? ?? json['phone_number'] as String?,
      email: json['email'] as String?,
      lastMedicalCheck: json['last_medical_check'] != null
          ? DateTime.parse(json['last_medical_check'] as String)
          : null,
      certifications: json['certifications'] != null 
          ? List<String>.from(json['certifications'])
          : [],
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      slackUserId: json['slack_user_id'] as String?,
      slackRealName: json['slack_real_name'] as String?,
      slackDisplayName: json['slack_display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'driver_name': name,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'phone': phoneNumber,
      'email': email,
      'last_medical_check': lastMedicalCheck?.toIso8601String(),
      'certifications': certifications,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'slack_user_id': slackUserId,
      'slack_real_name': slackRealName,
      'slack_display_name': slackDisplayName,
    };
  }

  DriverProfile copyWith({
    String? id,
    String? userId,
    String? name,
    String? licenseNumber,
    DateTime? licenseExpiry,
    String? phoneNumber,
    String? email,
    DateTime? lastMedicalCheck,
    List<String>? certifications,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? slackUserId,
    String? slackRealName,
    String? slackDisplayName,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      lastMedicalCheck: lastMedicalCheck ?? this.lastMedicalCheck,
      certifications: certifications ?? List.from(this.certifications),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      slackUserId: slackUserId ?? this.slackUserId,
      slackRealName: slackRealName ?? this.slackRealName,
      slackDisplayName: slackDisplayName ?? this.slackDisplayName,
    );
  }
}
