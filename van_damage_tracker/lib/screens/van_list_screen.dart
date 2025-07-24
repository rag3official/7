import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';
import 'van_detail_screen.dart';

class VanListScreen extends StatefulWidget {
  const VanListScreen({super.key});

  @override
  State<VanListScreen> createState() => _VanListScreenState();
}

class _VanListScreenState extends State<VanListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Van> _filterVans(List<Van> vans) {
    return vans.where((van) {
      final matchesSearch =
          van.vanNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              van.type.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              van.driver.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _statusFilter == 'All' || van.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Van Fleet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<VanProvider>().refreshVans(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search vans...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _statusFilter == 'All',
                      onSelected: (selected) {
                        setState(() => _statusFilter = 'All');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Active'),
                      selected: _statusFilter == 'Active',
                      onSelected: (selected) {
                        setState(() => _statusFilter = 'Active');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Maintenance'),
                      selected: _statusFilter == 'Maintenance',
                      onSelected: (selected) {
                        setState(() => _statusFilter = 'Maintenance');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Out of Service'),
                      selected: _statusFilter == 'Out of Service',
                      onSelected: (selected) {
                        setState(() => _statusFilter = 'Out of Service');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<VanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    textAlign: TextAlign.center,
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

          final filteredVans = _filterVans(provider.vans);

          if (filteredVans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_transfer, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    provider.vans.isEmpty
                        ? 'No vans found'
                        : 'No vans match your search',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredVans.length,
            itemBuilder: (context, index) {
              final van = filteredVans[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(van.status),
                    child: Text(
                      van.vanNumber.isNotEmpty ? van.vanNumber[0] : '#',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Van #${van.vanNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (van.driver.isNotEmpty)
                              Flexible(
                                child: Chip(
                                  label: Text(
                                    van.driver,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        van.type,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (van.damage.isNotEmpty)
                        Text(
                          'Damage: ${van.damage}',
                          style: const TextStyle(color: Colors.red),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      if (van.maintenanceHistory.isNotEmpty)
                        Text(
                          'Last maintenance: ${van.maintenanceHistory.last.date.toString().split(' ')[0]}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Chip(
                            label: Text(
                              van.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            backgroundColor: _getStatusColor(van.status),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (van.rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return Icon(
                                index < van.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 12,
                                color: Colors.amber,
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VanDetailScreen(van: van),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_van_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VanDetailScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'out of service':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
