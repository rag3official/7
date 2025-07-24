import 'package:uuid/uuid.dart';

class Van {
  final String id;
  final String name;
  String status;
  List<String> imageUrls;
  String? maintenanceNotes;
  DateTime? lastMaintenanceDate;

  // New schema fields
  String? vanNumber;
  String? make;
  String? model;
  String? notes;
  String? currentDriverId;
  String? currentDriverName;

  Van({
    String? id,
    required this.name,
    this.status = 'active',
    this.imageUrls = const [],
    this.maintenanceNotes,
    this.lastMaintenanceDate,
    this.vanNumber,
    this.make,
    this.model,
    this.notes,
    this.currentDriverId,
    this.currentDriverName,
  }) : id = id ?? const Uuid().v4();

  // Helper method to safely convert van_number to string
  static String? _safeConvertVanNumber(dynamic vanNumber) {
    try {
      if (vanNumber == null) return null;
      return vanNumber.toString();
    } catch (e) {
      print('Error converting van_number: $e');
      return 'Unknown';
    }
  }

  factory Van.fromJson(Map<String, dynamic> json) {
    return Van(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'active',
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      maintenanceNotes: json['maintenance_notes'] as String?,
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.parse(json['last_maintenance_date'] as String)
          : null,
    );
  }

  // Factory constructor for new schema (van_profiles table)
  factory Van.fromNewSchema(Map<String, dynamic> json) {
    List<String> imageUrls = [];

    // Extract image URLs from van_images relation
    if (json['van_images'] != null) {
      final images = json['van_images'] as List;
      imageUrls = images
          .map((img) {
            // Check if image_url contains base64 data
            final imageUrl = img['image_url'] as String?;
            if (imageUrl != null && imageUrl.startsWith('data:image/')) {
              return imageUrl; // Return data URL for base64 images
            }
            return imageUrl ?? '';
          })
          .where((url) => url.isNotEmpty)
          .toList();
    }

    // Extract driver information
    String? driverName;
    if (json['driver_profiles'] != null) {
      final driver = json['driver_profiles'];
      driverName = driver['driver_name'] as String?;
    }

    // Safely convert van_number to string - handle both int and string types
    final vanNumberStr = _safeConvertVanNumber(json['van_number']);

    return Van(
      id: json['id'] as String,
      name: vanNumberStr ?? 'Unknown',
      vanNumber: vanNumberStr,
      status: json['status'] as String? ?? 'active',
      make: json['make'] as String?,
      model: json['model'] as String?,
      notes: json['notes'] as String?,
      currentDriverId: json['current_driver_id'] as String?,
      currentDriverName: driverName,
      imageUrls: imageUrls,
      maintenanceNotes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'image_urls': imageUrls,
      'maintenance_notes': maintenanceNotes,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
    };
  }

  // Convert to new schema format
  Map<String, dynamic> toNewSchemaJson() {
    return {
      'id': id,
      'van_number': vanNumber ?? name,
      'status': status,
      'make': make,
      'model': model,
      'notes': notes ?? maintenanceNotes,
      'current_driver_id': currentDriverId,
    };
  }

  Van copyWith({
    String? name,
    String? status,
    List<String>? imageUrls,
    String? maintenanceNotes,
    DateTime? lastMaintenanceDate,
    String? vanNumber,
    String? make,
    String? model,
    String? notes,
    String? currentDriverId,
    String? currentDriverName,
  }) {
    return Van(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      vanNumber: vanNumber ?? this.vanNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      notes: notes ?? this.notes,
      currentDriverId: currentDriverId ?? this.currentDriverId,
      currentDriverName: currentDriverName ?? this.currentDriverName,
    );
  }
}
