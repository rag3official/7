class DriverProfile {
  final String id;
  final String? slackUserId;
  final String driverName;
  final String? email;
  final String? phone;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DateTime? lastMedicalCheck;
  final List<String> certifications;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverProfile({
    required this.id,
    this.slackUserId,
    required this.driverName,
    this.email,
    this.phone,
    this.licenseNumber,
    this.licenseExpiry,
    this.lastMedicalCheck,
    this.certifications = const [],
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      slackUserId: json['slack_user_id'] as String?,
      driverName: json['driver_name'] as String? ??
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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slack_user_id': slackUserId,
      'driver_name': driverName,
      'email': email,
      'phone': phone,
      'license_number': licenseNumber,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'last_medical_check': lastMedicalCheck?.toIso8601String(),
      'certifications': certifications,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DriverProfile copyWith({
    String? id,
    String? slackUserId,
    String? driverName,
    String? email,
    String? phone,
    String? licenseNumber,
    DateTime? licenseExpiry,
    DateTime? lastMedicalCheck,
    List<String>? certifications,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      slackUserId: slackUserId ?? this.slackUserId,
      driverName: driverName ?? this.driverName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      lastMedicalCheck: lastMedicalCheck ?? this.lastMedicalCheck,
      certifications: certifications ?? List.from(this.certifications),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getter for display name
  String get displayName => driverName;

  // Helper getter for contact info
  String get contactInfo {
    List<String> info = [];
    if (email != null && email!.isNotEmpty) info.add(email!);
    if (phone != null && phone!.isNotEmpty) info.add(phone!);
    return info.join(' • ');
  }
}
