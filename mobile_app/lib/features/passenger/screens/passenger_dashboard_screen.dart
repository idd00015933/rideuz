import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../providers/passenger_profile_provider.dart';

/// Passenger Dashboard — Tab 0 in the Passenger shell.
/// Shows greeting, active booking banner, recent bookings, and quick actions.
class PassengerDashboardScreen extends StatefulWidget {
  /// Callback to switch the parent shell to a given tab index.
  final ValueChanged<int>? onTabSwitch;
  const PassengerDashboardScreen({super.key, this.onTabSwitch});

  @override
  State<PassengerDashboardScreen> createState() =>
      _PassengerDashboardScreenState();
}

class _PassengerDashboardScreenState extends State<PassengerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().fetchMyBookings();
      context.read<PassengerProfileProvider>().fetchProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    final profile = context.watch<PassengerProfileProvider>().profile;
    final firstName =
        (profile?['full_name'] ?? 'Passenger').toString().split(' ').first;

    final bookings = rides.bookings;
    // Active booking = confirmed + ride is ongoing
    final activeBooking = bookings.cast<Map<String, dynamic>?>().firstWhere(
          (b) => b!['status'] == 'CONFIRMED' && b['ride_status'] == 'ONGOING',
          orElse: () => null,
        );
    final recentBookings = bookings.take(3).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final rp = context.read<RideProvider>();
        final pp = context.read<PassengerProfileProvider>();
        await rp.fetchMyBookings();
        await pp.fetchProfile();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // ── Greeting ──────────────────────────────────────────────────────
          _PassengerGreetingCard(
            name: firstName,
            onSearch: () => widget.onTabSwitch?.call(1),
          ),
          const SizedBox(height: 20),

          // ── Active Booking Banner ──────────────────────────────────────────
          if (activeBooking != null) ...[
            _ActiveBookingBanner(
              booking: activeBooking,
              onView: () => Navigator.of(context).pushNamed(
                AppConstants.routeRideStatus,
                arguments: activeBooking['ride'] as int,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Quick stats ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bookmark_rounded,
                  color: AppColors.primary,
                  label: 'Total Rides',
                  value: '${bookings.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  label: 'Completed',
                  value:
                      '${bookings.where((b) => b['ride_status'] == 'COMPLETED').length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.event_seat_rounded,
                  color: AppColors.warning,
                  label: 'Active',
                  value:
                      '${bookings.where((b) => b['status'] == 'CONFIRMED' && b['ride_status'] == 'PUBLISHED').length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Quick actions ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.search_rounded,
                  label: 'Find a Ride',
                  color: AppColors.primary,
                  onTap: () => widget.onTabSwitch?.call(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'My Bookings',
                  color: AppColors.secondary,
                  onTap: () => widget.onTabSwitch?.call(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Recent bookings ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Bookings',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => widget.onTabSwitch?.call(2),
                child: const Text('See all →'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rides.isLoading && recentBookings.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (recentBookings.isEmpty)
            _EmptyState(
              icon: Icons.search_off_rounded,
              message: 'No bookings yet.\nFind a ride to get started!',
              actionLabel: 'Find a Ride',
              onAction: () => widget.onTabSwitch?.call(1),
            )
          else
            ...recentBookings.map((b) => _RecentBookingCard(booking: b)),
        ],
      ),
    );
  }
}

// ── Passenger greeting card ──────────────────────────────────────────────────

class _PassengerGreetingCard extends StatelessWidget {
  const _PassengerGreetingCard({required this.name, required this.onSearch});
  final String name;
  final VoidCallback onSearch;

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
          colors: [Color(0xFF6B4EFF), Color(0xFF9B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4EFF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_timeGreeting()},',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          Text('$name 👋',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: Color(0xFF6B4EFF), size: 20),
                  const SizedBox(width: 10),
                  Text('Where are you going?',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active booking banner ─────────────────────────────────────────────────────

class _ActiveBookingBanner extends StatelessWidget {
  const _ActiveBookingBanner({required this.booking, required this.onView});
  final Map<String, dynamic> booking;
  final VoidCallback onView;

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
            child: const Icon(Icons.directions_car_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🟢 Ride in progress!',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.secondary)),
                Text(
                  '${booking['ride_origin']} → ${booking['ride_destination']}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Seat: ${(booking['seat_position'] ?? '').toString().replaceAll('_', ' ')}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onView, child: const Text('Track →')),
        ],
      ),
    );
  }
}

// ── Quick action button ───────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Recent booking card ───────────────────────────────────────────────────────

class _RecentBookingCard extends StatelessWidget {
  const _RecentBookingCard({required this.booking});
  final Map<String, dynamic> booking;

  Color _statusColor(String status) {
    if (status == 'CONFIRMED') return AppColors.secondary;
    if (status == 'COMPLETED') return AppColors.primary;
    return AppColors.textSecondary;
  }

  IconData _statusIcon(String status) {
    if (status == 'CONFIRMED') return Icons.bookmark_rounded;
    if (status == 'COMPLETED') return Icons.check_circle_rounded;
    return Icons.cancel_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? '';
    final rideStatus = booking['ride_status']?.toString() ?? '';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_statusIcon(status), color: color, size: 28),
        title: Text(
          '${booking['ride_origin'] ?? ''} → ${booking['ride_destination'] ?? ''}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${(booking['seat_position'] ?? '').toString().replaceAll('_', ' ')}  ·  Ride: $rideStatus',
          style:
              GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
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
          Icon(icon, color: color, size: 22),
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
