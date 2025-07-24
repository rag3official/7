import 'dart:math';
import 'maintenance_record.dart';
import 'van_image.dart';

class Van {
  final String id;
  final String plateNumber;
  final String model;
  final String year;
  final String status;
  final String alerts; // Alert flag for damage level 2/3
  final String? damageCausedBy; // Driver who initially caused the damage
  final String? driverName;
  final DateTime? lastInspection;
  final double? mileage;
  final String? url;
  final String? notes;
  final String? damage;
  final String? rating;
  final String? damageDescription;
  final List<VanImage> images;
  final List<MaintenanceRecord> maintenanceHistory;

  const Van({
    required this.id,
    required this.plateNumber,
    required this.model,
    required this.year,
    required this.status,
    this.alerts = 'no', // Default to no alerts
    this.damageCausedBy,
    this.driverName,
    this.lastInspection,
    this.mileage,
    this.url,
    this.notes,
    this.damage,
    this.rating,
    this.damageDescription,
    this.images = const [],
    this.maintenanceHistory = const [],
  });

  Van copyWith({
    String? id,
    String? plateNumber,
    String? model,
    String? year,
    String? status,
    String? alerts,
    String? damageCausedBy,
    String? driverName,
    DateTime? lastInspection,
    double? mileage,
    String? url,
    String? notes,
    String? damage,
    String? rating,
    String? damageDescription,
    List<VanImage>? images,
    List<MaintenanceRecord>? maintenanceHistory,
  }) {
    return Van(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      model: model ?? this.model,
      year: year ?? this.year,
      status: status ?? this.status,
      alerts: alerts ?? this.alerts,
      damageCausedBy: damageCausedBy ?? this.damageCausedBy,
      driverName: driverName ?? this.driverName,
      lastInspection: lastInspection ?? this.lastInspection,
      mileage: mileage ?? this.mileage,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      damage: damage ?? this.damage,
      rating: rating ?? this.rating,
      damageDescription: damageDescription ?? this.damageDescription,
      images: images ?? this.images,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
    );
  }

  factory Van.fromJson(Map<String, dynamic> json) {
    return Van(
      id: json['id'].toString(),
      plateNumber: json['van_number']?.toString() ?? '',
      model: json['make']?.toString() ?? json['type']?.toString() ?? '',
      year: json['model']?.toString() ?? json['year']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Unknown',
      alerts: json['alerts']?.toString() ?? 'no', // Default to no alerts
      damageCausedBy: json['damage_caused_by']?.toString(),
      driverName:
          json['current_driver_name']?.toString() ?? json['driver']?.toString(),
      lastInspection: json['created_at'] != null && json['created_at'] != ''
          ? DateTime.tryParse(json['created_at'])
          : json['date'] != null && json['date'] != ''
              ? DateTime.tryParse(json['date'])
              : null,
      mileage: json['mileage']?.toDouble(),
      url: json['url']?.toString(),
      notes: json['notes']?.toString(),
      damage: json['damage']?.toString(),
      rating: json['rating']?.toString(),
      damageDescription: json['damage_description']?.toString(),
      images: (json['images'] as List?)
              ?.map((e) => VanImage.fromJson(e))
              .toList() ??
          [],
      maintenanceHistory: (json['maintenance_history'] as List?)
              ?.map((e) => MaintenanceRecord.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'van_number': int.tryParse(plateNumber) ?? 0,
      'make': model,
      'model': year,
      'status': status,
      'current_driver_name': driverName,
      'created_at': lastInspection?.toIso8601String(),
      'notes': notes,
      'damage': damage,
      'rating': rating,
      'damage_description': damageDescription,
      'images': images.map((e) => e.toJson()).toList(),
      'maintenance_history': maintenanceHistory.map((e) => e.toJson()).toList(),
    };
  }

  // Helper method to get the main image URL
  String get mainImageUrl {
    if (url != null && url!.isNotEmpty) {
      return url!;
    }
    return images.isNotEmpty ? images.first.imageUrl : '';
  }

  // Helper method to get the latest image
  VanImage? get latestImage {
    if (images.isEmpty) return null;
    return images.reduce((a, b) => a.uploadedAt.isAfter(b.uploadedAt) ? a : b);
  }

  // Helper method to get all images sorted by upload date
  List<VanImage> get sortedImages {
    return List<VanImage>.from(images)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  // Helper method to get maximum damage level from images
  int get maxDamageLevel {
    if (images.isEmpty) return 0;
    return images.map((img) => img.damageLevel ?? 0).reduce(max);
  }

  // Add new maintenance record
  Van addMaintenanceRecord(MaintenanceRecord newRecord) {
    return copyWith(
      maintenanceHistory: [...maintenanceHistory, newRecord],
    );
  }

  // Update maintenance record
  Van updateMaintenanceRecord(
      String recordId, MaintenanceRecord updatedRecord) {
    final updatedHistory = maintenanceHistory.map((r) {
      if (r.id == recordId) {
        return updatedRecord;
      }
      return r;
    }).toList();
    return copyWith(maintenanceHistory: updatedHistory);
  }

  // Remove maintenance record
  Van removeMaintenanceRecord(String recordId) {
    final updatedHistory =
        maintenanceHistory.where((r) => r.id != recordId).toList();
    return copyWith(maintenanceHistory: updatedHistory);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Van &&
        other.id == id &&
        other.plateNumber == plateNumber &&
        other.model == model &&
        other.year == year &&
        other.status == status &&
        other.driverName == driverName &&
        other.lastInspection == lastInspection &&
        other.mileage == mileage &&
        other.url == url &&
        other.notes == notes &&
        other.damage == damage &&
        other.rating == rating &&
        other.damageDescription == damageDescription;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      plateNumber,
      model,
      year,
      status,
      driverName,
      lastInspection,
      mileage,
      url,
      notes,
      damage,
      rating,
      damageDescription,
    );
  }
}
