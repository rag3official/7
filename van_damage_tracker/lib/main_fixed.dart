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
      home: const VansScreen(),
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

// Simple Van Detail Screen
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
            const Text(
              '📸 Van Images',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (_isLoadingImages)
              const Center(child: CircularProgressIndicator())
            else if (_images.isEmpty)
              const Text('No images found')
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
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                        // Van Side indicator - NOW WITH PROPER VAN SIDE INFO!
                        if (image.vanSide?.isNotEmpty == true ||
                            image.location?.isNotEmpty == true)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.white, width: 0.5),
                              ),
                              child: Text(
                                (image.vanSide?.isNotEmpty == true
                                        ? image.vanSide!
                                        : image.location!)
                                    .toUpperCase()
                                    .replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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
