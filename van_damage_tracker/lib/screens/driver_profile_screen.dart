import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/enhanced_driver_service.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../widgets/modern_premium_components.dart';
import '../widgets/modern_premium_background.dart';
import '../theme/modern_premium_theme.dart';
import 'van_profile_screen.dart';
import 'dart:convert';
import 'dart:math' as math;

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

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? driverProfile;
  List<Map<String, dynamic>> imagesByVan = [];
  bool isLoading = true;
  String? error;

  // Enhanced animation controllers for Apple-style interactions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _breathingController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _rotationController;
  late AnimationController _springController;
  late AnimationController _bounceController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _springAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDriverData();
  }

  void _initializeAnimations() {
    // Enhanced fade in animation with Apple-style easing
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    // Enhanced slide up animation with spring physics
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Enhanced scale animation with bounce
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    // Refined breathing animation
    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Enhanced shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Spring animation
    _springController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _springAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.elasticOut,
    ));

    // Bounce animation
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.bounceOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _breathingController.repeat(reverse: true);
    _shimmerController.repeat();
    _particleController.repeat();
    _rotationController.repeat();
  }

  // Helper function to format upload date
  String _formatUploadDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown date';

    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        } else {
          return '${difference.inHours}h ago';
        }
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _breathingController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _rotationController.dispose();
    _springController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      print(
          '🔄 Loading driver profile for: ${widget.driverName} (${widget.driverId})');

      // Load driver profile first (fast)
      final profile =
          await EnhancedDriverService.getDriverProfile(widget.driverId);

      if (profile == null) {
        throw Exception('Driver profile not found');
      }

      print('✅ Driver profile loaded successfully');

      // Load images in background (optional, can be slow)
      List<Map<String, dynamic>> images = [];
      try {
        print('🔄 Loading driver images (this may take a moment)...');
        // Try the fast method first
        images = await EnhancedDriverService.getDriverImagesByVanFast(
                widget.driverId)
            .timeout(const Duration(
                seconds: 5)); // Shorter timeout for faster loading
        print('✅ Driver images loaded: ${images.length} images');
      } catch (e) {
        print('⚠️ Warning: Could not load driver images: $e');
        // Continue without images - they're not critical for the profile
        images = [];
      }

      setState(() {
        driverProfile = profile;
        imagesByVan = images;
        isLoading = false;
      });

      print('✅ Driver profile screen loaded successfully');
    } catch (e) {
      print('❌ Error loading driver data: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Enhanced premium animated backdrop
        _buildEnhancedBackdrop(),

        // Main content with Apple-style design
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppleStyleAppBar(),
          body: isLoading
              ? _buildAppleStyleLoadingScreen()
              : error != null
                  ? _buildAppleStyleErrorScreen()
                  : _buildAppleStyleContent(),
        ),
      ],
    );
  }

  Widget _buildEnhancedBackdrop() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0F),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
                Color(0xFF533483),
                Color(0xFF8B5CF6),
                Color(0xFF6366F1),
                Color(0xFF3B82F6),
                Color(0xFF0EA5E9),
                Color(0xFF06B6D4),
              ],
              stops: [
                0.0,
                0.1,
                0.2,
                0.3,
                0.4,
                0.5,
                0.6,
                0.7,
                0.8,
                1.0,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Enhanced geometric patterns
              _buildEnhancedGeometricPatterns(),

              // Refined floating particles
              _buildRefinedFloatingParticles(),

              // Enhanced gradient overlays
              _buildEnhancedGradientOverlays(),

              // Subtle noise texture
              _buildNoiseTexture(),

              // Enhanced light rays
              _buildEnhancedLightRays(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedGeometricPatterns() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: EnhancedGeometricPatternPainter(
            animation: _rotationAnimation,
            particleAnimation: _particleAnimation,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildRefinedFloatingParticles() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(30, (index) {
            final progress = (_particleAnimation.value + index * 0.03) % 1.0;
            final x = (index * 47.3) % MediaQuery.of(context).size.width;
            final y = (progress * MediaQuery.of(context).size.height * 2.5) -
                MediaQuery.of(context).size.height;

            return Positioned(
              left: x,
              top: y,
              child: Transform.scale(
                scale: 0.6 + 0.4 * math.sin(progress * 2 * math.pi),
                child: Container(
                  width: 3 + (index % 4) * 1.5,
                  height: 3 + (index % 4) * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ModernPremiumTheme.primaryNeon.withOpacity(0.6),
                        ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEnhancedGradientOverlays() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-left gradient
            Positioned(
              top: -120,
              left: -120,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.primaryNeon
                          .withOpacity(0.08 * _breathingAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom-right gradient
            Positioned(
              bottom: -120,
              right: -120,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.secondaryElectric
                          .withOpacity(0.06 * _breathingAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Center gradient
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: MediaQuery.of(context).size.width * 0.15,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.accentHotPink
                          .withOpacity(0.04 * _breathingAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoiseTexture() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.02,
          child: CustomPaint(
            painter: NoiseTexturePainter(
              animation: _shimmerAnimation,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildEnhancedLightRays() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: EnhancedLightRaysPainter(
            animation: _rotationAnimation,
            breathingAnimation: _breathingAnimation,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppleStyleAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              ModernPremiumTheme.primaryNeon.withOpacity(0.15),
              ModernPremiumTheme.secondaryElectric.withOpacity(0.15),
            ],
          ),
          border: Border.all(
            color: ModernPremiumTheme.primaryNeon.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ModernPremiumTheme.primaryNeon.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: IconButton(
          icon: AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: ModernPremiumTheme.textDiamond,
                  size: 22,
                ),
              );
            },
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👨‍💼 ${widget.driverName}',
                  style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Driver Profile',
                  style: ModernPremiumTheme.modernBodyStyle.copyWith(
                    fontSize: 14,
                    color: ModernPremiumTheme.textDiamond.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: ModernPremiumTheme.neonGradient,
            boxShadow: [
              BoxShadow(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _loadDriverData,
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          Colors.transparent,
                          ModernPremiumTheme.textDiamond.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: [
                          _shimmerAnimation.value - 0.3,
                          _shimmerAnimation.value,
                          _shimmerAnimation.value + 0.3,
                        ],
                      ).createShader(bounds);
                    },
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: ModernPremiumTheme.textDiamond,
                      size: 26,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleStyleLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ModernPremiumTheme.neonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: ModernPremiumTheme.textDiamond,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Loading Profile...',
                  style: ModernPremiumTheme.modernBodyStyle.copyWith(
                    fontSize: 18,
                    color: ModernPremiumTheme.textDiamond.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppleStyleErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  ModernPremiumTheme.errorHotPink.withOpacity(0.2),
                  ModernPremiumTheme.warningSunset.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: ModernPremiumTheme.errorHotPink.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: ModernPremiumTheme.errorHotPink,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error Loading Profile',
            style: ModernPremiumTheme.neonHeadingStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: ModernPremiumTheme.errorHotPink,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error ?? 'Unknown error occurred',
              style: ModernPremiumTheme.modernBodyStyle.copyWith(
                fontSize: 16,
                color: ModernPremiumTheme.textDiamond.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: ModernPremiumTheme.neonGradient,
              boxShadow: [
                BoxShadow(
                  color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _loadDriverData,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: ModernPremiumTheme.textDiamond,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleStyleContent() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Enhanced driver info card
                _buildEnhancedDriverInfoCard(),

                const SizedBox(height: 24),

                // Enhanced stats card
                _buildEnhancedStatsCard(),

                const SizedBox(height: 24),

                // Enhanced alerts section
                _buildEnhancedAlertsSection(),

                const SizedBox(height: 24),

                // Enhanced images section
                _buildEnhancedImagesSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedDriverInfoCard() {
    if (driverProfile == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.9),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _breathingAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _breathingAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ModernPremiumTheme.neonGradient,
                            boxShadow: [
                              BoxShadow(
                                color: ModernPremiumTheme.primaryNeon
                                    .withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (driverProfile!['driver_name']?.toString() ??
                                      'U')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: ModernPremiumTheme.textDiamond,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverProfile!['driver_name']?.toString() ??
                              'Unknown Driver',
                          style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (driverProfile!['slack_real_name'] != null)
                          _buildEnhancedInfoRow(
                            Icons.person_outline_rounded,
                            'Slack: ${driverProfile!['slack_real_name']}',
                          ),
                        if (driverProfile!['phone'] != null)
                          _buildEnhancedInfoRow(
                            Icons.phone_outlined,
                            'Phone: ${driverProfile!['phone']}',
                          ),
                        if (driverProfile!['email'] != null)
                          _buildEnhancedInfoRow(
                            Icons.email_outlined,
                            'Email: ${driverProfile!['email']}',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  ModernPremiumTheme.primaryNeon.withOpacity(0.15),
                  ModernPremiumTheme.secondaryElectric.withOpacity(0.15),
                ],
              ),
              border: Border.all(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: ModernPremiumTheme.primaryNeon,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: ModernPremiumTheme.modernBodyStyle.copyWith(
                color: ModernPremiumTheme.textDiamond.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatsCard() {
    final totalUploads = driverProfile!['total_uploads'] ?? 0;
    final memberSince = driverProfile!['created_at'] != null
        ? DateTime.tryParse(driverProfile!['created_at'].toString())
        : null;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.9),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: ModernPremiumTheme.neonGradient,
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: ModernPremiumTheme.textDiamond,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        '📊 Upload Statistics',
                        style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEnhancedStatItem(
                        'Total Uploads',
                        totalUploads.toString(),
                        Icons.upload_outlined,
                        ModernPremiumTheme.primaryNeon,
                      ),
                      _buildEnhancedStatItem(
                        'Vans Photographed',
                        imagesByVan.length.toString(),
                        Icons.local_shipping_outlined,
                        ModernPremiumTheme.secondaryElectric,
                      ),
                      if (memberSince != null)
                        _buildEnhancedStatItem(
                          'Member Since',
                          '${memberSince.month}/${memberSince.year}',
                          Icons.calendar_today_outlined,
                          ModernPremiumTheme.accentHotPink,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedStatItem(
      String label, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingAnimation.value,
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: ModernPremiumTheme.modernBodyStyle.copyWith(
                  fontSize: 14,
                  color: ModernPremiumTheme.textDiamond.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedAlertsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getDriverAlerts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: ModernPremiumCard(
                  enableGlass: true,
                  enableNeonEffect: true,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: ModernPremiumTheme.primaryNeon,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        final alertVans = snapshot.data ?? [];
        final hasAlerts = alertVans.isNotEmpty;

        print('🔍 Driver Profile - alertVans: $alertVans');
        print('🔍 Driver Profile - hasAlerts: $hasAlerts');
        print('🔍 Driver Profile - alertVans.length: ${alertVans.length}');

        return AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: ModernPremiumCard(
                enableGlass: true,
                enableNeonEffect: hasAlerts,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasAlerts
                          ? [
                              ModernPremiumTheme.errorHotPink.withOpacity(0.1),
                              ModernPremiumTheme.warningSunset.withOpacity(0.1),
                            ]
                          : [
                              ModernPremiumTheme.deepSpace.withOpacity(0.9),
                              ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                            ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: hasAlerts
                                ? _breathingAnimation
                                : _fadeAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale:
                                    hasAlerts ? _breathingAnimation.value : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: hasAlerts
                                        ? LinearGradient(
                                            colors: [
                                              ModernPremiumTheme.errorHotPink
                                                  .withOpacity(0.3),
                                              ModernPremiumTheme.warningSunset
                                                  .withOpacity(0.3),
                                            ],
                                          )
                                        : ModernPremiumTheme.neonGradient,
                                  ),
                                  child: Icon(
                                    Icons.warning_rounded,
                                    color: hasAlerts
                                        ? ModernPremiumTheme.errorHotPink
                                        : ModernPremiumTheme.textDiamond,
                                    size: 28,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          Text(
                            '🚨 Damage Alerts',
                            style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: hasAlerts
                                  ? ModernPremiumTheme.errorHotPink
                                  : ModernPremiumTheme.textDiamond,
                            ),
                          ),
                          if (hasAlerts) ...[
                            const SizedBox(width: 16),
                            AnimatedBuilder(
                              animation: _breathingAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _breathingAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          ModernPremiumTheme.errorHotPink,
                                          ModernPremiumTheme.warningSunset,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ModernPremiumTheme.errorHotPink
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${alertVans.length}',
                                      style: const TextStyle(
                                        color: ModernPremiumTheme.textDiamond,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (hasAlerts) ...[
                        Text(
                          'Vans with alerts that this driver has reported damage for:',
                          style: ModernPremiumTheme.modernBodyStyle.copyWith(
                            fontSize: 15,
                            color: ModernPremiumTheme.textDiamond
                                .withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...alertVans.map((van) {
                          print('🔍 Building alert item for van: $van');
                          return _buildEnhancedAlertItem(van);
                        }),
                      ] else ...[
                        Text(
                          'No damage alerts for this driver.',
                          style: ModernPremiumTheme.modernBodyStyle.copyWith(
                            fontSize: 15,
                            color:
                                ModernPremiumTheme.textDiamond.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getDamageDescription(Map<String, dynamic> van) {
    // First try to get the alert message from van_profiles
    if (van['alert_message'] != null &&
        van['alert_message'].toString().isNotEmpty) {
      return van['alert_message'].toString();
    }

    // Then try to get the actual damage description
    if (van['van_damage'] != null && van['van_damage'].toString().isNotEmpty) {
      return van['van_damage'].toString();
    }

    // If no description, try to create one based on severity
    if (van['damage_severity'] != null) {
      final severity = van['damage_severity'].toString().toLowerCase();
      switch (severity) {
        case 'low':
        case '1':
          return 'Minor damage detected';
        case 'medium':
        case '2':
          return 'Moderate damage detected';
        case 'high':
        case '3':
          return 'Major damage detected';
        default:
          return 'Damage severity: $severity';
      }
    }

    // If no severity, try to create one based on rating
    if (van['van_rating'] != null) {
      final rating = int.tryParse(van['van_rating'].toString()) ?? 0;
      if (rating > 0) {
        switch (rating) {
          case 1:
            return 'Minor damage detected';
          case 2:
            return 'Moderate damage detected';
          case 3:
            return 'Major damage detected';
          default:
            return 'Damage rating: $rating';
        }
      }
    }

    return 'Damage reported';
  }

  Future<List<Map<String, dynamic>>> _getDriverAlerts() async {
    try {
      print('🔍 Fetching damage alerts for driver: ${widget.driverName}');

      // Step 1: Get all vans with alerts from van_profiles table
      final vansWithAlerts = await Supabase.instance.client
          .from('van_profiles')
          .select('van_number, alerts, status')
          .not('alerts', 'is', null)
          .not('alerts', 'eq', '');

      print('📊 Vans with alerts from van_profiles: $vansWithAlerts');

      if (vansWithAlerts == null || vansWithAlerts.isEmpty) {
        print('ℹ️ No vans with alerts found in van_profiles table');
        return [];
      }

      // Step 2: Get van images uploaded by this driver
      final driverImages = await Supabase.instance.client
          .from('van_images')
          .select('''
            van_number,
            van_damage,
            damage_severity,
            damage_type,
            damage_location,
            van_rating,
            uploaded_by,
            created_at
          ''')
          .eq('uploaded_by', widget.driverName)
          .order('created_at', ascending: false);

      print('📊 Van images uploaded by ${widget.driverName}: $driverImages');

      // Step 3: Match vans with alerts to driver's van images
      final List<Map<String, dynamic>> matchedAlerts = [];

      for (final vanWithAlert in vansWithAlerts) {
        final vanNumber = vanWithAlert['van_number']?.toString();
        if (vanNumber != null) {
          // Find van images for this van uploaded by the driver
          final vanImages = driverImages
              .where((image) => image['van_number']?.toString() == vanNumber)
              .toList();

          if (vanImages.isNotEmpty) {
            // Get the most recent image for this van
            final latestImage = vanImages.reduce((a, b) {
              final aDate = DateTime.parse(a['created_at']);
              final bDate = DateTime.parse(b['created_at']);
              return aDate.isAfter(bDate) ? a : b;
            });

            // Create alert entry with van profile alert info and image details
            final alertEntry = {
              'van_number': vanNumber,
              'van_damage': latestImage['van_damage'],
              'damage_severity': latestImage['damage_severity'],
              'damage_type': latestImage['damage_type'],
              'damage_location': latestImage['damage_location'],
              'van_rating': latestImage['van_rating'],
              'uploaded_by': latestImage['uploaded_by'],
              'created_at': latestImage['created_at'],
              'alert_message': vanWithAlert['alerts'],
              'van_status': vanWithAlert['status'],
            };

            matchedAlerts.add(alertEntry);
          }
        }
      }

      print(
          '✅ Found ${matchedAlerts.length} matched alerts for ${widget.driverName}');
      return matchedAlerts;
    } catch (e) {
      print('❌ Error fetching driver alerts: $e');
      return [];
    }
  }

  Widget _buildEnhancedAlertItem(Map<String, dynamic> van) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingAnimation.value,
          child: GestureDetector(
            onTap: () {
              final vanNumber = van['van_number'];
              if (vanNumber != null) {
                // Convert string to int for VanProfileScreen
                final vanNumberInt = int.tryParse(vanNumber.toString());
                if (vanNumberInt != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VanProfileScreen(vanNumber: vanNumberInt),
                    ),
                  );
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    ModernPremiumTheme.errorHotPink.withOpacity(0.1),
                    ModernPremiumTheme.warningSunset.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: ModernPremiumTheme.errorHotPink.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ModernPremiumTheme.errorHotPink.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.errorHotPink.withOpacity(0.3),
                          ModernPremiumTheme.warningSunset.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: ModernPremiumTheme.textDiamond,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Van #${van['van_number']}',
                          style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Alert: ${_getDamageDescription(van)}',
                          style: ModernPremiumTheme.modernBodyStyle.copyWith(
                            fontSize: 14,
                            color:
                                ModernPremiumTheme.textDiamond.withOpacity(0.7),
                          ),
                        ),
                        if (van['van_status'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${van['van_status']}',
                            style: ModernPremiumTheme.modernBodyStyle.copyWith(
                              fontSize: 12,
                              color: ModernPremiumTheme.textDiamond
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                        if (van['damage_severity'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Severity: ${van['damage_severity']}',
                            style: ModernPremiumTheme.modernBodyStyle.copyWith(
                              fontSize: 12,
                              color: ModernPremiumTheme.textDiamond
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.errorHotPink,
                          ModernPremiumTheme.warningSunset,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ModernPremiumTheme.errorHotPink.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      'ALERT',
                      style: TextStyle(
                        color: ModernPremiumTheme.textDiamond,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: ModernPremiumTheme.errorHotPink,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedImagesSection() {
    if (imagesByVan.isEmpty) {
      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ModernPremiumCard(
              enableGlass: true,
              enableNeonEffect: true,
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernPremiumTheme.deepSpace.withOpacity(0.9),
                      ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _breathingAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _breathingAnimation.value,
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              size: 72,
                              color: ModernPremiumTheme.textDiamond
                                  .withOpacity(0.6),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No images uploaded yet',
                        style: ModernPremiumTheme.modernBodyStyle.copyWith(
                          fontSize: 18,
                          color:
                              ModernPremiumTheme.textDiamond.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Group images by van number
    Map<int, List<Map<String, dynamic>>> groupedImages = {};
    for (final image in imagesByVan) {
      final vanNumber = image['van_number'] as int?;
      if (vanNumber != null) {
        if (!groupedImages.containsKey(vanNumber)) {
          groupedImages[vanNumber] = [];
        }
        groupedImages[vanNumber]!.add(image);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: ModernPremiumTheme.neonGradient,
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: ModernPremiumTheme.textDiamond,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              '🚐 Images by Van',
              style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...groupedImages.entries.map((entry) => _buildEnhancedVanImageGroup(
              vanNumber: entry.key,
              images: entry.value,
            )),
      ],
    );
  }

  Widget _buildEnhancedVanImageGroup({
    required int vanNumber,
    required List<Map<String, dynamic>> images,
  }) {
    // Get van details from the first image
    final firstImage = images.first;
    final vanProfile = firstImage['van_profiles'] as Map<String, dynamic>?;
    final vanMake = vanProfile?['make']?.toString() ?? 'Unknown';
    final vanModel = vanProfile?['model']?.toString() ?? 'Unknown';
    final vanDisplayName = '$vanMake $vanModel (#$vanNumber)';
    final imageCount = images.length;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            margin: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.9),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          vanDisplayName,
                          style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: ModernPremiumTheme.neonGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: ModernPremiumTheme.primaryNeon
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          '$imageCount images',
                          style: const TextStyle(
                            color: ModernPremiumTheme.textDiamond,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      AnimatedBuilder(
                        animation: _breathingAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _breathingAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: ModernPremiumTheme.neonGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: ModernPremiumTheme.primaryNeon
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () => _navigateToVanProfile(vanNumber),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: ModernPremiumTheme.textDiamond,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length > 5 ? 5 : images.length,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildEnhancedImageWidget(image),
                          ),
                        );
                      },
                    ),
                  ),
                  if (images.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        '+ ${images.length - 5} more images',
                        style: ModernPremiumTheme.modernBodyStyle.copyWith(
                          color:
                              ModernPremiumTheme.textDiamond.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();
    String? imageUrl = image['image_url']?.toString();

    debugPrint('🖼️ Building enhanced image widget:');
    debugPrint('  - image_data length: ${imageData?.length ?? 0}');
    debugPrint('  - image_url: ${imageUrl?.substring(0, 100) ?? 'null'}...');
    debugPrint('  - van_rating: ${image['van_rating']}');
    debugPrint('  - van_side: ${image['van_side']}');

    // Try image_data first (base64 encoded)
    if (imageData != null && imageData.isNotEmpty) {
      try {
        final bytes = base64Decode(imageData);
        debugPrint('  ✅ Successfully decoded image data');

        return GestureDetector(
          onTap: () => _showImageDetail(image),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('  ❌ Error displaying image: $error');
                      return _buildImageErrorContainer();
                    },
                  ),
                  // Rating badge (L0, L1, L2, L3) - top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ModernPremiumTheme.primaryNeon,
                            ModernPremiumTheme.secondaryElectric,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        'L${image['van_rating'] ?? image['damage_level'] ?? '0'}',
                        style: const TextStyle(
                          color: ModernPremiumTheme.textDiamond,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Van side overlay - bottom left
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ModernPremiumTheme.deepSpace.withOpacity(0.8),
                            ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ModernPremiumTheme.textDiamond.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getVanSideIcon(
                                image['van_side']?.toString() ?? 'unknown'),
                            size: 14,
                            color: ModernPremiumTheme.textDiamond,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (image['van_side']?.toString() ?? 'unknown')
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: ModernPremiumTheme.textDiamond,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Upload date overlay - bottom right
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ModernPremiumTheme.deepSpace.withOpacity(0.9),
                            ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                ModernPremiumTheme.textDiamond.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        _formatUploadDate(image['uploaded_at']),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: ModernPremiumTheme.textDiamond,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('  ❌ Error decoding image data: $e');
        return Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ModernPremiumTheme.deepSpace.withOpacity(0.9),
                ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_rounded,
                    color: ModernPremiumTheme.textDiamond),
                Text('No image', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      debugPrint('  🔗 Loading image from URL: $imageUrl');

      return GestureDetector(
        onTap: () => _showImageDetail(image),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ModernPremiumTheme.deepSpace.withOpacity(0.9),
                            ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: ModernPremiumTheme.primaryNeon,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('  ❌ Error loading image from URL: $error');
                    return _buildImageErrorContainer();
                  },
                ),
                // Rating badge (L0, L1, L2, L3) - top right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.primaryNeon,
                          ModernPremiumTheme.secondaryElectric,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      'L${image['van_rating'] ?? image['damage_level'] ?? '0'}',
                      style: const TextStyle(
                        color: ModernPremiumTheme.textDiamond,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Van side overlay - bottom left
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.deepSpace.withOpacity(0.8),
                          ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ModernPremiumTheme.textDiamond.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getVanSideIcon(
                              image['van_side']?.toString() ?? 'unknown'),
                          size: 14,
                          color: ModernPremiumTheme.textDiamond,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (image['van_side']?.toString() ?? 'unknown')
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ModernPremiumTheme.textDiamond,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Upload date overlay - bottom right
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ModernPremiumTheme.deepSpace.withOpacity(0.9),
                          ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ModernPremiumTheme.textDiamond.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      _formatUploadDate(image['uploaded_at']),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: ModernPremiumTheme.textDiamond,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      debugPrint('  ⚠️ No image data or URL found');
      return _buildImageErrorContainer();
    }
  }

  IconData _getVanSideIcon(String vanSide) {
    switch (vanSide.toLowerCase()) {
      case 'front':
        return Icons.directions_car_filled;
      case 'back':
        return Icons.directions_car_filled;
      case 'left':
        return Icons.directions_car_filled;
      case 'right':
        return Icons.directions_car_filled;
      case 'interior':
        return Icons.airline_seat_recline_normal;
      default:
        return Icons.directions_car_filled;
    }
  }

  void _navigateToVanProfile(int vanNumber) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VanProfileScreen(vanNumber: vanNumber),
      ),
    );
  }

  void _showImageDetail(Map<String, dynamic> image) {
    // Find all images for this van group
    final vanNumber = image['van_number'] as int?;
    List<Map<String, dynamic>> vanImages = [];
    int selectedIndex = 0;

    // Find the van group that contains this image
    for (final vanGroup in imagesByVan) {
      if (vanGroup['van_number'] == vanNumber) {
        vanImages = List<Map<String, dynamic>>.from(vanGroup['images'] ?? []);
        // Find the index of the selected image
        selectedIndex = vanImages.indexWhere((img) => img['id'] == image['id']);
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

  Widget _buildImageErrorContainer() {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ModernPremiumTheme.deepSpace.withOpacity(0.9),
            ModernPremiumTheme.cosmicPurple.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_rounded,
                color: ModernPremiumTheme.textDiamond),
            Text('No image', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Enhanced Custom Painters for the backdrop
class EnhancedGeometricPatternPainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> particleAnimation;

  EnhancedGeometricPatternPainter({
    required this.animation,
    required this.particleAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernPremiumTheme.primaryNeon.withOpacity(0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.3;

    // Draw geometric patterns
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + animation.value * math.pi * 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      canvas.drawCircle(
        Offset(x, y),
        20 + 10 * math.sin(particleAnimation.value * math.pi * 2 + i),
        paint,
      );
    }

    // Draw connecting lines
    for (int i = 0; i < 8; i++) {
      final angle1 = (i * math.pi / 4) + animation.value * math.pi * 2;
      final angle2 = ((i + 2) * math.pi / 4) + animation.value * math.pi * 2;

      final x1 = center.dx + math.cos(angle1) * radius;
      final y1 = center.dy + math.sin(angle1) * radius;
      final x2 = center.dx + math.cos(angle2) * radius;
      final y2 = center.dy + math.sin(angle2) * radius;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NoiseTexturePainter extends CustomPainter {
  final Animation<double> animation;

  NoiseTexturePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernPremiumTheme.textDiamond.withOpacity(0.08)
      ..strokeWidth = 0.5;

    final random = math.Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < 1000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.3;

      paint.color = ModernPremiumTheme.textDiamond.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class EnhancedLightRaysPainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> breathingAnimation;

  EnhancedLightRaysPainter({
    required this.animation,
    required this.breathingAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ModernPremiumTheme.primaryNeon
              .withOpacity(0.05 * breathingAnimation.value),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.8;

    // Draw light rays
    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi / 6) + animation.value * math.pi * 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(x, y);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
