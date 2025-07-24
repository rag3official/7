import 'package:flutter/foundation.dart';

@immutable
class VanImage {
  final String id;
  final String vanId;
  final String imageUrl;
  final String? uploadedBy; // Driver name (for backward compatibility)
  final String? driverId; // Driver ID reference
  final DateTime uploadedAt;
  final String? description;
  final String? damageType;
  final int? damageLevel; // 0-5 scale
  final String? location; // "front", "rear", "left", "right", "interior", etc.
  final String?
      vanSide; // "front", "rear", "driver_side", "passenger_side", "interior", "roof", "undercarriage", "unknown"
  final DateTime createdAt;
  final DateTime updatedAt;

  // Driver information (when joined from drivers table)
  final String? driverName;
  final String? driverEmployeeId;
  final String? driverPhone;
  final String? driverEmail;

  // Van information (when joined from vans table for driver profiles)
  final String? vanNumber;
  final String? vanModel;
  final String? vanYear;
  final String? vanStatus;
  final String? vanDriver;
  final String? vanMainImageUrl;

  const VanImage({
    required this.id,
    required this.vanId,
    required this.imageUrl,
    this.uploadedBy,
    this.driverId,
    required this.uploadedAt,
    this.description,
    this.damageType,
    this.damageLevel,
    this.location,
    this.vanSide,
    required this.createdAt,
    required this.updatedAt,
    this.driverName,
    this.driverEmployeeId,
    this.driverPhone,
    this.driverEmail,
    this.vanNumber,
    this.vanModel,
    this.vanYear,
    this.vanStatus,
    this.vanDriver,
    this.vanMainImageUrl,
  });

  VanImage copyWith({
    String? id,
    String? vanId,
    String? imageUrl,
    String? uploadedBy,
    String? driverId,
    DateTime? uploadedAt,
    String? description,
    String? damageType,
    int? damageLevel,
    String? location,
    String? vanSide,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? driverName,
    String? driverEmployeeId,
    String? driverPhone,
    String? driverEmail,
    String? vanNumber,
    String? vanModel,
    String? vanYear,
    String? vanStatus,
    String? vanDriver,
    String? vanMainImageUrl,
  }) {
    return VanImage(
      id: id ?? this.id,
      vanId: vanId ?? this.vanId,
      imageUrl: imageUrl ?? this.imageUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      driverId: driverId ?? this.driverId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
      damageType: damageType ?? this.damageType,
      damageLevel: damageLevel ?? this.damageLevel,
      location: location ?? this.location,
      vanSide: vanSide ?? this.vanSide,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      driverName: driverName ?? this.driverName,
      driverEmployeeId: driverEmployeeId ?? this.driverEmployeeId,
      driverPhone: driverPhone ?? this.driverPhone,
      driverEmail: driverEmail ?? this.driverEmail,
      vanNumber: vanNumber ?? this.vanNumber,
      vanModel: vanModel ?? this.vanModel,
      vanYear: vanYear ?? this.vanYear,
      vanStatus: vanStatus ?? this.vanStatus,
      vanDriver: vanDriver ?? this.vanDriver,
      vanMainImageUrl: vanMainImageUrl ?? this.vanMainImageUrl,
    );
  }

  factory VanImage.fromJson(Map<String, dynamic> json) {
    return VanImage(
      id: json['id'].toString(),
      vanId: json['van_id'].toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      uploadedBy: json['uploaded_by']?.toString(),
      driverId: json['driver_id']?.toString(),
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : (json['updated_at'] !=
                  null // Fallback to updated_at if uploaded_at is missing
              ? DateTime.parse(json['updated_at'])
              : DateTime.now()),
      description: json['description']?.toString(),
      damageType: json['damage_type']?.toString(),
      damageLevel: json['damage_level']?.toInt(),
      location: json['location']?.toString(),
      vanSide: json['van_side']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      // Driver information from joined data
      driverName: json['driver_name']?.toString(),
      driverEmployeeId: json['driver_employee_id']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      driverEmail: json['driver_email']?.toString(),
      // Van information from joined data (using actual database column names)
      vanNumber: json['van_number']?.toString(),
      vanModel: json['model']?.toString(), // Using 'model' alias from view
      vanYear: json['year']?.toString(), // Will be null if column doesn't exist
      vanStatus:
          json['van_status']?.toString(), // Using 'van_status' alias from view
      vanDriver: json['driver']?.toString(),
      vanMainImageUrl: json['van_main_image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'van_id': vanId,
      'image_url': imageUrl,
      'uploaded_by': uploadedBy,
      'driver_id': driverId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'description': description,
      'damage_type': damageType,
      'damage_level': damageLevel,
      'location': location,
      'van_side': vanSide,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VanImage &&
        other.id == id &&
        other.vanId == vanId &&
        other.imageUrl == imageUrl &&
        other.uploadedBy == uploadedBy &&
        other.driverId == driverId &&
        other.uploadedAt == uploadedAt &&
        other.description == description &&
        other.damageType == damageType &&
        other.damageLevel == damageLevel &&
        other.location == location &&
        other.vanSide == vanSide &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      vanId,
      imageUrl,
      uploadedBy,
      driverId,
      uploadedAt,
      description,
      damageType,
      damageLevel,
      location,
      vanSide,
      createdAt,
      updatedAt,
    );
  }

  // Get the driver display name (prefer driver_name from join, fallback to uploaded_by)
  String? get displayDriverName {
    return driverName ?? uploadedBy;
  }

  // Get driver display info with employee ID if available
  String get displayDriverInfo {
    final name = displayDriverName ?? 'Unknown Driver';
    if (driverEmployeeId?.isNotEmpty == true) {
      return '$name ($driverEmployeeId)';
    }
    return name;
  }

  // Get van display name with number and model
  String get displayVanInfo {
    final number = vanNumber ?? 'Unknown';
    final model = vanModel ?? '';
    if (model.isNotEmpty) {
      return 'Van $number ($model)';
    }
    return 'Van $number';
  }

  // Get van status display with fallback
  String get displayVanStatus {
    return vanStatus ?? 'Unknown Status';
  }

  // Get complete van description for driver profiles
  String get displayVanDescription {
    final info = displayVanInfo;
    final year = vanYear;
    if (year?.isNotEmpty == true) {
      return '$info - $year';
    }
    return info;
  }
}

// Helper class to group images by date and driver
class VanImageGroup {
  final DateTime date;
  final String? driver;
  final List<VanImage> images;

