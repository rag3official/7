import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/van.dart';
import '../services/van_service_optimized.dart';

class VanProvider extends ChangeNotifier {
  final VanServiceOptimized _vanService = VanServiceOptimized();

  List<Van> _vans = [];
  bool _isLoading = false;
  String? _error;
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

      // Use fast loading for initial load
      print('🚀 Initializing with fast loading...');
      _vans = await _vanService.getVansFast();
      print('✅ Initial load completed: ${_vans.length} vans');
      _isInitialized = true;
    } catch (e) {
      _error = 'Failed to initialize database: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all vans from Supabase with retry logic
  Future<void> refreshVans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔄 VanProvider: Starting van refresh...');

      // Clear cache before fetching fresh data
      _vanService.clearCache();

      _vans = await _vanService.getAllVans();
      print(
          '📊 VanProvider: Loaded ${_vans.length} vans with optimized service');
      _error = null;
    } catch (e) {
      print('❌ VanProvider: Error loading vans: $e');
      _handleError('Failed to load vans: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle errors without auto-retry
  void _handleError(String errorMessage) {
    _error = errorMessage;
    debugPrint(_error);
    // No auto-retry - user must manually refresh
  }

  // Save or update a van
  Future<void> saveVan(Van van) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear cache to ensure fresh data
      _vanService.clearCache();
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
      // Clear cache to ensure fresh data
      _vanService.clearCache();
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
      return _vans.firstWhere((van) => van.plateNumber == vanNumber);
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
    return _vans.where((van) => van.model == type).toList();
  }

  // Filter vans by status
  List<Van> getVansByStatus(String status) {
    return _vans.where((van) => van.status == status).toList();
  }

  // Filter vans by driver
  List<Van> getVansByDriver(String driver) {
    return _vans.where((van) => van.driverName == driver).toList();
  }

  // Get unique van types for filtering
  List<String> get vanTypes {
    final types = _vans.map((van) => van.model).toSet().toList();
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
    final driverList = _vans
        .map((van) => van.driverName ?? '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    driverList.sort();
    return driverList;
  }

  // Background loading method for pre-loading data
  Future<void> loadVansInBackground() async {
    try {
      print('📦 VanProvider: Starting background van loading...');

      // Load vans without notifying listeners to avoid UI updates
      final backgroundVans = await _vanService.getAllVans();

      // Only update the internal list if we got data
      if (backgroundVans.isNotEmpty) {
        _vans = backgroundVans;
        print(
            '📦 VanProvider: Background loading completed - ${_vans.length} vans loaded');
      } else {
        print('📦 VanProvider: Background loading completed - no vans found');
      }
    } catch (e) {
      print('❌ VanProvider: Background loading error: $e');
      // Don't set error state for background loading
    }
  }

  // Clear cache method for refresh functionality
  void clearCache() {
    _vanService.clearCache();
    print('🗑️ VanProvider: Cache cleared');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
