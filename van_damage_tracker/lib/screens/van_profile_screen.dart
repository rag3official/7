import 'package:flutter/material.dart';
import '../services/enhanced_driver_service.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../widgets/van_status_dialog.dart';
import 'driver_profile_screen.dart';
import 'dart:convert';
import 'dart:async';

class VanProfileScreen extends StatefulWidget {
  final int vanNumber;

  const VanProfileScreen({
    super.key,
    required this.vanNumber,
  });

  @override
  State<VanProfileScreen> createState() => _VanProfileScreenState();
}

class _VanProfileScreenState extends State<VanProfileScreen> {
  Map<String, dynamic>? vanData;
  bool isLoading = true;
  String? error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadVanData();

    // Auto-refresh every 30 seconds to check for new Slack uploads
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      debugPrint('🔄 Auto-refresh triggered for Van #${widget.vanNumber}');
      _loadVanData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVanData() async {
    try {
      debugPrint(
          '🔄 Loading van data for Van #${widget.vanNumber} at ${DateTime.now()}');
      setState(() {
        isLoading = true;
        error = null;
      });

      final data =
          await EnhancedDriverService.getVanProfileWithImages(widget.vanNumber);

      if (data != null) {
        final images = data['images'] as List? ?? [];
        debugPrint('✅ Loaded van data: ${images.length} images found');

        // Log latest image info for debugging
        if (images.isNotEmpty) {
          final latestImage = images.first;
          debugPrint(
              '📷 Latest image: created_at=${latestImage['created_at']}, van_rating=${latestImage['van_rating']}, van_side=${latestImage['van_side']}');
        }
      } else {
        debugPrint('❌ No van data returned for Van #${widget.vanNumber}');
      }

      setState(() {
        vanData = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading van data for Van #${widget.vanNumber}: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚐 Van #${widget.vanNumber}'),
        backgroundColor: Colors.green[400],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              debugPrint(
                  '🔄 Manual refresh triggered for Van #${widget.vanNumber}');
              _loadVanData();
            },
            tooltip: 'Refresh van data',
          ),
          // Test button to verify EnhancedImageViewer works
          if (vanData != null && (vanData!['images'] as List? ?? []).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                debugPrint('🧪 TEST BUTTON: Opening EnhancedImageViewer...');
                final images = vanData!['images'] as List? ?? [];
                final imageList = images.cast<Map<String, dynamic>>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EnhancedImageViewer(
                      images: imageList,
                      initialIndex: 0,
                      title: 'Van #${widget.vanNumber} Images - TEST',
                    ),
                  ),
                );
              },
              tooltip: 'Test Image Viewer',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _loadVanData,
                  child: _buildVanProfile(),
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading van profile',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVanData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanProfile() {
    if (vanData == null) {
      return const Center(child: Text('No van data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVanInfoCard(),
          const SizedBox(height: 16),
          _buildVanStatusCard(),
          const SizedBox(height: 16),
          _buildDamageAssessmentCard(),
          const SizedBox(height: 16),
          _buildImageStatsCard(),
          const SizedBox(height: 16),
          _buildImagesSection(),
        ],
      ),
    );
  }

  Widget _buildVanInfoCard() {
    final vanMake = vanData!['van_make']?.toString() ?? 'Unknown';
    final vanModel = vanData!['van_model']?.toString() ?? 'Unknown';
    final vanYear = vanData!['van_year']?.toString() ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚐 Van Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.green[400], size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Van #${widget.vanNumber}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$vanYear $vanMake $vanModel',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanStatusCard() {
    final vanStatus = vanData!['status']?.toString() ?? 'active';
    final vanUpdatedAt = vanData!['updated_at']?.toString();
    final vanNotes = vanData!['notes']?.toString();

    final statusConfig = EnhancedDriverService.statusConfig[vanStatus] ??
        EnhancedDriverService.statusConfig['active']!;

    Color statusColor = _getStatusColor(vanStatus);
    IconData statusIcon = _getStatusIcon(vanStatus);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and change button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '🚗 Van Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showStatusDialog(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Change Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[400],
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current status display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusConfig['label'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              statusConfig['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: statusColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Status change timestamp
                  if (vanUpdatedAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Last updated: ${_formatStatusDate(vanUpdatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Status notes
                  if (vanNotes != null && vanNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.note,
                                  size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Notes:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vanNotes,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Quick status indicators for all statuses
            const SizedBox(height: 16),
            const Text(
              'Status Options:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: EnhancedDriverService.availableStatuses.map((status) {
                final config = EnhancedDriverService.statusConfig[status]!;
                final isActive = status == vanStatus;
                final color = _getStatusColor(status);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color:
                          isActive ? color.withOpacity(0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? color : Colors.grey[300]!,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: isActive ? color : Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config['label'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? color : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog() {
    final vanStatus = vanData!['status']?.toString() ?? 'active';

    showVanStatusDialog(
      context,
      vanNumber: widget.vanNumber,
      currentStatus: vanStatus,
      onStatusChanged: (newStatus) {
        // Reload van data to reflect the status change
        _loadVanData();
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green[600]!;
      case 'maintenance':
        return Colors.orange[600]!;
      case 'out_of_service':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'maintenance':
        return Icons.build;
      case 'out_of_service':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  String _formatStatusDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        final hours = difference.inHours;
        final minutes = difference.inMinutes;
        if (hours > 0) {
          return '$hours hour${hours > 1 ? 's' : ''} ago';
        } else if (minutes > 0) {
          return '$minutes minute${minutes > 1 ? 's' : ''} ago';
        } else {
          return 'Just now';
        }
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildDamageAssessmentCard() {
    final images = vanData!['images'] as List? ?? [];

    // First, check if we have van-level damage data (from the model field which contains damage rating)
    final vanMake = vanData!['van_make']?.toString() ?? 'Unknown';
    final vanModel = vanData!['van_model']?.toString() ?? 'Unknown';

    // Check if van_model contains damage rating info (format: "Rental Van - Moderate (Scratches) - scratches")
    String? vanLevelDamage;
    int? vanLevelRating;
    String? vanLevelType;
    String? vanLevelSeverity;

    if (vanModel.contains(' - ') &&
        vanModel.contains('(') &&
        vanModel.contains(')')) {
      final parts = vanModel.split(' - ');
      if (parts.length >= 2) {
        final damageInfo = parts[1];
        if (damageInfo.contains('(') && damageInfo.contains(')')) {
          final severityMatch =
              RegExp(r'(\w+)\s*\(([^)]+)\)').firstMatch(damageInfo);
          if (severityMatch != null) {
            vanLevelSeverity = severityMatch.group(1)?.toLowerCase();
            vanLevelType = severityMatch.group(2)?.toLowerCase();

            // Map severity to rating
            switch (vanLevelSeverity) {
              case 'no':
                vanLevelRating = 0;
                break;
              case 'minor':
                vanLevelRating = 1;
                break;
              case 'moderate':
                vanLevelRating = 2;
                break;
              case 'major':
                vanLevelRating = 3;
                break;
            }

            if (parts.length >= 3) {
              vanLevelDamage = parts[2];
            }
          }
        }
      }
    }

    // Find the worst damage from all images (highest rating)
    Map<String, dynamic>? worstDamageImage;
    int highestRating = vanLevelRating ?? 0;

    for (final image in images) {
      final imageRating = image['van_rating'] as int? ?? 0;
      if (imageRating > highestRating) {
        highestRating = imageRating;
        worstDamageImage = image;
      }
    }

    // Use worst damage image data if it has higher rating than van-level data
    String finalDamageDescription;
    String finalDamageType;
    String finalSeverity;
    String finalLocation;
    int finalRating;

    if (worstDamageImage != null &&
        (worstDamageImage['van_rating'] as int? ?? 0) > (vanLevelRating ?? 0)) {
      // Use individual image data (worst damage found)
      finalRating = worstDamageImage['van_rating'] as int? ?? 0;
      finalDamageType =
          worstDamageImage['damage_type']?.toString() ?? 'unknown';
      finalSeverity =
          worstDamageImage['damage_severity']?.toString() ?? 'unknown';
      finalLocation = worstDamageImage['van_side']
              ?.toString()
              ?.replaceAll('_', ' ')
              .toUpperCase() ??
          'UNKNOWN';
      finalDamageDescription = worstDamageImage['van_damage']?.toString() ??
          'No description available';
    } else if (vanLevelRating != null && vanLevelRating > 0) {
      // Use van-level data
      finalRating = vanLevelRating;
      finalDamageType = vanLevelType ?? 'unknown';
      finalSeverity = vanLevelSeverity ?? 'unknown';
      finalLocation = "DRIVER SIDE"; // Default for Enterprise vans
      finalDamageDescription =
          vanLevelDamage ?? 'Minor dirt and debris on vehicle surface.';
    } else {
      // No damage found
      finalRating = 0;
      finalDamageType = 'none';
      finalSeverity = 'none';
      finalLocation = 'OVERALL';
      finalDamageDescription = 'No visible damage detected.';
    }

    String getRatingDescription(int rating) {
      switch (rating) {
        case 0:
          return 'No Damage';
        case 1:
          return 'Minor (Dirt/Debris)';
        case 2:
          return 'Moderate (Scratches)';
        case 3:
          return 'Major (Dents/Damage)';
        default:
          return 'Unknown';
      }
    }

    Color getRatingColor(int rating) {
      switch (rating) {
        case 0:
          return Colors.green[600]!;
        case 1:
          return Colors.yellow[700]!;
        case 2:
          return Colors.orange[700]!;
        case 3:
          return Colors.red[700]!;
        default:
          return Colors.grey[600]!;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: finalRating >= 2
            ? Border.all(color: getRatingColor(finalRating), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finalRating >= 2 ? Icons.warning : Icons.assessment,
                color: finalRating >= 2
                    ? getRatingColor(finalRating)
                    : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                finalRating >= 2
                    ? '⚠️ Main Damage Assessment'
                    : '✅ Damage Assessment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: finalRating >= 2
                      ? getRatingColor(finalRating)
                      : Colors.blue[800],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Illustrated Van Icon with Damage Indicators
          _buildIllustratedVanIcon(images),

          const SizedBox(height: 12),

          // Main damage highlight banner
          if (finalRating >= 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getRatingColor(finalRating).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: getRatingColor(finalRating), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.priority_high,
                          color: getRatingColor(finalRating), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'NEEDS ATTENTION: $finalLocation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: getRatingColor(finalRating),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This side has the most damage and requires priority attention.',
                    style: TextStyle(
                      fontSize: 11,
                      color: getRatingColor(finalRating),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (finalRating >= 2) const SizedBox(height: 12),

          // Rating section
          Row(
            children: [
              const Text(
                'Rating: ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getRatingColor(finalRating),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getRatingDescription(finalRating),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($finalRating/3)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Details
          _buildDetailRow('Type:', finalDamageType),
          _buildDetailRow('Severity:', finalSeverity),
          _buildDetailRow('Location/\nSide:', finalLocation),

          const SizedBox(height: 8),

          const Text(
            'Description:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            finalDamageDescription,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),

          const SizedBox(height: 8),

          Text(
            'Last updated: ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustratedVanIcon(List images) {
    // Analyze damage by van side
    Map<String, int> sideDamageRatings = {
      'front': 0,
      'rear': 0,
      'driver_side': 0,
      'passenger_side': 0,
      'interior': 0,
      'roof': 0,
      'undercarriage': 0,
    };

    // Find the highest damage rating for each side
    for (final image in images) {
      final side = image['van_side']?.toString() ?? 'unknown';
      final rating = image['van_rating'] as int? ?? 0;

      if (sideDamageRatings.containsKey(side)) {
        if (rating > sideDamageRatings[side]!) {
          sideDamageRatings[side] = rating;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Text(
            '🚐 Van Damage Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal row of van side indicators
          Container(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Front
                Column(
                  children: [
                    _buildSideIndicator(
                      'FRONT',
                      sideDamageRatings['front'] ?? 0,
                      _getVanSideIcon('FRONT'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'FRONT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Driver Side
                Column(
                  children: [
                    _buildSideIndicator(
                      'DRIVER',
                      sideDamageRatings['driver_side'] ?? 0,
                      _getVanSideIcon('DRIVER'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'DRIVER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Passenger Side
                Column(
                  children: [
                    _buildSideIndicator(
                      'PASSENGER',
                      sideDamageRatings['passenger_side'] ?? 0,
                      _getVanSideIcon('PASSENGER'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PASSENGER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Rear
                Column(
                  children: [
                    _buildSideIndicator(
                      'REAR',
                      sideDamageRatings['rear'] ?? 0,
                      _getVanSideIcon('REAR'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'REAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildLegendItem('No Damage', Colors.green[600]!),
              _buildLegendItem('Minor (L1)', Colors.yellow[700]!),
              _buildLegendItem('Moderate (L2)', Colors.orange[700]!),
              _buildLegendItem('Major (L3)', Colors.red[700]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideIndicator(String label, int damageRating, IconData icon,
      {bool isSmall = false}) {
    Color indicatorColor = Colors.grey[400]!;
    final hasDamage = damageRating > 0;

    if (hasDamage) {
      switch (damageRating) {
        case 1:
          indicatorColor = Colors.yellow[700]!;
          break;
        case 2:
          indicatorColor = Colors.orange[700]!;
          break;
        case 3:
          indicatorColor = Colors.red[700]!;
          break;
      }
    }

    // Create a more visual van side representation
    return GestureDetector(
      onTap: hasDamage ? () => _navigateToDamageImage(label) : null,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 8 : 12),
        decoration: BoxDecoration(
          color: indicatorColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildVanSideVisual(label, isSmall),
            if (hasDamage)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app,
                    size: isSmall ? 8 : 12,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanSideVisual(String label, bool isSmall) {
    switch (label.toUpperCase()) {
      case 'FRONT':
        return _buildFrontView(isSmall);
      case 'REAR':
        return _buildRearView(isSmall);
      case 'DRIVER':
        return _buildDriverSide(isSmall);
      case 'PASSENGER':
        return _buildPassengerSide(isSmall);
      case 'INTERIOR':
        return Icon(Icons.airline_seat_recline_normal,
            color: Colors.white, size: isSmall ? 16 : 24);
      case 'ROOF':
        return Icon(Icons.roofing,
            color: Colors.white, size: isSmall ? 16 : 24);
      case 'UNDER':
        return Icon(Icons.build, color: Colors.white, size: isSmall ? 16 : 24);
      default:
        return Icon(Icons.local_shipping,
            color: Colors.white, size: isSmall ? 16 : 24);
    }
  }

  Widget _buildFrontView(bool isSmall) {
    return Container(
      width: isSmall ? 40 : 60,
      height: isSmall ? 30 : 40,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Ford grille - prominent horizontal slats
          Positioned(
            left: 8,
            top: 12,
            child: Container(
              width: 35,
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    5,
                    (index) => Container(
                          width: 5,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
              ),
            ),
          ),
          // Animated glowing headlights
          Positioned(
            left: 4,
            top: 4,
            child: _buildAnimatedHeadlight(isSmall),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: _buildAnimatedHeadlight(isSmall),
          ),
          // Ford logo area - more prominent
          Positioned(
            left: 15,
            top: 15,
            child: Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Front bumper
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRearView(bool isSmall) {
    return Container(
      width: isSmall ? 40 : 60,
      height: isSmall ? 30 : 40,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Rear doors with prominent vertical seam
          Positioned(
            left: 12,
            top: 4,
            child: Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Animated glowing taillights
          Positioned(
            left: 4,
            bottom: 4,
            child: _buildAnimatedTaillight(isSmall),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _buildAnimatedTaillight(isSmall),
          ),
          // TRANSIT text area - more prominent
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Rear bumper
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSide(bool isSmall) {
    return Container(
      width: isSmall ? 30 : 45,
      height: isSmall ? 40 : 55,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Driver window - larger and more prominent
          Positioned(
            left: 4,
            top: 6,
            child: Container(
              width: 25,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey[700]!, width: 1.5),
              ),
            ),
          ),
          // Large prominent side mirror
          Positioned(
            right: 3,
            top: 12,
            child: Container(
              width: 8,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[600]!, width: 1.5),
              ),
            ),
          ),
          // Lower trim panel
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 35,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Driver side door handle
          Positioned(
            left: 6,
            top: 25,
            child: Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Driver side steering wheel indicator
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerSide(bool isSmall) {
    return Container(
      width: isSmall ? 30 : 45,
      height: isSmall ? 40 : 55,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Passenger window - larger and more prominent
          Positioned(
            left: 4,
            top: 6,
            child: Container(
              width: 25,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey[700]!, width: 1.5),
              ),
            ),
          ),
          // Large prominent side mirror
          Positioned(
            right: 3,
            top: 12,
            child: Container(
              width: 8,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[600]!, width: 1.5),
              ),
            ),
          ),
          // Lower trim panel
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 35,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Passenger side door handle
          Positioned(
            left: 6,
            top: 25,
            child: Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Passenger side seat indicator
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.grey[500]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeadlight(bool isSmall) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Container(
          width: isSmall ? 8 : 12,
          height: isSmall ? 8 : 12,
          decoration: BoxDecoration(
            color: Colors.yellow[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[700]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow[300]!.withOpacity(0.8 * value),
                blurRadius: 3 + (2 * value),
                spreadRadius: 1 + value,
              ),
              BoxShadow(
                color: Colors.yellow[100]!.withOpacity(0.6 * value),
                blurRadius: 6 + (4 * value),
                spreadRadius: 2 + (2 * value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTaillight(bool isSmall) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Container(
          width: isSmall ? 8 : 12,
          height: isSmall ? 6 : 8,
          decoration: BoxDecoration(
            color: Colors.red[400],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[700]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red[300]!.withOpacity(0.8 * value),
                blurRadius: 3 + (2 * value),
                spreadRadius: 1 + value,
              ),
              BoxShadow(
                color: Colors.red[100]!.withOpacity(0.6 * value),
                blurRadius: 6 + (4 * value),
                spreadRadius: 2 + (2 * value),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getVanSideIcon(String label) {
    switch (label.toUpperCase()) {
      case 'FRONT':
        return Icons.local_shipping; // Van front view
      case 'REAR':
        return Icons.local_shipping; // Van rear view
      case 'DRIVER':
        return Icons.local_shipping; // Van driver side
      case 'PASSENGER':
        return Icons.local_shipping; // Van passenger side
      case 'INTERIOR':
        return Icons.airline_seat_recline_normal;
      case 'ROOF':
        return Icons.roofing;
      case 'UNDER':
        return Icons.build;
      default:
        return Icons.local_shipping; // Generic van icon
    }
  }

  void _navigateToDamageImage(String sideLabel) {
    if (vanData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No van data available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find images for this specific side
    final images = vanData!['images'] as List? ?? [];
    final sideImages = images.where((image) {
      final imageSide = image['van_side']?.toString().toLowerCase() ?? '';
      final targetSide = sideLabel.toLowerCase();

      // Map side labels to image side values
      switch (targetSide) {
        case 'front':
          return imageSide.contains('front') ||
              imageSide.contains('front_side');
        case 'rear':
          return imageSide.contains('rear') ||
              imageSide.contains('back') ||
              imageSide.contains('rear_side');
        case 'driver':
          return imageSide.contains('driver') ||
              imageSide.contains('driver_side');
        case 'passenger':
          return imageSide.contains('passenger') ||
              imageSide.contains('passenger_side');
        case 'interior':
          return imageSide.contains('interior') || imageSide.contains('inside');
        case 'roof':
          return imageSide.contains('roof') || imageSide.contains('top');
        case 'under':
          return imageSide.contains('under') ||
              imageSide.contains('undercarriage') ||
              imageSide.contains('bottom');
        default:
          return imageSide.contains(targetSide);
      }
    }).toList();

    if (sideImages.isNotEmpty) {
      // Find the image with the highest damage rating
      sideImages.sort((a, b) {
        final ratingA = a['van_rating'] as int? ?? 0;
        final ratingB = b['van_rating'] as int? ?? 0;
        return ratingB.compareTo(ratingA); // Sort descending
      });

      final targetImage = sideImages.first;
      final imageUrl = targetImage['image_url'] as String?;

      if (imageUrl != null) {
        // Navigate to the image viewer with the specific image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildImageViewer(imageUrl, targetImage),
          ),
        );
      } else {
        // Show error message if no image found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No damage image found for $sideLabel side'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Show error message if no images found for this side
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No images found for $sideLabel side'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildImageViewer(String imageUrl, Map<String, dynamic> imageData) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Damage Image - ${imageData['van_side'] ?? 'Unknown Side'}'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  Text(
                    'Damage Level: ${imageData['van_rating'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Side: ${imageData['van_side'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (imageData['created_at'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Uploaded: ${DateTime.parse(imageData['created_at']).toString().split('.')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value
                  .replaceAll('_', ' ')
                  .toLowerCase()
                  .split(' ')
                  .map((word) => word.isNotEmpty
                      ? word[0].toUpperCase() + word.substring(1)
                      : '')
                  .join(' '),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStatsCard() {
    final images = vanData!['images'] as List? ?? [];
    final totalImages = images.length;

    // Count unique drivers
    final Set<String> uniqueDrivers = {};
    for (final image in images) {
      final driverProfile = image['driver_profiles'] as Map<String, dynamic>?;
      if (driverProfile != null && driverProfile['id'] != null) {
        uniqueDrivers.add(driverProfile['id'].toString());
      }
    }

    // Find latest upload
    DateTime? latestUpload;
    for (final image in images) {
      final uploadedAt =
          DateTime.tryParse(image['created_at']?.toString() ?? '');
      if (uploadedAt != null) {
        if (latestUpload == null || uploadedAt.isAfter(latestUpload)) {
          latestUpload = uploadedAt;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Image Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    'Total Images', totalImages.toString(), Icons.image),
                _buildStatItem(
                    'Drivers', uniqueDrivers.length.toString(), Icons.people),
                _buildStatItem(
                    'Latest Upload',
                    latestUpload != null
                        ? '${latestUpload.month}/${latestUpload.day}'
                        : 'N/A',
                    Icons.upload),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.green[400]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    final images = vanData!['images'] as List? ?? [];

    if (images.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.image_not_supported,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No images uploaded yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group images by driver
    Map<String, List<Map<String, dynamic>>> imagesByDriver = {};
    for (final image in images) {
      final driverProfile = image['driver_profiles'] as Map<String, dynamic>?;
      final driverName = driverProfile?['driver_name']?.toString() ??
          driverProfile?['slack_real_name']?.toString() ??
          'Unknown Driver';
      final driverId = driverProfile?['id']?.toString() ?? 'unknown';

      if (!imagesByDriver.containsKey(driverId)) {
        imagesByDriver[driverId] = [];
      }
      imagesByDriver[driverId]!.add(Map<String, dynamic>.from(image));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📷 Images by Driver (${images.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Test button to verify EnhancedImageViewer works
            if (images.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  debugPrint(
                      '🧪 TEST: Opening EnhancedImageViewer directly...');
                  final imageList = images.cast<Map<String, dynamic>>();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EnhancedImageViewer(
                        images: imageList,
                        initialIndex: 0,
                        title: 'Van #${widget.vanNumber} Images - TEST',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('TEST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...imagesByDriver.entries
            .map((entry) => _buildDriverImageGroup(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDriverImageGroup(
      String driverId, List<Map<String, dynamic>> images) {
    final driverProfile =
        images.first['driver_profiles'] as Map<String, dynamic>?;
    final driverName = driverProfile?['driver_name']?.toString() ??
        driverProfile?['slack_real_name']?.toString() ??
        'Unknown Driver';
    final imageCount = images.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green[400],
                        child: Text(
                          driverName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          driverName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('$imageCount images'),
                  backgroundColor: Colors.blue[100],
                ),
                const SizedBox(width: 8),
                if (driverId != 'unknown')
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () =>
                        _navigateToDriverProfile(driverId, driverName),
                    tooltip: 'View driver profile',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120, // Increased height for button
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length > 5 ? 5 : images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return Container(
                    width: 120, // Increased width for button
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        // Image display
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(image),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Individual image damage assessment
                        _buildIndividualImageDamageAssessment(image),
                        const SizedBox(height: 4),
                        // Guaranteed working button
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                debugPrint(
                                    '🚀 VIEW BUTTON: Pressed for image ${image['id']}');
                                final allImages =
                                    vanData!['images'] as List? ?? [];
                                final imageList =
                                    allImages.cast<Map<String, dynamic>>();
                                final selectedIndex = imageList.indexWhere(
                                    (img) => img['id'] == image['id']);

                                debugPrint(
                                    '📷 Opening viewer with ${imageList.length} images, index: $selectedIndex');

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EnhancedImageViewer(
                                      images: imageList,
                                      initialIndex: selectedIndex >= 0
                                          ? selectedIndex
                                          : 0,
                                      title: 'Van #${widget.vanNumber} Images',
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                textStyle: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fullscreen, size: 12),
                                  const SizedBox(width: 2),
                                  const Text('VIEW'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (images.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${images.length - 5} more images',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getDamageRatingColor(int rating) {
    switch (rating) {
      case 0:
        return Colors.green[600]!;
      case 1:
        return Colors.yellow[700]!;
      case 2:
        return Colors.orange[700]!;
      case 3:
        return Colors.red[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();
    String? imageUrl = image['image_url']?.toString();

    debugPrint('🖼️ Building image widget:');
    debugPrint('  - image_data length: ${imageData?.length ?? 0}');
    debugPrint('  - image_url: ${imageUrl?.substring(0, 100) ?? 'null'}...');
    debugPrint('  - content_type: ${image['content_type']}');
    debugPrint('  - van_number: ${image['van_number']}');
    debugPrint('  - van_rating: ${image['van_rating']}');
    debugPrint('  - van_side: ${image['van_side']}');

    // Try image_url first (has data URL prefix), then fall back to image_data
    String? sourceData = imageUrl ?? imageData;

    if (sourceData != null && sourceData.isNotEmpty) {
      try {
        // Remove data URL prefix if it exists
        String base64Data = sourceData;
        if (sourceData.startsWith('data:')) {
          final commaIndex = sourceData.indexOf(',');
          if (commaIndex != -1) {
            base64Data = sourceData.substring(commaIndex + 1);
          }
        }

        final bytes = base64Decode(base64Data);
        debugPrint(
            '  ✅ Successfully decoded base64 image (${bytes.length} bytes)');

        return GestureDetector(
          onTap: () {
            debugPrint(
                '🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
            _openImageViewer(image);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('  ❌ Error displaying image: $error');
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              Text('Error', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Rating badge (L0, L1, L2, L3) - top left corner
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDamageRatingColor(
                            image['van_rating'] as int? ?? 0),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'L${image['van_rating'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Fullscreen icon - top right
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // Van side indicator (bottom)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getVanSideColor(
                            image['van_side']?.toString() ?? 'unknown'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (image['van_side']?.toString() ?? 'unknown')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Tap indicator overlay (invisible but helps with tap detection)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          debugPrint(
                              '🖱️ VAN PROFILE: InkWell tapped! Opening image viewer...');
                          _openImageViewer(image);
                        },
                        child: Container(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('  ❌ Error decoding base64: $e');
        return GestureDetector(
          onTap: () {
            debugPrint(
                '🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
            _openImageViewer(image);
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, color: Colors.grey),
                  Text('Invalid image', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Fallback to placeholder
    return GestureDetector(
      onTap: () {
        debugPrint('🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
        _openImageViewer(image);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, color: Colors.grey),
              Text('No image', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _openImageViewer(Map<String, dynamic> selectedImage) {
    debugPrint(
        '🔍 VAN PROFILE: _openImageViewer called for image: ${selectedImage['id']}');
    debugPrint('🔍 VAN PROFILE: selectedImage data: $selectedImage');

    final images = vanData!['images'] as List? ?? [];
    debugPrint('🔍 VAN PROFILE: vanData images: $images');

    final imageList = images.cast<Map<String, dynamic>>();
    final selectedIndex =
        imageList.indexWhere((img) => img['id'] == selectedImage['id']);

    debugPrint(
        '📷 VAN PROFILE: Total images: ${imageList.length}, Selected index: $selectedIndex');

    if (imageList.isNotEmpty) {
      debugPrint('🚀 VAN PROFILE: Navigating to EnhancedImageViewer...');
      try {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedImageViewer(
              images: imageList,
              initialIndex: selectedIndex >= 0 ? selectedIndex : 0,
              title: 'Van #${widget.vanNumber} Images',
            ),
          ),
        );
        debugPrint('✅ VAN PROFILE: Navigation successful!');
      } catch (e) {
        debugPrint('❌ VAN PROFILE: Navigation error: $e');
      }
    } else {
      debugPrint('❌ VAN PROFILE: No images available to display');
    }
  }

  void _navigateToDriverProfile(String driverId, String driverName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverProfileScreen(
          driverId: driverId,
          driverName: driverName,
        ),
      ),
    );
  }

  Color _getVanSideColor(String vanSide) {
    switch (vanSide) {
      case 'front':
        return Colors.blue[600]!;
      case 'rear':
        return Colors.green[600]!;
      case 'driver_side':
        return Colors.red[600]!;
      case 'passenger_side':
        return Colors.orange[600]!;
      case 'interior':
        return Colors.purple[600]!;
      case 'roof':
        return Colors.teal[600]!;
      case 'undercarriage':
        return Colors.brown[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getDamageSeverityColor(String damageSeverity) {
    switch (damageSeverity) {
      case 'none':
        return Colors.green[600]!;
      case 'minor':
        return Colors.yellow[700]!;
      case 'moderate':
        return Colors.orange[700]!;
      case 'major':
        return Colors.red[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildSimpleImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();

    if (imageData != null && imageData.isNotEmpty) {
      try {
        String base64Data = imageData;
        if (imageData.startsWith('data:')) {
          final commaIndex = imageData.indexOf(',');
          if (commaIndex != -1) {
            base64Data = imageData.substring(commaIndex + 1);
          }
        }

        final bytes = base64Decode(base64Data);

        return ElevatedButton(
          onPressed: () {
            debugPrint('🚀 SIMPLE: Button pressed! Opening image viewer...');
            final images = vanData!['images'] as List? ?? [];
            final imageList = images.cast<Map<String, dynamic>>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EnhancedImageViewer(
                  images: imageList,
                  initialIndex: 0,
                  title: 'Van #${widget.vanNumber} Images',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Container(
            width: 100,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        return Container(
          width: 100,
          height: 100,
          color: Colors.red,
          child: const Center(child: Text('ERROR')),
        );
      }
    }

    return Container(
      width: 100,
      height: 100,
      color: Colors.grey,
      child: const Center(child: Text('NO IMAGE')),
    );
  }

  Widget _buildIndividualImageDamageAssessment(Map<String, dynamic> image) {
    final rating = image['van_rating'] as int? ?? 0;
    final damageType = image['damage_type']?.toString() ?? 'Unknown';
    final vanSide = image['van_side']?.toString() ?? 'Unknown';

    String getRatingDescription(int rating) {
      switch (rating) {
        case 0:
          return 'No Damage';
        case 1:
          return 'Minor';
        case 2:
          return 'Moderate';
        case 3:
          return 'Major';
        default:
          return 'Unknown';
      }
    }

    Color getRatingColor(int rating) {
      switch (rating) {
        case 0:
          return Colors.green[600]!;
        case 1:
          return Colors.yellow[700]!;
        case 2:
          return Colors.orange[700]!;
        case 3:
          return Colors.red[700]!;
        default:
          return Colors.grey[600]!;
      }
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: getRatingColor(rating),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'L$rating',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Status and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getRatingDescription(rating),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: getRatingColor(rating),
                  ),
                ),
                Text(
                  '$damageType | ${vanSide.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
