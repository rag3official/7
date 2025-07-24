import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/van.dart';
import '../services/supabase_service_optimized.dart';
import '../config/environment.dart';
import 'dart:async';

class VanProvider with ChangeNotifier {
  final _supabaseService = SupabaseServiceOptimized();
  List<Van> _vans = [];
  bool _isLoading = false;
  String? _error;
  int _retryCount = 0;
  Timer? _retryTimer;
  bool _databaseInitialized = false;
  bool _isInitialized = false;

  List<Van> get vans => _vans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get databaseInitialized => _databaseInitialized;
  bool get isInitialized => _isInitialized;

  VanProvider() {
    _initializeDatabase();
  }

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

  Future<Van?> getVan(String id) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return null;
    }

    try {
      return await _supabaseService.getVan(id);
    } catch (e) {
      _error = 'Failed to load van: $e';
      debugPrint(_error);
      return null;
    }
  }

  Future<void> addVan(Map<String, dynamic> data) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    try {
      await _supabaseService.createVan(
        data['name'],
        data['status'],
        data['maintenance_notes'],
      );
      await refreshVans();
    } catch (e) {
      _error = 'Failed to add van: $e';
      debugPrint(_error);
    }
  }

  Future<void> updateVan(String id, Map<String, dynamic> data) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    try {
      await _supabaseService.updateVan(id, data);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to update van: $e';
      debugPrint(_error);
    }
  }

  Future<void> deleteVan(String id) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.deleteVan(id);
      _vans.removeWhere((van) => van.id == id);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete van: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadImage(String vanId, File imageFile) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    try {
      await _supabaseService.uploadImage(vanId, imageFile);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to upload image: $e';
      debugPrint(_error);
    }
  }

  Future<void> deleteImage(String vanId, String imageUrl) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    try {
      await _supabaseService.deleteImage(vanId, imageUrl);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to delete image: $e';
      debugPrint(_error);
    }
  }

  Future<void> saveVan(Van van) async {
    if (!Environment.isValid) {
      _error =
          'Supabase is not configured. Please check your environment variables.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedVan = await _supabaseService.saveVan(van);
      final index = _vans.indexWhere((v) => v.id == van.id);
      if (index >= 0) {
        _vans[index] = updatedVan;
      } else {
        _vans.add(updatedVan);
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to save van: $e';
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

  // Public method to start listening to van updates
  void startListeningToVans() {
    _setupRealTimeUpdates();
  }

  void _handleError(String errorMessage) {
    _error = errorMessage;
    debugPrint(_error);

    if (_retryCount < 3) {
      _retryCount++;
      _retryTimer = Timer(const Duration(seconds: 5), () => refreshVans());
    } else {
      _error = 'Max retries reached. Please try again later.';
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _supabaseService.unsubscribeFromVans();
    super.dispose();
  }
}
