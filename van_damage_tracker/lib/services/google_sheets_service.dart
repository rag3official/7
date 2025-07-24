import 'dart:convert';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/van.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../utils/sheets_config.dart';

class GoogleSheetsService {
  static const _scopes = [SheetsApi.spreadsheetsScope];

  // Spreadsheet ID and sheet name from config
  static const _spreadsheetId = SheetsConfig.spreadsheetId;
  static const _sheetName = SheetsConfig.vansWorksheetName;

  // Singleton instance
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // AuthClient and SheetsApi instances
  AuthClient? _client;
  SheetsApi? _sheetsApi;

  // Cache for van data
  List<Van> _cachedVans = [];
  DateTime? _lastFetched;

  // Initialize the service by authenticating
  Future<void> init() async {
    if (_client != null) return;

    try {
      // Use service account authentication with the credentials from SheetsConfig
      final serviceAccountCredentials = ServiceAccountCredentials.fromJson(
        jsonDecode(SheetsConfig.credentials),
      );

      _client = await clientViaServiceAccount(
        serviceAccountCredentials,
        _scopes,
      );
      _sheetsApi = SheetsApi(_client!);
      debugPrint('Google Sheets API initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Google Sheets API: $e');
      rethrow;
    }
  }

  // Fetch all vans from the Google Sheet
  Future<List<Van>> fetchVans({bool forceRefresh = false}) async {
    // Check if we have cached data that's less than the configured sync interval
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetched != null &&
        now.difference(_lastFetched!).inMinutes <
            SheetsConfig.syncIntervalMinutes &&
        _cachedVans.isNotEmpty) {
      return _cachedVans;
    }

    await init();

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        '$_sheetName!A2:J', // Assuming header is in row 1
      );

      final values = response.values;
      if (values == null || values.isEmpty) {
        return [];
      }

      // Process sheet data into van objects
      List<Van> allVans =
          values.map((row) {
            // Convert the row to a list of strings, handling potential null values
            final stringRow =
                row.map((cell) => cell?.toString() ?? '').toList();
            // Pad the row with empty strings if it's shorter than expected
            while (stringRow.length < 10) {
              stringRow.add('');
            }

            // Process URL field to ensure it's valid
            stringRow[6] = _processUrl(stringRow[6]); // URL is at index 6

            return Van.fromSheetRow(stringRow);
          }).toList();

      // Consolidate vans with the same van number, keeping only the most recent entry
      // Create a map of van number to van, overwriting with newer entries
      Map<String, Van> vanMap = {};

      for (var van in allVans) {
        // Skip empty van numbers
        if (van.vanNumber.isEmpty) continue;

        // If this van number already exists in our map, decide which to keep
        if (vanMap.containsKey(van.vanNumber)) {
          Van existingVan = vanMap[van.vanNumber]!;

          // Compare dates to keep the most recent entry
          DateTime existingDate;
          DateTime currentDate;

          try {
            existingDate = DateFormat(
              'yyyy-MM-dd',
            ).parse(existingVan.lastUpdated);
          } catch (e) {
            existingDate = DateTime(1900); // Default old date if parsing fails
          }

          try {
            currentDate = DateFormat('yyyy-MM-dd').parse(van.lastUpdated);
          } catch (e) {
            currentDate = DateTime(1900); // Default old date if parsing fails
          }

          // Keep the newer entry
          if (currentDate.isAfter(existingDate)) {
            vanMap[van.vanNumber] = van;
            debugPrint(
              'Updated consolidated van ${van.vanNumber} with newer entry',
            );
          }
        } else {
          // New van number, add it to the map
          vanMap[van.vanNumber] = van;
        }
      }

      // Convert map back to list
      _cachedVans = vanMap.values.toList();
      _lastFetched = now;

      debugPrint(
        'Fetched ${allVans.length} van records, consolidated to ${_cachedVans.length} unique vans',
      );
      return _cachedVans;
    } catch (e) {
      debugPrint('Error fetching vans from Google Sheets: $e');
      rethrow;
    }
  }

  // Process and validate URL
  String _processUrl(String url) {
    if (url.isEmpty) return '';

    // Trim whitespace
    url = url.trim();

    // Check if URL has a scheme (http:// or https://)
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Add https:// as default scheme
      url = 'https://$url';
    }

    // Simple validation - ensure it looks like a URL
    bool isValidUrl = Uri.tryParse(url)?.hasScheme ?? false;

    // For image validation, check common image extensions
    // This is a simple check, more robust validation might be needed
    bool looksLikeImageUrl =
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.gif') ||
        url.toLowerCase().endsWith('.webp') ||
        url.contains('images') ||
        url.contains('photos') ||
        url.contains('drive.google.com') ||
        url.contains('imgur') ||
        url.contains('storage');

    // Return the processed URL if it seems valid, otherwise return empty string
    return (isValidUrl) ? url : '';
  }

  // Add or update a van in the Google Sheet
  Future<void> saveVan(Van van) async {
    await init();

    try {
      // First check if this van already exists
      final vans = await fetchVans(forceRefresh: true);
      final existingIndex = vans.indexWhere(
        (v) => v.vanNumber == van.vanNumber,
      );

      // Format current date for lastUpdated field
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);

      // Process the URL to ensure it's valid
      final processedUrl = _processUrl(van.url);

      // Update the van with the current date and processed URL
      final updatedVan = van.copyWith(
        lastUpdated: formattedDate,
        url: processedUrl,
      );

      if (existingIndex >= 0) {
        // Van exists, update it
        final rowIndex =
            existingIndex + 2; // +2 because of header and 0-indexing

        await _updateRow(rowIndex, _vanToRow(updatedVan));
        debugPrint('Updated van ${van.vanNumber} at row $rowIndex');
      } else {
        // Van doesn't exist, add it as a new row
        await _appendRow(_vanToRow(updatedVan));
        debugPrint('Added new van ${van.vanNumber}');
      }

      // Refresh cache
      await fetchVans(forceRefresh: true);
    } catch (e) {
      debugPrint('Error saving van to Google Sheets: $e');
      rethrow;
    }
  }

  // Helper to update a row in the sheet
  Future<void> _updateRow(int rowIndex, List<String> values) async {
    final range = '$_sheetName!A$rowIndex:J$rowIndex';
    final valueRange = ValueRange(range: range, values: [values]);

    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      _spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  // Helper to append a row to the sheet
  Future<void> _appendRow(List<String> values) async {
    const range = '$_sheetName!A:J';
    final valueRange = ValueRange(values: [values]);

    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      _spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  // Convert a Van object to a row of cell values
  List<String> _vanToRow(Van van) {
    return [
      van.vanNumber,
      van.type,
      van.status,
      van.date,
      van.lastUpdated,
      van.notes,
      van.url,
      van.driver,
      van.damage,
      van.rating.toString(),
    ];
  }

  // Clean up resources
  void dispose() {
    _client?.close();
    _client = null;
    _sheetsApi = null;
  }
}
