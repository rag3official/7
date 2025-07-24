import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/van.dart';
import '../services/supabase_service.dart';

class VanProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Van> _vans = [];
  bool _isLoading = false;
  String? _error;
  int _retryCount = 0;
  Timer? _retryTimer;
  bool _databaseInitialized = false;
  bool _isInitialized = false;

  // Getters
  List<Van> get vans => _vans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get databaseInitialized => _databaseInitialized;
  bool get isInitialized => _isInitialized;

  VanProvider() {
    _initializeDatabase();
  }

  // Initialize database and then refresh vans
  Future<void> _initializeDatabase() async {
    try {
      _isLoading = true;
      notifyListeners();

      _databaseInitialized = await _supabaseService.initializeDatabase();

      if (_databaseInitialized) {
        await refreshVans();
        _setupRealTimeUpdates();
        _isInitialized = true;
      } else {
        _error = 'Failed to initialize database schema';
      }
    } catch (e) {
      _error = 'Failed to initialize database: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set up real-time updates for vans
  void _setupRealTimeUpdates() {
    _supabaseService.subscribeToVans((updatedVans) {
      _vans = updatedVans;
      notifyListeners();
    });
  }

  // Fetch all vans from Supabase with retry logic
  Future<void> refreshVans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vans = await _supabaseService.fetchVans(forceRefresh: true);
      _error = null;
      _retryCount = 0; // Reset retry count on success

      // Cancel any pending retry
      _retryTimer?.cancel();
      _retryTimer = null;
    } catch (e) {
      _handleError('Failed to load vans: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle errors with retry logic
  void _handleError(String errorMessage) {
    _error = errorMessage;
    debugPrint(_error);

    // Implement exponential backoff for retries
    if (_retryCount < 3) {
      // Maximum 3 retry attempts
      _retryCount++;
      final backoffSeconds = _retryCount * 2; // 2, 4, 6 seconds

      debugPrint('Retry attempt $_retryCount in $backoffSeconds seconds');

      // Schedule retry
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: backoffSeconds), () {
        debugPrint('Retrying van data fetch (attempt $_retryCount)');
        refreshVans();
      });
    }
  }

  // Save or update a van
  Future<void> saveVan(Van van) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.saveVan(van);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to save van: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a van
  Future<void> deleteVan(String? vanId) async {
    if (vanId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteVan(vanId);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to delete van: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get a van by its number
  Van? getVanByNumber(String vanNumber) {
    try {
      return _vans.firstWhere((van) => van.vanNumber == vanNumber);
    } catch (e) {
      return null;
    }
  }

  // Get a van by its ID
  Van? getVanById(String id) {
    try {
      return _vans.firstWhere((van) => van.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter vans by type
  List<Van> getVansByType(String type) {
    return _vans.where((van) => van.type == type).toList();
  }

  // Filter vans by status
  List<Van> getVansByStatus(String status) {
    return _vans.where((van) => van.status == status).toList();
  }

  // Filter vans by driver
  List<Van> getVansByDriver(String driver) {
    return _vans.where((van) => van.driver == driver).toList();
  }

  // Get unique van types for filtering
  List<String> get vanTypes {
    final types = _vans.map((van) => van.type).toSet().toList();
    types.sort();
    return types;
  }

  // Get unique van statuses for filtering
  List<String> get vanStatuses {
    final statuses = _vans.map((van) => van.status).toSet().toList();
    statuses.sort();
    return statuses;
  }

  // Get unique drivers for filtering
  List<String> get drivers {
    final driverList =
        _vans
            .map((van) => van.driver)
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList();
    driverList.sort();
    return driverList;
  }

  // Public method to start listening to van updates
  void startListeningToVans() {
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _supabaseService.unsubscribeFromVans();
    _retryTimer?.cancel();
    super.dispose();
  }
}
