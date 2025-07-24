import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/van.dart';
import '../services/van_service.dart';

class VanProvider with ChangeNotifier {
  final _vanService = VanService();
  List<Van> _vans = [];
  bool _isLoading = false;
  String? _error;

  List<Van> get vans => _vans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  VanProvider() {
    refreshVans();
  }

  Future<void> refreshVans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vans = await _vanService.getVans();
      _error = null;
    } catch (e) {
      _error = 'Failed to load vans: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Van?> getVan(String id) async {
    try {
      return await _vanService.getVan(id);
    } catch (e) {
      _error = 'Failed to load van: $e';
      debugPrint(_error);
      return null;
    }
  }

  Future<void> addVan(Map<String, dynamic> data) async {
    try {
      await _vanService.createVan(
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
    try {
      await _vanService.updateVan(id, data);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to update van: $e';
      debugPrint(_error);
    }
  }

  Future<void> deleteVan(String id) async {
    try {
      await _vanService.deleteVan(id);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to delete van: $e';
      debugPrint(_error);
    }
  }

  Future<void> uploadImage(String vanId, File imageFile) async {
    try {
      await _vanService.uploadImage(vanId, imageFile);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to upload image: $e';
      debugPrint(_error);
    }
  }

  Future<void> deleteImage(String vanId, String imageUrl) async {
    try {
      await _vanService.deleteImage(vanId, imageUrl);
      await refreshVans();
    } catch (e) {
      _error = 'Failed to delete image: $e';
      debugPrint(_error);
    }
  }
}
