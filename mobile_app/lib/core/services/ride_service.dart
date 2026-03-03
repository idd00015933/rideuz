import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// All ride/booking/review HTTP calls for the carpooling model.
class RideService {
  static const _base = 'http://127.0.0.1:8000';

  double _round7(double value) => double.parse(value.toStringAsFixed(7));

  Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('auth_token');
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      };

  // ── List / Search rides ──────────────────────────────────────────────────

  /// GET /api/rides/?origin=&destination=&date=&min_seats=&max_price=&sort=
  Future<List<Map<String, dynamic>>> searchRides({
    String? origin,
    String? destination,
    String? date,
    int? minSeats,
    double? maxPrice,
    String? sort,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final params = <String, String>{};
    if (origin != null && origin.isNotEmpty) params['origin'] = origin;
    if (destination != null && destination.isNotEmpty) {
      params['destination'] = destination;
    }
    if (date != null && date.isNotEmpty) params['date'] = date;
    if (minSeats != null) params['min_seats'] = minSeats.toString();
    if (maxPrice != null) params['max_price'] = maxPrice.toString();
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;

    final uri = Uri.parse('$_base/api/rides/').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers(token));

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

  /// GET /api/rides/ — Driver's own rides
  Future<List<Map<String, dynamic>>> getMyRides() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/rides/'),
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

  // ── Create ride (Driver) ─────────────────────────────────────────────────

  /// POST /api/rides/ — Driver publishes a new ride
  Future<Map<String, dynamic>> createRide({
    required String origin,
    required String destination,
    required String departureTime,
    required double pricePerSeat,
    required String paymentMethod,
    required List<String> seats,
    String? description,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final body = <String, dynamic>{
      'origin': origin,
      'destination': destination,
      'departure_time': departureTime,
      'price_per_seat': pricePerSeat,
      'payment_method': paymentMethod.toUpperCase(),
      'seats': seats,
    };
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
    if (originLat != null) body['origin_lat'] = _round7(originLat);
    if (originLng != null) body['origin_lng'] = _round7(originLng);
    if (destinationLat != null) {
      body['destination_lat'] = _round7(destinationLat);
    }
    if (destinationLng != null) {
      body['destination_lng'] = _round7(destinationLng);
    }

    final res = await http.post(
      Uri.parse('$_base/api/rides/'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  // ── Ride detail ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRide(int id) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/rides/$id/'),
      headers: _headers(token),
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  // ── State-machine actions (Driver) ────────────────────────────────────────

  Future<Map<String, dynamic>> startRide(int id) => _action(id, 'start');
  Future<Map<String, dynamic>> completeRide(int id) => _action(id, 'complete');
  Future<Map<String, dynamic>> cancelRide(int id) => _action(id, 'cancel');

  // ── Book a seat (Passenger) ──────────────────────────────────────────────

  /// POST /api/rides/{id}/book/
  Future<Map<String, dynamic>> bookSeat({
    required int rideId,
    required int seatId,
    String paymentMethod = 'CASH',
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.post(
      Uri.parse('$_base/api/rides/$rideId/book/'),
      headers: _headers(token),
      body: jsonEncode({
        'seat_id': seatId,
        'payment_method': paymentMethod.toUpperCase(),
      }),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  // ── Bookings (Passenger) ──────────────────────────────────────────────────

  /// GET /api/bookings/
  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/bookings/'),
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

  /// POST /api/bookings/{id}/cancel/
  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.post(
      Uri.parse('$_base/api/bookings/$bookingId/cancel/'),
      headers: _headers(token),
      body: '{}',
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  /// POST /api/reviews/
  Future<Map<String, dynamic>> submitReview({
    required int rideId,
    required int revieweeId,
    required int rating,
    String comment = '',
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.post(
      Uri.parse('$_base/api/reviews/'),
      headers: _headers(token),
      body: jsonEncode({
        'ride': rideId,
        'reviewee': revieweeId,
        'rating': rating,
        'comment': comment,
      }),
    );

    if (res.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  /// GET /api/reviews/
  Future<List<Map<String, dynamic>>> getMyReviews() async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.get(
      Uri.parse('$_base/api/reviews/'),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _action(int id, String verb) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated.');

    final res = await http.post(
      Uri.parse('$_base/api/rides/$id/$verb/'),
      headers: _headers(token),
      body: '{}',
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    }
    throw Exception(_errorDetail(res));
  }

  String _errorDetail(http.Response res) {
    try {
      final b = jsonDecode(res.body) as Map;
      return (b['detail'] ?? b['error'] ?? 'HTTP ${res.statusCode}').toString();
    } catch (_) {
      return 'HTTP ${res.statusCode}';
    }
  }
}
