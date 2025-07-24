import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';

class EnhancedImageViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final String title;

  const EnhancedImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.title,
  });

  @override
  State<EnhancedImageViewer> createState() => _EnhancedImageViewerState();
}

class _EnhancedImageViewerState extends State<EnhancedImageViewer>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _controlsAnimationController;
  late AnimationController _detailsAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _detailsAnimation;

  bool _showControls = true;
  bool _showImageDetails = false;
  bool _isLoading = false;
  double _currentScale = 1.0;

  // Magnifying glass functionality
  bool _showMagnifier = false;
  Offset _magnifierPosition = Offset.zero;
  double _magnifierScale = 2.0;
  bool _isDragging = false;
  bool _isHovering = false;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialize animations
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _detailsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    _detailsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _detailsAnimationController,
      curve: Curves.easeOutBack,
    ));

    _controlsAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controlsAnimationController.dispose();
    _detailsAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController.forward();
    } else {
      _controlsAnimationController.reverse();
    }

    // Hide details when hiding controls
    if (!_showControls && _showImageDetails) {
      _toggleImageDetails();
    }
  }

  void _toggleImageDetails() {
    setState(() {
      _showImageDetails = !_showImageDetails;
    });

    if (_showImageDetails) {
      _detailsAnimationController.forward();
      HapticFeedback.lightImpact();
    } else {
      _detailsAnimationController.reverse();
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
    HapticFeedback.selectionClick();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.5);
    _transformationController.value = matrix;
    setState(() {
      _currentScale *= 1.5;
    });
    HapticFeedback.selectionClick();
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(0.7);
    _transformationController.value = matrix;
    setState(() {
      _currentScale *= 0.7;
    });
    HapticFeedback.selectionClick();
  }

  void _toggleMagnifier() {
    setState(() {
      _showMagnifier = !_showMagnifier;
      if (!_showMagnifier) {
        _isDragging = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onMagnifierPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _magnifierPosition = details.localPosition;
    });
    HapticFeedback.selectionClick();
  }

  void _onMagnifierPanUpdate(DragUpdateDetails details) {
    setState(() {
      _magnifierPosition = details.localPosition;
    });
  }

  void _onMagnifierPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  void _onMouseHover(PointerHoverEvent event) {
    if (_showMagnifier && !_isDragging) {
      setState(() {
        _magnifierPosition = event.localPosition;
        _isHovering = true;
      });
    }
  }

  void _onMouseExit(PointerExitEvent event) {
    setState(() {
      _isHovering = false;
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_showMagnifier) {
      setState(() {
        _magnifierPosition = details.localPosition;
        _isDragging = true;
      });
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_showMagnifier) {
      setState(() {
        _isDragging = false;
      });
    }
  }

  void _increaseMagnification() {
    setState(() {
      _magnifierScale = (_magnifierScale + 0.5).clamp(1.5, 5.0);
    });
    HapticFeedback.selectionClick();
  }

  void _decreaseMagnification() {
    setState(() {
      _magnifierScale = (_magnifierScale - 0.5).clamp(1.5, 5.0);
    });
    HapticFeedback.selectionClick();
  }

  Widget _buildImage(Map<String, dynamic> image) {
    String? imageData = image['image_data']?.toString();
    String? imageUrl = image['image_url']?.toString();

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
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.black87,
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Main image with InteractiveViewer
              MouseRegion(
                cursor: _showMagnifier
                    ? SystemMouseCursors.precise
                    : SystemMouseCursors.basic,
                onHover: _onMouseHover,
                onExit: _onMouseExit,
                child: GestureDetector(
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onPanStart: _showMagnifier ? _onMagnifierPanStart : null,
                  onPanUpdate: _showMagnifier ? _onMagnifierPanUpdate : null,
                  onPanEnd: _showMagnifier ? _onMagnifierPanEnd : null,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: !_showMagnifier,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.3,
                    maxScale: 5.0,
                    onInteractionUpdate: (details) {
                      setState(() {
                        _currentScale =
                            _transformationController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Image data may be corrupted',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Magnifying glass overlay
              if (_showMagnifier) _buildMagnifyingGlass(bytes),
            ],
          ),
        );
      } catch (e) {
        return Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.warning_amber_outlined,
                  size: 50,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Invalid image data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cannot decode base64 data',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.image_not_supported_outlined,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No image data available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Image was not properly uploaded',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagnifyingGlass(Uint8List imageBytes) {
    const magnifierSize = 150.0;
    const borderWidth = 4.0;

    return Positioned(
      left: _magnifierPosition.dx - magnifierSize / 2,
      top: _magnifierPosition.dy - magnifierSize / 2,
      child: IgnorePointer(
        child: Container(
          width: magnifierSize,
          height: magnifierSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                // Magnified image
                Transform.scale(
                  scale: _magnifierScale,
                  child: Transform.translate(
                    offset: Offset(
                      -((_magnifierPosition.dx - magnifierSize / 2) *
                          _magnifierScale),
                      -((_magnifierPosition.dy - magnifierSize / 2) *
                          _magnifierScale),
                    ),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                // Crosshair in center
                Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
                // Magnification level indicator
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_magnifierScale.toStringAsFixed(1)}x',
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
          ),
        ),
      ),
    );
  }

  Widget _buildDamageRatingBadge(String rating) {
    final ratingNum = int.tryParse(rating) ?? 0;
    Color badgeColor;
    String ratingText;
    IconData icon;

    switch (ratingNum) {
      case 1:
        badgeColor = Colors.green;
        ratingText = 'MINOR';
        icon = Icons.check_circle;
        break;
      case 2:
        badgeColor = Colors.orange;
        ratingText = 'MODERATE';
        icon = Icons.warning;
        break;
      case 3:
        badgeColor = Colors.red;
        ratingText = 'SEVERE';
        icon = Icons.error;
        break;
      default:
        badgeColor = Colors.grey;
        ratingText = 'UNKNOWN';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            ratingText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageDetails(Map<String, dynamic> image) {
    final vanNumber = image['van_number']?.toString() ?? 'Unknown';
    final vanSide = image['van_side']?.toString() ??
        image['location']?.toString() ??
        'Unknown';
    final damageDescription =
        image['van_damage']?.toString() ?? 'No description';
    final damageType = image['damage_type']?.toString() ?? 'Unknown';
    final damageSeverity = image['damage_severity']?.toString() ?? 'Unknown';
    final rating = image['van_rating']?.toString() ?? '0';
    final uploadedAt = DateTime.tryParse(image['created_at']?.toString() ?? '');
    final uploadedBy = image['uploaded_by']?.toString() ?? 'Unknown';
    final fileSize = image['file_size'] as int? ?? 0;
    final contentType = image['content_type']?.toString() ?? 'Unknown';

    // Get driver info if available
    final driverProfiles = image['driver_profiles'] as Map<String, dynamic>?;
    final driverName = driverProfiles?['driver_name']?.toString() ?? uploadedBy;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(_detailsAnimation),
      child: FadeTransition(
        opacity: _detailsAnimation,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Image Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleImageDetails,
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Van Information
              _buildDetailSection('🚐 Van Information', [
                _buildDetailRow('Van Number', '#$vanNumber'),
                _buildDetailRow(
                    'Van Side', vanSide.replaceAll('_', ' ').toUpperCase()),
              ]),

              const SizedBox(height: 16),

              // Damage Assessment
              _buildDetailSection('⚠️ Damage Assessment', [
                Row(
                  children: [
                    const Text(
                      'Rating: ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    _buildDamageRatingBadge(rating),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                    'Type', damageType.replaceAll('_', ' ').toUpperCase()),
                _buildDetailRow('Severity', damageSeverity.toUpperCase()),
                _buildDetailRow('Description', damageDescription),
              ]),

              const SizedBox(height: 16),

              // Upload Information
              _buildDetailSection('📤 Upload Information', [
                _buildDetailRow('Uploaded By', driverName),
                if (uploadedAt != null)
                  _buildDetailRow('Upload Date',
                      '${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year} ${uploadedAt.hour}:${uploadedAt.minute.toString().padLeft(2, '0')}'),
                _buildDetailRow(
                    'File Size', '${(fileSize / 1024).toStringAsFixed(1)} KB'),
                _buildDetailRow(
                    'Format', contentType.split('/').last.toUpperCase()),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Magnifying glass toggle
          IconButton(
            onPressed: _toggleMagnifier,
            icon: Icon(
              _showMagnifier ? Icons.search : Icons.search_outlined,
              color: _showMagnifier ? Colors.blue : Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _showMagnifier
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
            ),
            tooltip: _showMagnifier
                ? 'Disable Magnifier'
                : (kIsWeb ||
                        defaultTargetPlatform == TargetPlatform.macOS ||
                        defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.linux)
                    ? 'Enable Magnifier\n(Hover mouse to move, click and drag to position)'
                    : 'Enable Magnifier',
          ),

          // Magnifier controls (only show when magnifier is active)
          if (_showMagnifier) ...[
            const SizedBox(height: 4),
            // PC instructions
            if (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Hover to move\nClick & drag to position',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // Increase magnification
            IconButton(
              onPressed: _increaseMagnification,
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                minimumSize: const Size(32, 32),
              ),
              tooltip: 'Increase Magnification',
            ),
            const SizedBox(height: 2),
            // Magnification level
            Text(
              '${_magnifierScale.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            // Decrease magnification
            IconButton(
              onPressed: _decreaseMagnification,
              icon: const Icon(Icons.remove, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                minimumSize: const Size(32, 32),
              ),
              tooltip: 'Decrease Magnification',
            ),
            const SizedBox(height: 8),
            // Divider
            Container(
              width: 20,
              height: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
          ],

          // Regular zoom controls
          IconButton(
            onPressed: _zoomIn,
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
            tooltip: 'Zoom In',
          ),
          const SizedBox(height: 4),
          Text(
            '${(_currentScale * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: _zoomOut,
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
            tooltip: 'Zoom Out',
          ),
          const SizedBox(height: 4),
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentImageDamageAssessment() {
    final currentImage = widget.images[_currentIndex];
    final rating = currentImage['van_rating'] as int? ?? 0;
    final damageType = currentImage['damage_type']?.toString() ?? 'Unknown';
    final damageDescription =
        currentImage['van_damage']?.toString() ?? 'No description';
    final vanSide = currentImage['van_side']?.toString() ?? 'Unknown';

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assessment, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'DAMAGE ASSESSMENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rating badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: getRatingColor(rating),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: getRatingColor(rating).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'L$rating',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Status text
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  getRatingDescription(rating).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional details
          Text(
            'Type: ${damageType.toUpperCase()} | Side: ${vanSide.replaceAll('_', ' ').toUpperCase()}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          if (damageDescription.isNotEmpty &&
              damageDescription != 'No description')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                damageDescription.length > 80
                    ? '${damageDescription.substring(0, 80)}...'
                    : damageDescription,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Image viewer
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Reset zoom when changing images
                _resetZoom();
              },
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return _buildImage(widget.images[index]);
              },
            ),

            // Top controls
            if (_showControls)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Transform.translate(
                      offset: Offset(0, -50 * (1 - _controlsAnimation.value)),
                      child: Opacity(
                        opacity: _controlsAnimation.value,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 8,
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_currentIndex + 1} of ${widget.images.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: IconButton(
                                  onPressed: _toggleImageDetails,
                                  icon: Icon(
                                    _showImageDetails
                                        ? Icons.info
                                        : Icons.info_outline,
                                    color: Colors.white,
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

            // Zoom controls
            if (_showControls)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: 16,
                    top: MediaQuery.of(context).size.height * 0.4,
                    child: Transform.translate(
                      offset: Offset(-80 * (1 - _controlsAnimation.value), 0),
                      child: Opacity(
                        opacity: _controlsAnimation.value,
                        child: _buildZoomControls(),
                      ),
                    ),
                  );
                },
              ),

            // Bottom navigation controls
            if (_showControls && widget.images.length > 1)
              AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Transform.translate(
                      offset: Offset(0, 80 * (1 - _controlsAnimation.value)),
                      child: Opacity(
                        opacity: _controlsAnimation.value,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 20,
                            bottom: MediaQuery.of(context).padding.bottom + 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Van side info for current image
                              if (widget.images[_currentIndex]['van_side'] !=
                                      null ||
                                  widget.images[_currentIndex]['location'] !=
                                      null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    (widget.images[_currentIndex]['van_side']
                                                ?.toString() ??
                                            widget.images[_currentIndex]
                                                    ['location']
                                                ?.toString() ??
                                            '')
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),

                              // Damage assessment for current image
                              _buildCurrentImageDamageAssessment(),

                              const SizedBox(height: 16),
                              // Navigation controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: IconButton(
                                      onPressed: _currentIndex > 0
                                          ? () {
                                              _pageController.previousPage(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                      icon: Icon(
                                        Icons.arrow_back_ios,
                                        color: _currentIndex > 0
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Page indicators
                                  ...List.generate(
                                    widget.images.length,
                                    (index) => GestureDetector(
                                      onTap: () {
                                        _pageController.animateToPage(
                                          index,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        width: index == _currentIndex ? 12 : 8,
                                        height: index == _currentIndex ? 12 : 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index == _currentIndex
                                              ? Colors.white
                                              : Colors.white38,
                                          boxShadow: index == _currentIndex
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.white
                                                        .withOpacity(0.5),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: IconButton(
                                      onPressed: _currentIndex <
                                              widget.images.length - 1
                                          ? () {
                                              _pageController.nextPage(
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                      icon: Icon(
                                        Icons.arrow_forward_ios,
                                        color: _currentIndex <
                                                widget.images.length - 1
                                            ? Colors.white
                                            : Colors.white38,
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
                  );
                },
              ),

            // Image details overlay
            if (_showImageDetails)
              Positioned(
                top: 100,
                right: 16,
                child: _buildImageDetails(widget.images[_currentIndex]),
              ),
          ],
        ),
      ),
    );
  }
}
