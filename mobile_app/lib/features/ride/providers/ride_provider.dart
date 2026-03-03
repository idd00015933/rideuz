import 'package:flutter/foundation.dart';
import '../../../core/services/ride_service.dart';

class RideProvider extends ChangeNotifier {
  final _service = RideService();

  // ── State ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _rides = []; // Driver's own rides
  List<Map<String, dynamic>> _searchResults = []; // Passenger search results
  List<Map<String, dynamic>> _bookings = []; // Passenger's bookings
  Map<String, dynamic>? _selectedRide; // Detail view
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get rides => _rides;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<Map<String, dynamic>> get bookings => _bookings;
  Map<String, dynamic>? get selectedRide => _selectedRide;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Published rides (driver view)
  List<Map<String, dynamic>> get publishedRides =>
      _rides.where((r) => r['status'] == 'PUBLISHED').toList();

  /// Active ride (ongoing)
  List<Map<String, dynamic>> get ongoingRides =>
      _rides.where((r) => r['status'] == 'ONGOING').toList();

  /// Terminal rides for history
  List<Map<String, dynamic>> get historyRides => _rides
      .where((r) => r['status'] == 'COMPLETED' || r['status'] == 'CANCELED')
      .toList();

  // ── Driver: Fetch own rides ───────────────────────────────────────────────

  Future<void> fetchMyRides() async {
    _setLoading(true);
    try {
      _rides = await _service.getMyRides();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  // ── Driver: Create ride ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createRide({
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
    _setLoading(true);
    try {
      final ride = await _service.createRide(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
        pricePerSeat: pricePerSeat,
        paymentMethod: paymentMethod,
        seats: seats,
        description: description,
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
      _rides.insert(0, ride);
      _errorMessage = null;
      _setLoading(false);
      return ride;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return null;
    }
  }

  // ── Driver: State transitions ─────────────────────────────────────────────

  Future<bool> startRide(int id) => _transition(id, _service.startRide);
  Future<bool> completeRide(int id) => _transition(id, _service.completeRide);
  Future<bool> cancelRide(int id) => _transition(id, _service.cancelRide);

  // ── Passenger: Search rides ───────────────────────────────────────────────

  Future<void> searchRides({
    String? origin,
    String? destination,
    String? date,
    int? minSeats,
    double? maxPrice,
    String? sort,
  }) async {
    _setLoading(true);
    try {
      _searchResults = await _service.searchRides(
        origin: origin,
        destination: destination,
        date: date,
        minSeats: minSeats,
        maxPrice: maxPrice,
        sort: sort,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  // ── Passenger: View ride detail ───────────────────────────────────────────

  Future<void> fetchRideDetail(int id) async {
    _setLoading(true);
    try {
      _selectedRide = await _service.getRide(id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  // ── Passenger: Book a seat ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> bookSeat({
    required int rideId,
    required int seatId,
    String paymentMethod = 'CASH',
  }) async {
    _setLoading(true);
    try {
      final booking = await _service.bookSeat(
        rideId: rideId,
        seatId: seatId,
        paymentMethod: paymentMethod,
      );
      _errorMessage = null;
      // Refresh the ride detail to reflect the new booking
      await fetchRideDetail(rideId);
      _setLoading(false);
      return booking;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return null;
    }
  }

  // ── Passenger: My bookings ────────────────────────────────────────────────

  Future<void> fetchMyBookings() async {
    _setLoading(true);
    try {
      _bookings = await _service.getMyBookings();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  Future<bool> cancelBooking(int bookingId) async {
    _setLoading(true);
    try {
      await _service.cancelBooking(bookingId);
      await fetchMyBookings();
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<bool> submitReview({
    required int rideId,
    required int revieweeId,
    required int rating,
    String comment = '',
  }) async {
    _setLoading(true);
    try {
      await _service.submitReview(
        rideId: rideId,
        revieweeId: revieweeId,
        rating: rating,
        comment: comment,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _transition(
      int id, Future<Map<String, dynamic>> Function(int) call) async {
    _setLoading(true);
    try {
      final updated = await call(id);
      _upsert(updated);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _upsert(Map<String, dynamic> ride) {
    final idx = _rides.indexWhere((r) => r['id'] == ride['id']);
    if (idx >= 0) {
      _rides[idx] = ride;
    } else {
      _rides.insert(0, ride);
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
