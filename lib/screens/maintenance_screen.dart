import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VanProvider>(
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
                  onPressed: () => provider.refreshVans(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final maintenanceVans = provider.vans
            .where((van) => van.status.toLowerCase() == 'maintenance')
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
            return MaintenanceCard(van: van);
          },
        );
      },
    );
  }
}

class MaintenanceCard extends StatelessWidget {
  final Van van;

  const MaintenanceCard({super.key, required this.van});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              van.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${van.status}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (van.maintenanceNotes != null &&
                van.maintenanceNotes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Notes: ${van.maintenanceNotes}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/van-detail',
                      arguments: van,
                    );
                  },
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
