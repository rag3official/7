class ApiConfig {
  // Google API Client ID and Secret
  // These should be replaced with your own values
  static const String clientId = 'YOUR_CLIENT_ID';
  static const String clientSecret = 'YOUR_CLIENT_SECRET';

  // Google Sheets Spreadsheet ID
  // This should be the ID of your Google Sheet containing the van data
  static const String spreadsheetId = '1zQUtwp-1zBcBI-gHkVQ9xdxd7RWT_QPeD9mhm14p0m4';

  // Sheet name where the data is stored
  static const String sheetName = 'Sheet1';

  // API OAuth scopes
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  // API key for additional services if needed
  static const String apiKey = 'YOUR_API_KEY';

  // This class is not meant to be instantiated
  ApiConfig._();
}
