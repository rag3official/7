import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';

class VanListScreen extends StatelessWidget {
  const VanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚐 Vans Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<VanProvider>(
        builder: (context, vanProvider, child) {
          if (vanProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading vans...'),
                ],
              ),
            );
          }

          if (vanProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load vans',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      vanProvider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => vanProvider.refreshVans(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (vanProvider.vans.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No vans found',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vans will appear here when added to the database',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => vanProvider.refreshVans(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vanProvider.vans.length,
              itemBuilder: (context, index) {
                final van = vanProvider.vans[index];
                return VanCard(van: van);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new van functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add van feature coming soon!')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class VanCard extends StatelessWidget {
  final Van van;

  const VanCard({super.key, required this.van});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(van.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Van ${van.vanNumber ?? van.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(van.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    van.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(van.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (van.make != null || van.model != null) ...[
              Row(
                children: [
                  const Icon(Icons.directions_car,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${van.make ?? 'Unknown'} ${van.model ?? ''}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (van.currentDriverName != null) ...[
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Driver: ${van.currentDriverName}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (van.imageUrls.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.photo_library, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${van.imageUrls.length} image(s)'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (van.notes != null && van.notes!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      van.notes!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
