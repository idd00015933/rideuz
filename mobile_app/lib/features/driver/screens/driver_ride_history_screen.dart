import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';

/// Driver ride history — COMPLETED and CANCELED rides.
class DriverRideHistoryScreen extends StatefulWidget {
  const DriverRideHistoryScreen({super.key});

  @override
  State<DriverRideHistoryScreen> createState() =>
      _DriverRideHistoryScreenState();
}

class _DriverRideHistoryScreenState extends State<DriverRideHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RideProvider>().fetchMyRides());
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final history = rides.historyRides;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: AppColors.surface,
      ),
      body: rides.isLoading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text('No past rides',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: rides.fetchMyRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) {
                      final ride = history[i];
                      final status = ride['status'] ?? '';
                      final isCompleted = status == 'COMPLETED';

                      String timeStr = '';
                      try {
                        final dt = DateTime.parse(ride['departure_time'] ?? '');
                        timeStr =
                            '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.secondary.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: isCompleted
                                  ? AppColors.secondary
                                  : AppColors.error,
                            ),
                          ),
                          title: Text(
                            '${ride['origin']} → ${ride['destination']}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(timeStr,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          trailing: Text(
                            '${ride['price_per_seat']} UZS',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary),
                          ),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppConstants.routeDriverActiveRide,
                            arguments: ride['id'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
