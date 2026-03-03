import 'dart:async';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../../shared/widgets/route_map_screen.dart';

/// Ride detail screen for Passengers.
/// Shows full ride info, seat map (tap a free seat to book), and driver info.
class PassengerRideStatusScreen extends StatefulWidget {
  const PassengerRideStatusScreen({super.key});

  @override
  State<PassengerRideStatusScreen> createState() =>
      _PassengerRideStatusScreenState();
}

class _PassengerRideStatusScreenState extends State<PassengerRideStatusScreen> {
  bool _didFetch = false;
  int? _rideId;
  Timer? _pollTimer;

  static const _activeStatuses = {'PUBLISHED', 'ONGOING'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      _rideId = ModalRoute.of(context)?.settings.arguments as int?;
      if (_rideId != null) {
        context.read<RideProvider>().fetchRideDetail(_rideId!);
        _startPolling();
      }
      _didFetch = true;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final ride = context.read<RideProvider>().selectedRide;
      final status = ride?['status']?.toString() ?? '';
      // Stop polling once ride is in a terminal state
      if (!_activeStatuses.contains(status) && ride != null) {
        _pollTimer?.cancel();
        return;
      }
      if (_rideId != null) {
        context.read<RideProvider>().fetchRideDetail(_rideId!);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _showRatingModal(Map<String, dynamic> ride) async {
    final driverId = ride['driver']?['id'] as int?;
    if (driverId == null) return;

    int selectedRating = 5;
    final commentCtrl = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rate Your Ride',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How was your experience with the driver?',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  // Star selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedRating = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            star <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.warning,
                            size: 44,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _ratingLabel(selectedRating),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Leave a comment (optional)…',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Submit Rating',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) return;

    final provider = context.read<RideProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await provider.submitReview(
      rideId: ride['id'] as int,
      revieweeId: driverId,
      rating: selectedRating,
      comment: commentCtrl.text.trim(),
    );

    commentCtrl.dispose();

    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Thank you for your rating! ⭐',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      // Refresh so has_reviewed becomes true
      await provider.fetchRideDetail(ride['id'] as int);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not submit rating.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    }
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Terrible';
      case 2:
        return 'Poor';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }

