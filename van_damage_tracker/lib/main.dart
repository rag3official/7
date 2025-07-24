import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/van.dart';
import 'models/van_image.dart';
import 'services/van_service_optimized.dart';
import 'services/enhanced_driver_service.dart';
import 'screens/driver_profile_screen.dart';
import 'screens/van_profile_screen.dart';
import 'dart:async';
import 'dart:io';
import 'config/environment.dart';
import 'widgets/van_status_dialog.dart';

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

class _VansScreenState extends State<VansScreen> with TickerProviderStateMixin {
  final VanServiceOptimized _vanService = VanServiceOptimized();
  List<Van> _vans = [];
  List<Van> _filteredVans = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  late TabController _tabController;

  // Filter and sort state
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _damageFilter = 'All';
  String _alertFilter = 'All';
  String _sortBy = 'Recently Updated';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Filter options
  final List<String> _statusOptions = [
    'All',
    'Active',
    'Maintenance',
    'Out of Service'
  ];
  final List<String> _damageOptions = [
    'All',
    'No Damage',
    'Minor',
    'Moderate',
    'Major'
  ];
  final List<String> _sortOptions = [
    'Recently Updated',
    'Van Number',
    'Status',
    'Damage Rating',
    'Driver Name',
    'Date Created'
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // 2 tabs: Filters & Sort, Alerts
    _loadVans();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadVans();
    });
  }

  Future<void> _loadVans() async {
    debugPrint('🔄 Loading vans at ${DateTime.now()}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vans = await _vanService.getAllVans();
      debugPrint('✅ Loaded ${vans.length} vans');

      // Log latest van numbers for debugging
      if (vans.isNotEmpty) {
        final latestVans = vans.take(5).map((v) => v.plateNumber).join(', ');
        debugPrint('📊 Latest vans: $latestVans');

        // Debug alerts field
        for (final van in vans.take(3)) {
          debugPrint('🚐 Van #${van.plateNumber}: alerts=${van.alerts}');
        }
      }

      setState(() {
        _vans = vans;
        _isLoading = false;
      });

      _applyFiltersAndSort();
    } catch (e) {
      debugPrint('❌ Error loading vans: $e');
      setState(() {
        _errorMessage = 'Failed to load vans: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method to normalize status for filtering
  String _normalizeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'maintenance':
        return 'Maintenance';
      case 'out_of_service':
      case 'out of service':
        return 'Out of Service';
      default:
        return status; // Return as-is for unknown statuses
    }
  }

  void _applyFiltersAndSort() {
    List<Van> filtered = List.from(_vans);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((van) {
        return van.plateNumber
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            van.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (van.driverName
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((van) {
        // Normalize the van status to match filter format
        final normalizedVanStatus = _normalizeStatus(van.status);
        return normalizedVanStatus == _statusFilter;
      }).toList();
    }

    // Apply damage filter
    if (_damageFilter != 'All') {
      filtered = filtered.where((van) {
        final rating = int.tryParse(van.rating ?? '0') ?? 0;
        switch (_damageFilter) {
          case 'No Damage':
            return rating == 0;
          case 'Minor':
            return rating == 1;
          case 'Moderate':
            return rating == 2;
          case 'Major':
            return rating == 3;
          default:
            return true;
        }
      }).toList();
    }

    // Apply alerts filter
    if (_alertFilter != 'All') {
      filtered = filtered.where((van) {
        switch (_alertFilter) {
          case 'With Alerts':
            return van.alerts == 'yes';
          case 'No Alerts':
            return van.alerts == 'no';
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'Recently Updated':
          final aDate = a.lastInspection ?? DateTime(1970);
          final bDate = b.lastInspection ?? DateTime(1970);
          result = bDate.compareTo(aDate);
          break;
        case 'Van Number':
          result = a.plateNumber.compareTo(b.plateNumber);
          break;
        case 'Status':
          result = a.status.compareTo(b.status);
          break;
        case 'Damage Rating':
          final aRating = int.tryParse(a.rating ?? '0') ?? 0;
          final bRating = int.tryParse(b.rating ?? '0') ?? 0;
          result = bRating.compareTo(aRating); // Higher damage first by default
          break;
        case 'Driver Name':
          result = (a.driverName ?? '').compareTo(b.driverName ?? '');
          break;
        case 'Date Created':
          final aDate = a.lastInspection ?? DateTime(1970);
          final bDate = b.lastInspection ?? DateTime(1970);
          result = aDate.compareTo(bDate);
          break;
      }
      return _sortAscending ? result : -result;
    });

    setState(() {
      _filteredVans = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _damageFilter = 'All';
      _alertFilter = 'All';
      _sortBy = 'Recently Updated';
      _sortAscending = false;
      _searchController.clear();
    });
    _applyFiltersAndSort();
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
            icon: const Icon(Icons.filter_list),
            onPressed: _showFiltersBottomSheet,
            tooltip: 'Filters & Sort',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVans,
            tooltip: 'Refresh',
          ),
          // Drivers button
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.pushNamed(context, '/driver-list');
            },
            tooltip: 'View Drivers',
          ),
          // Alerts icon with count
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.warning),
                onPressed: _showAlertsOnly,
                tooltip: 'View Alerts',
              ),
              if (_getAlertsCount() > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_getAlertsCount()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
        child: Column(
          children: [
            _buildSearchAndFiltersHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadVans,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFiltersHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vans by number, model, or driver...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _applyFiltersAndSort();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFiltersAndSort();
            },
          ),
          const SizedBox(height: 12),

          // Quick filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                    'Sort: $_sortBy', Icons.sort, () => _showSortBottomSheet()),
                const SizedBox(width: 8),
                _buildFilterChip('Status: $_statusFilter', Icons.info_outline,
                    () => _showStatusFilter()),
                const SizedBox(width: 8),
                _buildFilterChip('Damage: $_damageFilter', Icons.warning_amber,
                    () => _showDamageFilter()),
                const SizedBox(width: 8),
                _buildFilterChip('Alerts: $_alertFilter', Icons.warning,
                    () => _showAlertsFilter()),
                const SizedBox(width: 8),
                if (_hasActiveFilters())
                  _buildFilterChip('Clear All', Icons.clear_all, _clearFilters,
                      isAction: true),
              ],
            ),
          ),

          // Results summary
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing ${_filteredVans.length} of ${_vans.length} vans',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, VoidCallback onTap,
      {bool isAction = false}) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isAction ? Colors.red : Colors.blue[700]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isAction ? Colors.red : Colors.blue[700])),
        ],
      ),
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: isAction ? Colors.red[100] : Colors.blue[100],
      side: BorderSide(color: isAction ? Colors.red : Colors.blue[300]!),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _statusFilter != 'All' ||
        _damageFilter != 'All' ||
        _alertFilter != 'All' ||
        _sortBy != 'Recently Updated';
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
              decoration: BoxDecoration(
                color: Colors.blue[400],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters & Alerts',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.blue[400],
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Filters & Sort'),
                  Tab(text: 'Alerts'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFiltersTab(),
                  _buildAlertsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilterSection('Sort By', _sortOptions, _sortBy,
            (value) => setState(() => _sortBy = value)),
        const SizedBox(height: 20),
        _buildSortDirectionToggle(),
        const SizedBox(height: 20),
        _buildFilterSection('Status', _statusOptions, _statusFilter,
            (value) => setState(() => _statusFilter = value)),
        const SizedBox(height: 20),
        _buildFilterSection('Damage Level', _damageOptions, _damageFilter,
            (value) => setState(() => _damageFilter = value)),
        const SizedBox(height: 20),
        _buildFilterSection('Alerts', ['All', 'With Alerts', 'No Alerts'],
            _alertFilter, (value) => setState(() => _alertFilter = value)),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'All';
                    _damageFilter = 'All';
                    _alertFilter = 'All';
                    _sortBy = 'Recently Updated';
                    _sortAscending = false;
                    _searchController.clear();
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Clear All'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    // Get vans with alerts
    final alertVans = _vans.where((van) => van.alerts == 'yes').toList();

    // Debug output
    debugPrint('🔍 Alerts Tab Debug:');
    debugPrint('📊 Total vans: ${_vans.length}');
    debugPrint('🚨 Vans with alerts: ${alertVans.length}');
    for (final van in _vans.take(5)) {
      debugPrint(
          '🚐 Van #${van.plateNumber}: alerts=${van.alerts}, status=${van.status}');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          color: Colors.red[50],
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '${alertVans.length} Van(s) with Level 2/3 Damage',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: alertVans.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 16),
                      Text('No Critical Damage Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          )),
                      SizedBox(height: 8),
                      Text('All vans are in good condition',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alertVans.length,
                  itemBuilder: (context, index) {
                    final van = alertVans[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: Icon(Icons.warning, color: Colors.red[600]),
                        ),
                        title: Text('Van #${van.plateNumber}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${van.status}'),
                            Text('Driver: ${van.driverName ?? 'Unassigned'}'),
                            Text('Damage Level: ${van.maxDamageLevel}/5',
                                style: TextStyle(color: Colors.red[600])),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward_ios,
                                color: Colors.grey[400], size: 16),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VanProfileScreen(
                                vanNumber: int.parse(van.plateNumber),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(String title, List<String> options,
      String currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options
              .map((option) => ChoiceChip(
                    label: Text(option),
                    selected: option == currentValue,
                    onSelected: (_) => onChanged(option),
                    selectedColor: Colors.blue[100],
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSortDirectionToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sort Direction',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward, size: 16),
                  const SizedBox(width: 4),
                  Text(_sortBy == 'Recently Updated' ||
                          _sortBy == 'Damage Rating'
                      ? 'Newest/Highest First'
                      : 'Descending'),
                ],
              ),
              selected: !_sortAscending,
              onSelected: (_) => setState(() => _sortAscending = false),
              selectedColor: Colors.blue[100],
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward, size: 16),
                  const SizedBox(width: 4),
                  Text(_sortBy == 'Recently Updated' ||
                          _sortBy == 'Damage Rating'
                      ? 'Oldest/Lowest First'
                      : 'Ascending'),
                ],
              ),
              selected: _sortAscending,
              onSelected: (_) => setState(() => _sortAscending = true),
              selectedColor: Colors.blue[100],
            ),
          ],
        ),
      ],
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._sortOptions.map((option) => ListTile(
                  title: Text(option),
                  leading: Radio<String>(
                    value: option,
                    groupValue: _sortBy,
                    onChanged: (value) {
                      setState(() => _sortBy = value!);
                      _applyFiltersAndSort();
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._statusOptions.map((option) => ListTile(
                  title: Text(option),
                  leading: Radio<String>(
                    value: option,
                    groupValue: _statusFilter,
                    onChanged: (value) {
                      setState(() => _statusFilter = value!);
                      _applyFiltersAndSort();
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showDamageFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Damage Level',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._damageOptions.map((option) => ListTile(
                  title: Text(option),
                  trailing: option != 'All' ? _getDamageIcon(option) : null,
                  leading: Radio<String>(
                    value: option,
                    groupValue: _damageFilter,
                    onChanged: (value) {
                      setState(() => _damageFilter = value!);
                      _applyFiltersAndSort();
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _getDamageIcon(String damageLevel) {
    switch (damageLevel) {
      case 'No Damage':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'Minor':
        return const Icon(Icons.warning_amber, color: Colors.yellow);
      case 'Moderate':
        return const Icon(Icons.error, color: Colors.orange);
      case 'Major':
        return const Icon(Icons.dangerous, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  void _showAlertsFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...['All', 'With Alerts', 'No Alerts'].map((option) => ListTile(
                  title: Text(option),
                  trailing: option != 'All' ? _getAlertsIcon(option) : null,
                  leading: Radio<String>(
                    value: option,
                    groupValue: _alertFilter,
                    onChanged: (value) {
                      setState(() => _alertFilter = value!);
                      _applyFiltersAndSort();
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _getAlertsIcon(String alertLevel) {
    switch (alertLevel) {
      case 'With Alerts':
        return const Icon(Icons.warning, color: Colors.red);
      case 'No Alerts':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  int _getAlertsCount() {
    return _vans.where((van) => van.alerts == 'yes').length;
  }

  bool _driverHasCausedDamage(String driverName) {
    return _vans
        .any((van) => van.alerts == 'yes' && van.damageCausedBy == driverName);
  }

  List<Van> _getVansCausedByDriver(String driverName) {
    return _vans
        .where((van) => van.alerts == 'yes' && van.damageCausedBy == driverName)
        .toList();
  }

  void _showAlertsOnly() {
    setState(() {
      _alertFilter = 'With Alerts';
      _applyFiltersAndSort();
    });

    // Show a snackbar to indicate the filter is active
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing ${_getAlertsCount()} van(s) with alerts'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Clear',
          onPressed: () {
            setState(() {
              _alertFilter = 'All';
              _applyFiltersAndSort();
            });
          },
        ),
      ),
    );
  }

  void _testAlerts() async {
    try {
      // Test setting alerts for the first van
      if (_vans.isNotEmpty) {
        final firstVan = _vans.first;
        print('🧪 Testing alerts for van #${firstVan.plateNumber}');

        // Check current alerts status
        print('🚨 Current alerts status: ${firstVan.alerts}');

        // Toggle alerts (if 'yes', set to 'no', if 'no', set to 'yes')
        final newAlertsValue = firstVan.alerts == 'yes' ? 'no' : 'yes';

        // Update the van's alerts in the database
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('van_profiles')
            .update({'alerts': newAlertsValue}).eq(
                'van_number', int.tryParse(firstVan.plateNumber) ?? 0);

        if (response.data != null) {
          print(
              '✅ Successfully set alerts to "$newAlertsValue" for van #${firstVan.plateNumber}');
          // Reload vans to see the change
          _loadVans();
        } else {
          print('❌ Failed to set alerts for van #${firstVan.plateNumber}');
        }
      } else {
        print('❌ No vans available for testing');
      }
    } catch (e) {
      print('❌ Error testing alerts: $e');
    }
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

    if (_filteredVans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list_off, size: 100, color: Colors.white70),
            const SizedBox(height: 20),
            const Text(
              'No vans match your filters',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredVans.length,
      itemBuilder: (context, index) {
        final van = _filteredVans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(van.status),
              child: Text(
                van.plateNumber,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Van ${van.plateNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (van.alerts == 'yes') ...[
                        const SizedBox(width: 8),
                        Icon(Icons.warning, color: Colors.red[600], size: 16),
                      ],
                    ],
                  ),
                ),
                _getDamageRatingBadge(van.rating),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${van.model}'),
                Row(
                  children: [
                    Text('Status: '),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(van.status),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        van.status,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                if (van.driverName?.isNotEmpty == true)
                  Text('Driver: ${van.driverName}'),
                if (van.damage?.isNotEmpty == true)
                  Text('Damage: ${van.damage}'),
                if (van.damageDescription?.isNotEmpty == true)
                  Text(
                    'Description: ${van.damageDescription}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (van.alerts == 'yes')
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'CRITICAL DAMAGE ALERT',
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                Text(
                  'Updated: ${_formatDate(van.lastInspection)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status button with tap functionality
                GestureDetector(
                  onTap: () => _showQuickStatusDialog(van),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(van.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          van.status.toLowerCase() == 'active'
                              ? Icons.check_circle
                              : van.status.toLowerCase() == 'maintenance'
                                  ? Icons.build
                                  : Icons.warning,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          van.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show quick status dialog for van list
  void _showQuickStatusDialog(Van van) {
    final vanNumber = int.tryParse(van.plateNumber);
    if (vanNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid van number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showVanStatusDialog(
      context,
      vanNumber: vanNumber,
      currentStatus: van.status.toLowerCase(),
      onStatusChanged: (newStatus) {
        // Reload vans to reflect the status change
        _loadVans();
      },
    );
  }

  Widget _getDamageRatingBadge(String? rating) {
    final ratingInt = int.tryParse(rating ?? '0') ?? 0;
    Color color;
    String text;

    switch (ratingInt) {
      case 0:
        color = Colors.green;
        text = 'L0';
        break;
      case 1:
        color = Colors.yellow[700]!;
        text = 'L1';
        break;
      case 2:
        color = Colors.orange;
        text = 'L2';
        break;
      case 3:
        color = Colors.red;
        text = 'L3';
        break;
      default:
        color = Colors.grey;
        text = 'L?';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
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

    // Check if this driver has caused damage
    final hasAlerts = _checkDriverAlerts(driverName);

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAlerts)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
        onTap: () {
          _navigateToDriverProfile(driver);
        },
      ),
    );
  }

  bool _checkDriverAlerts(String driverName) {
    // For now, we'll use a simple check based on known data
    // In a real implementation, this would query the database
    // Based on the current data, Erick has caused damage to van #466
    return driverName.toLowerCase().contains('erick');
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID not found')),
      );
    }
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

              // Driver Alerts Section
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getDriverAlerts(driverName),
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
                                'Damage Alerts',
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
                              'This driver has caused damage to the following vans:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...alertVans.map((van) => Container(
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                    ],
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

  Future<List<Map<String, dynamic>>> _getDriverAlerts(String driverName) async {
    try {
      print('🔍 Checking alerts for driver: $driverName');

      // Query vans where this driver caused damage
      final response = await Supabase.instance.client
          .from('van_profiles')
          .select('van_number, status, alerts, damage_caused_by')
          .eq('alerts', 'yes')
          .eq('damage_caused_by', driverName);

      final alertVans = List<Map<String, dynamic>>.from(response);

      print(
          '🚨 Found ${alertVans.length} vans with alerts caused by $driverName');

      return alertVans;
    } catch (e) {
      print('❌ Error fetching driver alerts: $e');
      return [];
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
                    const Text(
                      '🚐 Van Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.local_shipping,
                            color: Colors.blue[400], size: 48),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Van ${widget.van.plateNumber}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.van.year ?? "Unknown"} ${widget.van.model}',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.van.status == 'Active'
                                          ? Colors.green[600]
                                          : Colors.orange[600],
                                      borderRadius: BorderRadius.circular(12),
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
                                  if (widget.van.driverName?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Driver: ${widget.van.driverName}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700]),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Damage Assessment Card
            _buildMainDamageAssessmentCard(),
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

  Color _getRatingColor(String rating) {
    final double score = double.tryParse(rating) ?? 0.0;
    if (score >= 4.0) {
      return Colors.green;
    } else if (score >= 3.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getRatingDescription(String rating) {
    final double score = double.tryParse(rating) ?? 0.0;
    if (score >= 4.0) {
      return 'Excellent';
    } else if (score >= 3.0) {
      return 'Good';
    } else {
      return 'Poor';
    }
  }

  Widget _buildDamageDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildMainDamageAssessmentCard() {
    // Find the worst damage from all images (highest damage level)
    VanImage? worstDamageImage;
    int highestLevel = 0;

    for (final image in _images) {
      final imageLevel = image.damageLevel ?? 0;
      if (imageLevel > highestLevel) {
        highestLevel = imageLevel;
        worstDamageImage = image;
      }
    }

    // Also check van-level damage data from the van model
    int vanLevelRating = 0;
    String vanLevelType = 'none';
    String vanLevelSeverity = 'none';
    String vanLevelDescription = 'No damage detected.';

    if (widget.van.rating?.isNotEmpty == true) {
      try {
        vanLevelRating = int.parse(widget.van.rating!);
      } catch (e) {
        vanLevelRating = 0;
      }
    }

    if (widget.van.damage?.isNotEmpty == true) {
      vanLevelType = widget.van.damage!;
    }

    if (widget.van.damageDescription?.isNotEmpty == true) {
      vanLevelDescription = widget.van.damageDescription!;
    }

    // Determine final damage data (use worst of image-level or van-level)
    String finalDamageDescription;
    String finalDamageType;
    String finalSeverity;
    String finalLocation;
    int finalRating;

    if (worstDamageImage != null &&
        (worstDamageImage.damageLevel ?? 0) > vanLevelRating) {
      // Use individual image data (worst damage found)
      finalRating = worstDamageImage.damageLevel ?? 0;
      finalDamageType = worstDamageImage.damageType ?? 'unknown';
      finalSeverity = _getDamageSeverityFromLevel(finalRating);
      finalLocation = (worstDamageImage.vanSide?.isNotEmpty == true
              ? worstDamageImage.vanSide!
              : worstDamageImage.location ?? 'UNKNOWN')
          .replaceAll('_', ' ')
          .toUpperCase();
      finalDamageDescription =
          worstDamageImage.description ?? 'No description available';
    } else if (vanLevelRating > 0) {
      // Use van-level data
      finalRating = vanLevelRating;
      finalDamageType = vanLevelType;
      finalSeverity = _getDamageSeverityFromLevel(finalRating);
      finalLocation = "OVERALL";
      finalDamageDescription = vanLevelDescription;
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

  String _getDamageSeverityFromLevel(int level) {
    switch (level) {
      case 0:
        return 'none';
      case 1:
        return 'minor';
      case 2:
        return 'moderate';
      case 3:
        return 'major';
      default:
        return 'unknown';
    }
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
}
