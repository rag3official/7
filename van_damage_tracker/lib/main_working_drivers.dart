import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/van.dart';
import 'models/van_image.dart';
import 'services/van_service_optimized.dart';

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
          ),
        );
      },
    );
  }
}

// WORKING DRIVERS SCREEN WITH REAL DATA
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

      print('🔍 Loading drivers from database...');
      final response = await Supabase.instance.client
          .from('driver_profiles')
          .select('*')
          .order('driver_name')
          .limit(50);

      setState(() {
        drivers = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      print('✅ Loaded ${drivers.length} drivers');
    } catch (e) {
      print('❌ Error loading drivers: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
        drivers = [];
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green, Colors.lightGreen],
          ),
        ),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Loading drivers...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              )
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
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
                                size: 64, color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'No drivers found',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Drivers will appear here when they upload images via Slack',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
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
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final driverName = driver['driver_name']?.toString() ?? 'Unknown Driver';
    final totalUploads = driver['total_uploads'] ?? 0;
    final slackRealName = driver['slack_real_name']?.toString();
    final lastUpload = driver['last_upload_date'] != null
        ? DateTime.tryParse(driver['last_upload_date'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[700],
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailScreen(driver: driver),
            ),
          );
        },
      ),
    );
  }
}

// DRIVER DETAIL SCREEN
class DriverDetailScreen extends StatelessWidget {
  final Map<String, dynamic> driver;

  const DriverDetailScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final driverName = driver['driver_name']?.toString() ?? 'Unknown Driver';
    final totalUploads = driver['total_uploads'] ?? 0;
    final slackRealName = driver['slack_real_name']?.toString();
    final phone = driver['phone']?.toString();
    final email = driver['email']?.toString();
    final lastUpload = driver['last_upload_date'] != null
        ? DateTime.tryParse(driver['last_upload_date'].toString())
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver: $driverName'),
        backgroundColor: Colors.green[400],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green, Colors.lightGreen],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Driver Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.green[700],
                        child: Text(
                          driverName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (slackRealName != null &&
                          slackRealName != driverName) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Slack: $slackRealName',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Contact Info
                      if (phone != null || email != null) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        if (phone != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 20),
                              const SizedBox(width: 8),
                              Text('Phone: $phone'),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (email != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.email, size: 20),
                              const SizedBox(width: 8),
                              Text('Email: $email'),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],

                      const Divider(),
                      const SizedBox(height: 8),

                      // Statistics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.upload, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                '$totalUploads',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Total Uploads'),
                            ],
                          ),
                          if (lastUpload != null)
                            Column(
                              children: [
                                const Icon(Icons.access_time, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  '${lastUpload.month}/${lastUpload.day}/${lastUpload.year}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Last Upload'),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Future: Driver's upload history
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Upload History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Driver upload history and images coming soon!'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class VanDetailScreen extends StatefulWidget {
  final Van van;

  const VanDetailScreen({super.key, required this.van});

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  final VanServiceOptimized _vanService = VanServiceOptimized();
  List<VanImage> _images = [];
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
      setState(() {
        _images = images;
        _isLoadingImages = false;
      });
      print(
          '📸 Loaded ${_images.length} images for van ${widget.van.plateNumber}');
      for (var image in _images) {
        print(
            '   - Image: ${image.vanSide ?? image.location ?? "no side info"} | Driver: ${image.driverName ?? "unknown"}');
      }
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Van Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 8),
                    Text('Model: ${widget.van.model}'),
                    Text('Status: ${widget.van.status}'),
                    if (widget.van.driverName?.isNotEmpty == true)
                      Text('Driver: ${widget.van.driverName}'),
                    if (widget.van.damage?.isNotEmpty == true)
                      Text('Damage: ${widget.van.damage}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Images Section
            Text(
              '📸 Van Images (${_images.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (_isLoadingImages)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_images.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No images found for this van'),
                      ],
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return Card(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey),
                                    Text('Error loading image'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Van Side indicator - ENHANCED with driver info!
                        if (image.vanSide?.isNotEmpty == true ||
                            image.location?.isNotEmpty == true)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.white, width: 1),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                (image.vanSide?.isNotEmpty == true
                                        ? image.vanSide!
                                        : image.location!)
                                    .toUpperCase()
                                    .replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                        // Driver info indicator
                        if (image.driverName?.isNotEmpty == true)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                image.driverName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Damage level indicator
                        if (image.damageLevel != null && image.damageLevel! > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: image.damageLevel! >= 3
                                    ? Colors.red
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'L${image.damageLevel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
