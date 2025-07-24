class SheetsConfig {
  // The ID of your Google Sheet
  // Can be found in the URL: https://docs.google.com/spreadsheets/d/ YOUR_SPREADSHEET_ID/edit
  static const String spreadsheetId =
      '1zQUtwp-1zBcBI-gHkVQ9xdxd7RWT_QPeD9mhm14p0m4';

  // The name of the worksheet where van profiles are stored
  static const String vansWorksheetName = 'Sheet1';

  // The title to use when displaying the worksheet
  static const String vansWorksheetTitle = 'Vans';

  // The name of the worksheet where damage reports are stored (if separate)
  // Note: Based on your structure, you might not need a separate worksheet for damage reports
  static const String damageReportsWorksheetName = 'DamageReports';

  // Service account email - needed for sharing the Google Sheet
  static const String serviceAccountEmail =
      'vans-304@arr-453903.iam.gserviceaccount.com';

  // Google Sheets API credentials in JSON format
  // IMPORTANT: Make sure your Google Sheet is shared with the service account email above
  static const String credentials = '''
{
  "type": "service_account",
  "project_id": "arr-453903",
  "private_key_id": "113289e028b55a87d684877adddccf62348d4587",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDYG5KVARMdAoCB\\n8NGi10CGSvo6FqFDuUvPy+aT8O4qu8ER+83Xe7qz3rmWhqeG7vwSxIZ+6D+Pjwhu\\n5v03i9pvnwU48DdqPwL8yIOhEcIDzJGcdSMow6okPdfcF850soqZd+XXpkbL114W\\nJ6HIT6QXivlKdfH1Gl5S4Oh+8Agbo9MY86+DBfk+E9YN7I3VdE8cMfFjnEH4coy0\\nMJTguYe91nd/TiXWDEhO4AuU7OyKM3+HiBH25cFvOCNgBCL/fasYfqDzdPRdGqfT\\nUuj9DuN6I9uJ5BixEXFLfNMH38gKkKU2oxa4khyP1MUqOMgCISZEXxFILwI+HgXo\\nyKAWaVXbAgMBAAECggEAEX6J6zi0YhDQc7RvBA5bfC5C+24sN930M9TUdv12Ckzm\\nCvKmGIo89E//bh67Hm088rf+EJ/0epv1mXoRiEGbY+ss8mMKhAtTI+uHhwPM/58R\\nL+fmT2fSNNoyHfBqF4BXP/04xLBX4tXYbqqz/2c9vWTUBsxtfeNYkhUAPTu+gZ4n\\nQ4JUInFhsl94xAEbZqR1OQDMOElX9fmW6aDMaDFGh+bpqHWn2Eu952yUHs4sOKPe\\nAehbO+ZcAS875ycb/SuBWtyc75yOZrNinyLMzOf5CSpK7Kx18XvjoT/mE3pgZScJ\\nU7TXzV0hvBggl4v4UpGURMWzxi8dD+bLaXGT0yCNgQKBgQD/iFmDsK7LxvFYXb8m\\nC4Yyhu9JJZIGhu+P703F9ZQGNqXli06SFn7q3frIBHMDTtpDgNtlYEy6RnWrpZ/B\\nSv7/iIDNs+zeB0UYN99Lw4VwoUAClePURqyiYD8j/44yqF2QQSVYq0TO7xw3KTku\\nVGDs/JZFhYOsOqBNqrvY3B4TcQKBgQDYgMM8YjDjz3p7di7ZfFh378AfBZrJiLol\\nd+M5ivHXCl5/EW8PT7BSrCjXL1gdyeqz/qWbNGfg5nbRfifAp3VpkP2DZOd3plz+\\nFQu2M7WOEk/NSyTguhWOAvCjvTb0LQUGajlPircur8AdCuEcSmLMDNH4SaOm3pFw\\nr/HCbsaACwKBgExy54z9lB4FI/ly+pgQRJLjSb2RjvGC9zMRvivmf+Wn/dQB7HzK\\nXCg6RygGJL6tnaEqcPkQaYQlRlkXEQeMP2QF27svBEOc2zAWryiEk2yR4Yukemfs\\nyQM/VkSX1VwUgQGCbADuJITghol+PMw+lEzyeKbN/gnN9F2oIdEMcbcRAoGBAMPA\\nEEYtZZTkiBLO9WcQ5ZBzhlrGH4CujdfIwPrLJQRQTMZJBghq/bqSDE8bcGlmoj3i\\nNOvSg0W2OqIJlXm8Lw2m2YCOoDXvhk74ymEP+cydw+eTVKGXvltrTxZMwz4c4lk9\\ne9nuStf8chAQQR7qJs/lm4cJVd1PiWLAwi8RJ4qnAoGBANG5+pNxfZsCai6ctoby\\nkVkBsjFCwqaZVMplDJLRN7v8XDJpt5B6zYqAun7XreKmkYkoe4/52itMiN99f3kb\\nzt5aUbjHk5NBh0vBpjfVZqxuPTXsb3GHbWATFgROfe4GnU0RMvUbHN6htC0H0cba\\n1D0GTkz7qH2uDRdr81nkBvwM\\n-----END PRIVATE KEY-----\\n",
  "client_email": "vans-304@arr-453903.iam.gserviceaccount.com",
  "client_id": "107956827940316405943",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/vans-304%40arr-453903.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
''';

  // Google Sheets API key - Make sure this is a valid API key with access to the Google Sheets API
  static const String apiKey = 'AIzaSyBQB5ZN3QU6hKAYxGRpRFUm3XxeIU9kHbk';

  // Sync interval in minutes
  static const int syncIntervalMinutes = 5;

  // Worksheet Names
  static const String damagesWorksheetName = 'Damages';
  static const String maintenanceWorksheetName = 'Maintenance';

  // Column Headers and Mapping
  static const Map<String, String> columnHeaders = {
    'A': 'Van Number',
    'B': 'Type',
    'C': 'Status',
    'D': 'Date',
    'E': 'Last Updated',
    'F': 'Notes',
    'G': 'URL',
    'H': 'Driver',
    'I': 'Damage',
    'J': 'Rating',
  };
}
