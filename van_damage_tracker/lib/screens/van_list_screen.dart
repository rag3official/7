import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';
import '../models/van_image.dart';
import '../widgets/modern_premium_components.dart';
import '../widgets/modern_premium_background.dart';
import '../widgets/enhanced_damage_alert.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../widgets/premium_apple_loading.dart';
import '../theme/modern_premium_theme.dart';
import 'van_profile_screen.dart';
import 'van_profile_screen_new.dart';
import '../widgets/van_image_upload_dialog.dart';

class VanListScreen extends StatefulWidget {
  const VanListScreen({super.key});

  @override
  State<VanListScreen> createState() => _VanListScreenState();
}

class _VanListScreenState extends State<VanListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _shrinkController;
  late AnimationController _breathingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shrinkAnimation;
  late Animation<double> _breathingAnimation;

  String? _vanStatusFilter; // For detailed view filtering
  String?
      _fleetOverviewFilter; // For fleet overview card clicks (affects compact grid only)
  String _sortOption = 'recent'; // 'recent' or 'chronological'
  bool _isCompactView =
      false; // false = detailed view, true = compact grid view
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  static const double _maxScrollOffset =
      200.0; // Maximum scroll for full shrink
  static const double _hideScrollOffset =
      300.0; // Scroll threshold for complete hide
  static const double _headerMaxHeight =
      280.0; // Reduced from 400.0 for smaller overview
  static const double _headerMinHeight =
      140.0; // Reduced from 200.0 for smaller minimum size

  Timer? _midnightTimer;
  DateTime _lastMidnightCheck = DateTime.now();

  // Date picker functionality
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Shrink animation for header
    _shrinkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Breathing animation for premium elements
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _shrinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _shrinkController,
      curve: Curves.easeInOut,
    ));

    _breathingAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
    _breathingController.repeat(reverse: true);

    // Setup midnight timer to refresh status
    _setupMidnightTimer();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset.clamp(0.0, double.infinity);
      // Update shrink animation based on scroll
      final shrinkProgress = (_scrollOffset / _maxScrollOffset).clamp(0.0, 1.0);
      _shrinkController.value = shrinkProgress;
    });
  }

  double _getHideProgress() {
    // Calculate hide progress from 0 to 1 over the entire scroll range
    return (_scrollOffset / _hideScrollOffset).clamp(0.0, 1.0);
  }

  /// Setup timer to check for midnight and refresh status
  void _setupMidnightTimer() {
    _midnightTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final lastCheck = _lastMidnightCheck;

      // Check if we've crossed midnight since last check
      if (now.day != lastCheck.day ||
          now.month != lastCheck.month ||
          now.year != lastCheck.year) {
        print('🕛 Midnight detected! Refreshing van statuses...');
        _lastMidnightCheck = now;

        // Trigger a rebuild to refresh all statuses
        if (mounted) {
          setState(() {
            // This will cause all van cards to recalculate their daily status
          });
        }
      }
    });
  }

  /// Show date picker dialog
  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ModernPremiumTheme.primaryNeon,
              onPrimary: Colors.white,
              surface: ModernPremiumTheme.darkCharcoal,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: ModernPremiumTheme.darkCharcoal,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Show van image upload dialog
  Future<void> _showUploadDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const VanImageUploadDialog();
      },
    );

    // If upload was successful, refresh the van list
    if (result == true && mounted) {
      await context.read<VanProvider>().refreshVans();

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: ModernPremiumTheme.successElectric,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Van image uploaded successfully with AI damage analysis!',
                    style: ModernPremiumTheme.modernBodyStyle.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: ModernPremiumTheme.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shrinkController.dispose();
    _breathingController.dispose();
    _scrollController.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernPremiumBackground(
      enableAnimatedGradient: true,
      enableParticleEffect: true,
      enableGridPattern: false,
      enableFloatingElements: false,
      enableMorphingShapes: false,
      enableEnergyWaves: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<VanProvider>(
          builder: (context, vanProvider, child) {
            if (vanProvider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElasticLoadingRing(
                      size: 90,
                      color: ModernPremiumTheme.primaryNeon,
                      strokeWidth: 5,
                    ),
                    SizedBox(height: ModernPremiumTheme.spacingL),
                    AppleStyleActivityIndicator(
                      size: 60,
                      color: ModernPremiumTheme.secondaryElectric,
                      showLabel: true,
                      label: 'Loading Van Fleet...',
                    ),
                  ],
                ),
              );
            }

            if (vanProvider.vans.isEmpty) {
              return const Center(
                child: ModernPremiumCard(
                  enableGlass: true,
                  enableNeonEffect: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: ModernPremiumTheme.textPlatinum,
                      ),
                      SizedBox(height: ModernPremiumTheme.spacingL),
                      Text(
                        'No Vans Available',
                        style: ModernPremiumTheme.neonHeadingStyle,
                      ),
                      SizedBox(height: ModernPremiumTheme.spacingM),
                      Text(
                        'Add some vans to get started',
                        style: ModernPremiumTheme.neonBodyStyle,
                      ),
                    ],
                  ),
                ),
              );
            }

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(ModernPremiumTheme.spacingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dynamic Premium Header with shrinking effect
                        AnimatedBuilder(
                          animation: _shrinkAnimation,
                          builder: (context, child) {
                            return _buildDynamicPremiumHeader(vanProvider);
                          },
                        ),
                        const SizedBox(height: ModernPremiumTheme.spacingL),

                        // Van list with scroll controller
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight:
                                  200, // Ensure minimum space for van list
                            ),
                            child: RefreshIndicator(
                              onRefresh: () async {
                                await context.read<VanProvider>().refreshVans();
                              },
                              backgroundColor: ModernPremiumTheme.darkCharcoal,
                              color: ModernPremiumTheme.primaryNeon,
                              child: _isCompactView
                                  ? _buildCompactVanGrid(vanProvider)
                                  : ListView.builder(
                                      controller: _scrollController,
                                      itemCount: _filteredVansForDetailedView(
                                              vanProvider)
                                          .length,
                                      itemBuilder: (context, index) {
                                        final van =
                                            _filteredVansForDetailedView(
                                                vanProvider)[index];
                                        return _buildVanCard(van);
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showUploadDialog,
          backgroundColor: ModernPremiumTheme.primaryNeon,
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add_a_photo),
          label: const Text(
            'Upload Van Image',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicPremiumHeader(VanProvider vanProvider) {
    // Calculate single progress value for even shrinking and hiding
    final progress = _getHideProgress();
    final currentHeight = (_headerMaxHeight - (progress * _headerMaxHeight))
        .clamp(0.0, _headerMaxHeight);

    // Completely hide when progress is 1.0
    if (progress >= 1.0) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
      height: currentHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ModernPremiumTheme.darkCharcoal.withOpacity(0.95),
            ModernPremiumTheme.deepSpace.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ModernPremiumTheme.primaryNeon.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.all(progress > 0.5 ? 12.0 : 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title section with date picker
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  padding: EdgeInsets.all(progress > 0.5 ? 6 : 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                        ModernPremiumTheme.primaryNeon.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: progress > 0.5 ? 16 : 22,
                      color: ModernPremiumTheme.primaryNeon,
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: ModernPremiumTheme.primaryNeon,
                      size: progress > 0.5 ? 16 : 22,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  width: progress > 0.5 ? 10 : 14,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOutCubic,
                        style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                          fontSize: progress > 0.5 ? 16 : 22,
                          fontWeight: FontWeight.w600,
                        ),
                        child: const Text(
                          'Fleet Overview',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (progress <= 0.5) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOutCubic,
                          height: 3,
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOutCubic,
                          style: ModernPremiumTheme.neonBodyStyle.copyWith(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          child: Text(
                            '${vanProvider.vans.length} vehicles in your fleet',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Date picker button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  width: progress > 0.5 ? 8 : 12,
                ),
                InkWell(
                  onTap: _showDatePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOutCubic,
                    padding: EdgeInsets.all(progress > 0.5 ? 6 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.secondaryElectric.withOpacity(0.2),
                          ModernPremiumTheme.secondaryElectric.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ModernPremiumTheme.secondaryElectric
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: ModernPremiumTheme.secondaryElectric,
                          size: progress > 0.5 ? 14 : 16,
                        ),
                        if (progress <= 0.5) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}',
                            style: TextStyle(
                              color: ModernPremiumTheme.secondaryElectric,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Stats section - only show when not heavily shrunk
            if (progress <= 0.7) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.3 ? 12 : 18,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.3 ? 60 : 90,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMinimalStatCard(
                        vanProvider.vans.length.toString(),
                        Icons.directions_car,
                        ModernPremiumTheme.primaryNeon,
                        progress,
                        onTap: () {
                          setState(() {
                            _vanStatusFilter = null;
                          });
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                      width: 10,
                    ),
                    Expanded(
                      child: _buildMinimalStatCard(
                        () {
                          final activeVans = vanProvider.vans.where((van) {
                            final dailyStatus = _getDailyStatus(van);
                            // Count vans that have images uploaded on selected date
                            final isActive = dailyStatus == 'active';

                            // Debug logging
                            if (isActive) {
                              print(
                                  '✅ Active van: ${van.plateNumber} - daily status: $dailyStatus');
                            }

                            return isActive;
                          }).toList();

                          print(
                              '📊 Fleet Overview - Active Vans (${_selectedDate.day}/${_selectedDate.month}): ${activeVans.length}');

                          return activeVans.length.toString();
                        }(),
                        Icons.check_circle,
                        ModernPremiumTheme.successElectric,
                        progress,
                        onTap: () {
                          setState(() {
                            _fleetOverviewFilter = 'active';
                          });
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                      width: 10,
                    ),
                    Expanded(
                      child: _buildMinimalStatCard(
                        () {
                          final pendingVans = vanProvider.vans.where((van) {
                            final dailyStatus = _getDailyStatus(van);
                            // Count vans that don't have images uploaded on selected date
                            final isPending = dailyStatus == 'pending';

                            // Debug logging
                            if (isPending) {
                              print(
                                  '⏳ Pending van: ${van.plateNumber} - daily status: $dailyStatus');
                            }

                            return isPending;
                          }).toList();

                          print(
                              '📊 Fleet Overview - Pending Vans (${_selectedDate.day}/${_selectedDate.month}): ${pendingVans.length}');

                          return pendingVans.length.toString();
                        }(),
                        Icons.schedule,
                        ModernPremiumTheme.warningSunset,
                        progress,
                        onTap: () {
                          setState(() {
                            _fleetOverviewFilter = 'pending';
                          });
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                      width: 10,
                    ),
                    Expanded(
                      child: _buildMinimalStatCard(
                        () {
                          final highDamageVans = vanProvider.vans.where((van) {
                            final maxDamageLevel = van.maxDamageLevel;
                            // Count vans with high damage (L2 or L3)
                            final hasHighDamage = maxDamageLevel >= 2;

                            // Debug logging
                            if (hasHighDamage) {
                              print(
                                  '🚨 High damage van: ${van.plateNumber} - damage level: $maxDamageLevel');
                            }

                            return hasHighDamage;
                          }).toList();

                          print(
                              '📊 Fleet Overview - High Damage Vans: ${highDamageVans.length}');
                          print('📊 Total vans: ${vanProvider.vans.length}');
                          print(
                              '📊 Selected date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}');
                          print(
                              '📊 Van daily statuses: ${vanProvider.vans.map((v) => '${v.plateNumber}:${_getDailyStatus(v)}').join(', ')}');
                          print(
                              '📊 Van damage levels: ${vanProvider.vans.map((v) => '${v.plateNumber}:${v.maxDamageLevel}').join(', ')}');

                          return highDamageVans.length.toString();
                        }(),
                        Icons.warning_amber_rounded,
                        Colors.red[400]!,
                        progress,
                        onTap: () {
                          setState(() {
                            _fleetOverviewFilter = 'high_damage';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // View toggle and sorting options - only show when not heavily shrunk
            if (progress <= 0.8) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.4 ? 8 : 12,
              ),
              // View toggle button
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.4 ? 40 : 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildViewToggleOption(
                        'Detailed View',
                        Icons.view_list,
                        !_isCompactView,
                        progress,
                        onTap: () {
                          setState(() {
                            _isCompactView = false;
                          });
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                      width: 8,
                    ),
                    Expanded(
                      child: _buildViewToggleOption(
                        'Compact Grid',
                        Icons.grid_view,
                        _isCompactView,
                        progress,
                        onTap: () {
                          setState(() {
                            _isCompactView = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Sorting options - only show when not heavily shrunk
            if (progress <= 0.8) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.4 ? 8 : 12,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                height: progress > 0.4 ? 40 : 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSortOption(
                        'Most Recent',
                        Icons.access_time,
                        _sortOption == 'recent',
                        progress,
                        onTap: () {
                          setState(() {
                            _sortOption = 'recent';
                          });
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOutCubic,
                      width: 8,
                    ),
                    Expanded(
                      child: _buildSortOption(
                        'Chronological',
                        Icons.sort,
                        _sortOption == 'chronological',
                        progress,
                        isDisabled:
                            !_isCompactView, // Disabled when in detailed view
                        onTap: () {
                          setState(() {
                            _sortOption = 'chronological';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalStatCard(
      String value, IconData icon, Color color, double progress,
      {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.all(progress > 0.3 ? 8.0 : 12.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontSize: progress > 0.3 ? 18 : 24,
                color: color,
              ),
              child: Icon(
                icon,
                color: color,
                size: progress > 0.3 ? 18 : 24,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              height: progress > 0.3 ? 8 : 10,
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontSize: progress > 0.3 ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
      String label, IconData icon, bool isSelected, double progress,
      {VoidCallback? onTap, bool isDisabled = false}) {
    final color = isDisabled
        ? ModernPremiumTheme.textPlatinum.withOpacity(0.3)
        : isSelected
            ? ModernPremiumTheme.primaryNeon
            : ModernPremiumTheme.textPlatinum;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.all(progress > 0.4 ? 6.0 : 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ]
                : [
                    color.withOpacity(0.05),
                    color.withOpacity(0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isSelected ? 0.4 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontSize: progress > 0.4 ? 12 : 14,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Icon(
                icon,
                color: color,
                size: progress > 0.4 ? 12 : 14,
              ),
            ),
            if (progress <= 0.4) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                width: 4,
              ),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleOption(
      String label, IconData icon, bool isSelected, double progress,
      {VoidCallback? onTap}) {
    final color = isSelected
        ? ModernPremiumTheme.primaryNeon
        : ModernPremiumTheme.textPlatinum;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.all(progress > 0.4 ? 6.0 : 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ]
                : [
                    color.withOpacity(0.05),
                    color.withOpacity(0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isSelected ? 0.4 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontSize: progress > 0.4 ? 12 : 14,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Icon(
                icon,
                color: color,
                size: progress > 0.4 ? 12 : 14,
              ),
            ),
            if (progress <= 0.4) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOutCubic,
                width: 4,
              ),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactVanGrid(VanProvider vanProvider) {
    final filteredVans = _filteredVans(vanProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // Reduced from 10 for better spacing
          childAspectRatio: 0.9, // Slightly taller cards
          crossAxisSpacing: 12, // Increased spacing
          mainAxisSpacing: 16, // Increased spacing
        ),
        itemCount: filteredVans.length,
        itemBuilder: (context, index) {
          final van = filteredVans[index];
          return _buildCompactVanCard(van);
        },
      ),
    );
  }

  Widget _buildCompactVanCard(Van van) {
    final maxDamageLevel = van.maxDamageLevel;
    final isHighDamage = maxDamageLevel >= 2;
    final dailyStatus = _getDailyStatus(van);
    final statusColor = _getStatusColor(dailyStatus);
    final damageColor = _getDamageLevelColor(maxDamageLevel);

    return Container(
      margin: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToVanDetail(context, van),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: ModernPremiumTheme.darkCharcoal.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHighDamage
                    ? damageColor.withOpacity(0.4)
                    : statusColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with van number and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Van #${van.plateNumber}',
                          style: const TextStyle(
                            fontSize: 14, // Increased from 12
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          dailyStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, // Minimum 11pt for Apple
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Damage indicator
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: damageColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'L$maxDamageLevel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: damageColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Van image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ModernPremiumTheme.deepSpace.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: van.images.isNotEmpty
                            ? Image.network(
                                van.images.first.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImagePlaceholder();
                                },
                              )
                            : _buildImagePlaceholder(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Last updated
                  if (van.images.isNotEmpty)
                    Text(
                      _isImageFromSelectedDate(van.images.first)
                          ? 'Updated ${_formatTimeAgo(van.images.first.createdAt)}'
                          : 'Last: ${_formatDate(van.images.first.createdAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  bool _isImageFromSelectedDate(VanImage image) {
    final selectedDate = _selectedDate;
    final dateStart =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    return image.createdAt.isAfter(dateStart) &&
        image.createdAt.isBefore(dateEnd);
  }

  Widget _buildVanCard(Van van) {
    // Check if van has high damage rating (L2 or L3) using maxDamageLevel from images
    final maxDamageLevel = van.maxDamageLevel;
    final isHighDamage = maxDamageLevel >= 2; // L2 and L3 damage

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToVanDetail(context, van),
          borderRadius:
              BorderRadius.circular(16), // Apple standard corner radius
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ModernPremiumTheme.darkCharcoal.withOpacity(0.95),
                  ModernPremiumTheme.deepSpace.withOpacity(0.9),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(16), // Apple standard corner radius
              border: Border.all(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                width: 1.0, // Thinner border for cleaner look
              ),
              boxShadow: [
                BoxShadow(
                  color: ModernPremiumTheme.primaryNeon.withOpacity(0.08),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0), // Apple standard padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with van number and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ModernPremiumTheme.primaryNeon
                                        .withOpacity(0.2),
                                    ModernPremiumTheme.primaryNeon
                                        .withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: ModernPremiumTheme.primaryNeon,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Van #${van.plateNumber}',
                                    style: const TextStyle(
                                      fontSize: 22, // Apple large title size
                                      fontWeight:
                                          FontWeight.w600, // Apple semibold
                                      color: Colors.white,
                                      letterSpacing:
                                          -0.5, // Apple letter spacing
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    van.model,
                                    style: const TextStyle(
                                      fontSize: 15, // Apple body text size
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge with Apple UI styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8), // Apple standard padding
                        decoration: BoxDecoration(
                          color: _getStatusColor(_getDailyStatus(van))
                              .withOpacity(0.15), // Apple subtle background
                          borderRadius: BorderRadius.circular(
                              8), // Apple standard corner radius
                          border: Border.all(
                            color: _getStatusColor(_getDailyStatus(van))
                                .withOpacity(0.3),
                            width: 0.5, // Thinner border
                          ),
                        ),
                        child: Text(
                          _getDailyStatus(van).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, // Apple minimum readable text
                            fontWeight: FontWeight.w600, // Apple semibold
                            color: _getStatusColor(_getDailyStatus(van)),
                            letterSpacing: 0.5, // Apple letter spacing
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Enhanced Damage Alert for High Damage Vans
                  if (isHighDamage) ...[
                    const SizedBox(height: 16),
                    EnhancedDamageAlert(
                      damageLevel: maxDamageLevel == 2 ? 'Moderate' : 'Major',
                      damageDescription: _getDamageDescription(maxDamageLevel),
                      damageType: 'Van Damage',
                      customColor: _getDamageLevelColor(maxDamageLevel),
                      onTap: () => _navigateToVanDetail(context, van),
                      isAnimated: true,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Enhanced Damage Assessment Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isHighDamage
                              ? (maxDamageLevel == 2
                                  ? Colors.red[700]!.withOpacity(0.4)
                                  : _getDamageLevelColor(maxDamageLevel)
                                      .withOpacity(0.25))
                              : Colors.black.withOpacity(0.3),
                          isHighDamage
                              ? (maxDamageLevel == 2
                                  ? Colors.red[600]!.withOpacity(0.25)
                                  : _getDamageLevelColor(maxDamageLevel)
                                      .withOpacity(0.15))
                              : Colors.black.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHighDamage
                            ? (maxDamageLevel == 2
                                ? Colors.red[400]!.withOpacity(0.6)
                                : _getDamageLevelColor(maxDamageLevel)
                                    .withOpacity(0.4))
                            : Colors.white.withOpacity(0.1),
                        width: isHighDamage ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with damage level badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isHighDamage
                                      ? Icons.warning_amber_rounded
                                      : Icons.assessment,
                                  color: isHighDamage
                                      ? _getDamageLevelColor(maxDamageLevel)
                                      : ModernPremiumTheme.primaryNeon,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isHighDamage
                                      ? 'DAMAGE ALERT'
                                      : 'Damage Assessment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isHighDamage
                                        ? _getDamageLevelColor(maxDamageLevel)
                                        : ModernPremiumTheme.primaryNeon,
                                  ),
                                ),
                              ],
                            ),
                            // Damage level badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getDamageLevelColor(maxDamageLevel),
                                    _getDamageLevelColor(maxDamageLevel)
                                        .withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getDamageLevelColor(maxDamageLevel)
                                        .withOpacity(0.15),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                'L$maxDamageLevel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Damage description
                        Text(
                          _getDamageDescription(maxDamageLevel),
                          style: TextStyle(
                            fontSize: 13,
                            color: isHighDamage
                                ? _getDamageLevelColor(maxDamageLevel)
                                    .withOpacity(0.9)
                                : Colors.white70,
                            height: 1.4,
                            fontWeight: isHighDamage
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),

                        // Additional damage info if available
                        if (van.damage?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              van.damage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Image Preview Section
                  if (van.images.isNotEmpty) ...[
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showImageGallery(context, van),
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // Main preview image
                                Positioned.fill(
                                  child: _buildImagePreview(van.images.first),
                                ),
                                // Click to expand overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.fullscreen,
                                        color: Colors.white.withOpacity(0.7),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                // Image count overlay
                                if (van.images.length > 1)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '+${van.images.length - 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Damage level indicator on image
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _getDamageLevelColor(maxDamageLevel)
                                              .withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'L$maxDamageLevel',
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
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Enhanced Damage Level Display with Delete Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Damage Level with Icon and Delete Button
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getDamageLevelColor(maxDamageLevel)
                                        .withOpacity(0.2),
                                    _getDamageLevelColor(maxDamageLevel)
                                        .withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _getDamageLevelColor(maxDamageLevel)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _getDamageLevelIcon(maxDamageLevel),
                                color: _getDamageLevelColor(maxDamageLevel),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Damage Level',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'L$maxDamageLevel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _getDamageLevelColor(maxDamageLevel),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Delete button for recently uploaded images
                            FutureBuilder<VanImage?>(
                              future: _getRecentlyUploadedDeletableImage(
                                  van.plateNumber),
                              builder: (context, snapshot) {
                                debugPrint(
                                    '🎯 FutureBuilder for Van #${van.plateNumber}: connectionState=${snapshot.connectionState}');
                                if (snapshot.hasError) {
                                  debugPrint(
                                      '❌ FutureBuilder error: ${snapshot.error}');
                                }
                                if (snapshot.hasData) {
                                  debugPrint(
                                      '🎯 FutureBuilder hasData: ${snapshot.data != null}');
                                }

                                if (snapshot.hasData && snapshot.data != null) {
                                  final deletableImage = snapshot.data!;
                                  debugPrint(
                                      '✅ RENDERING DELETE BUTTON for Van #${van.plateNumber}');
                                  return Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showDeleteImageDialog(
                                            deletableImage),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ModernPremiumTheme
                                                .errorHotPink
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: ModernPremiumTheme
                                                  .errorHotPink
                                                  .withOpacity(0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.timer,
                                                color: ModernPremiumTheme
                                                    .errorHotPink,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                deletableImage
                                                    .remainingDeletionTimeFormatted,
                                                style: TextStyle(
                                                  color: ModernPremiumTheme
                                                      .errorHotPink,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                debugPrint(
                                    '❌ NO DELETE BUTTON for Van #${van.plateNumber} - no deletable image');
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(_getDailyStatus(van))
                                  .withOpacity(0.8),
                              _getStatusColor(_getDailyStatus(van))
                                  .withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(_getDailyStatus(van))
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getDailyStatus(van).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    bool isSuccess = false;
    bool isWarning = false;
    bool isError = false;

    switch (status.toLowerCase()) {
      case 'active':
        badgeColor = ModernPremiumTheme.successElectric;
        isSuccess = true;
        break;
      case 'maintenance':
        badgeColor = ModernPremiumTheme.warningSunset;
        isWarning = true;
        break;
      case 'inactive':
        badgeColor = ModernPremiumTheme.errorHotPink;
        isError = true;
        break;
      default:
        badgeColor = ModernPremiumTheme.primaryNeon;
    }

    return ModernPremiumBadge(
      text: status.toUpperCase(),
      color: badgeColor,
      isSuccess: isSuccess,
      isWarning: isWarning,
      isError: isError,
      enableNeonEffect: true,
    );
  }

  Widget _buildImagePreview(VanImage image) {
    try {
      if (image.imageUrl.isNotEmpty) {
        return Image.network(
          image.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      } else {
        return _buildImagePlaceholder();
      }
    } catch (e) {
      return _buildImagePlaceholder();
    }
  }

  void _showImageGallery(BuildContext context, Van van) {
    if (van.images.isNotEmpty) {
      final images = van.images
          .map((image) => {
                'image_url': image.imageUrl,
                'image_data': null, // VanImage doesn't have imageData property
                'van_rating': image.damageLevel ?? 0,
                'van_side': image.vanSide ?? 'unknown',
                'damage_type': image.damageType ?? 'unknown',
                'damage_severity':
                    'unknown', // VanImage doesn't have this property
                'damage_location': image.location ?? 'unknown',
                'van_damage': image.description ?? 'No description',
                'created_at': image.createdAt.toIso8601String(),
                'uploaded_by': image.uploadedBy ?? 'Unknown',
              })
          .toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedImageViewer(
            images: images,
            initialIndex: 0,
            title: 'Van #${van.plateNumber} Images',
          ),
        ),
      );
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(ModernPremiumTheme.spacingS),
      decoration: BoxDecoration(
        borderRadius: ModernPremiumTheme.smallRadius,
        color: ModernPremiumTheme.cosmicPurple.withOpacity(0.3),
        border: Border.all(
          color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: ModernPremiumTheme.primaryNeon,
            size: 20,
          ),
          const SizedBox(height: ModernPremiumTheme.spacingXS),
          Text(
            value,
            style: ModernPremiumTheme.modernBodyStyle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: ModernPremiumTheme.spacingXS),
          Text(
            label,
            style: ModernPremiumTheme.modernCaptionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isHighDamageVan(Van van) {
    // Simple logic to determine if van has high damage
    // In a real app, this would check actual damage data
    return van.status.toLowerCase() == 'maintenance' ||
        (van.mileage ?? 0) > 100000;
  }

  /// Get the daily status for a van based on selected date's image uploads
  String _getDailyStatus(Van van) {
    final selectedDate = _selectedDate;
    final dateStart =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    // Check if van has any images created on the selected date (using created_at)
    final hasDateImages = van.images.any((image) {
      // Convert image createdAt to local date for comparison
      final imageDate = DateTime(
        image.createdAt.year,
        image.createdAt.month,
        image.createdAt.day,
      );

      // Debug logging for first few vans
      if (van.plateNumber == '1' || van.plateNumber == '2') {
        print(
            '🔍 Van ${van.plateNumber}: Selected date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}');
        print(
            '🔍 Van ${van.plateNumber}: Image date: ${imageDate.day}/${imageDate.month}/${imageDate.year}');
        print('🔍 Van ${van.plateNumber}: Image createdAt: ${image.createdAt}');
        print(
            '🔍 Van ${van.plateNumber}: Date match: ${imageDate.isAtSameMomentAs(dateStart)}');
      }

      // Check if image date matches selected date
      return imageDate.isAtSameMomentAs(dateStart);
    });

    return hasDateImages ? 'active' : 'pending';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'maintenance':
        return Colors.orange;
      case 'out_of_service':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToVanDetail(BuildContext context, Van van) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VanProfileScreen(
          vanNumber: int.parse(van.plateNumber),
        ),
      ),
    );
  }

  Color _getDamageLevelColor(int level) {
    switch (level) {
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

  String _getDamageDescription(int level) {
    switch (level) {
      case 0:
        return 'No visible damage detected. Vehicle in excellent condition.';
      case 1:
        return 'Minor damage: Light scratches, dirt, or debris. Requires basic cleaning.';
      case 2:
        return 'Moderate damage: Visible scratches, scuffs, or minor dents. Requires attention.';
      case 3:
        return 'Major damage: Significant dents, broken parts, or structural issues. Immediate attention required.';
      default:
        return 'Damage level unknown.';
    }
  }

  IconData _getDamageLevelIcon(int level) {
    switch (level) {
      case 0:
        return Icons.check_circle;
      case 1:
        return Icons.info;
      case 2:
        return Icons.warning_amber_rounded;
      case 3:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  /// Check if van has any recently uploaded images that can be deleted
  Future<VanImage?> _getRecentlyUploadedDeletableImage(String vanNumber) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugPrint('🔍 DELETE BUTTON CHECK for Van #$vanNumber');
      debugPrint('🔍 Current user: ${currentUser?.email}');

      if (currentUser == null) {
        debugPrint('❌ No current user - delete button hidden');
        return null;
      }

      // Get recent images for this van uploaded by current user
      debugPrint(
          '🔍 Querying van_images for van_number=$vanNumber, uploaded_by=${currentUser.email}');
      final response = await Supabase.instance.client
          .from('van_images')
          .select('*')
          .eq('van_number', vanNumber)
          .eq('uploaded_by', currentUser.email!)
          .order('created_at', ascending: false)
          .limit(1);

      // Debug: Also try querying without user filter to see all images for this van
      final allImagesResponse = await Supabase.instance.client
          .from('van_images')
          .select('id, van_number, uploaded_by, created_at')
          .eq('van_number', vanNumber)
          .order('created_at', ascending: false)
          .limit(5);
      debugPrint(
          '🔍 All images for van $vanNumber: ${allImagesResponse.length} total');
      for (final img in allImagesResponse) {
        debugPrint(
            '🔍   - ${img['id']}: uploaded_by=${img['uploaded_by']}, created_at=${img['created_at']}');
      }

      debugPrint('🔍 Query response: ${response.length} images found');
      if (response.isEmpty) {
        debugPrint(
            '❌ No images found for this van/user - delete button hidden');
        return null;
      }

      final imageData = response.first;
      final vanImage = VanImage(
        id: imageData['id'],
        vanId: imageData['van_number']?.toString() ?? '',
        imageUrl: imageData['image_url'] ?? '',
        uploadedBy: imageData['uploaded_by'],
        driverName: imageData['driver_name'],
        damageType: imageData['damage_type'],
        damageLevel: imageData['van_rating'] ?? 0,
        location: imageData['damage_location'],
        vanSide: imageData['van_side'] ?? 'unknown',
        vanDamage: imageData['van_damage'],
        vanNumber: imageData['van_number']?.toString(),
        createdAt: imageData['created_at'] != null
            ? DateTime.parse(imageData['created_at']).toUtc()
            : DateTime.now().toUtc(),
        updatedAt: imageData['updated_at'] != null
            ? DateTime.parse(imageData['updated_at']).toUtc()
            : DateTime.now().toUtc(),
        uploadedAt: imageData['uploaded_at'] != null
            ? DateTime.parse(imageData['uploaded_at']).toUtc()
            : (imageData['created_at'] != null
                ? DateTime.parse(imageData['created_at']).toUtc()
                : DateTime.now().toUtc()),
      );

      debugPrint('🔍 Image found: ${imageData['id']}');
      debugPrint('🔍 Image created_at: ${imageData['created_at']}');
      debugPrint('🔍 Image uploaded_at: ${imageData['uploaded_at']}');
      debugPrint('🔍 Image uploaded_by: ${imageData['uploaded_by']}');

      final canDelete = vanImage.canBeDeleted;
      debugPrint('🔍 canBeDeleted: $canDelete');
      debugPrint(
          '🔍 remainingTime: ${vanImage.remainingDeletionTimeFormatted}');

      if (canDelete) {
        debugPrint('✅ DELETE BUTTON SHOULD BE VISIBLE for Van #$vanNumber');
        return vanImage;
      } else {
        debugPrint(
            '❌ DELETE BUTTON HIDDEN - outside 5-minute window for Van #$vanNumber');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error checking deletable images: $e');
      return null;
    }
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteImageDialog(VanImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ModernPremiumTheme.darkCharcoal,
        title: const Text(
          'Delete Van Image',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this van image?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernPremiumTheme.errorHotPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ModernPremiumTheme.errorHotPink.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: ModernPremiumTheme.errorHotPink,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time remaining: ${image.remainingDeletionTimeFormatted}',
                    style: TextStyle(
                      color: ModernPremiumTheme.errorHotPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Van #${image.vanNumber}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernPremiumTheme.errorHotPink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVanImage(image);
    }
  }

  /// Delete van image from database and storage
  Future<void> _deleteVanImage(VanImage image) async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: ModernPremiumTheme.primaryNeon,
            ),
          ),
        );
      }

      // Delete from database
      await Supabase.instance.client
          .from('van_images')
          .delete()
          .eq('id', image.id);

      // Check if this was the last image for this van
      if (image.vanNumber != null) {
        final remainingImages = await Supabase.instance.client
            .from('van_images')
            .select('id')
            .eq('van_number', image.vanNumber!);

        debugPrint(
            '🔍 Remaining images for van ${image.vanNumber}: ${remainingImages.length}');

        // If no images remain, delete the van profile to clean up
        if (remainingImages.isEmpty) {
          debugPrint(
              '🗑️ No images remaining for van ${image.vanNumber}, deleting van profile...');
          try {
            await Supabase.instance.client
                .from('van_profiles')
                .delete()
                .eq('van_number', image.vanNumber!);
            debugPrint('✅ Van profile deleted for van ${image.vanNumber}');
          } catch (vanDeleteError) {
            debugPrint('⚠️ Error deleting van profile: $vanDeleteError');
          }
        }
      }

      // Delete from storage if it's a storage URL (not base64 data)
      if (image.imageUrl.startsWith('https://')) {
        try {
          final fileName = image.imageUrl.split('/').last;
          await Supabase.instance.client.storage
              .from('van-images')
              .remove(['van_${image.vanNumber}/$fileName']);
        } catch (storageError) {
          debugPrint('⚠️ Storage deletion error (non-critical): $storageError');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Van image deleted successfully'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh van list
        final vanProvider = Provider.of<VanProvider>(context, listen: false);
        await vanProvider.refreshVans();
        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      debugPrint('❌ Error deleting van image: $e');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Van> _filteredVans(VanProvider vanProvider) {
    List<Van> filteredVans;

    // Apply status filter based on daily status
    if (_fleetOverviewFilter == null) {
      // Show only vans that were active on the selected date
      filteredVans = vanProvider.vans.where((van) {
        final dailyStatus = _getDailyStatus(van);
        return dailyStatus == 'active';
      }).toList();
    } else if (_fleetOverviewFilter == 'active') {
      filteredVans = vanProvider.vans.where((van) {
        final dailyStatus = _getDailyStatus(van);
        return dailyStatus == 'active';
      }).toList();
    } else if (_fleetOverviewFilter == 'pending') {
      filteredVans = vanProvider.vans.where((van) {
        final dailyStatus = _getDailyStatus(van);
        return dailyStatus == 'pending';
      }).toList();
    } else if (_fleetOverviewFilter == 'high_damage') {
      filteredVans = vanProvider.vans.where((van) {
        final maxDamageLevel = van.maxDamageLevel;
        return maxDamageLevel >= 2; // L2 or L3 damage
      }).toList();
    } else {
      filteredVans = vanProvider.vans;
    }

    // Apply sorting
    if (_sortOption == 'recent') {
      // Sort by most recent updates (based on latest image upload or van update)
      filteredVans.sort((a, b) {
        // Get the most recent image upload time for each van
        final aLatestImage = a.images.isNotEmpty
            ? a.images
                .map((img) => img.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bLatestImage = b.images.isNotEmpty
            ? b.images
                .map((img) => img.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.fromMillisecondsSinceEpoch(0);

        // Compare van update time (lastInspection or lastUpdated)
        final aVanUpdate = a.lastInspection ??
            a.lastUpdated ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bVanUpdate = b.lastInspection ??
            b.lastUpdated ??
            DateTime.fromMillisecondsSinceEpoch(0);

        // Use the most recent of either image upload or van update
        final aMostRecent =
            aLatestImage.isAfter(aVanUpdate) ? aLatestImage : aVanUpdate;
        final bMostRecent =
            bLatestImage.isAfter(bVanUpdate) ? bLatestImage : bVanUpdate;

        // Sort in descending order (most recent first)
        return bMostRecent.compareTo(aMostRecent);
      });
    } else if (_sortOption == 'chronological') {
      // Sort by van number (chronological order)
      filteredVans.sort((a, b) {
        final aNumber = int.tryParse(a.plateNumber) ?? 0;
        final bNumber = int.tryParse(b.plateNumber) ?? 0;
        return aNumber.compareTo(bNumber);
      });
    }

    return filteredVans;
  }

  List<Van> _filteredVansForDetailedView(VanProvider vanProvider) {
    List<Van> filteredVans;

    // Apply status filter based on database status (not daily status)
    if (_vanStatusFilter == null) {
      filteredVans = vanProvider.vans;
    } else if (_vanStatusFilter == 'active') {
      filteredVans = vanProvider.vans.where((van) {
        return van.status == 'active';
      }).toList();
    } else if (_vanStatusFilter == 'pending') {
      filteredVans = vanProvider.vans.where((van) {
        return van.status == 'pending';
      }).toList();
    } else if (_vanStatusFilter == 'high_damage') {
      filteredVans = vanProvider.vans.where((van) {
        final maxDamageLevel = van.maxDamageLevel;
        return maxDamageLevel >= 2; // L2 or L3 damage
      }).toList();
    } else {
      filteredVans = vanProvider.vans;
    }

    // Apply sorting
    if (_sortOption == 'recent') {
      // Sort by most recent updates (based on latest image upload or van update)
      filteredVans.sort((a, b) {
        // Get the most recent image upload time for each van
        final aLatestImage = a.images.isNotEmpty
            ? a.images
                .map((img) => img.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bLatestImage = b.images.isNotEmpty
            ? b.images
                .map((img) => img.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : DateTime.fromMillisecondsSinceEpoch(0);

        // Compare van update time (lastInspection or lastUpdated)
        final aVanUpdate = a.lastInspection ??
            a.lastUpdated ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bVanUpdate = b.lastInspection ??
            b.lastUpdated ??
            DateTime.fromMillisecondsSinceEpoch(0);

        // Use the most recent of either image upload or van update
        final aMostRecent =
            aLatestImage.isAfter(aVanUpdate) ? aLatestImage : aVanUpdate;
        final bMostRecent =
            bLatestImage.isAfter(bVanUpdate) ? bLatestImage : bVanUpdate;

        return bMostRecent.compareTo(aMostRecent);
      });
    } else if (_sortOption == 'damage') {
      // Sort by damage level (highest first)
      filteredVans.sort((a, b) => b.maxDamageLevel.compareTo(a.maxDamageLevel));
    } else if (_sortOption == 'plate') {
      // Sort by plate number
      filteredVans.sort((a, b) {
        final aNumber = int.tryParse(a.plateNumber) ?? 0;
        final bNumber = int.tryParse(b.plateNumber) ?? 0;
        return aNumber.compareTo(bNumber);
      });
    }

    return filteredVans;
  }
}
