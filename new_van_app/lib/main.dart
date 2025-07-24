import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/environment.dart';
import 'providers/van_provider.dart';
import 'screens/home_screen.dart';
import 'screens/van_detail_screen.dart';
import 'screens/van_list_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment variables
  await Environment.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: Environment.supabaseUrl,
    anonKey: Environment.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuration Error',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The application is not properly configured. Please ensure you have set up your environment variables correctly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (Environment.supabaseUrl.isEmpty)
                  const Text(
                    'Missing Supabase URL',
                    style: TextStyle(color: Colors.red),
                  ),
                if (Environment.supabaseAnonKey.isEmpty)
                  const Text(
                    'Missing Supabase Anonymous Key',
                    style: TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Environment.initialize().then((_) {
                      if (Environment.isValid) {
                        runApp(const MyApp());
                      }
                    });
                  },
                  child: const Text('Retry Configuration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VanProvider(),
      child: MaterialApp(
        title: 'Van Fleet Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
        routes: {
          '/van-list': (context) => const VanListScreen(),
          '/van-detail': (context) => const VanDetailScreen(),
          '/maintenance': (context) => const MaintenanceScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
