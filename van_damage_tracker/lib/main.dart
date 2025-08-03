import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/van_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/statistics_provider.dart';
import 'screens/van_list_screen.dart';
import 'screens/driver_list_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'theme/modern_premium_theme.dart';
import 'widgets/modern_premium_components.dart';
import 'widgets/modern_premium_background.dart';
import 'widgets/adaptive_refresh_manager.dart';
import 'dart:async';
import 'dart:io';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print('Environment variables loaded successfully');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // Initialize Environment
  await Environment.initialize();

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: Environment.supabaseUrl,
      anonKey: Environment.supabaseAnonKey,
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
  }

  // Initialize Adaptive Refresh Rate Manager
  try {
    await AdaptiveRefreshManager().initialize();
    print('Adaptive Refresh Manager initialized successfully');
  } catch (e) {
    print('Error initializing Adaptive Refresh Manager: $e');
  }

  runApp(const VanDamageTrackerApp());
}

class VanDamageTrackerApp extends StatelessWidget {
  const VanDamageTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => VanProvider()),
        ChangeNotifierProvider(create: (context) => DriverProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (context) => StatisticsProvider()),
      ],
      child: MaterialApp(
        title: 'Van Damage Tracker',
        debugShowCheckedModeBanner: false,
        theme: ModernPremiumTheme.modernTheme,
        home: const BackgroundDataLoader(),
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: ModernPremiumTheme.modernSurfaceGradient,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class BackgroundDataLoader extends StatefulWidget {
  const BackgroundDataLoader({super.key});

  @override
  State<BackgroundDataLoader> createState() => _BackgroundDataLoaderState();
}

class _BackgroundDataLoaderState extends State<BackgroundDataLoader> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeBackgroundData();
  }

  Future<void> _initializeBackgroundData() async {
    try {
      print('🚀 Starting background data initialization...');

      // Start background data loading immediately
      final vanProvider = Provider.of<VanProvider>(context, listen: false);
      final driverProvider =
          Provider.of<DriverProvider>(context, listen: false);

      // Start background loading without blocking the UI
      _startBackgroundLoading(vanProvider, driverProvider);
    } catch (e) {
      print('❌ Error during background initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _startBackgroundLoading(
      VanProvider vanProvider, DriverProvider driverProvider) {
    // Use Future.microtask to avoid blocking the UI
    Future.microtask(() async {
      try {
        print('📦 Starting background van data loading...');
        await vanProvider.loadVansInBackground();
        print('✅ Background van data loading completed');

        print('👥 Starting background driver data loading...');
        await driverProvider.loadDriversInBackground();
        print('✅ Background driver data loading completed');
      } catch (e) {
        print('❌ Background data loading error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const AuthWrapper();
    }

    return const AuthWrapper();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _titles = ['Van Fleet', 'Drivers'];
  final List<Widget> _screens = [
    const VanListScreen(),
    const DriverListScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: ModernPremiumTheme.mediumAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: ModernPremiumTheme.modernCurve,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _refreshData() async {
    print('🔄 REFRESH BUTTON CLICKED - Starting data refresh...');

    // Show simple loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ModernPremiumTheme.darkCharcoal.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        ModernPremiumTheme.primaryNeon,
                        ModernPremiumTheme.secondaryElectric,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Refreshing Data...',
                  style: TextStyle(
                    color: ModernPremiumTheme.textDiamond,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we fetch the latest information',
                  style: TextStyle(
                    color: ModernPremiumTheme.textDiamond.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      print('🔄 Refreshing van data...');
      await context.read<VanProvider>().refreshVans();
      print('✅ Van data refreshed successfully');

      print('🔄 Refreshing driver data...');
      await context.read<DriverProvider>().refreshDrivers();
      print('✅ Driver data refreshed successfully');

      print('✅ All data refreshed successfully!');

      Navigator.of(context).pop();
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: ModernPremiumTheme.primaryNeon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Data refreshed successfully!',
                  style: TextStyle(color: ModernPremiumTheme.textDiamond),
                ),
              ),
            ],
          ),
          backgroundColor: ModernPremiumTheme.darkCharcoal.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      print('❌ Error during refresh: $error');
      Navigator.of(context).pop();
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error,
                color: ModernPremiumTheme.errorHotPink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to refresh data: $error',
                  style: TextStyle(color: ModernPremiumTheme.textDiamond),
                ),
              ),
            ],
          ),
          backgroundColor: ModernPremiumTheme.darkCharcoal.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernPremiumBackground(
      enableAnimatedGradient: true,
      enableParticleEffect: true,
      enableGridPattern: true,
      enableFloatingElements: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ModernPremiumAppBar(
          title: _titles[_selectedIndex],
          leading: Container(
            margin: const EdgeInsets.only(right: ModernPremiumTheme.spacingM),
            padding: const EdgeInsets.all(ModernPremiumTheme.spacingS),
            decoration: BoxDecoration(
              borderRadius: ModernPremiumTheme.smallRadius,
              gradient: ModernPremiumTheme.neonGradient,
              boxShadow: ModernPremiumTheme.neonShadow,
            ),
            child: Icon(
              _selectedIndex == 0 ? Icons.directions_car : Icons.people,
              color: ModernPremiumTheme.textDiamond,
              size: 24,
            ),
          ),
          actions: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: ModernPremiumTheme.spacingM),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: ModernPremiumTheme.neonGradient,
                boxShadow: ModernPremiumTheme.neonShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _refreshData(),
                  child: const Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: ModernPremiumTheme.textDiamond,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _screens[_selectedIndex],
          ),
        ),
        bottomNavigationBar: ModernPremiumBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              activeIcon: Icon(Icons.directions_car),
              label: 'Vans',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              activeIcon: Icon(Icons.people),
              label: 'Drivers',
            ),
          ],
        ),
      ),
    );
  }
}
