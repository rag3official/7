import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/van_provider.dart';
import 'lib/providers/driver_provider.dart';

void main() {
  runApp(PerformanceTestApp());
}

class PerformanceTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VanProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: MaterialApp(
        title: 'Performance Test',
        theme: ThemeData.dark(),
        home: PerformanceTestScreen(),
      ),
    );
  }
}

class PerformanceTestScreen extends StatefulWidget {
  @override
  _PerformanceTestScreenState createState() => _PerformanceTestScreenState();
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen> {
  DateTime? _startTime;
  DateTime? _endTime;
  String _status = 'Ready to test';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Performance Test'),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Test Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[100],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Status: $_status',
                        style: TextStyle(color: Colors.white)),
                    if (_startTime != null && _endTime != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Load Time: ${_endTime!.difference(_startTime!).inMilliseconds}ms',
                        style: TextStyle(color: Colors.green[300]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Consumer<VanProvider>(
              builder: (context, vanProvider, child) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Van Provider Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[100],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Loading: ${vanProvider.isLoading}',
                            style: TextStyle(color: Colors.white)),
                        Text('Vans Count: ${vanProvider.vans.length}',
                            style: TextStyle(color: Colors.white)),
                        Text('Error: ${vanProvider.error ?? "None"}',
                            style: TextStyle(color: Colors.white)),
                        if (vanProvider.vans.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                              'First Van: ${vanProvider.vans.first.plateNumber}',
                              style: TextStyle(color: Colors.green[300])),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Consumer<DriverProvider>(
              builder: (context, driverProvider, child) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Provider Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[100],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Loading: ${driverProvider.isLoading}',
                            style: TextStyle(color: Colors.white)),
                        Text('Drivers Count: ${driverProvider.drivers.length}',
                            style: TextStyle(color: Colors.white)),
                        Text('Error: ${driverProvider.error ?? "None"}',
                            style: TextStyle(color: Colors.white)),
                        if (driverProvider.drivers.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                              'First Driver: ${driverProvider.drivers.first.driverName}',
                              style: TextStyle(color: Colors.green[300])),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testVanLoading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: Text('Test Van Loading'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testDriverLoading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                    child: Text('Test Driver Loading'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testCache,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              child: Text('Test Cache Performance'),
            ),
          ],
        ),
      ),
    );
  }

  void _testVanLoading() async {
    setState(() {
      _status = 'Testing van loading...';
      _startTime = DateTime.now();
    });

    final vanProvider = Provider.of<VanProvider>(context, listen: false);
    await vanProvider.refreshVans();

    setState(() {
      _endTime = DateTime.now();
      _status = 'Van loading test completed';
    });
  }

  void _testDriverLoading() async {
    setState(() {
      _status = 'Testing driver loading...';
      _startTime = DateTime.now();
    });

    final driverProvider = Provider.of<DriverProvider>(context, listen: false);
    await driverProvider.refreshDrivers();

    setState(() {
      _endTime = DateTime.now();
      _status = 'Driver loading test completed';
    });
  }

  void _testCache() async {
    setState(() {
      _status = 'Testing cache performance...';
      _startTime = DateTime.now();
    });

    final vanProvider = Provider.of<VanProvider>(context, listen: false);

    // First load (should be slow)
    await vanProvider.refreshVans();

    // Second load (should be fast due to cache)
    await vanProvider.refreshVans();

    setState(() {
      _endTime = DateTime.now();
      _status = 'Cache test completed - check console for cache messages';
    });
  }
}
