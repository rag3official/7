import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runApp(VanDataTestApp());
}

class VanDataTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Van Data Test',
      theme: ThemeData.dark(),
      home: VanDataTestScreen(),
    );
  }
}

class VanDataTestScreen extends StatefulWidget {
  @override
  _VanDataTestScreenState createState() => _VanDataTestScreenState();
}

class _VanDataTestScreenState extends State<VanDataTestScreen> {
  String _status = 'Ready to test';
  List<Map<String, dynamic>> _vanData = [];
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Van Data Test'),
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
                      'Van Profiles Table Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[100],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Status: $_status',
                        style: TextStyle(color: Colors.white)),
                    if (_error.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text('Error: $_error',
                          style: TextStyle(color: Colors.red[300])),
                    ],
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _testVanProfiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                      ),
                      child: Text('Test Van Profiles Table'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            if (_vanData.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Van Data Found (${_vanData.length} vans)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[100],
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(_vanData.take(5).map((van) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Van #${van['van_number'] ?? 'Unknown'}: ${van['make'] ?? 'Unknown'} ${van['model'] ?? ''}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ))),
                      if (_vanData.length > 5) ...[
                        SizedBox(height: 8),
                        Text(
                          '... and ${_vanData.length - 5} more vans',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _testVanProfiles() async {
    setState(() {
      _status = 'Testing van_profiles table...';
      _error = '';
      _vanData = [];
    });

    try {
      final supabase = Supabase.instance.client;

      print('🔍 Testing van_profiles table access...');

      // Test 1: Check if table exists
      setState(() {
        _status = 'Checking if van_profiles table exists...';
      });

      final response =
          await supabase.from('van_profiles').select('*').limit(10);

      print('✅ van_profiles table exists and is accessible');
      print('📊 Found ${response.length} van profiles');

      if (response.isNotEmpty) {
        print('📝 First van: ${response.first}');
      }

      setState(() {
        _status = 'Found ${response.length} van profiles in database';
        _vanData = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('❌ Error testing van_profiles: $e');
      setState(() {
        _status = 'Error occurred';
        _error = e.toString();
      });
    }
  }
}
