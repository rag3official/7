import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/van_service.dart';

class DamageReportDialog extends StatefulWidget {
  final String vanId;
  final VanService vanService;

  const DamageReportDialog({
    Key? key,
    required this.vanId,
    required this.vanService,
  }) : super(key: key);

  @override
  _DamageReportDialogState createState() => _DamageReportDialogState();
}

class _DamageReportDialogState extends State<DamageReportDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick images: $e';
      });
    }
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter a damage description';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Upload images and get their URLs
      List<String> imageUrls = [];
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final fileName = image.name;
        final imageUrl = await widget.vanService.uploadImage(
          widget.vanId,
          fileName,
          bytes,
        );
        imageUrls.add(imageUrl);
      }

      // Add damage report with images
      await widget.vanService.addDamageReport(
        widget.vanId,
        _descriptionController.text.trim(),
        imageUrls,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to submit damage report: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Damage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Damage Description',
                hintText: 'Describe the damage...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImages,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Photos'),
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedImages.length} ${_selectedImages.length == 1 ? 'photo' : 'photos'} selected',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
