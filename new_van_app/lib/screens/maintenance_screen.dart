import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
      ),
      body: Consumer<VanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final maintenanceVans = provider.vans
              .where((van) => van.status == 'maintenance')
              .toList();

          if (maintenanceVans.isEmpty) {
            return const Center(
              child: Text('No vans currently in maintenance'),
            );
          }

          return ListView.builder(
            itemCount: maintenanceVans.length,
            itemBuilder: (context, index) {
              final van = maintenanceVans[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.build, color: Colors.white),
                  ),
                  title: Text(van.name),
                  subtitle: Text(
                    van.maintenanceNotes ?? 'No maintenance notes',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/van-detail',
                      arguments: van.toJson(),
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
}
