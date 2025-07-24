class Van {
  final String id;
  final String name;
  final String status;
  final String? maintenanceNotes;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  Van({
    required this.id,
    required this.name,
    required this.status,
    this.maintenanceNotes,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Van.fromJson(Map<String, dynamic> json) {
    return Van(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      maintenanceNotes: json['maintenance_notes'] as String?,
      imageUrls: (json['van_images'] as List<dynamic>?)
              ?.map((image) => image['url'] as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'maintenance_notes': maintenanceNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