  const VanImageGroup({
    required this.date,
    this.driver,
    required this.images,
  });

  String get displayDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get displayDriver {
    return driver?.isNotEmpty == true ? driver! : 'Unknown Driver';
  }

  int get totalImages => images.length;

  int get maxDamageLevel {
    if (images.isEmpty) return 0;
    return images
        .map((img) => img.damageLevel ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  bool get hasDamage =>
      images.any((img) => img.damageLevel != null && img.damageLevel! > 0);

  // Get the most recent upload time from all images in this group
  DateTime get mostRecentUpload {
    if (images.isEmpty) return date;
    return images.first.uploadedAt; // Images are already sorted by upload time
  }

  // Get a display string for the most recent upload time
  String get displayMostRecentUpload {
    final now = DateTime.now();
    final recent = mostRecentUpload;
    final difference = now.difference(recent);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${recent.day}/${recent.month}/${recent.year}';
    }
  }
}

// Helper class to group images and provide utility functions
class VanImageGroupingHelper {
  static List<VanImageGroup> groupImagesByDateAndDriver(List<VanImage> images) {
    if (images.isEmpty) return [];

    // Group by date first, then by driver
    final Map<String, Map<String, List<VanImage>>> groupedData = {};

    for (final image in images) {
      final dateKey =
          '${image.uploadedAt.year}-${image.uploadedAt.month}-${image.uploadedAt.day}';
      // Use the enhanced driver display name (prefers driver_name from join)
      final driverKey = image.displayDriverName ?? 'Unknown';

      groupedData.putIfAbsent(dateKey, () => {});
      groupedData[dateKey]!.putIfAbsent(driverKey, () => []);
      groupedData[dateKey]![driverKey]!.add(image);
    }

    // Convert to VanImageGroup list
    final List<VanImageGroup> groups = [];

    for (final dateEntry in groupedData.entries) {
      final dateParts = dateEntry.key.split('-');
      final date = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      for (final driverEntry in dateEntry.value.entries) {
        // Sort images within the group by upload time (newest first)
        final sortedImages = List<VanImage>.from(driverEntry.value);
        sortedImages.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        groups.add(VanImageGroup(
          date: date,
          driver: driverEntry.key == 'Unknown' ? null : driverEntry.key,
          images: sortedImages,
        ));
      }
    }

    // Sort groups by the most recent image upload time within each group (newest first)
    groups.sort((a, b) {
      // Get the most recent image from each group
      final mostRecentA =
          a.images.first.uploadedAt; // Already sorted, so first is newest
      final mostRecentB = b.images.first.uploadedAt;

      // Sort by most recent upload time first
      final timeComparison = mostRecentB.compareTo(mostRecentA);
      if (timeComparison != 0) return timeComparison;

      // If upload times are the same, sort by driver name
      return a.displayDriver.compareTo(b.displayDriver);
    });

    return groups;
  }

  static List<VanImage> sortImagesByUploadTime(List<VanImage> images) {
    final sortedImages = List<VanImage>.from(images);
    sortedImages.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return sortedImages;
  }

  static List<VanImage> filterImagesByDamageLevel(
      List<VanImage> images, int minLevel) {
    return images.where((img) => (img.damageLevel ?? 0) >= minLevel).toList();
  }

  static List<VanImage> filterImagesByLocation(
      List<VanImage> images, String location) {
    return images
        .where((img) => img.location?.toLowerCase() == location.toLowerCase())
        .toList();
  }

  static List<VanImage> filterImagesByDriver(
      List<VanImage> images, String driverName) {
    return images
        .where((img) =>
            img.displayDriverName?.toLowerCase() == driverName.toLowerCase())
        .toList();
  }
}
