import 'package:flutter/material.dart';
import '../models/driver_profile.dart';
import '../services/driver_service.dart';

class DriverDetailPage extends StatefulWidget {
  final DriverProfile driver;
  final DriverService driverService;

  const DriverDetailPage({
    Key? key,
    required this.driver,
    required this.driverService,
  }) : super(key: key);

  @override
  _DriverDetailPageState createState() => _DriverDetailPageState();
}

class _DriverDetailPageState extends State<DriverDetailPage> {
  late Future<List<Map<String, dynamic>>> _assignmentsFuture;
  late Future<List<Map<String, dynamic>>> _uploadsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _assignmentsFuture = widget.driverService.getDriverAssignments(
      widget.driver.id,
    );
    _uploadsFuture = widget.driverService.getDriverUploads(widget.driver.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.driver.slackUsername),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Assignments'),
              Tab(text: 'Uploads'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(),
            _buildAssignmentsTab(),
            _buildUploadsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      widget.driver.slackUsername[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Slack Username', widget.driver.slackUsername),
                  if (widget.driver.fullName != null)
                    _buildInfoRow('Full Name', widget.driver.fullName!),
                  if (widget.driver.email != null)
                    _buildInfoRow('Email', widget.driver.email!),
                  if (widget.driver.phone != null)
                    _buildInfoRow('Phone', widget.driver.phone!),
                  _buildInfoRow('Status', widget.driver.status),
                  _buildInfoRow(
                    'Member Since',
                    widget.driver.createdAt.toLocal().toString().split('.')[0],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _assignmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final assignments = snapshot.data ?? [];

        if (assignments.isEmpty) {
          return const Center(child: Text('No assignments found'));
        }

        return ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            final van = assignment['vans'];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Van ${van['van_number']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${assignment['assignment_date']}'),
                    Text('Status: ${assignment['status']}'),
                    if (assignment['notes'] != null)
                      Text('Notes: ${assignment['notes']}'),
                  ],
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color:
                        assignment['status'] == 'active'
                            ? Colors.green
                            : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    assignment['status'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUploadsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _uploadsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final uploads = snapshot.data ?? [];

        if (uploads.isEmpty) {
          return const Center(child: Text('No uploads found'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: uploads.length,
          itemBuilder: (context, index) {
            final upload = uploads[index];
            final vanImage = upload['van_images'];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Image.network(
                    vanImage['image_url'],
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Damage Level: ${vanImage['damage_level']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            upload['upload_timestamp'].toString().split('.')[0],
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
