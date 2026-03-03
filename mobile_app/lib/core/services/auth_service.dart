import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Result types ──────────────────────────────────────────────────────────────

/// Outcome of POST /api/auth/register/.
enum OtpRequestOutcome { success, alreadyVerified, error }

class OtpRequestResult {
  const OtpRequestResult._({
    required this.outcome,
    this.otpCode,
    this.errorMessage,
  });

  factory OtpRequestResult.success(String otpCode) =>
      OtpRequestResult._(outcome: OtpRequestOutcome.success, otpCode: otpCode);

  /// 400 "already registered and verified" — non-fatal: proceed to OTP screen.
  factory OtpRequestResult.alreadyVerified() =>
      const OtpRequestResult._(outcome: OtpRequestOutcome.alreadyVerified);

  factory OtpRequestResult.error(String message) => OtpRequestResult._(
      outcome: OtpRequestOutcome.error, errorMessage: message);

  final OtpRequestOutcome outcome;
  final String? otpCode;
  final String? errorMessage;

  bool get isSuccess => outcome == OtpRequestOutcome.success;
  bool get isAlreadyVerified => outcome == OtpRequestOutcome.alreadyVerified;
  bool get isError => outcome == OtpRequestOutcome.error;
}

// ── AuthService ───────────────────────────────────────────────────────────────

class AuthService {
  static const _baseUrl = 'http://127.0.0.1:8000';
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';

  // ── Step 1 ────────────────────────────────────────────────────────────────

  /// POST /api/auth/register/
  ///
  /// Returns:
  ///   - [OtpRequestResult.success]         on 200  (new / unverified user)
  ///   - [OtpRequestResult.alreadyVerified] on 400 if message contains
  ///     "already registered" — signals that the user can still proceed to OTP
  ///     because the verify endpoint doubles as login.
  ///   - [OtpRequestResult.error]           on any other failure.
  Future<OtpRequestResult> requestOtp(String phoneDigits) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': '+998$phoneDigits'}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return OtpRequestResult.success(data['otp_code'] as String);
    }

    // 400 with "already registered" means the number is verified.
    // The user can still log in via OTP verify — redirect them silently.
    final detail = (data['detail'] ?? data['error'] ?? '').toString();
    if (_isAlreadyVerifiedMessage(detail)) {
      return OtpRequestResult.alreadyVerified();
    }

    return OtpRequestResult.error(
        detail.isNotEmpty ? detail : 'Registration failed.');
  }

  /// Heuristic: does the backend error message indicate an already-verified user?
  bool _isAlreadyVerifiedMessage(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('already verified') ||
        lower.contains('log in via') ||
        lower.contains('verified. please');
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  /// POST /api/auth/verify-otp/
  /// Saves the returned token to SharedPreferences.
  Future<String> verifyOtp(String phoneNumber, String otpCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/verify-otp/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'otp_code': otpCode,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final token = data['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return token;
    }
    final msg = (data['detail'] ?? data['error'] ?? 'OTP verification failed.')
        .toString();
    throw Exception(msg);
  }

  // ── Step 2.5 — fetch role from server ────────────────────────────────────

  /// GET /api/users/me/
  ///
  /// Returns the lowercase role string ('driver' | 'passenger') or null if the
  /// user exists but has not yet chosen a role (role == null / empty from BE).
  /// Throws if the request fails (e.g. invalid token).
  Future<String?> fetchMe() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.get(
      Uri.parse('$_baseUrl/api/users/me/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final role = (data['role'] ?? '').toString().toLowerCase().trim();
      // Save to SharedPreferences so splash can use it offline-first next cold start
      if (role == 'driver' || role == 'passenger') {
        await prefs.setString(_roleKey, role);
      }
      return role.isEmpty ? null : role;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token invalid/expired — clear it
      await prefs.remove(_tokenKey);
      await prefs.remove(_roleKey);
      throw Exception('Session expired. Please log in again.');
    }

    throw Exception('Could not fetch user profile.');
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────

  /// POST /api/auth/select-role/
  Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) throw Exception('Not authenticated.');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/select-role/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode({'role': role.toUpperCase()}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      await prefs.setString(_roleKey, role.toLowerCase());
      return;
    }
    final msg =
        (data['detail'] ?? data['error'] ?? 'Could not set role.').toString();
    throw Exception(msg);
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}
