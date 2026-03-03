import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/driver_service.dart';

class DriverProvider extends ChangeNotifier {
  final _service = DriverService();

  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;
  bool get isOnline => _profile?['is_online'] == true;

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> fetchProfile() async {
    _setLoading(true);
    try {
      _profile = await _service.getProfile(); // null if not found
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<bool> createProfile({
    required String fullName,
    required String carModel,
    required String plateNumber,
    required XFile profilePicture,
  }) async {
    _setLoading(true);
    try {
      _profile = await _service.createProfile(
        fullName: fullName,
        carModel: carModel,
        plateNumber: plateNumber,
        profilePicture: profilePicture,
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<bool> updateProfile({
    required String fullName,
    required String carModel,
    required String plateNumber,
    XFile? profilePicture,
  }) async {
    _setLoading(true);
    try {
      _profile = await _service.patchProfile(
        fullName: fullName,
        carModel: carModel,
        plateNumber: plateNumber,
        profilePicture: profilePicture,
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Toggle online ─────────────────────────────────────────────────────────

  Future<bool> toggleOnline() async {
    final newState = !isOnline;
    _setLoading(true);
    try {
      _profile = await _service.toggleOnline(newState);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
