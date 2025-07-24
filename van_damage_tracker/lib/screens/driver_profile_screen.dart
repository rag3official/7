import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/enhanced_driver_service.dart';
import '../widgets/enhanced_image_viewer.dart';
import 'van_profile_screen.dart';
import 'dart:convert';

class DriverProfileScreen extends StatefulWidget {
  final String driverId;
  final String driverName;

  const DriverProfileScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? driverProfile;
  List<Map<String, dynamic>> imagesByVan = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final profile =
          await EnhancedDriverService.getDriverProfile(widget.driverId);
      final images =
          await EnhancedDriverService.getDriverImagesByVan(widget.driverId);

      setState(() {
        driverProfile = profile;
        imagesByVan = images;
        isLoading = false;
      });
    } catch (e) {
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
        title: Text('👨‍💼 ${widget.driverName}'),
        backgroundColor: Colors.green[400],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDriverData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildDriverProfile(),
    );
  }

  Widget _buildDriverProfile() {
    if (driverProfile == null) {
      return const Center(child: Text('Driver profile not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDriverInfoCard(),
          const SizedBox(height: 20),
          _buildUploadStatsCard(),
          const SizedBox(height: 20),
          _buildDriverAlertsSection(),
          const SizedBox(height: 20),
          _buildVanImagesSection(),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green[400],
                  child: Text(
                    (driverProfile!['driver_name']?.toString() ?? 'U')[0]
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverProfile!['driver_name']?.toString() ??
                            'Unknown Driver',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (driverProfile!['slack_real_name'] != null)
                        Text(
                          'Slack: ${driverProfile!['slack_real_name']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      if (driverProfile!['phone'] != null)
                        Text(
                          'Phone: ${driverProfile!['phone']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      if (driverProfile!['email'] != null)
                        Text(
                          'Email: ${driverProfile!['email']}',
                          style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildUploadStatsCard() {
    final totalUploads = driverProfile!['total_uploads'] ?? 0;
    final memberSince = driverProfile!['created_at'] != null
        ? DateTime.tryParse(driverProfile!['created_at'].toString())
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Upload Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    'Total Uploads', totalUploads.toString(), Icons.upload),
                _buildStatItem('Vans Photographed',
                    imagesByVan.length.toString(), Icons.local_shipping),
                if (memberSince != null)
                  _buildStatItem(
                      'Member Since',
                      '${memberSince.month}/${memberSince.year}',
                      Icons.calendar_today),
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

  Widget _buildDriverAlertsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getDriverAlerts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final alertVans = snapshot.data ?? [];
        final hasAlerts = alertVans.isNotEmpty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: hasAlerts ? Colors.red : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🚨 Damage Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasAlerts ? Colors.red : Colors.grey,
                      ),
                    ),
                    if (hasAlerts) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${alertVans.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (hasAlerts) ...[
                  Text(
                    'Vans with alerts (may include all alerts if driver tracking not yet implemented):',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...alertVans.map((van) => GestureDetector(
                        onTap: () {
                          final vanNumber = van['van_number'];
                          if (vanNumber != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VanProfileScreen(vanNumber: vanNumber),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.directions_car,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Van #${van['van_number']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Status: ${van['status'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ALERT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.red[700],
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      )),
                ] else ...[
                  Text(
                    'No damage alerts for this driver.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVanImagesSection() {
    if (imagesByVan.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚐 Images by Van',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...imagesByVan.map((vanGroup) => _buildVanImageGroup(vanGroup)),
      ],
    );
  }

  Widget _buildVanImageGroup(Map<String, dynamic> vanGroup) {
    final vanNumber = vanGroup['van_number'] as int?;
    final vanMake = vanGroup['van_make']?.toString() ?? 'Unknown';
    final vanModel = vanGroup['van_model']?.toString() ?? 'Unknown';
    final vanDisplayName = '$vanMake $vanModel (#$vanNumber)';
    final imageCount = vanGroup['image_count'] ?? 0;
    final images = vanGroup['images'] as List? ?? [];

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
                  child: Text(
                    vanDisplayName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text('$imageCount images'),
                  backgroundColor: Colors.blue[100],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: vanNumber != null
                      ? () => _navigateToVanProfile(vanNumber)
                      : null,
                  tooltip: 'View van profile',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length > 5 ? 5 : images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(image),
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

  Widget _buildImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();
    String? imageUrl = image['image_url']?.toString();

    debugPrint('🖼️ Building image widget:');
    debugPrint('  - image_data length: ${imageData?.length ?? 0}');
    debugPrint('  - image_url: ${imageUrl?.substring(0, 100) ?? 'null'}...');
    debugPrint('  - content_type: ${image['content_type']}');
    debugPrint('  - van_number: ${image['van_number']}');
    debugPrint('  - van_rating: ${image['van_rating']}');

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
          onTap: () => _openImageViewer(image),
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
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('  ❌ Error displaying image: $error');
                      return Container(
                        width: double.infinity,
                        height: 120,
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

                  // Rating badge (L0, L1, L2, L3) - top right
                  Positioned(
                    top: 4,
                    right: 4,
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

                  // Van side overlay - bottom left
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getVanSideColor(
                            image['van_side']?.toString() ?? 'unknown'),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getVanSideIcon(
                                image['van_side']?.toString() ?? 'unknown'),
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            (image['van_side']?.toString() ?? 'unknown')
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
          onTap: () => _openImageViewer(image),
          child: Container(
            width: double.infinity,
            height: 120,
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
      onTap: () => _openImageViewer(image),
      child: Container(
        width: double.infinity,
        height: 120,
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
    // Find all images for this van group
    final vanNumber = selectedImage['van_number'] as int?;
    List<Map<String, dynamic>> vanImages = [];
    int selectedIndex = 0;

    // Find the van group that contains this image
    for (final vanGroup in imagesByVan) {
      if (vanGroup['van_number'] == vanNumber) {
        vanImages = List<Map<String, dynamic>>.from(vanGroup['images'] ?? []);
        // Find the index of the selected image
        selectedIndex =
            vanImages.indexWhere((img) => img['id'] == selectedImage['id']);
        if (selectedIndex == -1) selectedIndex = 0;
        break;
      }
    }

    if (vanImages.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EnhancedImageViewer(
            images: vanImages,
            initialIndex: selectedIndex,
            title: 'Van #$vanNumber Images',
          ),
        ),
      );
    }
  }

  void _navigateToVanProfile(int vanNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VanProfileScreen(vanNumber: vanNumber),
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

  IconData _getVanSideIcon(String vanSide) {
    switch (vanSide) {
      case 'front':
        return Icons.directions_car;
      case 'rear':
        return Icons.directions_car_filled;
      case 'driver_side':
        return Icons.keyboard_arrow_left;
      case 'passenger_side':
        return Icons.keyboard_arrow_right;
      case 'interior':
        return Icons.airline_seat_recline_normal;
      case 'roof':
        return Icons.keyboard_arrow_up;
      case 'undercarriage':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.help_outline;
    }
  }

  Color _getDamageRatingColor(int rating) {
    switch (rating) {
      case 0:
        return Colors.green[600]!;
      case 1:
        return Colors.yellow[600]!;
      case 2:
        return Colors.orange[600]!;
      case 3:
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Future<List<Map<String, dynamic>>> _getDriverAlerts() async {
    try {
      print('🔍 Checking alerts for driver: ${widget.driverName}');

      // First, let's check what vans have alerts and what drivers are recorded
      final allAlertsResponse = await Supabase.instance.client
          .from('van_profiles')
          .select('van_number, status, alerts, damage_caused_by')
          .eq('alerts', 'yes');

      print('🔍 All vans with alerts: $allAlertsResponse');

      // Query vans where this driver caused damage
      final response = await Supabase.instance.client
          .from('van_profiles')
          .select('van_number, status, alerts, damage_caused_by')
          .eq('alerts', 'yes')
          .eq('damage_caused_by', widget.driverName);

      final alertVans = List<Map<String, dynamic>>.from(response);

      print(
          '🚨 Found ${alertVans.length} vans with alerts caused by ${widget.driverName}');

      // If no results with exact match, try partial match
      if (alertVans.isEmpty) {
        print('🔍 Trying partial match for driver name...');
        final partialResponse = await Supabase.instance.client
            .from('van_profiles')
            .select('van_number, status, alerts, damage_caused_by')
            .eq('alerts', 'yes')
            .ilike('damage_caused_by', '%${widget.driverName}%');

        final partialAlertVans =
            List<Map<String, dynamic>>.from(partialResponse);
        print('🚨 Found ${partialAlertVans.length} vans with partial match');

        // If still no results, show all vans with alerts for debugging
        if (partialAlertVans.isEmpty) {
          print(
              '🔍 No driver-specific alerts found, showing all vans with alerts for debugging...');
          final allAlerts = List<Map<String, dynamic>>.from(allAlertsResponse);
          return allAlerts;
        }

        return partialAlertVans;
      }

      return alertVans;
    } catch (e) {
      print('❌ Error fetching driver alerts: $e');
      return [];
    }
  }
}
