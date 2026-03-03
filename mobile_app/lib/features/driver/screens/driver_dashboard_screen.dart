import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../../driver/providers/driver_provider.dart';

/// Driver Dashboard — Tab 0 in the Driver shell.
/// Shows greeting, active ride banner, quick stats, upcoming rides.
class DriverDashboardScreen extends StatefulWidget {
  /// Callback to switch the parent shell to a given tab index.
  final ValueChanged<int>? onTabSwitch;
  const DriverDashboardScreen({super.key, this.onTabSwitch});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().fetchMyRides();
      context.read<DriverProvider>().fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final driver = context.watch<DriverProvider>();

    final profile = driver.profile;
    final firstName =
        (profile?['full_name'] ?? 'Driver').toString().split(' ').first;

    final ongoing = rides.ongoingRides;
    final upcoming = rides.publishedRides
      ..sort((a, b) =>
          (a['departure_time'] ?? '').compareTo(b['departure_time'] ?? ''));
    final upcomingSlice = upcoming.take(3).toList();

    final history = rides.historyRides;
    final completedCount =
        history.where((r) => r['status'] == 'COMPLETED').length;
    // client-side earnings estimate
    final earnings = history
        .where((r) => r['status'] == 'COMPLETED')
        .fold<double>(0, (sum, r) {
      final booked = (r['total_seats'] ?? 0) - (r['available_seats'] ?? 0);
      final price =
          double.tryParse(r['price_per_seat']?.toString() ?? '0') ?? 0.0;
      return sum + booked * price;
    });

    return RefreshIndicator(
      onRefresh: () async {
        final rp = context.read<RideProvider>();
        final dp = context.read<DriverProvider>();
        await rp.fetchMyRides();
        await dp.fetchProfile();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // ── Greeting ──────────────────────────────────────────────────────
          _GreetingCard(
            name: firstName,
            isOnline: driver.isOnline,
            onToggle: () => driver.toggleOnline(),
          ),
          const SizedBox(height: 20),

          // ── Active Ride Banner ─────────────────────────────────────────────
          if (ongoing.isNotEmpty) ...[
            _ActiveRideBanner(
              ride: ongoing.first,
              onManage: () => Navigator.of(context).pushNamed(
                AppConstants.routeDriverActiveRide,
                arguments: ongoing.first['id'] as int,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Quick stats ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  label: 'Completed',
                  value: '$completedCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.attach_money_rounded,
                  color: AppColors.primary,
                  label: 'Est. Earnings',
                  value: earnings >= 1000
                      ? '${(earnings / 1000).toStringAsFixed(0)}K UZS'
                      : '${earnings.toStringAsFixed(0)} UZS',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.star_rounded,
                  color: AppColors.warning,
                  label: 'Rating',
                  value: profile?['rating'] != null
                      ? '${profile!['rating']}'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Upcoming rides ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upcoming Rides',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => widget.onTabSwitch?.call(2),
                child: const Text('See all →'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rides.isLoading && upcomingSlice.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (upcomingSlice.isEmpty)
            _EmptyState(
              icon: Icons.directions_car_outlined,
              message: 'No upcoming rides.\nPublish one!',
              actionLabel: 'Publish a Ride',
              onAction: () => widget.onTabSwitch?.call(1),
            )
          else
            ...upcomingSlice.map((r) => _UpcomingRideCard(ride: r)),
        ],
      ),
    );
  }
}

// ── Greeting card ────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  const _GreetingCard(
      {required this.name, required this.isOnline, required this.onToggle});
  final String name;
  final bool isOnline;
  final VoidCallback onToggle;

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4C7DE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_timeGreeting()},',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13)),
                Text('$name 👋',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline
                              ? Icons.wifi_tethering_rounded
                              : Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_car_rounded,
              color: Colors.white24, size: 64),
        ],
      ),
    );
  }
}

// ── Active Ride Banner ───────────────────────────────────────────────────────

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride, required this.onManage});
  final Map<String, dynamic> ride;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚗 Ride in progress',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.secondary)),
                Text(
                  '${ride['origin']} → ${ride['destination']}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${((ride['total_seats'] ?? 0) - (ride['available_seats'] ?? 0))} passengers aboard',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onManage,
            child: const Text('Manage →'),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Upcoming ride card ───────────────────────────────────────────────────────

class _UpcomingRideCard extends StatelessWidget {
  const _UpcomingRideCard({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    try {
      final dt = DateTime.parse(ride['departure_time'] ?? '').toLocal();
      timeStr =
          '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final booked = (ride['total_seats'] ?? 0) - (ride['available_seats'] ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.route_rounded,
              color: AppColors.primary, size: 22),
        ),
        title: Text(
          '${ride['origin']} → ${ride['destination']}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$timeStr · $booked/${ride['total_seats']} booked',
          style:
              GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${ride['price_per_seat']} UZS',
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.actionLabel,
      required this.onAction});
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
