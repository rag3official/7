import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/van_image_service.dart';

class VanImageWidget extends StatelessWidget {
  final VanImage image;
  final double? width;
  final double? height;
  final BoxFit fit;

  const VanImageWidget({
    Key? key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    // For base64 data in image_data field
    if (image.imageData != null && image.imageData!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(image.imageData!);
        return Image.memory(
          imageBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading base64 image from image_data: $error');
            return _buildErrorWidget();
          },
        );
      } catch (e) {
        print('❌ Error decoding base64 from image_data: $e');
        return _buildErrorWidget();
      }
    }

    // For data URLs in image_url field
    if (image.imageUrl.startsWith('data:')) {
      try {
        // Extract base64 data from data URL
        final base64Data = image.imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64Data);
        return Image.memory(
          imageBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error loading base64 image from data URL: $error');
            return _buildErrorWidget();
          },
        );
      } catch (e) {
        print('❌ Error decoding base64 from data URL: $e');
        return _buildErrorWidget();
      }
    }

    // For storage URLs
    if (image.imageUrl.startsWith('https://')) {
      return Image.network(
        image.imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingWidget(loadingProgress);
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading network image: $error');
          print('🔍 URL: ${image.imageUrl}');
          return _buildErrorWidget();
        },
      );
    }

    print('❌ No valid image source found:');
    print('🔍 image_data: ${image.imageData?.substring(0, 50)}...');
    print('🔍 image_url: ${image.imageUrl}');
    print('🔍 content_type: ${image.contentType}');
    print('🔍 storage_type: ${image.storageType}');
    return _buildErrorWidget();
  }

  Widget _buildLoadingWidget(ImageChunkEvent loadingProgress) {
    return Center(
      child: CircularProgressIndicator(
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Invalid image data',
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 4),
          Text(
            'Cannot decode base64 data',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
