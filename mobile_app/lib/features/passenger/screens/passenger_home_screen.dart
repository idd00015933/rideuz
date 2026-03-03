import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../../shared/widgets/city_search_field.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().fetchMyBookings();
      // Load all published rides by default
      context.read<RideProvider>().searchRides();
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService().clearToken();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppConstants.routeLogin, (_) => false);
  }

  void _search() {
    context.read<RideProvider>().searchRides(
          origin: _originCtrl.text.trim(),
          destination: _destCtrl.text.trim(),
        );
  }

  void _openRideDetail(Map<String, dynamic> ride) {
    Navigator.of(context).pushNamed(
      AppConstants.routeRideStatus,
      arguments: ride['id'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find a Ride'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                CitySearchField(
                  controller: _originCtrl,
                  label: 'From',
                  hint: 'e.g. Tashkent',
                  prefixIcon: const Icon(Icons.trip_origin_rounded,
                      color: AppColors.secondary, size: 20),
                  onSelected: (city, _) {
                    _originCtrl.text = city;
                  },
                ),
                const SizedBox(height: 10),
                CitySearchField(
                  controller: _destCtrl,
                  label: 'To',
                  hint: 'e.g. Samarkand',
                  prefixIcon: const Icon(Icons.location_on_rounded,
                      color: AppColors.error, size: 20),
                  onSelected: (city, _) {
                    _destCtrl.text = city;
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search Rides'),
                  ),
                ),
              ],
            ),
          ),

          // ── Quick nav ─────────────────────────────────────────────────

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _QuickNavChip(
                  icon: Icons.bookmark_rounded,
                  label: 'My Bookings',
                  count: rides.bookings.length,
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppConstants.routePassengerHistory),
                ),
                const SizedBox(width: 8),
                _QuickNavChip(
                  icon: Icons.account_circle_rounded,
                  label: 'Profile',
                  onTap: () => Navigator.of(context)
                      .pushNamed(AppConstants.routePassengerProfile),
                ),
              ],
            ),
          ),

          // ── Results ───────────────────────────────────────────────────
          Expanded(
            child: rides.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rides.searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.textHint),
                            const SizedBox(height: 8),
                            Text('No rides found',
                                style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary)),
                            Text('Try another route or date',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textHint)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => rides.searchRides(
                          origin: _originCtrl.text.trim(),
                          destination: _destCtrl.text.trim(),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: rides.searchResults.length,
                          itemBuilder: (ctx, i) => _RideCard(
                            ride: rides.searchResults[i],
                            onTap: () =>
                                _openRideDetail(rides.searchResults[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Quick nav chip ───────────────────────────────────────────────────────────

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(
        count != null ? '$label ($count)' : label,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// ── Ride card ────────────────────────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.onTap});
  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final driver = ride['driver'] as Map<String, dynamic>?;
    final driverName = driver?['full_name'] ?? 'Driver';
    final carModel = driver?['car_model'] ?? '';
    final available = ride['available_seats'] ?? 0;
    final total = ride['total_seats'] ?? 0;
    final price = ride['price_per_seat'];
    final departure = ride['departure_time'] ?? '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(departure);
      timeStr =
          '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route
              Row(
                children: [
                  const Icon(Icons.trip_origin_rounded,
                      color: AppColors.secondary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ride['origin']} → ${ride['destination']}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Details row
              Row(
                children: [
                  _InfoChip(Icons.person_rounded, driverName),
                  const SizedBox(width: 8),
                  _InfoChip(Icons.access_time_rounded, timeStr),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(Icons.directions_car_rounded, carModel),
                  const Spacer(),
                  // Seats
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: available > 0
                          ? AppColors.secondary.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$available/$total seats',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: available > 0
                            ? AppColors.secondary
                            : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Price
                  Text(
                    '${price ?? '?'} UZS',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style:
              GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
