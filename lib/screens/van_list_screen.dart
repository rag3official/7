import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';
import '../models/van.dart';
import '../widgets/premium_components.dart';
import '../widgets/premium_illustrations.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_glass_card.dart';
import '../widgets/premium_app_bar.dart';
import 'van_detail_screen.dart';
import 'van_profile_screen.dart';

class VanListScreen extends StatefulWidget {
  const VanListScreen({super.key});

  @override
  State<VanListScreen> createState() => _VanListScreenState();
}

class _VanListScreenState extends State<VanListScreen> {
  bool _isHighDamageVan(Van van) {
    // Check if van has damage based on status or notes
    final status = van.status.toLowerCase();
    final notes = van.notes?.toLowerCase() ?? '';
    return status == 'maintenance' ||
        status == 'inactive' ||
        notes.contains('damage') ||
        notes.contains('repair');
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              Hero(
                tag: 'van-fleet-icon',
                child: PremiumIllustrations.premiumVan(
                  width: 40,
                  height: 24,
                  enableAnimation: true,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Van Fleet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            GestureDetector(
              onTap: () => context.read<VanProvider>().refreshVans(),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        body: Consumer<VanProvider>(
          builder: (context, vanProvider, child) {
            if (vanProvider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading premium fleet data...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        vanProvider.error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
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
                      style: TextStyle(fontSize: 18, color: Colors.white),
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
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VanProfileScreen(van: van),
                        ),
                      );
                    },
                    child: PremiumGlassCard(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      enableGlow: _isHighDamageVan(van),
                      glowColor: _isHighDamageVan(van) ? Colors.red : null,
                      child: ListTile(
                        leading: Hero(
                          tag: 'van-${van.vanNumber ?? van.name}',
                          child: PremiumIllustrations.premiumVan(
                            width: 40,
                            height: 24,
                            enableAnimation: true,
                          ),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Van #${van.vanNumber ?? van.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isHighDamageVan(van)) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.red.withOpacity(0.8),
                                ),
                                child: Text(
                                  'ALERT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${van.make ?? 'Unknown'} ${van.model ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            if (van.currentDriverName != null &&
                                van.currentDriverName!.isNotEmpty)
                              Text(
                                'Driver: ${van.currentDriverName}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _getStatusColor(van.status).withOpacity(0.2),
                            border: Border.all(
                              color: _getStatusColor(van.status),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            van.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(van.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VanDetailScreen(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
