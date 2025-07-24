import 'package:flutter/foundation.dart';

class SheetsValidator {
  static bool validateVanNumber(String vanNumber) {
    // Basic validation for van number format
    return vanNumber.isNotEmpty && vanNumber.length >= 3;
  }

  static bool validateType(String type) {
    // Basic validation for van type
    return type.isNotEmpty;
  }

  static bool validateStatus(String status) {
    // Basic validation for van status
    final validStatuses = ['Active', 'Inactive', 'Maintenance', 'Repair'];
    return validStatuses.contains(status);
  }

  static bool validateRating(double rating) {
    // Basic validation for van rating
    return rating >= 0.0 && rating <= 5.0;
  }

  static bool validateMaintenanceRecord(Map<String, dynamic> record) {
    try {
      // Basic validation for maintenance record
      return record['date'] != null &&
          record['description'] != null &&
          record['technician'] != null &&
          record['cost'] != null &&
          record['status'] != null;
    } catch (e) {
      debugPrint('Error validating maintenance record: $e');
      return false;
    }
  }
}
