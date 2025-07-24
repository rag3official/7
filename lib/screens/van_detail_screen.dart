import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/van.dart';
import '../providers/van_provider.dart';

class VanDetailScreen extends StatefulWidget {
  final Van? van;

  const VanDetailScreen({super.key, this.van});

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _maintenanceNotesController;
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.van?.name ?? '');
    _maintenanceNotesController =
        TextEditingController(text: widget.van?.maintenanceNotes ?? '');
    if (widget.van != null) {
      _status = widget.van!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maintenanceNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveVan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text,
        'status': _status,
        'maintenance_notes': _maintenanceNotesController.text,
      };

      if (widget.van != null) {
        await context.read<VanProvider>().updateVan(widget.van!.id, data);
      } else {
        await context.read<VanProvider>().addVan(data);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving van: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.van == null ? 'Add Van' : 'Edit Van'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Van Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'out_of_service',
                          child: Text('Out of Service'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maintenanceNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Maintenance Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveVan,
                      child: Text(
                        widget.van == null ? 'Add Van' : 'Save Changes',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
