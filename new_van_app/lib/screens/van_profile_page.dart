import 'package:flutter/material.dart';
import '../models/van.dart';
import '../widgets/full_screen_image.dart';
import '../widgets/damage_report_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/van_service.dart';

class VanProfilePage extends StatefulWidget {
  final Van van;

  const VanProfilePage({Key? key, required this.van}) : super(key: key);

  @override
  _VanProfilePageState createState() => _VanProfilePageState();
}

class _VanProfilePageState extends State<VanProfilePage> {
  final VanService _vanService = VanService(Supabase.instance.client);
  bool _isLoading = false;
  String? _error;
  late Van _currentVan;

  @override
  void initState() {
    super.initState();
    _currentVan = widget.van;
  }

  Future<void> _updateVanStatus(String newStatus) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final updatedVan = Van(
        id: _currentVan.id,
        vanNumber: _currentVan.vanNumber,
        type: _currentVan.type,
        status: newStatus,
        notes: _currentVan.notes,
        url: _currentVan.url,
        imageUrls: _currentVan.imageUrls,
        driver: _currentVan.driver,
        damage: _currentVan.damage,
        damageDescription: _currentVan.damageDescription,
        rating: _currentVan.rating,
        createdAt: _currentVan.createdAt,
        lastUpdated: DateTime.now(),
      );

      await _vanService.updateVan(updatedVan);

      if (mounted) {
        setState(() {
          _currentVan = updatedVan;
          _isLoading = false;
        });
        Navigator.pop(context); // Close the status dialog
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to update van status: $e';
        });
      }
    }
  }

  Future<void> _showDamageReportDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DamageReportDialog(
        vanId: _currentVan.id,
        vanService: _vanService,
      ),
    );

    if (result == true && mounted) {
      // Reload van data
      try {
        final updatedVan =
            await _vanService.getVanByNumber(_currentVan.vanNumber);
        setState(() {
          _currentVan = updatedVan;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh van data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.green),
              title: const Text('Active'),
              onTap: () => _updateVanStatus('active'),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.orange),
              title: const Text('Maintenance'),
              onTap: () => _updateVanStatus('maintenance'),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red),
              title: const Text('Out of Service'),
              onTap: () => _updateVanStatus('out_of_service'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteImage(String imageUrl) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _vanService.deleteImage(_currentVan.id, imageUrl);

      // Reload van data
      final updatedVan =
          await _vanService.getVanByNumber(_currentVan.vanNumber);

      if (mounted) {
        setState(() {
          _currentVan = updatedVan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to delete image: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Van #${_currentVan.vanNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: _showStatusUpdateDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentVan.imageUrls.isNotEmpty) ...[
                  SizedBox(
                    height: _currentVan.imageUrls.length == 1 ? 200 : 300,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            _currentVan.imageUrls.length == 1 ? 1 : 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _currentVan.imageUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenImageViewer(
                                      imageUrls: _currentVan.imageUrls,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Hero(
                                tag: 'van_image_$index',
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          _currentVan.imageUrls[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.white),
                                onPressed: () =>
                                    _deleteImage(_currentVan.imageUrls[index]),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Status', _currentVan.status,
                            _getStatusColor(_currentVan.status)),
                        const Divider(),
                        _buildInfoRow('Type', _currentVan.type ?? 'Unknown'),
                        const Divider(),
                        _buildInfoRow('Rating', '${_currentVan.rating}'),
                        if (_currentVan.driver != null &&
                            _currentVan.driver!.isNotEmpty) ...[
                          const Divider(),
                          _buildInfoRow('Driver', _currentVan.driver!),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_currentVan.damageDescription != null &&
                    _currentVan.damageDescription!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Damage Report',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_currentVan.damageDescription!),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_currentVan.notes != null &&
                    _currentVan.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_currentVan.notes!),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timeline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                            'Created', _formatDate(_currentVan.createdAt)),
                        const Divider(),
                        _buildInfoRow('Last Updated',
                            _formatDate(_currentVan.lastUpdated)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_error != null)
            Container(
              color: Colors.black.withOpacity(0.3),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDamageReportDialog,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
}
