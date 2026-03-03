import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';

/// Shows the driver's own published rides with passenger counts.
class AvailableRidesScreen extends StatefulWidget {
  const AvailableRidesScreen({super.key});

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RideProvider>().fetchMyRides());
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final published = rides.publishedRides;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Published Rides'),
        backgroundColor: AppColors.surface,
      ),
      body: rides.isLoading
          ? const Center(child: CircularProgressIndicator())
          : published.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route_rounded,
                          size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text('No published rides',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Publish a ride from the home screen',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: rides.fetchMyRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: published.length,
                    itemBuilder: (ctx, i) {
                      final ride = published[i];
                      final booked = (ride['total_seats'] ?? 0) -
                          (ride['available_seats'] ?? 0);
                      String timeStr = '';
                      try {
                        final dt = DateTime.parse(ride['departure_time'] ?? '');
                        timeStr =
                            '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            '${ride['origin']} → ${ride['destination']}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(timeStr,
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(width: 12),
                                Icon(Icons.people_rounded,
                                    size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text('$booked booked',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
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
