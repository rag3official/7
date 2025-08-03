import 'package:flutter/material.dart';
import '../services/enhanced_driver_service.dart';
import '../widgets/enhanced_image_viewer.dart';
import '../widgets/van_status_dialog.dart';
import '../widgets/modern_premium_components.dart';
import '../widgets/modern_premium_background.dart';
import '../widgets/enhanced_damage_alert.dart';
import '../theme/modern_premium_theme.dart';
import 'driver_profile_screen.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

class VanProfileScreen extends StatefulWidget {
  final int vanNumber;

  const VanProfileScreen({
    super.key,
    required this.vanNumber,
  });

  @override
  State<VanProfileScreen> createState() => _VanProfileScreenState();
}

class _VanProfileScreenState extends State<VanProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? vanData;
  bool isLoading = true;
  String? error;

  // Animation controllers for luxury effects
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _breathingController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;
  late AnimationController _rotationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadVanData();
  }

  void _initializeAnimations() {
    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    // Slide up animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Scale animation for cards
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Breathing animation for premium elements
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation for van icon
    _rotationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
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

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _breathingController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadVanData() async {
    try {
      debugPrint(
          '🔄 Loading van data for Van #${widget.vanNumber} at ${DateTime.now()}');
      setState(() {
        isLoading = true;
        error = null;
      });

      final data =
          await EnhancedDriverService.getVanProfileWithImages(widget.vanNumber);

      if (data != null) {
        final images = data['images'] as List? ?? [];
        debugPrint('✅ Loaded van data: ${images.length} images found');

        // Log latest image info for debugging
        if (images.isNotEmpty) {
          final latestImage = images.first;
          debugPrint(
              '📷 Latest image: created_at=${latestImage['created_at']}, van_rating=${latestImage['van_rating']}, van_side=${latestImage['van_side']}');
        }
      } else {
        debugPrint('❌ No van data returned for Van #${widget.vanNumber}');
      }

      setState(() {
        vanData = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading van data for Van #${widget.vanNumber}: $e');
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
        // Premium animated backdrop
        _buildPremiumBackdrop(),

        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildLuxuryAppBar(),
          body: isLoading
              ? _buildLuxuryLoadingScreen()
              : error != null
                  ? _buildLuxuryErrorScreen()
                  : _buildLuxuryContent(),
        ),
      ],
    );
  }

  Widget _buildPremiumBackdrop() {
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
              // Animated geometric patterns
              _buildGeometricPatterns(),

              // Floating particles
              _buildFloatingParticles(),

              // Gradient overlays
              _buildGradientOverlays(),

              // Subtle noise texture
              _buildNoiseTexture(),

              // Animated light rays
              _buildLightRays(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeometricPatterns() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: GeometricPatternPainter(
            animation: _rotationAnimation,
            particleAnimation: _particleAnimation,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(50, (index) {
            final progress = (_particleAnimation.value + index * 0.02) % 1.0;
            final x = (index * 37.5) % MediaQuery.of(context).size.width;
            final y = (progress * MediaQuery.of(context).size.height * 2) -
                MediaQuery.of(context).size.height;

            return Positioned(
              left: x,
              top: y,
              child: Transform.scale(
                scale: 0.5 + 0.5 * math.sin(progress * 2 * math.pi),
                child: Container(
                  width: 2 + (index % 3) * 2,
                  height: 2 + (index % 3) * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ModernPremiumTheme.primaryNeon.withOpacity(0.8),
                        ModernPremiumTheme.primaryNeon.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
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

  Widget _buildGradientOverlays() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-left gradient
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.primaryNeon
                          .withOpacity(0.1 * _breathingAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom-right gradient
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.secondaryElectric
                          .withOpacity(0.08 * _breathingAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Center gradient
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: MediaQuery.of(context).size.width * 0.1,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ModernPremiumTheme.accentHotPink
                          .withOpacity(0.05 * _breathingAnimation.value),
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
          opacity: 0.03,
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

  Widget _buildLightRays() {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: LightRaysPainter(
            animation: _rotationAnimation,
            breathingAnimation: _breathingAnimation,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  PreferredSizeWidget _buildLuxuryAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              ModernPremiumTheme.primaryNeon.withOpacity(0.2),
              ModernPremiumTheme.secondaryElectric.withOpacity(0.2),
            ],
          ),
          border: Border.all(
            color: ModernPremiumTheme.primaryNeon.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ModernPremiumTheme.primaryNeon.withOpacity(0.2),
              blurRadius: 8,
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
                  size: 20,
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
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: ModernPremiumTheme.neonGradient,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: ModernPremiumTheme.textDiamond,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Van #${widget.vanNumber}',
                      style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Fleet Management',
                      style: ModernPremiumTheme.modernBodyStyle.copyWith(
                        fontSize: 10,
                        color: ModernPremiumTheme.textDiamond.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        // Refresh button with luxury design
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                debugPrint(
                    '🔄 Manual refresh triggered for Van #${widget.vanNumber}');
                _loadVanData();
              },
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          Colors.transparent,
                          ModernPremiumTheme.textDiamond.withOpacity(0.3),
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
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Settings button with luxury design
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Add settings functionality here
              },
              child: const Icon(
                Icons.settings_rounded,
                color: ModernPremiumTheme.textDiamond,
                size: 24,
              ),
            ),
          ),
        ),
        // Premium status indicator
        AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _breathingAnimation.value,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ModernPremiumTheme.successElectric.withOpacity(0.8),
                      ModernPremiumTheme.secondaryElectric.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ModernPremiumTheme.successElectric.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          ModernPremiumTheme.successElectric.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ModernPremiumTheme.textDiamond,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: ModernPremiumTheme.textDiamond,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLuxuryLoadingScreen() {
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ModernPremiumTheme.neonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: ModernPremiumTheme.primaryNeon.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: ModernPremiumTheme.textDiamond,
                          size: 60,
                        ),
                      );
                    },
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
                  'Loading Van #${widget.vanNumber}',
                  style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.transparent,
                      ModernPremiumTheme.textDiamond.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: [
                      _shimmerAnimation.value - 0.3,
                      _shimmerAnimation.value,
                      _shimmerAnimation.value + 0.3,
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  'Preparing luxury experience...',
                  style: ModernPremiumTheme.modernBodyStyle.copyWith(
                    color: ModernPremiumTheme.textDiamond.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryErrorScreen() {
    return Center(
      child: ModernPremiumCard(
        enableGlass: true,
        enableNeonEffect: true,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _breathingAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _breathingAnimation.value,
                    child: Icon(
                      Icons.error_outline,
                      size: 80,
                      color: ModernPremiumTheme.errorHotPink,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Error Loading Van Data',
                style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error!,
                style: ModernPremiumTheme.modernBodyStyle.copyWith(
                  color: ModernPremiumTheme.textDiamond.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ModernPremiumButton(
                text: 'Retry',
                onPressed: _loadVanData,
                icon: Icons.refresh_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryContent() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLuxuryVanInfoCard(),
                    const SizedBox(height: 24),
                    _buildLuxuryVanStatusCard(),
                    const SizedBox(height: 24),
                    _buildLuxuryDamageAssessmentCard(),
                    const SizedBox(height: 24),
                    _buildLuxuryImageStatsCard(),
                    const SizedBox(height: 24),
                    _buildLuxuryImagesSection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLuxuryVanInfoCard() {
    final vanMake = vanData!['van_make']?.toString() ?? 'Unknown';
    final vanModel = vanData!['van_model']?.toString() ?? 'Unknown';
    final vanYear = vanData!['van_year']?.toString() ?? 'Unknown';

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            enableFloatingAnimation: true,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.8),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: ModernPremiumTheme.neonGradient,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: ModernPremiumTheme.textDiamond,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '🚐 Van Information',
                        style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
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
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ModernPremiumTheme.deepSpace,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.local_shipping_rounded,
                                    color: ModernPremiumTheme.textDiamond,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Van #${widget.vanNumber}',
                              style:
                                  ModernPremiumTheme.neonHeadingStyle.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$vanYear $vanMake $vanModel',
                              style:
                                  ModernPremiumTheme.modernBodyStyle.copyWith(
                                fontSize: 16,
                                color: ModernPremiumTheme.textDiamond
                                    .withOpacity(0.8),
                              ),
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
        );
      },
    );
  }

  Widget _buildLuxuryVanStatusCard() {
    final vanStatus = vanData!['status']?.toString() ?? 'active';
    final vanUpdatedAt = vanData!['updated_at']?.toString();
    final vanNotes = vanData!['notes']?.toString();

    final statusConfig = EnhancedDriverService.statusConfig[vanStatus] ??
        EnhancedDriverService.statusConfig['active']!;

    Color statusColor = _getStatusColor(vanStatus);
    IconData statusIcon = _getStatusIcon(vanStatus);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.8),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: ModernPremiumTheme.neonGradient,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: ModernPremiumTheme.textDiamond,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '🚗 Van Status',
                        style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showStatusDialog(),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Change Status'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernPremiumTheme.primaryNeon,
                          foregroundColor: ModernPremiumTheme.textDiamond,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusConfig['label'],
                                    style: ModernPremiumTheme.neonHeadingStyle
                                        .copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                  Text(
                                    statusConfig['description'],
                                    style: ModernPremiumTheme.modernBodyStyle
                                        .copyWith(
                                      fontSize: 14,
                                      color: ModernPremiumTheme.textDiamond
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (vanNotes != null && vanNotes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ModernPremiumTheme.textDiamond
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Notes: $vanNotes',
                              style:
                                  ModernPremiumTheme.modernBodyStyle.copyWith(
                                fontSize: 12,
                                color: ModernPremiumTheme.textDiamond
                                    .withOpacity(0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildLuxuryImageStatsCard() {
    final images = vanData!['images'] as List? ?? [];
    final imageCount = images.length;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: ModernPremiumCard(
            enableGlass: true,
            enableNeonEffect: true,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ModernPremiumTheme.deepSpace.withOpacity(0.8),
                    ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: ModernPremiumTheme.neonGradient,
                        ),
                        child: const Icon(
                          Icons.photo_library_rounded,
                          color: ModernPremiumTheme.textDiamond,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '📊 Image Statistics',
                        style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLuxuryStatItem(
                        'Total Images',
                        imageCount.toString(),
                        Icons.image_rounded,
                        ModernPremiumTheme.primaryNeon,
                      ),
                      _buildLuxuryStatItem(
                        'Damage Levels',
                        _getUniqueDamageLevels(images).toString(),
                        Icons.analytics_rounded,
                        ModernPremiumTheme.secondaryElectric,
                      ),
                      _buildLuxuryStatItem(
                        'Last Updated',
                        _getLastUpdateTime(images),
                        Icons.schedule_rounded,
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

  Widget _buildLuxuryStatItem(
      String label, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingAnimation.value,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
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
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: ModernPremiumTheme.modernBodyStyle.copyWith(
                  fontSize: 10,
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

  Widget _buildLuxuryImagesSection() {
    final images = vanData!['images'] as List? ?? [];

    if (images.isEmpty) {
      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ModernPremiumCard(
              enableGlass: true,
              enableNeonEffect: true,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ModernPremiumTheme.deepSpace.withOpacity(0.8),
                      ModernPremiumTheme.cosmicPurple.withOpacity(0.6),
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
                              size: 64,
                              color: ModernPremiumTheme.textDiamond
                                  .withOpacity(0.5),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No images available',
                        style: ModernPremiumTheme.modernBodyStyle.copyWith(
                          fontSize: 16,
                          color:
                              ModernPremiumTheme.textDiamond.withOpacity(0.7),
                        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: ModernPremiumTheme.neonGradient,
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                color: ModernPremiumTheme.textDiamond,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '🖼️ Van Images',
              style: ModernPremiumTheme.neonHeadingStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildImagesSection(),
      ],
    );
  }

  int _getUniqueDamageLevels(List images) {
    final levels = images.map((img) => img['van_rating'] ?? 0).toSet();
    return levels.length;
  }

  String _getLastUpdateTime(List images) {
    if (images.isEmpty) return 'N/A';

    final latestImage = images.first;
    final createdAt = latestImage['created_at'];
    if (createdAt == null) return 'N/A';

    try {
      final date = DateTime.parse(createdAt);
      return '${date.month}/${date.day}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green[600]!;
      case 'maintenance':
        return Colors.orange[600]!;
      case 'out_of_service':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'maintenance':
        return Icons.build;
      case 'out_of_service':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  void _showStatusDialog() {
    final vanStatus = vanData!['status']?.toString() ?? 'active';

    showVanStatusDialog(
      context,
      vanNumber: widget.vanNumber,
      currentStatus: vanStatus,
      onStatusChanged: (newStatus) {
        // Reload van data to reflect the status change
        _loadVanData();
      },
    );
  }

  Widget _buildLuxuryDamageAssessmentCard() {
    final images = vanData!['images'] as List? ?? [];

    // First, check if we have van-level damage data (from the model field which contains damage rating)
    final vanMake = vanData!['van_make']?.toString() ?? 'Unknown';
    final vanModel = vanData!['van_model']?.toString() ?? 'Unknown';

    // Check if van_model contains damage rating info (format: "Rental Van - Moderate (Scratches) - scratches")
    String? vanLevelDamage;
    int? vanLevelRating;
    String? vanLevelType;
    String? vanLevelSeverity;

    if (vanModel.contains(' - ') &&
        vanModel.contains('(') &&
        vanModel.contains(')')) {
      final parts = vanModel.split(' - ');
      if (parts.length >= 2) {
        final damageInfo = parts[1];
        if (damageInfo.contains('(') && damageInfo.contains(')')) {
          final severityMatch =
              RegExp(r'(\w+)\s*\(([^)]+)\)').firstMatch(damageInfo);
          if (severityMatch != null) {
            vanLevelSeverity = severityMatch.group(1)?.toLowerCase();
            vanLevelType = severityMatch.group(2)?.toLowerCase();

            // Map severity to rating
            switch (vanLevelSeverity) {
              case 'no':
                vanLevelRating = 0;
                break;
              case 'minor':
                vanLevelRating = 1;
                break;
              case 'moderate':
                vanLevelRating = 2;
                break;
              case 'major':
                vanLevelRating = 3;
                break;
            }

            if (parts.length >= 3) {
              vanLevelDamage = parts[2];
            }
          }
        }
      }
    }

    // Find the worst damage from all images (highest rating)
    Map<String, dynamic>? worstDamageImage;
    int highestRating = vanLevelRating ?? 0;

    // Calculate damage statistics
    int noDamage = 0;
    int minorDamage = 0;
    int moderateDamage = 0;
    int majorDamage = 0;

    for (final image in images) {
      final imageRating = image['van_rating'] as int? ?? 0;
      if (imageRating > highestRating) {
        highestRating = imageRating;
        worstDamageImage = image;
      }

      // Count damage levels
      switch (imageRating) {
        case 0:
          noDamage++;
          break;
        case 1:
          minorDamage++;
          break;
        case 2:
          moderateDamage++;
          break;
        case 3:
          majorDamage++;
          break;
      }
    }

    // Use worst damage image data if it has higher rating than van-level data
    String finalDamageDescription;
    String finalDamageType;
    String finalSeverity;
    String finalLocation;
    int finalRating;

    if (worstDamageImage != null &&
        (worstDamageImage['van_rating'] as int? ?? 0) > (vanLevelRating ?? 0)) {
      // Use individual image data (worst damage found)
      finalRating = worstDamageImage['van_rating'] as int? ?? 0;
      finalDamageType =
          worstDamageImage['damage_type']?.toString() ?? 'unknown';
      finalSeverity =
          worstDamageImage['damage_severity']?.toString() ?? 'unknown';
      finalLocation = worstDamageImage['van_side']
              ?.toString()
              ?.replaceAll('_', ' ')
              .toUpperCase() ??
          'UNKNOWN';
      finalDamageDescription = worstDamageImage['van_damage']?.toString() ??
          'No description available';
    } else if (vanLevelRating != null && vanLevelRating > 0) {
      // Use van-level data
      finalRating = vanLevelRating;
      finalDamageType = vanLevelType ?? 'unknown';
      finalSeverity = vanLevelSeverity ?? 'unknown';
      finalLocation = "DRIVER SIDE"; // Default for Enterprise vans
      finalDamageDescription =
          vanLevelDamage ?? 'Minor dirt and debris on vehicle surface.';
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

    return ModernPremiumCard(
      enableGlass: true,
      enableNeonEffect: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: finalRating >= 2
                        ? getRatingColor(finalRating).withOpacity(0.2)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    finalRating >= 2
                        ? Icons.warning_amber_rounded
                        : Icons.assessment,
                    color: finalRating >= 2
                        ? getRatingColor(finalRating)
                        : Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finalRating >= 2
                            ? '⚠️ DAMAGE ALERT'
                            : '✅ Damage Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: finalRating >= 2
                              ? getRatingColor(finalRating)
                              : Colors.blue[800],
                        ),
                      ),
                      Text(
                        'Level $finalRating - ${getRatingDescription(finalRating)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: finalRating >= 2
                              ? getRatingColor(finalRating).withOpacity(0.8)
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Damage level badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        getRatingColor(finalRating),
                        getRatingColor(finalRating).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: getRatingColor(finalRating).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'L$finalRating',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Enhanced Damage Statistics Section
            DamageStatisticsCard(
              damageStats: {
                'L0': noDamage,
                'L1': minorDamage,
                'L2': moderateDamage,
                'L3': majorDamage,
              },
              selectedLevel: finalRating >= 2 ? 'L$finalRating' : null,
            ),

            const SizedBox(height: 16),

            // Illustrated Van Icon with Damage Indicators
            _buildIllustratedVanIcon(images),

            const SizedBox(height: 12),

            // Enhanced Damage Alert - More Visible
            if (finalRating >= 2)
              EnhancedDamageAlert(
                damageLevel: getRatingDescription(finalRating).split(' ')[0],
                damageDescription: finalDamageDescription,
                damageType: finalDamageType,
                customColor: getRatingColor(finalRating),
                onTap: () {
                  // Handle damage alert tap
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Viewing damage details for $finalLocation'),
                      backgroundColor: getRatingColor(finalRating),
                    ),
                  );
                },
                onViewDetails: () {
                  // Show detailed damage information
                  _showDamageDetailsDialog(context, finalRating,
                      finalDamageDescription, finalDamageType, finalLocation);
                },
                onReportDamage: () {
                  // Open damage report form
                  _showDamageReportDialog(context);
                },
              ),

            if (finalRating >= 2) const SizedBox(height: 12),

            // Rating section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[50]!,
                    Colors.white,
                    Colors.grey[50]!,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[600]!,
                          Colors.blue[500]!,
                          Colors.blue[600]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      'Rating: ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          getRatingColor(finalRating),
                          getRatingColor(finalRating).withOpacity(0.8),
                          getRatingColor(finalRating),
                          getRatingColor(finalRating).withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: getRatingColor(finalRating).withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      getRatingDescription(finalRating),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey[300]!,
                          Colors.grey[200]!,
                          Colors.grey[300]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '($finalRating/3)',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Details
            _buildDetailRow('Type:', finalDamageType),
            _buildDetailRow('Severity:', finalSeverity),
            _buildDetailRow('Location/\nSide:', finalLocation),

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
      ),
    );
  }

  Widget _buildIllustratedVanIcon(List images) {
    // Analyze damage by van side
    Map<String, int> sideDamageRatings = {
      'front': 0,
      'rear': 0,
      'driver_side': 0,
      'passenger_side': 0,
      'interior': 0,
      'roof': 0,
      'undercarriage': 0,
    };

    // Find the highest damage rating for each side
    for (final image in images) {
      final side = image['van_side']?.toString() ?? 'unknown';
      final rating = image['van_rating'] as int? ?? 0;

      if (sideDamageRatings.containsKey(side)) {
        if (rating > sideDamageRatings[side]!) {
          sideDamageRatings[side] = rating;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Text(
            '🚐 Van Damage Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal row of van side indicators
          Container(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Front
                Column(
                  children: [
                    _buildSideIndicator(
                      'FRONT',
                      sideDamageRatings['front'] ?? 0,
                      _getVanSideIcon('FRONT'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[100]!,
                            Colors.white,
                            Colors.grey[100]!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'FRONT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Driver Side
                Column(
                  children: [
                    _buildSideIndicator(
                      'DRIVER',
                      sideDamageRatings['driver_side'] ?? 0,
                      _getVanSideIcon('DRIVER'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[200]!,
                            Colors.white,
                            Colors.grey[200]!,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[400]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'DRIVER',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Passenger Side
                Column(
                  children: [
                    _buildSideIndicator(
                      'PASSENGER',
                      sideDamageRatings['passenger_side'] ?? 0,
                      _getVanSideIcon('PASSENGER'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[200]!,
                            Colors.white,
                            Colors.grey[200]!,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[400]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'PASSENGER',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Rear
                Column(
                  children: [
                    _buildSideIndicator(
                      'REAR',
                      sideDamageRatings['rear'] ?? 0,
                      _getVanSideIcon('REAR'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[200]!,
                            Colors.white,
                            Colors.grey[200]!,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey[400]!,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'REAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildLegendItem('No Damage', Colors.green[600]!),
              _buildLegendItem('Minor (L1)', Colors.yellow[700]!),
              _buildLegendItem('Moderate (L2)', Colors.orange[700]!),
              _buildLegendItem('Major (L3)', Colors.red[700]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideIndicator(String label, int damageRating, IconData icon,
      {bool isSmall = false}) {
    Color indicatorColor = Colors.grey[400]!;
    final hasDamage = damageRating > 0;

    if (hasDamage) {
      switch (damageRating) {
        case 1:
          indicatorColor = Colors.yellow[700]!;
          break;
        case 2:
          indicatorColor = Colors.orange[700]!;
          break;
        case 3:
          indicatorColor = Colors.red[700]!;
          break;
      }
    }

    // Create a more visual van side representation
    return GestureDetector(
      onTap: hasDamage ? () => _navigateToDamageImage(label) : null,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 8 : 12),
        decoration: BoxDecoration(
          color: indicatorColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildVanSideVisual(label, isSmall),
            if (hasDamage)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app,
                    size: isSmall ? 8 : 12,
                    color: Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanSideVisual(String label, bool isSmall) {
    switch (label.toUpperCase()) {
      case 'FRONT':
        return _buildFrontView(isSmall);
      case 'REAR':
        return _buildRearView(isSmall);
      case 'DRIVER':
        return _buildDriverSide(isSmall);
      case 'PASSENGER':
        return _buildPassengerSide(isSmall);
      case 'INTERIOR':
        return Icon(Icons.airline_seat_recline_normal,
            color: Colors.white, size: isSmall ? 16 : 24);
      case 'ROOF':
        return Icon(Icons.roofing,
            color: Colors.white, size: isSmall ? 16 : 24);
      case 'UNDER':
        return Icon(Icons.build, color: Colors.white, size: isSmall ? 16 : 24);
      default:
        return Icon(Icons.local_shipping,
            color: Colors.white, size: isSmall ? 16 : 24);
    }
  }

  Widget _buildFrontView(bool isSmall) {
    return Container(
      width: isSmall ? 40 : 60,
      height: isSmall ? 30 : 40,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Ford grille - prominent horizontal slats
          Positioned(
            left: 8,
            top: 12,
            child: Container(
              width: 35,
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    5,
                    (index) => Container(
                          width: 5,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
              ),
            ),
          ),
          // Animated glowing headlights
          Positioned(
            left: 4,
            top: 4,
            child: _buildAnimatedHeadlight(isSmall),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: _buildAnimatedHeadlight(isSmall),
          ),
          // Ford logo area - more prominent
          Positioned(
            left: 15,
            top: 15,
            child: Container(
              width: 12,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Front bumper
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRearView(bool isSmall) {
    return Container(
      width: isSmall ? 40 : 60,
      height: isSmall ? 30 : 40,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Rear doors with prominent vertical seam
          Positioned(
            left: 12,
            top: 4,
            child: Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Animated glowing taillights
          Positioned(
            left: 4,
            bottom: 4,
            child: _buildAnimatedTaillight(isSmall),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _buildAnimatedTaillight(isSmall),
          ),
          // TRANSIT text area - more prominent
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 28,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Rear bumper
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSide(bool isSmall) {
    return Container(
      width: isSmall ? 30 : 45,
      height: isSmall ? 40 : 55,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Driver window - larger and more prominent
          Positioned(
            left: 4,
            top: 6,
            child: Container(
              width: 25,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey[700]!, width: 1.5),
              ),
            ),
          ),
          // Large prominent side mirror
          Positioned(
            right: 3,
            top: 12,
            child: Container(
              width: 8,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[600]!, width: 1.5),
              ),
            ),
          ),
          // Lower trim panel
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 35,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Driver side door handle
          Positioned(
            left: 6,
            top: 25,
            child: Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Driver side steering wheel indicator
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerSide(bool isSmall) {
    return Container(
      width: isSmall ? 30 : 45,
      height: isSmall ? 40 : 55,
      child: Stack(
        children: [
          // Van body - more rectangular like Ford Transit
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),
          // Passenger window - larger and more prominent
          Positioned(
            left: 4,
            top: 6,
            child: Container(
              width: 25,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey[700]!, width: 1.5),
              ),
            ),
          ),
          // Large prominent side mirror
          Positioned(
            right: 3,
            top: 12,
            child: Container(
              width: 8,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[600]!, width: 1.5),
              ),
            ),
          ),
          // Lower trim panel
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 35,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Passenger side door handle
          Positioned(
            left: 6,
            top: 25,
            child: Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[500],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Passenger side seat indicator
          Positioned(
            left: 8,
            top: 15,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.grey[500]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeadlight(bool isSmall) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Container(
          width: isSmall ? 8 : 12,
          height: isSmall ? 8 : 12,
          decoration: BoxDecoration(
            color: Colors.yellow[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[700]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.yellow[300]!.withOpacity(0.8 * value),
                blurRadius: 3 + (2 * value),
                spreadRadius: 1 + value,
              ),
              BoxShadow(
                color: Colors.yellow[100]!.withOpacity(0.6 * value),
                blurRadius: 6 + (4 * value),
                spreadRadius: 2 + (2 * value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTaillight(bool isSmall) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Container(
          width: isSmall ? 8 : 12,
          height: isSmall ? 6 : 8,
          decoration: BoxDecoration(
            color: Colors.red[400],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[700]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red[300]!.withOpacity(0.8 * value),
                blurRadius: 3 + (2 * value),
                spreadRadius: 1 + value,
              ),
              BoxShadow(
                color: Colors.red[100]!.withOpacity(0.6 * value),
                blurRadius: 6 + (4 * value),
                spreadRadius: 2 + (2 * value),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getVanSideIcon(String label) {
    switch (label.toUpperCase()) {
      case 'FRONT':
        return Icons.local_shipping; // Van front view
      case 'REAR':
        return Icons.local_shipping; // Van rear view
      case 'DRIVER':
        return Icons.local_shipping; // Van driver side
      case 'PASSENGER':
        return Icons.local_shipping; // Van passenger side
      case 'INTERIOR':
        return Icons.airline_seat_recline_normal;
      case 'ROOF':
        return Icons.roofing;
      case 'UNDER':
        return Icons.build;
      default:
        return Icons.local_shipping; // Generic van icon
    }
  }

  void _navigateToDamageImage(String sideLabel) {
    if (vanData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No van data available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Find images for this specific side
    final images = vanData!['images'] as List? ?? [];
    final sideImages = images.where((image) {
      final imageSide = image['van_side']?.toString().toLowerCase() ?? '';
      final targetSide = sideLabel.toLowerCase();

      // Map side labels to image side values
      switch (targetSide) {
        case 'front':
          return imageSide.contains('front') ||
              imageSide.contains('front_side');
        case 'rear':
          return imageSide.contains('rear') ||
              imageSide.contains('back') ||
              imageSide.contains('rear_side');
        case 'driver':
          return imageSide.contains('driver') ||
              imageSide.contains('driver_side');
        case 'passenger':
          return imageSide.contains('passenger') ||
              imageSide.contains('passenger_side');
        case 'interior':
          return imageSide.contains('interior') || imageSide.contains('inside');
        case 'roof':
          return imageSide.contains('roof') || imageSide.contains('top');
        case 'under':
          return imageSide.contains('under') ||
              imageSide.contains('undercarriage') ||
              imageSide.contains('bottom');
        default:
          return imageSide.contains(targetSide);
      }
    }).toList();

    if (sideImages.isNotEmpty) {
      // Find the image with the highest damage rating
      sideImages.sort((a, b) {
        final ratingA = a['van_rating'] as int? ?? 0;
        final ratingB = b['van_rating'] as int? ?? 0;
        return ratingB.compareTo(ratingA); // Sort descending
      });

      final targetImage = sideImages.first;
      final imageUrl = targetImage['image_url'] as String?;

      if (imageUrl != null) {
        // Navigate to the image viewer with the specific image
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildImageViewer(imageUrl, targetImage),
          ),
        );
      } else {
        // Show error message if no image found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No damage image found for $sideLabel side'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Show error message if no images found for this side
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No images found for $sideLabel side'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildImageViewer(String imageUrl, Map<String, dynamic> imageData) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Damage Image - ${imageData['van_side'] ?? 'Unknown Side'}'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  Text(
                    'Damage Level: ${imageData['van_rating'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Side: ${imageData['van_side'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (imageData['created_at'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Uploaded: ${DateTime.parse(imageData['created_at']).toString().split('.')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
            Colors.white,
            Colors.grey[50]!,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  color,
                  color.withOpacity(0.8),
                  color,
                  color.withOpacity(0.9),
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
            Colors.white,
            Colors.grey[50]!,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[600]!,
                  Colors.blue[500]!,
                  Colors.blue[600]!,
                  Colors.blue[500]!,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[100]!,
                    Colors.white,
                    Colors.grey[100]!,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  height: 1.4,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStatsCard() {
    final images = vanData!['images'] as List? ?? [];
    final totalImages = images.length;

    // Count unique drivers
    final Set<String> uniqueDrivers = {};
    for (final image in images) {
      final driverProfile = image['driver_profiles'] as Map<String, dynamic>?;
      if (driverProfile != null && driverProfile['id'] != null) {
        uniqueDrivers.add(driverProfile['id'].toString());
      }
    }

    // Find latest upload
    DateTime? latestUpload;
    for (final image in images) {
      final uploadedAt =
          DateTime.tryParse(image['created_at']?.toString() ?? '');
      if (uploadedAt != null) {
        if (latestUpload == null || uploadedAt.isAfter(latestUpload)) {
          latestUpload = uploadedAt;
        }
      }
    }

    return ModernPremiumCard(
      enableGlass: true,
      enableNeonEffect: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Image Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    'Total Images', totalImages.toString(), Icons.image),
                _buildStatItem(
                    'Drivers', uniqueDrivers.length.toString(), Icons.people),
                _buildStatItem(
                    'Latest Upload',
                    latestUpload != null
                        ? '${latestUpload.month}/${latestUpload.day}'
                        : 'N/A',
                    Icons.upload),
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

  Widget _buildImagesSection() {
    final images = vanData!['images'] as List? ?? [];

    if (images.isEmpty) {
      return ModernPremiumCard(
        enableGlass: true,
        enableNeonEffect: true,
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

    // Group images by driver
    Map<String, List<Map<String, dynamic>>> imagesByDriver = {};
    for (final image in images) {
      final driverProfile = image['driver_profiles'] as Map<String, dynamic>?;
      final driverName = driverProfile?['driver_name']?.toString() ??
          driverProfile?['slack_real_name']?.toString() ??
          'Unknown Driver';
      final driverId = driverProfile?['id']?.toString() ?? 'unknown';

      if (!imagesByDriver.containsKey(driverId)) {
        imagesByDriver[driverId] = [];
      }
      imagesByDriver[driverId]!.add(Map<String, dynamic>.from(image));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📷 Images by Driver (${images.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // Test button to verify EnhancedImageViewer works
            if (images.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  debugPrint(
                      '🧪 TEST: Opening EnhancedImageViewer directly...');
                  final imageList = images.cast<Map<String, dynamic>>();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EnhancedImageViewer(
                        images: imageList,
                        initialIndex: 0,
                        title: 'Van #${widget.vanNumber} Images - TEST',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('TEST'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...imagesByDriver.entries
            .map((entry) => _buildDriverImageGroup(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildDriverImageGroup(
      String driverId, List<Map<String, dynamic>> images) {
    final driverProfile =
        images.first['driver_profiles'] as Map<String, dynamic>?;
    final driverName = driverProfile?['driver_name']?.toString() ??
        driverProfile?['slack_real_name']?.toString() ??
        'Unknown Driver';
    final imageCount = images.length;

    return ModernPremiumCard(
      enableGlass: true,
      enableNeonEffect: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green[400],
                        child: Text(
                          driverName[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          driverName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('$imageCount images'),
                  backgroundColor: Colors.blue[100],
                ),
                const SizedBox(width: 8),
                if (driverId != 'unknown')
                  ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToDriverProfile(driverId, driverName),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('VIEW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120, // Increased height for button
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length > 5 ? 5 : images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return Container(
                    width: 120, // Increased width for button
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        // Image display
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildImageWidget(image),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Individual image damage assessment
                        _buildIndividualImageDamageAssessment(image),
                        const SizedBox(height: 4),
                        // Guaranteed working button
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            width: double.infinity,
                            child: ModernPremiumButton(
                              text: 'VIEW',
                              onPressed: () {
                                debugPrint(
                                    '🚀 VIEW BUTTON: Pressed for image ${image['id']}');
                                final allImages =
                                    vanData!['images'] as List? ?? [];
                                final imageList =
                                    allImages.cast<Map<String, dynamic>>();
                                final selectedIndex = imageList.indexWhere(
                                    (img) => img['id'] == image['id']);

                                debugPrint(
                                    '📷 Opening viewer with ${imageList.length} images, index: $selectedIndex');

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EnhancedImageViewer(
                                      images: imageList,
                                      initialIndex: selectedIndex >= 0
                                          ? selectedIndex
                                          : 0,
                                      title: 'Van #${widget.vanNumber} Images',
                                    ),
                                  ),
                                );
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

  Color _getDamageRatingColor(int rating) {
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

  Widget _buildImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();
    String? imageUrl = image['image_url']?.toString();

    debugPrint('🖼️ Building image widget:');
    debugPrint('  - image_data length: ${imageData?.length ?? 0}');
    debugPrint('  - image_url: ${imageUrl?.substring(0, 100) ?? 'null'}...');
    debugPrint('  - content_type: ${image['content_type']}');
    debugPrint('  - van_number: ${image['van_number']}');
    debugPrint('  - van_rating: ${image['van_rating']}');
    debugPrint('  - van_side: ${image['van_side']}');

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
          onTap: () {
            debugPrint(
                '🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
            _openImageViewer(image);
          },
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
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('  ❌ Error displaying image: $error');
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
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
                  // Rating badge (L0, L1, L2, L3) - top left corner
                  Positioned(
                    top: 4,
                    left: 4,
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
                  // Fullscreen icon - top right
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // Van side indicator (bottom)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getVanSideColor(
                            image['van_side']?.toString() ?? 'unknown'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (image['van_side']?.toString() ?? 'unknown')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Tap indicator overlay (invisible but helps with tap detection)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          debugPrint(
                              '🖱️ VAN PROFILE: InkWell tapped! Opening image viewer...');
                          _openImageViewer(image);
                        },
                        child: Container(),
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
          onTap: () {
            debugPrint(
                '🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
            _openImageViewer(image);
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
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
      onTap: () {
        debugPrint('🖱️ VAN PROFILE: Image tapped! Opening image viewer...');
        _openImageViewer(image);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
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
    debugPrint(
        '🔍 VAN PROFILE: _openImageViewer called for image: ${selectedImage['id']}');
    debugPrint('🔍 VAN PROFILE: selectedImage data: $selectedImage');

    final images = vanData!['images'] as List? ?? [];
    debugPrint('🔍 VAN PROFILE: vanData images: $images');

    final imageList = images.cast<Map<String, dynamic>>();
    final selectedIndex =
        imageList.indexWhere((img) => img['id'] == selectedImage['id']);

    debugPrint(
        '📷 VAN PROFILE: Total images: ${imageList.length}, Selected index: $selectedIndex');

    if (imageList.isNotEmpty) {
      debugPrint('🚀 VAN PROFILE: Navigating to EnhancedImageViewer...');
      try {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedImageViewer(
              images: imageList,
              initialIndex: selectedIndex >= 0 ? selectedIndex : 0,
              title: 'Van #${widget.vanNumber} Images',
            ),
          ),
        );
        debugPrint('✅ VAN PROFILE: Navigation successful!');
      } catch (e) {
        debugPrint('❌ VAN PROFILE: Navigation error: $e');
      }
    } else {
      debugPrint('❌ VAN PROFILE: No images available to display');
    }
  }

  void _navigateToDriverProfile(String driverId, String driverName) {
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

  Color _getDamageSeverityColor(String damageSeverity) {
    switch (damageSeverity) {
      case 'none':
        return Colors.green[600]!;
      case 'minor':
        return Colors.yellow[700]!;
      case 'moderate':
        return Colors.orange[700]!;
      case 'major':
        return Colors.red[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildSimpleImageWidget(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();

    if (imageData != null && imageData.isNotEmpty) {
      try {
        String base64Data = imageData;
        if (imageData.startsWith('data:')) {
          final commaIndex = imageData.indexOf(',');
          if (commaIndex != -1) {
            base64Data = imageData.substring(commaIndex + 1);
          }
        }

        final bytes = base64Decode(base64Data);

        return GestureDetector(
          onTap: () {
            debugPrint('🚀 SIMPLE: Button pressed! Opening image viewer...');
            final images = vanData!['images'] as List? ?? [];
            final imageList = images.cast<Map<String, dynamic>>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EnhancedImageViewer(
                  images: imageList,
                  initialIndex: 0,
                  title: 'Van #${widget.vanNumber} Images',
                ),
              ),
            );
          },
          child: Container(
            width: 100,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        return Container(
          width: 100,
          height: 100,
          color: Colors.red,
          child: const Center(child: Text('ERROR')),
        );
      }
    }

    return Container(
      width: 100,
      height: 100,
      color: Colors.grey,
      child: const Center(child: Text('NO IMAGE')),
    );
  }

  Widget _buildIndividualImageDamageAssessment(Map<String, dynamic> image) {
    final rating = image['van_rating'] as int? ?? 0;
    final damageType = image['damage_type']?.toString() ?? 'Unknown';
    final vanSide = image['van_side']?.toString() ?? 'Unknown';

    String getRatingDescription(int rating) {
      switch (rating) {
        case 0:
          return 'No Damage';
        case 1:
          return 'Minor';
        case 2:
          return 'Moderate';
        case 3:
          return 'Major';
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: getRatingColor(rating),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'L$rating',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Status and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getRatingDescription(rating),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: getRatingColor(rating),
                  ),
                ),
                Text(
                  '$damageType | ${vanSide.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageStatistics(List images) {
    // Calculate damage statistics
    int totalImages = images.length;
    int noDamage = 0;
    int minorDamage = 0;
    int moderateDamage = 0;
    int majorDamage = 0;

    for (final image in images) {
      final damageLevel = image['van_rating'] as int? ?? 0;
      switch (damageLevel) {
        case 0:
          noDamage++;
          break;
        case 1:
          minorDamage++;
          break;
        case 2:
          moderateDamage++;
          break;
        case 3:
          majorDamage++;
          break;
      }
    }

    return ModernPremiumCard(
      enableGlass: true,
      enableNeonEffect: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Damage Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDamageLevelBar(
                'No Damage (L0)', noDamage, totalImages, Colors.green[600]!),
            const SizedBox(height: 8),
            _buildDamageLevelBar(
                'Minor (L1)', minorDamage, totalImages, Colors.yellow[700]!),
            const SizedBox(height: 8),
            _buildDamageLevelBar('Moderate (L2)', moderateDamage, totalImages,
                Colors.orange[700]!),
            const SizedBox(height: 8),
            _buildDamageLevelBar(
                'Major (L3)', majorDamage, totalImages, Colors.red[700]!),
          ],
        ),
      ),
    );
  }

  Widget _buildDamageLevelBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Dialog methods for damage alerts
  void _showDamageDetailsDialog(BuildContext context, int rating,
      String description, String type, String location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: _getDamageLevelColor(rating),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Damage Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getDamageLevelColor(rating),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                  'Level:', 'L$rating - ${_getDamageLevelDescription(rating)}'),
              _buildDetailRow('Type:', type),
              _buildDetailRow('Location:', location),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getDamageLevelColor(rating).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getDamageLevelColor(rating).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDamageReportDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getDamageLevelColor(rating),
                foregroundColor: Colors.white,
              ),
              child: const Text('Report New Damage'),
            ),
          ],
        );
      },
    );
  }

  void _showDamageReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Report New Damage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This feature will allow you to report new damage to the van. The form will include:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildFeatureItem('Damage type selection'),
              _buildFeatureItem('Location on van'),
              _buildFeatureItem('Severity level'),
              _buildFeatureItem('Photo upload'),
              _buildFeatureItem('Description field'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Damage report form coming soon!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[600],
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            feature,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getDamageLevelDescription(int level) {
    switch (level) {
      case 0:
        return 'No Damage';
      case 1:
        return 'Minor';
      case 2:
        return 'Moderate';
      case 3:
        return 'Major';
      default:
        return 'Unknown';
    }
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
}

// Premium Custom Painters for the backdrop
class GeometricPatternPainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> particleAnimation;

  GeometricPatternPainter({
    required this.animation,
    required this.particleAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ModernPremiumTheme.primaryNeon.withOpacity(0.1)
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
      ..color = ModernPremiumTheme.textDiamond.withOpacity(0.1)
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

class LightRaysPainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> breathingAnimation;

  LightRaysPainter({
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
