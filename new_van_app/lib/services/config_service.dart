import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static Future<void> load() async {
    try {
      await dotenv.load();
      print('Environment variables loaded successfully');

      // Validate required environment variables
      if (supabaseUrl.isEmpty) {
        throw 'SUPABASE_URL is not set in .env file';
      }
      if (supabaseAnonKey.isEmpty) {
        throw 'SUPABASE_ANON_KEY is not set in .env file';
      }
    } catch (e) {
      print('Error loading environment variables: $e');
      rethrow;
    }
  }
}
