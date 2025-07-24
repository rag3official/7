import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/van.dart';
import '../models/maintenance_record.dart';
import '../providers/van_provider.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VanProvider>(
      builder: (context, vanProvider, child) {
        if (vanProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vanProvider.error != null) {
          return Center(child: Text('Error: ${vanProvider.error}'));
        }

        // Create a map of vans to their maintenance records
        final Map<Van, List<MaintenanceRecord>> maintenanceMap = {};
        for (final van in vanProvider.vans) {
          if (van.maintenanceHistory.isNotEmpty) {
            maintenanceMap[van] = van.maintenanceHistory;
          }
        }

        // Sort all maintenance records by date
        final sortedRecords = _sortMaintenanceRecords(maintenanceMap);

        if (sortedRecords.isEmpty) {
          return const Center(
            child: Text('No maintenance records found'),
          );
        }

        return ListView.builder(
          itemCount: sortedRecords.length,
          itemBuilder: (context, index) {
            final entry = sortedRecords[index];
            final van = entry.van;
            final record = entry.record;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('${van.vanNumber} - ${van.type}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title),
                    Text(record.description),
                    Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(record.date)}',
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () => _showMaintenanceDetails(context, van, record),
              ),
            );
          },
        );
      },
    );
  }

  List<MaintenanceEntry> _sortMaintenanceRecords(
    Map<Van, List<MaintenanceRecord>> records,
  ) {
    final allRecords = <MaintenanceEntry>[];

    // Flatten the map into a list of entries
    records.forEach((van, records) {
      for (final record in records) {
        allRecords.add(MaintenanceEntry(van: van, record: record));
      }
    });

    // Sort by date
    allRecords.sort((a, b) => b.record.date.compareTo(a.record.date));

    return allRecords;
  }

  void _showMaintenanceDetails(
    BuildContext context,
    Van van,
    MaintenanceRecord record,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${van.vanNumber} - ${record.title}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Van Type: ${van.type}'),
              const SizedBox(height: 8),
              Text('Date: ${DateFormat('yyyy-MM-dd').format(record.date)}'),
              const SizedBox(height: 8),
              Text('Type: ${record.type}'),
              const SizedBox(height: 8),
              Text('Description: ${record.description}'),
              const SizedBox(height: 8),
              Text('Technician: ${record.technician}'),
              const SizedBox(height: 8),
              Text('Cost: \$${record.cost.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Mileage: ${record.mileage}'),
              if (record.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes: ${record.notes}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class MaintenanceEntry {
  final Van van;
  final MaintenanceRecord record;

  MaintenanceEntry({required this.van, required this.record});
}
