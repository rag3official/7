import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/driver_profile.dart';
import '../providers/driver_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverDetailScreen extends StatefulWidget {
  final DriverProfile? driver;

  const DriverDetailScreen({super.key, this.driver});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _emailController;
  DateTime _licenseExpiry = DateTime.now().add(const Duration(days: 365));
  String _status = 'active';
  DateTime? _lastMedicalCheck;
  List<String> _certifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver?.name ?? '');
    _licenseNumberController = TextEditingController(
      text: widget.driver?.licenseNumber ?? '',
    );
    _phoneNumberController = TextEditingController(
      text: widget.driver?.phoneNumber ?? '',
    );
    _emailController = TextEditingController(text: widget.driver?.email ?? '');

    if (widget.driver != null) {
      _licenseExpiry = widget.driver!.licenseExpiry ?? DateTime.now().add(const Duration(days: 365));
      _status = widget.driver!.status;
      _lastMedicalCheck = widget.driver!.lastMedicalCheck;
      _certifications = List.from(widget.driver!.certifications);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseNumberController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isLicenseExpiry) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isLicenseExpiry
          ? _licenseExpiry
          : _lastMedicalCheck ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isLicenseExpiry) {
          _licenseExpiry = picked;
        } else {
          _lastMedicalCheck = picked;
        }
      });
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.driver != null) {
        final updatedDriver = DriverProfile(
          id: widget.driver!.id,
          userId: widget.driver!.userId,
          name: _nameController.text,
          licenseNumber: _licenseNumberController.text,
          licenseExpiry: _licenseExpiry,
          phoneNumber: _phoneNumberController.text,
          email: _emailController.text,
          lastMedicalCheck: _lastMedicalCheck,
          certifications: _certifications,
          status: _status,
          createdAt: widget.driver!.createdAt,
          updatedAt: DateTime.now(),
        );
        await context.read<DriverProvider>().updateDriver(updatedDriver);
      } else {
        // Get the current user's ID from Supabase
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          throw Exception('No authenticated user');
        }

        final driver = DriverProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          name: _nameController.text,
          licenseNumber: _licenseNumberController.text,
          licenseExpiry: _licenseExpiry,
          phoneNumber: _phoneNumberController.text,
          email: _emailController.text,
          lastMedicalCheck: _lastMedicalCheck,
          certifications: _certifications,
          status: _status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await context.read<DriverProvider>().createDriver(driver);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving driver: $e')));
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
        title: Text(widget.driver == null ? 'Add Driver' : 'Edit Driver'),
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
                        labelText: 'Name',
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
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'License Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'License Expiry',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_licenseExpiry ?? DateTime.now()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
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
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                        DropdownMenuItem(
                          value: 'on_leave',
                          child: Text('On Leave'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Last Medical Check',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _lastMedicalCheck != null
                              ? DateFormat('MMM d, yyyy')
                                  .format(_lastMedicalCheck!)
                              : 'Not set',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: const Text('Certifications'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    String newCertification = '';
                                    return AlertDialog(
                                      title: const Text('Add Certification'),
                                      content: TextField(
                                        onChanged: (value) =>
                                            newCertification = value,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter certification name',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            if (newCertification.isNotEmpty) {
                                              setState(() {
                                                _certifications
                                                    .add(newCertification);
                                              });
                                            }
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          if (_certifications.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Wrap(
                                spacing: 8.0,
                                children: _certifications
                                    .map(
                                      (cert) => Chip(
                                        label: Text(cert),
                                        onDeleted: () {
                                          setState(() {
                                            _certifications.remove(cert);
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveDriver,
                      child: Text(
                        widget.driver == null ? 'Add Driver' : 'Save Changes',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
