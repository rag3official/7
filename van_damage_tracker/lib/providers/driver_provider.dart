import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/driver_profile.dart';
import '../services/driver_service.dart';

class DriverProvider extends ChangeNotifier {
  final DriverService _driverService = DriverService();
  List<DriverProfile> _drivers = [];
  bool _isLoading = false;
  String? _error;
  bool _databaseInitialized = false;
  bool _isInitialized = false;
  StreamSubscription<List<DriverProfile>>? _driverSubscription;

  // Getters
  List<DriverProfile> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get databaseInitialized => _databaseInitialized;
  bool get isInitialized => _isInitialized;

  DriverProvider() {
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      _isLoading = true;
      notifyListeners();

      _databaseInitialized = await _driverService.initializeDatabase();

      if (_databaseInitialized) {
        await refreshDrivers();
        _setupRealTimeUpdates();
        _isInitialized = true;
      } else {
        _error = 'Failed to initialize driver database';
      }
    } catch (e) {
      _error = 'Failed to initialize database: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealTimeUpdates() {
    _driverSubscription = _driverService.subscribeToDrivers().listen(
      (updatedDrivers) {
        _drivers = updatedDrivers;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Error in driver subscription: $error';
        debugPrint(_error);
        notifyListeners();
      },
    );
  }

  Future<void> refreshDrivers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔄 DriverProvider: Starting driver refresh...');

      // Clear cache before fetching fresh data
      _driverService.clearCache();

      _drivers = await _driverService.getDrivers();
      print('📊 DriverProvider: Loaded ${_drivers.length} drivers');
      _error = null;
    } catch (e) {
      print('❌ DriverProvider: Error loading drivers: $e');
      _error = 'Failed to load drivers: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DriverProfile?> getDriver(String id) async {
    try {
      return await _driverService.getDriver(id);
    } catch (e) {
      _error = 'Failed to load driver: $e';
      debugPrint(_error);
      return null;
    }
  }

  Future<void> createDriver(DriverProfile driver) async {
    try {
      await _driverService.createDriver(driver);
      // Clear cache to ensure fresh data
      _driverService.clearCache();
      await refreshDrivers();
    } catch (e) {
      _error = 'Failed to add driver: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  Future<void> updateDriver(DriverProfile driver) async {
    try {
      await _driverService.updateDriver(driver.id, driver.toJson());
      // Clear cache to ensure fresh data
      _driverService.clearCache();
      await refreshDrivers();
    } catch (e) {
      _error = 'Failed to update driver: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  Future<void> deleteDriver(String id) async {
    try {
      await _driverService.deleteDriver(id);
      // Clear cache to ensure fresh data
      _driverService.clearCache();
      await refreshDrivers();
    } catch (e) {
      _error = 'Failed to delete driver: $e';
      debugPrint(_error);
      rethrow;
    }
  }

  DriverProfile? getDriverById(String id) {
    try {
      return _drivers.firstWhere((driver) => driver.id == id);
    } catch (e) {
      return null;
    }
  }

  List<DriverProfile> getDriversByStatus(String status) {
    return _drivers.where((driver) => driver.status == status).toList();
  }

  List<String> get driverStatuses {
    final statuses = _drivers.map((driver) => driver.status).toSet().toList();
    statuses.sort();
    return statuses;
  }

  // Background loading method for pre-loading data
  Future<void> loadDriversInBackground() async {
    try {
      print('👥 DriverProvider: Starting background driver loading...');

      // Load drivers without notifying listeners to avoid UI updates
      final backgroundDrivers = await _driverService.getDrivers();

      // Only update the internal list if we got data
      if (backgroundDrivers.isNotEmpty) {
        _drivers = backgroundDrivers;
        print(
            '👥 DriverProvider: Background loading completed - ${_drivers.length} drivers loaded');
      } else {
        print(
            '👥 DriverProvider: Background loading completed - no drivers found');
      }
    } catch (e) {
      print('❌ DriverProvider: Background loading error: $e');
      // Don't set error state for background loading
    }
  }

  // Clear cache method for refresh functionality
  void clearCache() {
    _driverService.clearCache();
    print('🗑️ DriverProvider: Cache cleared');
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    super.dispose();
  }
}
