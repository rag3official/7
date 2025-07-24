import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/van.dart';
import '../services/supabase_service.dart';

class VanGridItem extends StatelessWidget {
  final Van van;
  final VoidCallback onTap;

  const VanGridItem({super.key, required this.van, required this.onTap});

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
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Van image at the top
            Expanded(flex: 4, child: _buildVanImage()),
            // Van details
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Van number and status indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '#${van.vanNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(van.status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Van type and driver
                    Text(
                      'Type: ${van.type}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (van.driver.isNotEmpty)
                      Text(
                        'Driver: ${van.driver}',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Last updated date
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.update, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${_formatLastUpdated(van.lastUpdated)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isRecentlyUpdated()
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Condition badge
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getConditionColor(van.rating.toInt()),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getConditionText(van.rating.toInt()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    // Damage description if damage exists
                    if (van.damage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Damage:',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Expanded(
                                child: Text(
                                  van.damage,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade900,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

  // Build the van image component
  Widget _buildVanImage() {
    // Determine border color based on condition
    final borderColor = _getDamageBorderColor();
    const borderWidth = 3.0;

    return FutureBuilder<String?>(
      // Try to get the latest image from the van's folder
      future: SupabaseService().getLatestVanImage(van.vanNumber),
      builder: (context, snapshot) {
        // Determine the image URL to use
        final imageUrl = van.url.isNotEmpty ? van.url : snapshot.data;
        final hasValidUrl = imageUrl != null && imageUrl.isNotEmpty;

        // Create the image content
        Widget imageContent;
        if (hasValidUrl) {
          imageContent = CachedNetworkImage(
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
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.directions_car,
                size: 40,
                color: Colors.grey,
              ),
            ),
          );
        } else {
          // No image URL, show placeholder
          imageContent = Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.directions_car, size: 40, color: Colors.grey),
            ),
          );
        }

        // Wrap the image with a colored border
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: imageContent,
        );
      },
    );
  }

  // Check if the van was updated recently (within the last 7 days)
  bool _isRecentlyUpdated() {
    // Get the date 7 days ago
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    // Return true if the van was updated within the last 7 days
    return van.lastUpdated.isAfter(sevenDaysAgo);
  }

  // Determine the border color based on damage status
  Color _getDamageBorderColor() {
    // First check if damage text exists
    if (van.damage.isNotEmpty) {
      return Colors.red;
    }

    // Then check the rating/condition
    int condition = van.rating.toInt();
    switch (condition) {
      case 0: // No scratches
      case 1: // Dust or dirt (not actual damage)
        return Colors.green;
      case 2: // Scratches
        return Colors.yellow;
      case 3: // Dents
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  String _getConditionText(int condition) {
    // Cap at 3 in case old data has higher values
    int safeCondition = condition > 3 ? 3 : condition;
    return '$safeCondition: ${_conditionDescriptions[safeCondition] ?? "Unknown"}';
  }
}
