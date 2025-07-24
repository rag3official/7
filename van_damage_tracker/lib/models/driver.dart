import 'package:flutter/foundation.dart';

@immutable
class Driver {
  final String id;
  final String name;
  final String? employeeId;
  final String? phone;
  final String? email;
  final String? licenseNumber;
  final DateTime? licenseExpiryDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Driver({
    required this.id,
    required this.name,
    this.employeeId,
    this.phone,
    this.email,
    this.licenseNumber,
    this.licenseExpiryDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Driver copyWith({
    String? id,
    String? name,
    String? employeeId,
    String? phone,
    String? email,
    String? licenseNumber,
    DateTime? licenseExpiryDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      licenseExpiryDate: json['license_expiry_date'] != null
          ? DateTime.parse(json['license_expiry_date'])
          : null,
      status: json['status']?.toString() ?? 'active',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'employee_id': employeeId,
      'phone': phone,
      'email': email,
      'license_number': licenseNumber,
      'license_expiry_date': licenseExpiryDate?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Driver &&
        other.id == id &&
        other.name == name &&
        other.employeeId == employeeId &&
        other.phone == phone &&
        other.email == email &&
        other.licenseNumber == licenseNumber &&
        other.licenseExpiryDate == licenseExpiryDate &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      employeeId,
      phone,
      email,
      licenseNumber,
      licenseExpiryDate,
      status,
      createdAt,
      updatedAt,
    );
  }

  String get displayName => name;

  String get displayInfo {
    if (employeeId?.isNotEmpty == true) {
      return '$name ($employeeId)';
    }
    return name;
  }

  bool get isActive => status == 'active';
}
