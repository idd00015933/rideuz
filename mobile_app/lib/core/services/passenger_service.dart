import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GET/POST/PATCH /api/users/passenger-profile/
class PassengerService {
  static const _base = 'http://127.0.0.1:8000';

  Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('auth_token');
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Token $token',
      };

  Future<Map<String, dynamic>?> getProfile() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/users/passenger-profile/'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(token),
      },
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    if (res.statusCode == 404) return null;
    throw Exception(_errorDetailFromBody(res.body, res.statusCode));
  }

  Future<Map<String, dynamic>> createProfile({
    required String fullName,
    String cardHolderName = '',
    String cardLast4 = '',
    String cardExpiryMmYy = '',
    XFile? profilePicture,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    return _sendMultipart(
      method: 'POST',
      token: token,
      fields: {
        'full_name': fullName,
        'card_holder_name': cardHolderName,
        'card_last4': cardLast4,
        'card_expiry_mm_yy': cardExpiryMmYy,
      },
      profilePicture: profilePicture,
    );
  }

  Future<Map<String, dynamic>> patchProfile({
    String? fullName,
    String? cardHolderName,
    String? cardLast4,
    String? cardExpiryMmYy,
    XFile? profilePicture,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final fields = <String, String>{};
    if (fullName != null) fields['full_name'] = fullName;
    if (cardHolderName != null) fields['card_holder_name'] = cardHolderName;
    if (cardLast4 != null) fields['card_last4'] = cardLast4;
    if (cardExpiryMmYy != null) fields['card_expiry_mm_yy'] = cardExpiryMmYy;

    return _sendMultipart(
      method: 'PATCH',
      token: token,
      fields: fields,
      profilePicture: profilePicture,
    );
  }

  Future<Map<String, dynamic>> _sendMultipart({
    required String method,
    required String token,
    required Map<String, String> fields,
    XFile? profilePicture,
  }) async {
    final req = http.MultipartRequest(
      method,
      Uri.parse('$_base/api/users/passenger-profile/'),
    );
    req.headers.addAll(_authHeaders(token));
    req.fields.addAll(fields);

    if (profilePicture != null) {
      final bytes = await profilePicture.readAsBytes();
      req.files.add(
        http.MultipartFile.fromBytes(
          'profile_picture',
          bytes,
          filename: profilePicture.name,
        ),
      );
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    }
    throw Exception(_errorDetailFromBody(body, streamed.statusCode));
  }

  String _errorDetailFromBody(String body, int statusCode) {
    try {
      final b = jsonDecode(body) as Map<String, dynamic>;
      if (b['detail'] != null) return b['detail'].toString();
      if (b['full_name'] is List && (b['full_name'] as List).isNotEmpty) {
        return (b['full_name'] as List).first.toString();
      }
      if (b['card_last4'] is List && (b['card_last4'] as List).isNotEmpty) {
        return (b['card_last4'] as List).first.toString();
      }
      if (b['card_expiry_mm_yy'] is List && (b['card_expiry_mm_yy'] as List).isNotEmpty) {
        return (b['card_expiry_mm_yy'] as List).first.toString();
      }
      return (b['error'] ?? 'HTTP $statusCode').toString();
    } catch (_) {
      return 'HTTP $statusCode';
    }
  }
}
