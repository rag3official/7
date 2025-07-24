import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/van.dart';
import '../models/van_image.dart';
import '../providers/van_provider.dart';
import '../services/van_service.dart';

class VanDetailScreen extends StatefulWidget {
  final Van? van;

  const VanDetailScreen({super.key, this.van});

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _damageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _damageDescriptionController =
      TextEditingController();
  String _status = 'Active';
  String _model = 'Ford Transit';
  final List<String> _statusOptions = [
    'Active',
    'Maintenance',
    'Out of Service'
  ];
  final List<String> _modelOptions = [
    'Ford Transit',
    'Mercedes Sprinter',
    'Iveco Daily'
  ];
  String _rating = '3';
  bool _isSaving = false;
  String? _imageUrl;

  // Add date range filter state
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Initialize with last 30 days as default
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    if (widget.van != null) {
      _plateNumberController.text = widget.van!.plateNumber;
      _model = _modelOptions.contains(widget.van!.model)
          ? widget.van!.model
          : 'Ford Transit';
      _yearController.text = widget.van!.year;
      _statusController.text = widget.van!.status;
      _driverController.text = widget.van!.driverName ?? '';
      _damageController.text = widget.van!.damage ?? '';
      _notesController.text = widget.van!.notes ?? '';
      _damageDescriptionController.text = widget.van!.damageDescription ?? '';
      _status = _statusOptions.contains(widget.van!.status)
          ? widget.van!.status
          : 'Active';
      _rating = widget.van!.rating ?? '3';
      _imageUrl = widget.van!.url;
    }
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _statusController.dispose();
    _driverController.dispose();
    _damageController.dispose();
    _notesController.dispose();
    _damageDescriptionController.dispose();
    super.dispose();
  }

  // Add date range picker method
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Theme.of(context).colorScheme.primary,
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Widget _buildImageGallery() {
    return FutureBuilder<List<VanImage>>(
      future: VanService().getVanImages(widget.van?.id ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 10),
                  Text('Error loading images: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('No images available for this van'),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Van Images (${images.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () {
                        _showImageDetails(image);
                      },
                      child: Container(
                        width: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  image.imageUrl,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 200,
                                      color: Colors.grey.shade200,
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image,
                                              size: 48, color: Colors.grey),
                                          Text('Image not available'),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              width: 200,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(8),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (image.damageType != null)
                                    Text(
                                      'Type: ${image.damageType}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  if (image.damageLevel != null)
                                    Text(
                                      'Level: ${image.damageLevel}/5',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (image.location != null)
                                    Text(
                                      'Location: ${image.location}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    'Uploaded: ${image.uploadedAt.toString().split(' ')[0]}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
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
              ),
            ),
          ],
        );
      },
    );
  }

  void _showImageDetails(VanImage image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              AppBar(
                title: const Text('Image Details'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        image.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey),
                                Text('Image not available'),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (image.description != null) ...[
                        const Text('Description:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(image.description!),
                        const SizedBox(height: 12),
                      ],
                      if (image.damageType != null) ...[
                        const Text('Damage Type:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(image.damageType!),
                        const SizedBox(height: 12),
                      ],
                      if (image.damageLevel != null) ...[
                        const Text('Damage Level:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${image.damageLevel}/5'),
                        const SizedBox(height: 12),
                      ],
                      if (image.location != null) ...[
                        const Text('Location:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(image.location!),
                        const SizedBox(height: 12),
                      ],
                      if (image.driverName != null) ...[
                        const Text('Uploaded by:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(image.driverName!),
                        const SizedBox(height: 12),
                      ],
                      const Text('Upload Date:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(image.uploadedAt.toString()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.van == null
            ? 'Create New Van'
            : 'Van ${widget.van!.plateNumber}'),
        actions: [
          if (widget.van != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteVan,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add the image gallery at the top only for existing vans
            if (widget.van != null) _buildImageGallery(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _plateNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Plate Number *',
                        border: OutlineInputBorder(),
                        helperText: 'Enter the license plate number',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a plate number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _model,
                      decoration: const InputDecoration(
                        labelText: 'Model *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the model of van',
                      ),
                      items: _modelOptions.map((String model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null &&
                            _modelOptions.contains(newValue)) {
                          setState(() {
                            _model = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || !_modelOptions.contains(value)) {
                          return 'Please select a van model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Year *',
                        border: OutlineInputBorder(),
                        helperText: 'Enter the year of manufacture',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the current status of the van',
                      ),
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null &&
                            _statusOptions.contains(newValue)) {
                          setState(() {
                            _status = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || !_statusOptions.contains(value)) {
                          return 'Please select a valid status';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _driverController,
                      decoration: const InputDecoration(
                        labelText: 'Driver',
                        border: OutlineInputBorder(),
                        helperText:
                            'Enter the name of the assigned driver (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _damageController,
                      decoration: const InputDecoration(
                        labelText: 'Damage Description',
                        border: OutlineInputBorder(),
                        helperText:
                            'Describe any current damage to the van (optional)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        helperText:
                            'Add any additional notes about the van (optional)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Condition Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _rating,
                          decoration: const InputDecoration(
                            labelText: 'Rating',
                            border: OutlineInputBorder(),
                            helperText:
                                'Rate the van\'s condition from 1 (poor) to 5 (excellent)',
                          ),
                          items: ['1', '2', '3', '4', '5'].map((String rating) {
                            return DropdownMenuItem<String>(
                              value: rating,
                              child:
                                  Text('$rating - ${_getRatingLabel(rating)}'),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _rating = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveVan,
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Saving...'),
                                ],
                              )
                            : Text(widget.van == null
                                ? 'Create Van'
                                : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteVan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Van'),
        content: const Text('Are you sure you want to delete this van?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final vanProvider =
                  Provider.of<VanProvider>(context, listen: false);
              await vanProvider.deleteVan(widget.van!.id);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveVan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final van = Van(
        id: widget.van?.id ?? '',
        plateNumber: _plateNumberController.text,
        model: _model,
        year: _yearController.text,
        status: _status,
        lastInspection: now,
        notes: _notesController.text,
        url: _imageUrl ?? '',
        driverName: _driverController.text,
        damage: _damageController.text,
        damageDescription: _damageDescriptionController.text,
        rating: _rating,
      );

      await context.read<VanProvider>().saveVan(van);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.van == null
                  ? 'Van ${van.plateNumber} created successfully'
                  : 'Van ${van.plateNumber} updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving van: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getRatingLabel(String rating) {
    switch (rating) {
      case '1':
        return 'Poor';
      case '2':
        return 'Fair';
      case '3':
        return 'Good';
      case '4':
        return 'Very Good';
      case '5':
        return 'Excellent';
      default:
        return 'Good';
    }
  }
}
