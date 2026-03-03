import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';

/// Shows a single ride detail for the driver, with Start/Complete/Cancel actions.
class DriverActiveRideScreen extends StatefulWidget {
  const DriverActiveRideScreen({super.key});

  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  bool _didFetch = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      final rideId = ModalRoute.of(context)?.settings.arguments as int?;
      if (rideId != null) {
        context.read<RideProvider>().fetchRideDetail(rideId);
      }
      _didFetch = true;
    }
  }

  Future<void> _doAction(String action) async {
    final rides = context.read<RideProvider>();
    final ride = rides.selectedRide;
    if (ride == null) return;
    final id = ride['id'] as int;

    bool success = false;
    if (action == 'start') success = await rides.startRide(id);
    if (action == 'complete') success = await rides.completeRide(id);
    if (action == 'cancel') success = await rides.cancelRide(id);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      await rides.fetchRideDetail(id);
      messenger.showSnackBar(
        SnackBar(content: Text('Ride ${action}ed successfully!')),
      );
    } else if (rides.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(rides.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final ride = rides.selectedRide;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Ride'),
        backgroundColor: AppColors.surface,
      ),
      body: rides.isLoading && ride == null
          ? const Center(child: CircularProgressIndicator())
          : ride == null
              ? Center(
                  child: Text('Ride not found.',
                      style:
                          GoogleFonts.poppins(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Route header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF4C7DE8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${ride['origin']} → ${ride['destination']}',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(ride['status'] ?? '',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _InfoRow('Price per seat',
                                '${ride['price_per_seat']} UZS'),
                            _InfoRow('Seats booked',
                                '${(ride['total_seats'] ?? 0) - (ride['available_seats'] ?? 0)} / ${ride['total_seats']}'),
                            _InfoRow(
                                'Payment', ride['payment_method'] ?? 'BOTH'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Passengers list
                    Text('Passengers',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (ride['seats'] != null)
                      ...(ride['seats'] as List).map((seat) {
                        final s = seat as Map<String, dynamic>;
                        final isBooked = s['is_available'] != true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: Icon(
                              isBooked
                                  ? Icons.person_rounded
                                  : Icons.event_seat_outlined,
                              color: isBooked
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                            title: Text(
                              s['position']?.toString().replaceAll('_', ' ') ??
                                  '',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                            trailing: Text(
                              isBooked
                                  ? s['booked_by_phone'] ?? 'Booked'
                                  : 'Available',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isBooked
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Actions
                    if (ride['status'] == 'PUBLISHED') ...[
                      ElevatedButton.icon(
                        onPressed:
                            rides.isLoading ? null : () => _doAction('start'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Ride'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed:
                            rides.isLoading ? null : () => _doAction('cancel'),
                        icon: const Icon(Icons.cancel_rounded),
                        label: const Text('Cancel Ride'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                    if (ride['status'] == 'ONGOING')
                      ElevatedButton.icon(
                        onPressed: rides.isLoading
                            ? null
                            : () => _doAction('complete'),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Complete Ride'),
                      ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
