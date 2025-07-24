import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing Supabase storage access...');

  const supabaseUrl = 'https://lcvbagsksedduygdzsca.supabase.co';
  const supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjdmJhZ3Nrc2VkZHV5Z2R6c2NhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY2MTI0OTgsImV4cCI6MjAyMjE4ODQ5OH0.vkGmkfzumkRacnhsHm2zx-YKE8uuDojT4ZcJBGdKrfE';

  try {
    print('📡 Testing storage API access...');

    // Test storage buckets endpoint
    final response = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
      },
    );

    print('Status: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final buckets = json.decode(response.body) as List;
      print('✅ Found ${buckets.length} buckets');
      for (var bucket in buckets) {
        print(
            '  📦 ${bucket['name']} (${bucket['public'] ? 'public' : 'private'})');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e, stackTrace) {
    print('❌ Exception: $e');
    print('Stack trace: $stackTrace');
  }
}