  Future<void> _bookSeat(int rideId, int seatId) async {
    // Capture context-dependent objects before first await
    final provider = context.read<RideProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final paymentMethod = await _showPaymentPicker();
    if (paymentMethod == null) return;

    final booking = await provider.bookSeat(
      rideId: rideId,
      seatId: seatId,
      paymentMethod: paymentMethod,
    );

    if (!mounted) return;
    if (booking != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Seat booked successfully! 🎉')),
      );
    } else if (provider.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  Future<String?> _showPaymentPicker() async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Method',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.money_rounded,
                  color: AppColors.secondary, size: 28),
              title: Text('Cash',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('Pay the driver in cash',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(ctx, 'CASH'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.credit_card_rounded,
                  color: AppColors.primary, size: 28),
              title: Text('Card',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('Pay online (coming soon)',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(ctx, 'CARD'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _shareTracking(Map<String, dynamic> ride) async {
    final driver = ride['driver'] as Map<String, dynamic>? ?? {};
    String locationPart = '';
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission effective = perm;
      if (perm == LocationPermission.denied) {
        effective = await Geolocator.requestPermission();
      }
      if (effective == LocationPermission.whileInUse ||
          effective == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        locationPart =
            '\nMy current location 📍: https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      }
    } catch (_) {}

    final msg = '🚗 Tracking me on RideUz!\n'
        'Ride: ${ride['origin']} → ${ride['destination']}\n'
        'Driver: ${driver['full_name'] ?? 'N/A'}, Plate: ${driver['plate_number'] ?? 'N/A'}\n'
        'Price: ${ride['price_per_seat']} UZS/seat'
        '$locationPart';

    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final ride = rides.selectedRide;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: AppColors.surface,
      ),
      body: rides.isLoading && ride == null
          ? const Center(child: CircularProgressIndicator())
          : ride == null
              ? Center(
                  child: Text('Ride not found.',
                      style:
                          GoogleFonts.poppins(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: () => rides.fetchRideDetail(ride['id'] as int),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── Route card ──────────────────────────────────────
                      _RouteCard(ride: ride),
                      const SizedBox(height: 16),

                      // ── Driver card ─────────────────────────────────────
                      _DriverCard(
                        driver: ride['driver'] as Map<String, dynamic>? ?? {},
                        rating: ride['driver_rating'],
                      ),
                      const SizedBox(height: 16),

                      // ── Info card ───────────────────────────────────────
                      _InfoCard(ride: ride),
                      const SizedBox(height: 20),

                      // ── Seat map ────────────────────────────────────────
                      Text('Choose a Seat',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Green = Available · Red = Taken',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      _PassengerSeatMap(
                        seats: (ride['seats'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [],
                        rideStatus: ride['status'] ?? '',
                        onBook: (seatId) =>
                            _bookSeat(ride['id'] as int, seatId),
                      ),

                      const SizedBox(height: 20),

                      // ── View Route on Map ────────────────────────────────
                      _ViewOnMapButton(ride: ride),

                      const SizedBox(height: 12),

                      // ── Share tracking (ONGOING only) ────────────────────
                      if (ride['status'] == 'ONGOING')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _shareTracking(ride),
                              icon: const Icon(Icons.share_location_rounded,
                                  color: Colors.white),
                              label: const Text('Share My Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),

                      // ── Description ─────────────────────────────────────
                      if ((ride['description'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        Text('Notes from Driver',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(ride['description'].toString(),
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                      ],

                      // ── Rate Driver (COMPLETED only) ─────────────────────
                      if (ride['status'] == 'COMPLETED') ...[
                        const Divider(),
                        const SizedBox(height: 12),
                        if (ride['has_reviewed'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'You have rated this ride ✓',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: rides.isLoading
                                  ? null
                                  : () => _showRatingModal(ride),
                              icon: const Icon(Icons.star_rounded,
                                  color: Colors.white),
                              label: Text(
                                'Rate This Ride',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ── Route card ──────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    try {
      final dt = DateTime.parse(ride['departure_time'] ?? '');
      timeStr =
          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4C7DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ride['origin'] ?? '',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.more_vert_rounded,
                color: Colors.white.withValues(alpha: 0.5), size: 18),
          ),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ride['destination'] ?? '',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(timeStr,
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(ride['status'] ?? '',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Driver card ─────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver, this.rating});
  final Map<String, dynamic> driver;
  final dynamic rating;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver['full_name'] ?? 'Driver',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(
                    '${driver['car_model'] ?? ''} · ${driver['plate_number'] ?? ''}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (rating != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text('$rating',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.warning)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Info card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _InfoItem(
              icon: Icons.attach_money_rounded,
              label: 'Price',
              value: '${ride['price_per_seat'] ?? '?'} UZS',
            ),
            _InfoItem(
              icon: Icons.event_seat_rounded,
              label: 'Seats',
              value: '${ride['available_seats']}/${ride['total_seats']}',
            ),
            _InfoItem(
              icon: Icons.payment_rounded,
              label: 'Payment',
              value: ride['payment_method'] ?? 'BOTH',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary)),
        Text(value,
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Passenger seat map (tap free seat to book) ──────────────────────────────

class _PassengerSeatMap extends StatelessWidget {
  const _PassengerSeatMap({
    required this.seats,
    required this.rideStatus,
    required this.onBook,
  });
  final List<Map<String, dynamic>> seats;
  final String rideStatus;
  final ValueChanged<int> onBook;

  Map<String, dynamic>? _seatByPosition(String pos) {
    try {
      return seats.firstWhere((s) => s['position'] == pos);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canBook = rideStatus == 'PUBLISHED';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECFC)),
      ),
      child: Column(
        children: [
          // Front row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DriverSeatWidget(),
              const SizedBox(width: 24),
              _BookableSeat(
                seat: _seatByPosition('FRONT_RIGHT'),
                label: 'Front\nRight',
                canBook: canBook,
                onBook: onBook,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Back row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BookableSeat(
                seat: _seatByPosition('BACK_LEFT'),
                label: 'Back\nLeft',
                canBook: canBook,
                onBook: onBook,
              ),
              const SizedBox(width: 12),
              _BookableSeat(
                seat: _seatByPosition('BACK_MIDDLE'),
                label: 'Back\nMiddle',
                canBook: canBook,
                onBook: onBook,
              ),
              const SizedBox(width: 12),
              _BookableSeat(
                seat: _seatByPosition('BACK_RIGHT'),
                label: 'Back\nRight',
                canBook: canBook,
                onBook: onBook,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverSeatWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.airline_seat_recline_extra_rounded,
              color: AppColors.textSecondary, size: 24),
          Text('Driver',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BookableSeat extends StatelessWidget {
  const _BookableSeat({
    required this.seat,
    required this.label,
    required this.canBook,
    required this.onBook,
  });
  final Map<String, dynamic>? seat;
  final String label;
  final bool canBook;
  final ValueChanged<int> onBook;

  @override
  Widget build(BuildContext context) {
    if (seat == null) {
      // This position doesn't exist for this ride
      return SizedBox(
        width: 72,
        height: 72,
        child: Center(
            child: Text('—',
                style: GoogleFonts.poppins(color: AppColors.textHint))),
      );
    }

    final isAvailable = seat!['is_available'] == true;
    final seatId = seat!['id'] as int;

    return GestureDetector(
      onTap: (isAvailable && canBook) ? () => onBook(seatId) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isAvailable
              ? AppColors.secondary.withValues(alpha: 0.12)
              : AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAvailable ? AppColors.secondary : AppColors.error,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAvailable
                  ? Icons.event_seat_rounded
                  : Icons.event_seat_outlined,
              color: isAvailable ? AppColors.secondary : AppColors.error,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isAvailable ? AppColors.secondary : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View On Map Button ───────────────────────────────────────────────────────

/// Reads origin/destination lat-lng from the ride object and pushes
/// [RouteMapScreen]. Enables live GPS tracking for ONGOING rides.
class _ViewOnMapButton extends StatelessWidget {
  const _ViewOnMapButton({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final originLat = double.tryParse(ride['origin_lat']?.toString() ?? '');
    final originLng = double.tryParse(ride['origin_lng']?.toString() ?? '');
    final destLat = double.tryParse(ride['destination_lat']?.toString() ?? '');
    final destLng = double.tryParse(ride['destination_lng']?.toString() ?? '');

    final hasCoords = originLat != null &&
        originLng != null &&
        destLat != null &&
        destLng != null;

    final isOngoing = ride['status'] == 'ONGOING';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: hasCoords
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RouteMapScreen(
                    origin: LatLng(originLat, originLng),
                    destination: LatLng(destLat, destLng),
                    originLabel: ride['origin']?.toString() ?? 'Origin',
                    destinationLabel:
                        ride['destination']?.toString() ?? 'Destination',
                    liveTracking: isOngoing,
                  ),
                ))
            : null,
        icon: Icon(
          isOngoing ? Icons.my_location_rounded : Icons.map_outlined,
          size: 18,
        ),
        label: Text(
          hasCoords
              ? (isOngoing ? 'Track on Map (Live)' : 'View Route on Map')
              : 'Map unavailable (no coordinates)',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: hasCoords ? AppColors.primary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
