import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/driver_provider.dart';
import '../models/driver_profile.dart';
import 'driver_detail_screen.dart';

class DriverListScreen extends StatelessWidget {
  const DriverListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DriverProvider>().refreshDrivers(),
          ),
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
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${provider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.refreshDrivers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.drivers.isEmpty) {
            return const Center(child: Text('No drivers found'));
          }

          return ListView.builder(
            itemCount: provider.drivers.length,
            itemBuilder: (context, index) {
              final driver = provider.drivers[index];
              return DriverListTile(driver: driver);
            },
          );
        },
      ),
    );
  }
}

class DriverListTile extends StatelessWidget {
  final DriverProfile driver;

  const DriverListTile({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final licenseExpiryColor =
        driver.licenseExpiry.isBefore(DateTime.now())
            ? Colors.red
            : driver.licenseExpiry.isBefore(
              DateTime.now().add(const Duration(days: 30)),
            )
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(driver.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('License: ${driver.licenseNumber}'),
            Text(
              'Expires: ${DateFormat('MMM d, yyyy').format(driver.licenseExpiry)}',
              style: TextStyle(color: licenseExpiryColor),
            ),
            Text('Status: ${driver.status}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverDetailScreen(driver: driver),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Driver'),
                        content: Text(
                          'Are you sure you want to delete ${driver.name}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<DriverProvider>().deleteDriver(
                                driver.id,
                              );
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailScreen(driver: driver),
            ),
          );
        },
      ),
    );
  }
}
