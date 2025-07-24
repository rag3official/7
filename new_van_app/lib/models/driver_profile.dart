
class DriverProfile {
  final String id;
  final String slackUserId;
  final String slackUsername;
  final String? fullName;
  final String? email;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverProfile({
    required this.id,
    required this.slackUserId,
    required this.slackUsername,
    this.fullName,
    this.email,
    this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'],
      slackUserId: json['slack_user_id'],
      slackUsername: json['slack_username'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slack_user_id': slackUserId,
      'slack_username': slackUsername,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
