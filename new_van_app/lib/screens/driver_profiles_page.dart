import 'package:flutter/material.dart';
import '../models/driver_profile.dart';
import '../services/driver_service.dart';
import 'driver_detail_page.dart';

class DriverProfilesPage extends StatefulWidget {
  final DriverService driverService;

  const DriverProfilesPage({Key? key, required this.driverService})
    : super(key: key);

  @override
  _DriverProfilesPageState createState() => _DriverProfilesPageState();
}

class _DriverProfilesPageState extends State<DriverProfilesPage> {
  late Future<List<DriverProfile>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  void _loadDrivers() {
    _driversFuture = widget.driverService.getAllDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadDrivers();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<DriverProfile>>(
        future: _driversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading drivers: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadDrivers();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final drivers = snapshot.data ?? [];

          if (drivers.isEmpty) {
            return const Center(child: Text('No drivers found'));
          }

          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(driver.slackUsername[0].toUpperCase()),
                  ),
                  title: Text(driver.slackUsername),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (driver.fullName != null) Text(driver.fullName!),
                      Text('Status: ${driver.status}'),
                    ],
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color:
                          driver.status == 'active'
                              ? Colors.green
                              : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      driver.status,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => DriverDetailPage(
                              driver: driver,
                              driverService: widget.driverService,
                            ),
                      ),
                    ).then((_) {
                      // Refresh the list when returning from detail page
                      setState(() {
                        _loadDrivers();
                      });
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
