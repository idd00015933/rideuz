import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GET/POST /api/complaints/
class ComplaintService {
  static const _base = 'http://127.0.0.1:8000';

  Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      };

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getComplaints() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/complaints/'),
      headers: _headers(token),
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is List) return List<Map<String, dynamic>>.from(body);
      if (body is Map && body['results'] is List) {
        return List<Map<String, dynamic>>.from(body['results'] as List);
      }
      return [];
    }
    throw Exception(_errorDetail(res));
  }

  // ── File ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fileComplaint({
    required int rideId,
    required String description,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.post(
      Uri.parse('$_base/api/complaints/'),
      headers: _headers(token),
      body: jsonEncode({
        'ride_id': rideId,
        'description': description,
      }),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _errorDetail(http.Response res) {
    try {
      final b = jsonDecode(res.body) as Map;
      return (b['detail'] ?? b['error'] ?? 'HTTP ${res.statusCode}').toString();
    } catch (_) {
      return 'HTTP ${res.statusCode}';
    }
  }
}
