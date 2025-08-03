import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
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

  String? _vanStatusFilter;
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _shrinkController.dispose();
    _breathingController.dispose();
    _scrollController.dispose();
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
              return Center(
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
                      const SizedBox(height: ModernPremiumTheme.spacingL),
                      Text(
                        'No Vans Available',
                        style: ModernPremiumTheme.neonHeadingStyle,
                      ),
                      const SizedBox(height: ModernPremiumTheme.spacingM),
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
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _filteredVans(vanProvider).length,
                                itemBuilder: (context, index) {
                                  final van = _filteredVans(vanProvider)[index];
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
            // Title section
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
                        child: Text(
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
                            final status = van.status.toLowerCase();
                            final maxDamageLevel = van.maxDamageLevel;
                            // Count vans that are active AND have no damage
                            final isActive =
                                (status == 'active' || status == 'available') &&
                                    maxDamageLevel == 0; // No damage

                            // Debug logging
                            if (isActive) {
                              print(
                                  '✅ Active van: ${van.plateNumber} - status: $status, damage: $maxDamageLevel');
                            }

                            return isActive;
                          }).toList();

                          print(
                              '📊 Fleet Overview - Active Vans: ${activeVans.length}');

                          return activeVans.length.toString();
                        }(),
                        Icons.check_circle,
                        ModernPremiumTheme.successElectric,
                        progress,
                        onTap: () {
                          setState(() {
                            _vanStatusFilter = 'active';
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
                          final maintenanceVans = vanProvider.vans.where((van) {
                            final status = van.status.toLowerCase();
                            final maxDamageLevel = van.maxDamageLevel;
                            // Count vans that need maintenance OR have moderate damage
                            final needsMaintenance = status == 'maintenance' ||
                                status == 'repair' ||
                                maxDamageLevel == 1; // L1 damage

                            // Debug logging
                            if (needsMaintenance) {
                              print(
                                  '🔧 Maintenance van: ${van.plateNumber} - status: $status, damage: $maxDamageLevel');
                            }

                            return needsMaintenance;
                          }).toList();

                          print(
                              '📊 Fleet Overview - Maintenance Vans: ${maintenanceVans.length}');

                          return maintenanceVans.length.toString();
                        }(),
                        Icons.build,
                        ModernPremiumTheme.warningSunset,
                        progress,
                        onTap: () {
                          setState(() {
                            _vanStatusFilter = 'maintenance';
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
                          final outOfServiceVans =
                              vanProvider.vans.where((van) {
                            final maxDamageLevel = van.maxDamageLevel;
                            final status = van.status.toLowerCase();
                            // Count vans that are out of service OR have high damage
                            final isOutOfService = status == 'out_of_service' ||
                                status == 'out of service' ||
                                status == 'inactive' ||
                                maxDamageLevel >= 2;

                            // Debug logging
                            if (isOutOfService) {
                              print(
                                  '🚨 Out of service van: ${van.plateNumber} - status: $status, damage: $maxDamageLevel');
                            }

                            return isOutOfService;
                          }).toList();

                          print(
                              '📊 Fleet Overview - Out of Service Vans: ${outOfServiceVans.length}');
                          print('📊 Total vans: ${vanProvider.vans.length}');
                          print(
                              '📊 Van statuses: ${vanProvider.vans.map((v) => '${v.plateNumber}:${v.status}').join(', ')}');
                          print(
                              '📊 Van damage levels: ${vanProvider.vans.map((v) => '${v.plateNumber}:${v.maxDamageLevel}').join(', ')}');

                          return outOfServiceVans.length.toString();
                        }(),
                        Icons.warning_amber_rounded,
                        Colors.red[400]!,
                        progress,
                        onTap: () {
                          setState(() {
                            _vanStatusFilter = 'out_of_service';
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
          borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ModernPremiumTheme.primaryNeon.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
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
                              child: Icon(
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
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    van.model,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge with enhanced styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(van.status).withOpacity(0.8),
                              _getStatusColor(van.status).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(van.status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          van.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

                  // Enhanced Damage Level Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Damage Level with Icon
                      Row(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                                  color: _getDamageLevelColor(maxDamageLevel),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(van.status).withOpacity(0.8),
                              _getStatusColor(van.status).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(van.status).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          van.status.toUpperCase(),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
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

  List<Van> _filteredVans(VanProvider vanProvider) {
    if (_vanStatusFilter == null) return vanProvider.vans;
    if (_vanStatusFilter == 'active') {
      return vanProvider.vans.where((van) {
        final status = van.status.toLowerCase();
        final maxDamageLevel = van.maxDamageLevel;
        return (status == 'active' || status == 'available') &&
            maxDamageLevel == 0; // No damage
      }).toList();
    }
    if (_vanStatusFilter == 'maintenance') {
      return vanProvider.vans.where((van) {
        final status = van.status.toLowerCase();
        final maxDamageLevel = van.maxDamageLevel;
        return status == 'maintenance' ||
            status == 'repair' ||
            maxDamageLevel == 1; // L1 damage
      }).toList();
    }
    if (_vanStatusFilter == 'out_of_service') {
      return vanProvider.vans.where((van) {
        final status = van.status.toLowerCase();
        final maxDamageLevel = van.maxDamageLevel;
        return status == 'out_of_service' ||
            status == 'out of service' ||
            status == 'inactive' ||
            maxDamageLevel >= 2; // L2 or L3 damage
      }).toList();
    }
    return vanProvider.vans;
  }
}
