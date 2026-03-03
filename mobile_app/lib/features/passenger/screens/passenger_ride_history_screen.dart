import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';

/// Shows the passenger's bookings (current and past).
class PassengerRideHistoryScreen extends StatefulWidget {
  const PassengerRideHistoryScreen({super.key});

  @override
  State<PassengerRideHistoryScreen> createState() =>
      _PassengerRideHistoryScreenState();
}

class _PassengerRideHistoryScreenState
    extends State<PassengerRideHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RideProvider>().fetchMyBookings());
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final bookings = rides.bookings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppColors.surface,
      ),
      body: rides.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border_rounded,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text('No bookings yet',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: rides.fetchMyBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    itemBuilder: (ctx, i) {
                      final b = bookings[i];
                      final status = b['status'] ?? '';
                      final rideStatus = b['ride_status'] ?? '';
                      final isActive = status == 'CONFIRMED';
                      final isCompleted =
                          isActive && rideStatus == 'COMPLETED';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppConstants.routeRideStatus,
                            arguments: b['ride'] as int,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${b['ride_origin']} → ${b['ride_destination']}',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.secondary
                                                .withValues(alpha: 0.12)
                                            : AppColors.textSecondary
                                                .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isActive
                                              ? AppColors.secondary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.event_seat_rounded,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      (b['seat_position'] ?? '')
                                          .toString()
                                          .replaceAll('_', ' '),
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.payment_rounded,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      b['payment_method'] ?? '',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.info_outline_rounded,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ride: $rideStatus',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),

                                // ── Cancel button (PUBLISHED rides only) ──
                                if (isActive && rideStatus == 'PUBLISHED') ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: rides.isLoading
                                          ? null
                                          : () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(
                                                      context);
                                              final ok = await rides
                                                  .cancelBooking(
                                                      b['id'] as int);
                                              if (ok && mounted) {
                                                messenger.showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Booking canceled.')));
                                              }
                                            },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(
                                            color: AppColors.error),
                                      ),
                                      child: const Text('Cancel Booking'),
                                    ),
                                  ),
                                ],

                                // ── Rate button (COMPLETED rides only) ────
                                if (isCompleted) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).pushNamed(
                                        AppConstants.routeRideStatus,
                                        arguments: b['ride'] as int,
                                      ),
                                      icon: const Icon(Icons.star_rounded,
                                          color: Colors.white, size: 18),
                                      label: Text(
                                        'Rate This Ride',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        minimumSize:
                                            const Size(double.infinity, 44),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
