class DriverProfile {
  final String id;
  final String? slackUserId;
  final String name;
  final String? email;
  final String? phone;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DateTime? lastMedicalCheck;
  final List<String> certifications;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Enhanced schema fields
  final String? slackRealName;
  final String? slackDisplayName;
  final String? slackUsername;
  final int totalUploads;
  final DateTime? lastUploadDate;
  final DateTime? hireDate;

  DriverProfile({
    required this.id,
    this.slackUserId,
    required this.name,
    this.email,
    this.phone,
    this.licenseNumber,
    this.licenseExpiry,
    this.lastMedicalCheck,
    this.certifications = const [],
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.slackRealName,
    this.slackDisplayName,
    this.slackUsername,
    this.totalUploads = 0,
    this.lastUploadDate,
    this.hireDate,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      slackUserId: json['slack_user_id'] as String?,
      name: json['driver_name'] as String? ??
          json['name'] as String? ??
          'Unknown Driver',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? json['phone_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      licenseExpiry: json['license_expiry'] != null
          ? DateTime.tryParse(json['license_expiry'] as String)
          : null,
      lastMedicalCheck: json['last_medical_check'] != null
          ? DateTime.tryParse(json['last_medical_check'] as String)
          : null,
      certifications: List<String>.from(json['certifications'] ?? []),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      slackRealName: json['slack_real_name'] as String?,
      slackDisplayName: json['slack_display_name'] as String?,
      slackUsername: json['slack_username'] as String?,
      totalUploads: json['total_uploads'] as int? ?? 0,
      lastUploadDate: json['last_upload_date'] != null
          ? DateTime.tryParse(json['last_upload_date'] as String)
          : null,
      hireDate: json['hire_date'] != null
          ? DateTime.tryParse(json['hire_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slack_user_id': slackUserId,
      'driver_name': name,
      'email': email,
      'phone': phone,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'last_medical_check': lastMedicalCheck?.toIso8601String(),
      'certifications': certifications,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'slack_real_name': slackRealName,
      'slack_display_name': slackDisplayName,
      'slack_username': slackUsername,
      'total_uploads': totalUploads,
      'last_upload_date': lastUploadDate?.toIso8601String(),
      'hire_date': hireDate?.toIso8601String(),
    };
  }

  // Helper getter for display name
  String get displayName => slackRealName ?? slackDisplayName ?? name;

  // Helper getter for contact info
  String get contactInfo {
    List<String> info = [];
    if (email != null && email!.isNotEmpty) info.add(email!);
    if (phone != null && phone!.isNotEmpty) info.add(phone!);
    return info.join(' • ');
  }

  // Helper getter for Slack info
  String get slackInfo {
    List<String> info = [];
    if (slackRealName != null && slackRealName!.isNotEmpty) info.add(slackRealName!);
    if (slackDisplayName != null && slackDisplayName!.isNotEmpty && slackDisplayName != slackRealName) {
      info.add('(@$slackDisplayName)');
    }
    return info.join(' ');
  }
}
