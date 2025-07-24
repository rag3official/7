
class MaintenanceRecord {
  final String id;
  final String vanId;
  final String type;
  final String description;
  final DateTime date;
  final double? cost;
  final String? technician;
  final String status;
  final DateTime createdAt;

  const MaintenanceRecord({
    required this.id,
    required this.vanId,
    required this.type,
    required this.description,
    required this.date,
    this.cost,
    this.technician,
    this.status = 'completed',
    required this.createdAt,
  });

  MaintenanceRecord copyWith({
    String? id,
    String? vanId,
    String? type,
    String? description,
    DateTime? date,
    double? cost,
    String? technician,
    String? status,
    DateTime? createdAt,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      vanId: vanId ?? this.vanId,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      cost: cost ?? this.cost,
      technician: technician ?? this.technician,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'].toString(),
      vanId: json['van_id'].toString(),
      type: json['type']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      cost: json['cost']?.toDouble(),
      technician: json['technician']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'van_id': vanId,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'cost': cost,
      'technician': technician,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create new maintenance record with generated ID
  static MaintenanceRecord create({
    required String vanId,
    required String type,
    required String description,
    required DateTime date,
    double? cost,
    String? technician,
    String status = 'completed',
  }) {
    return MaintenanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      vanId: vanId,
      type: type,
      description: description,
      date: date,
      cost: cost,
      technician: technician,
      status: status,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceRecord &&
        other.id == id &&
        other.vanId == vanId &&
        other.type == type &&
        other.description == description &&
        other.date == date &&
        other.cost == cost &&
        other.technician == technician &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      vanId,
      type,
      description,
      date,
      cost,
      technician,
      status,
      createdAt,
    );
  }
}
