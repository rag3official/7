import 'package:flutter/material.dart';
import '../services/enhanced_driver_service.dart';

class VanStatusDialog extends StatefulWidget {
  final int vanNumber;
  final String currentStatus;
  final Function(String newStatus)? onStatusChanged;

  const VanStatusDialog({
    super.key,
    required this.vanNumber,
    required this.currentStatus,
    this.onStatusChanged,
  });

  @override
  State<VanStatusDialog> createState() => _VanStatusDialogState();
}

class _VanStatusDialogState extends State<VanStatusDialog> {
  String _selectedStatus = '';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus() async {
    print(
        '🔥 _updateStatus called! Selected: $_selectedStatus, Current: ${widget.currentStatus}');
    debugPrint(
        '🔥 _updateStatus called! Selected: $_selectedStatus, Current: ${widget.currentStatus}');

    if (_selectedStatus == widget.currentStatus) {
      print('🔥 No change needed, closing dialog');
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isUpdating = true);

    try {
      print(
          '🔥 About to call EnhancedDriverService.updateVanStatus(${widget.vanNumber}, $_selectedStatus)');
      debugPrint(
          '🔥 About to call EnhancedDriverService.updateVanStatus(${widget.vanNumber}, $_selectedStatus)');

      final success = await EnhancedDriverService.updateVanStatus(
        widget.vanNumber,
        _selectedStatus,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      print('🔥 EnhancedDriverService.updateVanStatus returned: $success');
      debugPrint('🔥 EnhancedDriverService.updateVanStatus returned: $success');

      if (success) {
        if (mounted) {
          widget.onStatusChanged?.call(_selectedStatus);
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Van #${widget.vanNumber} status updated to ${EnhancedDriverService.statusConfig[_selectedStatus]?['label'] ?? _selectedStatus}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update van status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.local_shipping, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text('Van #${widget.vanNumber} Status'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select new status:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Status options
            ...EnhancedDriverService.availableStatuses.map((status) {
              final config = EnhancedDriverService.statusConfig[status]!;
              final isSelected = status == _selectedStatus;
              final isCurrent = status == widget.currentStatus;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? _getStatusColor(status)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? _getStatusColor(status).withOpacity(0.1)
                      : null,
                ),
                child: ListTile(
                  leading: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                  ),
                  title: Row(
                    children: [
                      Text(
                        config['label'],
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? _getStatusColor(status) : null,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    config['description'],
                    style: TextStyle(
                      color: isSelected
                          ? _getStatusColor(status)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() => _selectedStatus = status);
                  },
                ),
              );
            }).toList(),

            if (_selectedStatus != widget.currentStatus) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Reason field
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for change (optional)',
                  hintText: 'e.g., Scheduled maintenance, Engine trouble',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Notes field
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  hintText: 'Any additional details about the status change',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_add),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedStatus != widget.currentStatus
                ? _getStatusColor(_selectedStatus)
                : Colors.grey,
          ),
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _selectedStatus == widget.currentStatus
                      ? 'Close'
                      : 'Update Status',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}

// Helper function to show the status dialog
Future<void> showVanStatusDialog(
  BuildContext context, {
  required int vanNumber,
  required String currentStatus,
  Function(String newStatus)? onStatusChanged,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return VanStatusDialog(
        vanNumber: vanNumber,
        currentStatus: currentStatus,
        onStatusChanged: onStatusChanged,
      );
    },
  );
}
