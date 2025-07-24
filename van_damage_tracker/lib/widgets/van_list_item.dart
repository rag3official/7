import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/van.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class VanListItem extends StatelessWidget {
  final Van van;
  final VoidCallback onTap;

  const VanListItem({super.key, required this.van, required this.onTap});

  // Damage condition descriptions
  static const Map<int, String> _conditionDescriptions = {
    0: 'No scratches',
    1: 'Dust or dirt',
    2: 'Scratches',
    3: 'Dents',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Van image
              _buildVanImage(),
              const SizedBox(width: 16),

              // Van details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Van #${van.vanNumber}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Type: ${van.type}'),
                    Text('Status: ${van.status}'),
                    Text('Driver: ${van.driver}'),

                    // Last updated date
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.update, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${_formatLastUpdated(van.lastUpdated)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isRecentlyUpdated()
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Condition indicator (replaces star rating)
                    Row(
                      children: [
                        const Text('Condition: '),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getConditionColor(van.rating.toInt()),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getConditionIcon(van.rating.toInt()),
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getConditionText(van.rating.toInt()),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Display damage if exists
                    if (van.damage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Damage: ${van.damage}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(van.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format the last updated date to a more readable format
  String _formatLastUpdated(DateTime lastUpdated) {
    // Calculate days ago
    final now = DateTime.now();
    final difference = now.difference(lastUpdated).inDays;

    // Format based on recency
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      // Use a more readable date format for older updates
      return DateFormat('MMM d, yyyy').format(lastUpdated);
    }
  }

  // Check if the van was updated recently (within the last 7 days)
  bool _isRecentlyUpdated() {
    // Get the date 7 days ago
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    // Return true if the van was updated within the last 7 days
    return van.lastUpdated.isAfter(sevenDaysAgo);
  }

  // Build the van image component
  Widget _buildVanImage() {
    return FutureBuilder<String?>(
      // Try to get the latest image from the van's folder
      future: SupabaseService().getLatestVanImage(van.vanNumber),
      builder: (context, snapshot) {
        // Log the snapshot state and data
        debugPrint('Image loading state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          debugPrint('Error loading image: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugPrint('Loaded image URL: ${snapshot.data}');
        }

        // Determine the image URL to use
        final imageUrl = van.url.isNotEmpty ? van.url : snapshot.data;
        final hasValidUrl = imageUrl != null && imageUrl.isNotEmpty;
        debugPrint('Using image URL: $imageUrl (hasValidUrl: $hasValidUrl)');

        if (hasValidUrl) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading image from URL $url: $error');
                  return Container(
                    color: Colors.grey[300],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'Error: ${error.toString().substring(0, min(error.toString().length, 20))}',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          // No image URL, show placeholder
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.directions_car, size: 40, color: Colors.grey),
            ),
          );
        }
      },
    );
  }

  // Get status color based on status text
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'operational':
        return Colors.green;
      case 'maintenance':
      case 'repair':
        return Colors.orange;
      case 'out of service':
      case 'damaged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper methods for condition display
  Color _getConditionColor(int condition) {
    // Cap at 3 in case old data has higher values
    int safeCondition = condition > 3 ? 3 : condition;

    switch (safeCondition) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getConditionIcon(int condition) {
    // Cap at 3 in case old data has higher values
    int safeCondition = condition > 3 ? 3 : condition;

    switch (safeCondition) {
      case 0:
        return Icons.check_circle;
      case 1:
        return Icons.cleaning_services;
      case 2:
        return Icons.auto_fix_high;
      case 3:
        return Icons.car_crash;
      default:
        return Icons.question_mark;
    }
  }

  String _getConditionText(int condition) {
    // Cap at 3 in case old data has higher values
    int safeCondition = condition > 3 ? 3 : condition;
    return '$safeCondition: ${_conditionDescriptions[safeCondition] ?? "Unknown"}';
  }
}
