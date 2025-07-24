import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/van_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Data'),
              subtitle: const Text('Manually refresh van data from the server'),
              onTap: () {
                context.read<VanProvider>().refreshVans();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing data...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Van Damage Tracker v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Van Damage Tracker',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024',
                  children: [
                    const Text(
                      'A comprehensive van fleet management application for tracking vehicle damage, maintenance, and repairs.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
