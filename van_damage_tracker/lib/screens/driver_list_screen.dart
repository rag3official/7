import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/driver_provider.dart';
import '../models/driver_profile.dart';
import '../widgets/modern_premium_components.dart';
import '../widgets/modern_premium_background.dart';
import '../widgets/premium_apple_loading.dart';
import '../theme/modern_premium_theme.dart';
import 'driver_profile_screen.dart';

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  String? _driverStatusFilter; // Add this line

  @override
  Widget build(BuildContext context) {
    return ModernPremiumBackground(
      enableAnimatedGradient: true, // Enable only gradient animation
      enableParticleEffect:
          true, // Enable minimal particles (should be optimized)
      enableGridPattern: false, // Keep disabled for performance
      enableFloatingElements: false, // Keep disabled for performance
      enableMorphingShapes: false, // Keep disabled for performance
      enableEnergyWaves: false, // Keep disabled for performance
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<DriverProvider>(
          builder: (context, driverProvider, child) {
            if (driverProvider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppleStyleActivityIndicator(
                      size: 80,
                      color: ModernPremiumTheme.primaryNeon,
                      showLabel: true,
                      label: 'Loading Drivers...',
                    ),
                    SizedBox(height: ModernPremiumTheme.spacingM),
                    PremiumPulseLoader(
                      size: 60,
                      color: ModernPremiumTheme.secondaryElectric,
                    ),
                  ],
                ),
              );
            }

            if (driverProvider.drivers.isEmpty) {
              return Center(
                child: ModernPremiumCard(
                  enableGlass: true,
                  enableNeonEffect: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: ModernPremiumTheme.textPlatinum,
                      ),
                      const SizedBox(height: ModernPremiumTheme.spacingL),
                      Text(
                        'No Drivers Available',
                        style: ModernPremiumTheme.neonHeadingStyle,
                      ),
                      const SizedBox(height: ModernPremiumTheme.spacingM),
                      Text(
                        'Add some drivers to get started',
                        style: ModernPremiumTheme.neonBodyStyle,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(ModernPremiumTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with stats
                  ModernPremiumCard(
                    enableGlass: true,
                    enableNeonEffect: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Drivers',
                            driverProvider.drivers.length.toString(),
                            Icons.people,
                            ModernPremiumTheme.primaryNeon,
                            onTap: () {
                              setState(() {
                                _driverStatusFilter = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: ModernPremiumTheme.spacingM),
                        Expanded(
                          child: _buildStatCard(
                            'Active',
                            driverProvider.drivers
                                .where((driver) =>
                                    driver.status.toLowerCase() == 'active')
                                .length
                                .toString(),
                            Icons.check_circle,
                            ModernPremiumTheme.successElectric,
                            onTap: () {
                              setState(() {
                                _driverStatusFilter = 'active';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: ModernPremiumTheme.spacingM),
                        Expanded(
                          child: _buildStatCard(
                            'Inactive',
                            driverProvider.drivers
                                .where((driver) =>
                                    driver.status.toLowerCase() == 'inactive')
                                .length
                                .toString(),
                            Icons.person_off,
                            ModernPremiumTheme.errorHotPink,
                            onTap: () {
                              setState(() {
                                _driverStatusFilter = 'inactive';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ModernPremiumTheme.spacingL),

                  // Driver list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await context.read<DriverProvider>().refreshDrivers();
                      },
                      backgroundColor: ModernPremiumTheme.darkCharcoal,
                      color: ModernPremiumTheme.primaryNeon,
                      child: ListView.builder(
                        itemCount: _filteredDrivers(driverProvider).length,
                        itemBuilder: (context, index) {
                          final driver =
                              _filteredDrivers(driverProvider)[index];
                          return _buildDriverCard(driver, index);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<DriverProfile> _filteredDrivers(DriverProvider driverProvider) {
    if (_driverStatusFilter == null) {
      return driverProvider.drivers;
    }
    return driverProvider.drivers
        .where((driver) => driver.status.toLowerCase() == _driverStatusFilter)
        .toList();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(ModernPremiumTheme.spacingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: ModernPremiumTheme.spacingS),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: ModernPremiumTheme.spacingXS),
            Text(
              title,
              style: ModernPremiumTheme.modernCaptionStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(DriverProfile driver, int index) {
    final isActive = driver.status.toLowerCase() == 'active';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToDriverDetail(driver),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ModernPremiumTheme.darkCharcoal.withOpacity(0.9),
                ModernPremiumTheme.darkCharcoal.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? ModernPremiumTheme.primaryNeon.withOpacity(0.5)
                  : ModernPremiumTheme.secondaryElectric.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive
                              ? [
                                  ModernPremiumTheme.primaryNeon,
                                  ModernPremiumTheme.secondaryElectric
                                ]
                              : [
                                  ModernPremiumTheme.darkCharcoal,
                                  ModernPremiumTheme.darkCharcoal
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.driverName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${driver.id}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        driver.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: ModernPremiumTheme.primaryNeon,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${driver.certifications.length} certs',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: ModernPremiumTheme.primaryNeon.withOpacity(0.7),
                      size: 16,
                    ),
                  ],
                ),
              ],
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

  void _navigateToDriverDetail(DriverProfile driver) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverProfileScreen(
          driverId: driver.id,
          driverName: driver.driverName,
        ),
      ),
    );
  }
}
