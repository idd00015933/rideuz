import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingPhone; // full E.164, kept for the OTP verify call

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Step 1 — Request OTP ─────────────────────────────────────────────────

  /// Calls POST /api/auth/register/.
  ///
  /// Returns an [OtpRequestResult]:
  ///   - .isSuccess       → otp_code available; navigate to OTP screen
  ///   - .isAlreadyVerified → proceed to OTP screen silently (existing user login)
  ///   - .isError         → show errorMessage to user
  Future<OtpRequestResult> requestOtp(String phoneDigits) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingPhone = '+998$phoneDigits';
      final result = await _service.requestOtp(phoneDigits);
      if (result.isError) {
        _errorMessage = result.errorMessage;
      }
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return OtpRequestResult.error(_errorMessage!);
    }
  }

  // ── Step 2 — Verify OTP ──────────────────────────────────────────────────

  /// Calls POST /api/auth/verify-otp/. Returns true on success, false on failure.
  Future<bool> verifyOtp(String otpCode) async {
    if (_pendingPhone == null) {
      _errorMessage = 'Phone number missing. Please go back and try again.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.verifyOtp(_pendingPhone!, otpCode);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ── Step 2.5 — Fetch /me/ and return route name ──────────────────────────

  /// Calls GET /api/users/me/, saves role to SharedPreferences, and returns
  /// the named route the app should navigate to:
  ///   - DRIVER    → routeDriverHome
  ///   - PASSENGER → routePassengerHome
  ///   - no role   → routeRoleSelect
  ///   - error     → null  (errorMessage is set; caller should show it)
  Future<String?> fetchMeAndRoute() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final role = await _service.fetchMe();
      _isLoading = false;
      notifyListeners();

      return switch (role) {
        'driver' => AppConstants.routeDriverHome,
        'passenger' => AppConstants.routePassengerHome,
        _ => AppConstants.routeRoleSelect,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  // ── Step 3 — Confirm role ────────────────────────────────────────────────

  /// POST /api/auth/select-role/. Returns the route to navigate to on success.
  Future<String?> confirmRole(String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.setRole(role);
      _isLoading = false;
      notifyListeners();
      return switch (role.toLowerCase()) {
        'driver' => AppConstants.routeDriverHome,
        'passenger' => AppConstants.routePassengerHome,
        _ => AppConstants.routeRoleSelect,
      };
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  // ── Compat shims kept for RoleSelectionScreen ─────────────────────────────

  // ignore: unused_element
  void setSelectedRole(String role) {} // no-op; role comes from server now

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
