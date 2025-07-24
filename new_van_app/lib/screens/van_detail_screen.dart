import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';

class VanDetailScreen extends StatefulWidget {
  const VanDetailScreen({super.key});

  @override
  State<VanDetailScreen> createState() => _VanDetailScreenState();
}

class _VanDetailScreenState extends State<VanDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _status = 'active';
  String? _maintenanceNotes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Map<String, dynamic>? vanData =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (vanData != null) {
        final van = Van.fromJson(vanData);
        _nameController.text = van.name;
        _status = van.status;
        _maintenanceNotes = van.maintenanceNotes;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? vanData =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isEditing = vanData != null;
    final van = isEditing ? Van.fromJson(vanData) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Van' : 'Add Van'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Van'),
                    content:
                        const Text('Are you sure you want to delete this van?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<VanProvider>().deleteVan(van!.id);
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Go back to list
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(
                    value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(
                    value: 'out_of_service', child: Text('Out of Service')),
              ],
              onChanged: (value) {
                setState(() {
                  _status = value!;
                });
              },
            ),
            if (_status == 'maintenance') ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _maintenanceNotes,
                decoration: const InputDecoration(
                  labelText: 'Maintenance Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  _maintenanceNotes = value;
                },
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final data = {
              'name': _nameController.text,
              'status': _status,
              if (_status == 'maintenance')
                'maintenance_notes': _maintenanceNotes,
            };

            if (isEditing) {
              context.read<VanProvider>().updateVan(van!.id, data);
            } else {
              context.read<VanProvider>().addVan(data);
            }

            Navigator.pop(context);
          }
        },
        child: const Icon(Icons.save),
      ),
    );
  }
}
