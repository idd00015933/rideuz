import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/driver_provider.dart';
import '../../ride/providers/ride_provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().fetchProfile();
      context.read<RideProvider>().fetchMyRides();
    });
  }

  Future<void> _logout() async {
    await AuthService().clearToken();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppConstants.routeLogin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final rides = context.watch<RideProvider>();
    final profile = driver.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await driver.fetchProfile();
          await rides.fetchMyRides();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Profile card ─────────────────────────────────────────────
            _ProfileCard(profile: profile),
            const SizedBox(height: 24),

            // ── Active rides banner ──────────────────────────────────────
            if (rides.ongoingRides.isNotEmpty) ...[
              ...rides.ongoingRides.map((ride) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ActiveRideBanner(
                      ride: ride,
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppConstants.routeDriverActiveRide),
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // ── Action tiles ─────────────────────────────────────────────
            Text('Quick Actions',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _NavTile(
              icon: Icons.add_road_rounded,
              color: AppColors.primary,
              label: 'Publish a Ride',
              subtitle: 'Create a new trip for passengers',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppConstants.routeCreateRide),
            ),
            _NavTile(
              icon: Icons.list_alt_rounded,
              color: AppColors.secondary,
              label: 'My Published Rides',
              subtitle: '${rides.publishedRides.length} active',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppConstants.routeAvailableRides),
            ),
            _NavTile(
              icon: Icons.directions_car_rounded,
              color: const Color(0xFF7C4DFF),
              label: 'My Profile',
              subtitle: profile == null
                  ? 'Not set up yet'
                  : profile['car_model']?.toString() ?? '',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppConstants.routeDriverProfile),
            ),
            _NavTile(
              icon: Icons.history_rounded,
              color: AppColors.warning,
              label: 'Trip History',
              subtitle: '${rides.historyRides.length} completed',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppConstants.routeDriverHistory),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final Map<String, dynamic>? profile;

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
        borderRadius: BorderRadius.circular(18),
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
          const Icon(Icons.directions_car_filled_rounded,
              color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?['full_name'] ?? 'Driver',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (profile != null)
                  Text(
                    '${profile!['car_model']} · ${profile!['plate_number']}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                if (profile == null)
                  Text(
                    'Set up your profile first',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride, required this.onTap});
  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ride['origin']} → ${ride['destination']}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Status: ${ride['status']}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(label,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
