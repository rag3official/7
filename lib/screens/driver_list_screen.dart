import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/driver_provider.dart';
import 'driver_detail_screen.dart';

class DriverListScreen extends StatelessWidget {
  const DriverListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DriverDetailScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<DriverProvider>(
        builder: (context, driverProvider, child) {
          if (driverProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (driverProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${driverProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => driverProvider.refreshDrivers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final drivers = driverProvider.drivers;
          if (drivers.isEmpty) {
            return const Center(
              child: Text('No drivers found'),
            );
          }

          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final licenseExpiryColor =
                  _getLicenseExpiryColor(driver.licenseExpiry);
              final medicalCheckColor =
                  _getMedicalCheckColor(driver.lastMedicalCheck);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(driver.name[0].toUpperCase()),
                  ),
                  title: Text(driver.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.drive_eta,
                              size: 16, color: licenseExpiryColor),
                          const SizedBox(width: 4),
                          Text(
                            'License: ${DateFormat('MMM dd, yyyy').format(driver.licenseExpiry)}',
                            style: TextStyle(color: licenseExpiryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.medical_services,
                              size: 16, color: medicalCheckColor),
                          const SizedBox(width: 4),
                          Text(
                            'Medical: ${driver.lastMedicalCheck != null ? DateFormat('MMM dd, yyyy').format(driver.lastMedicalCheck!) : 'Not set'}',
                            style: TextStyle(color: medicalCheckColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(driver.status),
                    backgroundColor: _getStatusColor(driver.status),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DriverDetailScreen(driver: driver),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getLicenseExpiryColor(DateTime expiryDate) {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    if (daysUntilExpiry < 0) return Colors.red;
    if (daysUntilExpiry < 30) return Colors.orange;
    return Colors.green;
  }

  Color _getMedicalCheckColor(DateTime? checkDate) {
    if (checkDate == null) return Colors.grey;
    final daysSinceCheck = DateTime.now().difference(checkDate).inDays;
    if (daysSinceCheck > 365) return Colors.red;
    if (daysSinceCheck > 300) return Colors.orange;
    return Colors.green;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.shade100;
      case 'inactive':
        return Colors.grey.shade300;
      case 'suspended':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
