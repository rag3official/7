import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/van.dart';
import 'models/van_image.dart';
import 'services/van_service_optimized.dart';
// import 'services/enhanced_driver_service.dart';
// import 'screens/driver_profile_screen.dart';
import 'screens/van_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print('Environment variables loaded successfully');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
  }

  runApp(const VanFleetApp());
}

class VanFleetApp extends StatelessWidget {
  const VanFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🚐 VAN FLEET TRACKER 🚐',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const VanFleetHomeScreen(),
    );
  }
}

class VanFleetHomeScreen extends StatelessWidget {
  const VanFleetHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚐 VAN FLEET TRACKER 🚐'),
        backgroundColor: Colors.red[400],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red, Colors.orange],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    '🎉 SUCCESS! 🎉',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Van Fleet Manager is working!',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connected to Supabase! 🚀',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 1.2,
                      children: [
                        _buildClickableTile(context, '🚐 VANS', Colors.blue,
                            const VansScreen()),
                        _buildClickableTile(context, '👨‍💼 DRIVERS',
                            Colors.green, const DriversScreen()),
                        _buildClickableTile(context, '🔧 MAINTENANCE',
                            Colors.purple, const MaintenanceScreen()),
                        _buildClickableTile(context, '⚙️ SETTINGS',
                            Colors.orange, const SettingsScreen()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSuccessDialog(context),
        backgroundColor: Colors.green,
        icon: const Icon(Icons.celebration, color: Colors.white),
        label: const Text('IT WORKS!', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildClickableTile(BuildContext context, String title, Color color,
      Widget destinationScreen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 CONGRATULATIONS! 🎉'),
        content: const Text('Your Van Fleet Manager app is working perfectly!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('AWESOME!'),
          ),
        ],
      ),
    );
  }
}

// Real Vans Screen with Supabase integration
class VansScreen extends StatefulWidget {
  const VansScreen({super.key});

  @override
  State<VansScreen> createState() => _VansScreenState();
}

class _VansScreenState extends State<VansScreen> {
  final VanServiceOptimized _vanService = VanServiceOptimized();
  List<Van> _vans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVans();
  }

  Future<void> _loadVans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vans = await _vanService.getAllVans();
      setState(() {
        _vans = vans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load vans: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚐 Vans Management'),
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVans,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlue],
          ),
        ),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new van functionality
          _showAddVanDialog();
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Loading vans...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadVans,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 100, color: Colors.white70),
            SizedBox(height: 20),
            Text(
              'No vans found',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              'Add your first van to get started!',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vans.length,
      itemBuilder: (context, index) {
        final van = _vans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[700],
              child: Text(
                van.plateNumber,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              'Van ${van.plateNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${van.model}'),
                Text('Status: ${van.status}'),
                if (van.driverName?.isNotEmpty == true)
                  Text('Driver: ${van.driverName}'),
                if (van.rating?.isNotEmpty == true)
                  Text('Rating: ${van.rating}'),
                if (van.damage?.isNotEmpty == true)
                  Text('Damage: ${van.damage}'),
                if (van.damageDescription?.isNotEmpty == true)
                  Text(
                    'Description: ${van.damageDescription}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VanDetailScreen(van: van),
                ),
              );
            },
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  // TODO: Edit van functionality
                } else if (value == 'delete') {
                  _deleteVan(van);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddVanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Van'),
        content: const Text('Add van functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVan(Van van) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Van'),
        content:
            Text('Are you sure you want to delete van ${van.plateNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _vanService.deleteVan(van.id);
      if (success) {
        _loadVans(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Van ${van.plateNumber} deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete van')),
          );
        }
      }
    }
  }
}

