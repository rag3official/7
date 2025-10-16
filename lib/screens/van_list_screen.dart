import 'package:flutter/material.dart';
import '../widgets/van_profile_image.dart';
import '../services/van_image_service.dart';

class VanListScreen extends StatelessWidget {
  const VanListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Van List'),
      ),
      body: ListView.builder(
        itemCount: 50, // Assuming vans 1-50
        itemBuilder: (context, index) {
          final vanNumber = index + 1;
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Van $vanNumber',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VanImageUploadScreen(
                                    vanNumber: vanNumber,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Upload Images'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
