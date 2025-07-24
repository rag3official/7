import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/van.dart';

class NotificationService {
  static const String _lastCheckedTimeKey = 'last_checked_time';
  static const String _knownDamagedVansKey = 'known_damaged_vans';
  static const String _clearedAlertsKey = 'cleared_alerts';
  static const String _lastClearTimeKey = 'last_clear_time';

  // Check for new damage and show notifications if needed
  static Future<List<Van>> checkForNewDamage(
    BuildContext context,
    List<Van> currentVans,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get last checked time
    final lastCheckedTimeMillis = prefs.getInt(_lastCheckedTimeKey) ?? 0;
    final lastCheckedTime = DateTime.fromMillisecondsSinceEpoch(
      lastCheckedTimeMillis,
    );

    // Get known damaged van numbers
    final knownDamagedVanNumbers =
        prefs.getStringList(_knownDamagedVansKey) ?? [];

    // Find damaged vans
    List<Van> damagedVans =
        currentVans
            .where((van) => van.damage.isNotEmpty || van.rating >= 2.0)
            .toList();

    // Find newly damaged vans
    List<Van> newlyDamagedVans = [];

    for (var van in damagedVans) {
      // Check if this damaged van was not in our known list
      if (!knownDamagedVanNumbers.contains(van.vanNumber)) {
        newlyDamagedVans.add(van);
      }
    }

    // Remove the popup alert
    // if (newlyDamagedVans.isNotEmpty && context.mounted) {
    //   _showDamageAlert(context, newlyDamagedVans);
    // }

    // Update last checked time
    prefs.setInt(_lastCheckedTimeKey, DateTime.now().millisecondsSinceEpoch);

    // Update known damaged vans
    prefs.setStringList(
      _knownDamagedVansKey,
      damagedVans.map((van) => van.vanNumber).toList(),
    );

    return newlyDamagedVans;
  }

  // Clear all alerts
  static Future<List<String>> clearAllAlerts() async {
    final prefs = await SharedPreferences.getInstance();

    // Get current alerts before clearing
    final currentAlerts = prefs.getStringList(_knownDamagedVansKey) ?? [];

    // Save cleared alerts for potential undo
    await prefs.setStringList(_clearedAlertsKey, currentAlerts);
    await prefs.setInt(
      _lastClearTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    // Clear current alerts
    await prefs.setStringList(_knownDamagedVansKey, []);

    return currentAlerts;
  }

  // Check if there are any recently cleared alerts that can be restored
  static Future<bool> hasClearedAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final clearedAlerts = prefs.getStringList(_clearedAlertsKey) ?? [];

    // Check if there are any cleared alerts
    return clearedAlerts.isNotEmpty;
  }

  // Restore recently cleared alerts
  static Future<List<String>> restoreClearedAlerts() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the cleared alerts
    final clearedAlerts = prefs.getStringList(_clearedAlertsKey) ?? [];

    if (clearedAlerts.isNotEmpty) {
      // Restore the cleared alerts to the known damaged vans
      await prefs.setStringList(_knownDamagedVansKey, clearedAlerts);

      // Clear the saved cleared alerts
      await prefs.setStringList(_clearedAlertsKey, []);
    }

    return clearedAlerts;
  }

  // Show alert dialog for new damage
  static void _showDamageAlert(
    BuildContext context,
    List<Van> newlyDamagedVans,
  ) {
    // Only show if the context is still mounted
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('New Damage Detected'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${newlyDamagedVans.length} ${newlyDamagedVans.length == 1 ? 'van has' : 'vans have'} reported new damage:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...newlyDamagedVans
                    .map(
                      (van) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text: 'Van #${van.vanNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          van.damage.isNotEmpty
                                              ? ' - ${van.damage}'
                                              : ' - Condition rating: ${van.rating.toInt()}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    ,
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('DISMISS'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToAlerts(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('VIEW ALERTS'),
              ),
            ],
          ),
    );
  }

  // Navigate to alerts screen
  static void _navigateToAlerts(BuildContext context) {
    Navigator.pushNamed(context, '/alerts');
  }

  // Reset all notification data
  static Future<void> resetNotificationData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_lastCheckedTimeKey);
    prefs.remove(_knownDamagedVansKey);
    prefs.remove(_clearedAlertsKey);
    prefs.remove(_lastClearTimeKey);
  }
}