// Enhanced Drivers Screen with navigation
class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List<Map<String, dynamic>> drivers = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final driversData = await EnhancedDriverService.getAllDriverProfiles();

      setState(() {
        drivers = driversData;
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
        title: const Text('👨‍💼 Drivers Management'),
        backgroundColor: Colors.green[400],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDrivers,
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
                        onPressed: _loadDrivers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : drivers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No drivers found'),
                          SizedBox(height: 8),
                          Text(
                              'Drivers will appear here when they upload images via Slack'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: drivers.length,
                      itemBuilder: (context, index) {
                        final driver = drivers[index];
                        return _buildDriverCard(driver);
                      },
                    ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final driverName = driver['driver_name']?.toString() ?? 'Unknown Driver';
    final slackRealName = driver['slack_real_name']?.toString();
    final totalUploads = driver['total_uploads'] ?? 0;
    final lastUpload = driver['last_upload_date'] != null
        ? DateTime.tryParse(driver['last_upload_date'].toString())
        : null;
    final phone = driver['phone']?.toString();
    final email = driver['email']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[400],
          child: Text(
            driverName[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          driverName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (slackRealName != null && slackRealName != driverName)
              Text('Slack: $slackRealName'),
            if (phone != null) Text('Phone: $phone'),
            if (email != null) Text('Email: $email'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.upload, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$totalUploads uploads',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (lastUpload != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Last: ${lastUpload.month}/${lastUpload.day}/${lastUpload.year}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _navigateToDriverProfile(driver),
      ),
    );
  }

  void _navigateToDriverProfile(Map<String, dynamic> driver) {
    final driverId = driver['id']?.toString();
    final driverName = driver['driver_name']?.toString() ?? 'Unknown Driver';

    if (driverId != null) {
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
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Maintenance'),
        backgroundColor: Colors.purple[400],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple, Colors.deepPurple],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Maintenance',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(
                'Maintenance tracking coming soon!',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Settings'),
        backgroundColor: Colors.orange[400],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange, Colors.deepOrange],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Settings',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(
                'App settings coming soon!',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Detailed Van Profile Screen
class VanDetailScreen extends StatefulWidget {
  final Van van;

  const VanDetailScreen({super.key, required this.van});

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  final VanServiceOptimized _vanService = VanServiceOptimized();
  List<VanImageGroup> _imageGroups = [];
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadVanImages();
  }

  Future<void> _loadVanImages() async {
    setState(() {
      _isLoadingImages = true;
    });

    try {
      final images = await _vanService.getVanImages(widget.van.id);
      final groups = VanImageGroupingHelper.groupImagesByDateAndDriver(images);
      setState(() {
        _imageGroups = groups;
        _isLoadingImages = false;
      });
    } catch (e) {
      print('Error loading van images: $e');
      setState(() {
        _isLoadingImages = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚐 Van ${widget.van.plateNumber}'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVanImages,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Edit functionality coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Van Header Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue[700],
                            child: Text(
                              widget.van.plateNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Van ${widget.van.plateNumber}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.van.model,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(widget.van.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.van.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Van Information Section
              _buildInfoSection('📋 Van Information', [
                _buildInfoRow('Type', widget.van.model),
                _buildInfoRow('Year', widget.van.year ?? 'Unknown'),
                _buildInfoRow('Status', widget.van.status),
                if (widget.van.mileage != null)
                  _buildInfoRow('Mileage',
                      '${widget.van.mileage!.toStringAsFixed(0)} miles'),
                if (widget.van.lastInspection != null)
                  _buildInfoRow('Last Inspection',
                      '${widget.van.lastInspection!.day}/${widget.van.lastInspection!.month}/${widget.van.lastInspection!.year}'),
              ]),

              // Driver Information Section
              if (widget.van.driverName?.isNotEmpty == true)
                _buildInfoSection('👨‍💼 Driver Information', [
                  _buildInfoRow('Driver', widget.van.driverName!),
                ]),

              // Damage Assessment Section
              if (widget.van.damage?.isNotEmpty == true ||
                  widget.van.rating?.isNotEmpty == true)
                _buildInfoSection('⚠️ Damage Assessment', [
                  if (widget.van.rating?.isNotEmpty == true)
                    _buildInfoRow(
                        'Damage Rating', _getRatingDisplay(widget.van.rating!)),
                  if (widget.van.damage?.isNotEmpty == true)
                    _buildInfoRow('Damage Type', widget.van.damage!),
                  if (widget.van.damageDescription?.isNotEmpty == true)
                    _buildDescriptionRow(
                        'Description', widget.van.damageDescription!),
                ]),

              // Van Images Section (NEW - Grouped by Date and Driver)
              _buildImageGallerySection(),

              // Notes Section
              if (widget.van.notes?.isNotEmpty == true)
                _buildInfoSection('📝 Notes', [
                  _buildDescriptionRow('Additional Notes', widget.van.notes!),
                ]),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Damage report coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.warning),
                      label: const Text('Report Damage'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Maintenance scheduling coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.build),
                      label: const Text('Maintenance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Add photo functionality coming soon!')),
          );
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildImageGallerySection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '📸 Van Images',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                if (_isLoadingImages)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingImages)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_imageGroups.isEmpty)
              // Show main van image if no damage images are available
              widget.van.url?.isNotEmpty == true
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping,
                                  size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Main Van Photo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo,
                                        size: 12, color: Colors.blue[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Profile',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showMainVanImageDetail(),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.van.url!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported,
                                              color: Colors.grey, size: 48),
                                          SizedBox(height: 8),
                                          Text('Image not available',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.image, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No images found for this van',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
            else
              ..._imageGroups.map((group) => _buildImageGroup(group)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGroup(VanImageGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First row: Driver and most recent upload time
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // Use the enhanced driver display info if available
                        group.images.isNotEmpty
                            ? group.images.first.displayDriverInfo
                            : group.displayDriver,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            group.displayMostRecentUpload,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Second row: Date, damage level, and image count
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.blue[600]),
                    const SizedBox(width: 6),
                    Text(
                      group.displayDate,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (group.hasDamage) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getDamageLevelColor(group.maxDamageLevel),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Level ${group.maxDamageLevel}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Spacer(),
                    Icon(Icons.photo_library,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${group.totalImages} image${group.totalImages != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Images Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: group.images.length,
            itemBuilder: (context, index) {
              final image = group.images[index];
              return _buildImageThumbnail(image);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(VanImage image) {
    return GestureDetector(
      onTap: () => _showImageDetail(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child:
                          Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  );
                },
              ),

              // Damage level indicator
              if (image.damageLevel != null && image.damageLevel! > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getDamageLevelColor(image.damageLevel!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${image.damageLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Location indicator
              if (image.location?.isNotEmpty == true)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      image.location!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageDetail(VanImage image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  image.imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),

              // Image details
              if (image.description?.isNotEmpty == true) ...[
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(image.description!),
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  const Text(
                    'Uploaded by: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(image.displayDriverInfo),
                ],
              ),
              const SizedBox(height: 4),

              // Show driver contact info if available
              if (image.driverPhone?.isNotEmpty == true) ...[
                Row(
                  children: [
                    const Text(
                      'Phone: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(image.driverPhone!),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              if (image.driverEmail?.isNotEmpty == true) ...[
                Row(
                  children: [
                    const Text(
                      'Email: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(image.driverEmail!),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              Row(
                children: [
                  const Text(
                    'Date: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                      '${image.uploadedAt.day}/${image.uploadedAt.month}/${image.uploadedAt.year}'),
                ],
              ),

              if (image.damageLevel != null && image.damageLevel! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Damage Level: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDamageLevelColor(image.damageLevel!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Level ${image.damageLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (image.location?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      'Location: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(image.location!.toUpperCase()),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMainVanImageDetail() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Van ${widget.van.plateNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.van.url!,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 48),
                            SizedBox(height: 8),
                            Text('Image not available',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Van details
              if (widget.van.model.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Model: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(widget.van.model),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (widget.van.year.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Year: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(widget.van.year),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (widget.van.driverName?.isNotEmpty == true) ...[
                Row(
                  children: [
                    const Text(
                      'Current Driver: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(widget.van.driverName!),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.van.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.van.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDamageLevelColor(int level) {
    switch (level) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.yellow[700]!;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red[400]!;
      case 5:
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'out of service':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getRatingDisplay(String rating) {
    switch (rating) {
      case '1':
        return '⭐ Minor (1)';
      case '2':
        return '⭐⭐ Moderate (2)';
      case '3':
        return '⭐⭐⭐ Major (3)';
      case '4':
        return '⭐⭐⭐⭐ Severe (4)';
      case '5':
        return '⭐⭐⭐⭐⭐ Critical (5)';
      default:
        return rating;
    }
  }
}
