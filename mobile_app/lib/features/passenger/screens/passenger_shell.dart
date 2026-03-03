import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import 'passenger_dashboard_screen.dart';
import 'passenger_home_screen.dart';
import 'passenger_ride_history_screen.dart';
import 'passenger_profile_screen.dart';
import 'complaint_screen.dart';

/// Root shell for the Passenger role.
/// Hosts a bottom NavigationBar + an SOS FloatingActionButton during active rides.
class PassengerShell extends StatefulWidget {
  const PassengerShell({super.key});

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _selectedIndex = 0;
  Timer? _pollTimer;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      PassengerDashboardScreen(onTabSwitch: _switchTab), // 0 · Home
      const PassengerHomeScreen(), // 1 · Find Ride
      const PassengerRideHistoryScreen(), // 2 · Bookings
      const ComplaintScreen(), // 3 · Complaint
      const PassengerProfileScreen(), // 4 · Profile
    ];
    // Poll bookings every 15 s so the badge & dashboard stay fresh
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) context.read<RideProvider>().fetchMyBookings();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _switchTab(int index) => setState(() => _selectedIndex = index);

  Future<void> _logout() async {
    await AuthService().clearToken();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppConstants.routeLogin, (_) => false);
  }

  // ── SOS dialog ───────────────────────────────────────────────────────────

  Future<void> _showSOS(String? emergencyContact) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded,
                  color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              'Emergency Options',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose who to call:',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // ── Call 1050 ────────────────────────────────────────────────
            _SOSActionTile(
              icon: Icons.local_police_rounded,
              color: AppColors.error,
              title: 'Emergency Services',
              subtitle: '1050',
              onTap: () async {
                Navigator.pop(ctx);
                await _dial('1050');
              },
            ),
            const SizedBox(height: 10),
            // ── Call personal emergency contact ─────────────────────────
            _SOSActionTile(
              icon: Icons.person_pin_circle_rounded,
              color: emergencyContact != null && emergencyContact.isNotEmpty
                  ? AppColors.warning
                  : AppColors.textHint,
              title: 'My Emergency Contact',
              subtitle: emergencyContact != null && emergencyContact.isNotEmpty
                  ? emergencyContact
                  : 'Not set — go to Profile to add',
              onTap: emergencyContact != null && emergencyContact.isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      await _dial(emergencyContact);
                    }
                  : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();

    // Count confirmed bookings for the badge
    final confirmedCount =
        rides.bookings.where((b) => b['status'] == 'CONFIRMED').length;

    // SOS is visible only when there is an ongoing ride
    final hasOngoingRide =
        rides.bookings.any((b) => b['ride_status'] == 'ONGOING');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _tabTitle(_selectedIndex),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      // ── SOS floating button ──────────────────────────────────────────────
      floatingActionButton: hasOngoingRide
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.error,
              icon: const Icon(Icons.sos_rounded, color: Colors.white),
              label: Text(
                'SOS',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final contact = prefs.getString('emergency_contact');
                if (!mounted) return;
                await _showSOS(contact);
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _switchTab,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon:
                  Icon(Icons.search_rounded, color: AppColors.primary),
              label: 'Find Ride',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: confirmedCount > 0,
                label: Text('$confirmedCount'),
                child: const Icon(Icons.bookmark_outline_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: confirmedCount > 0,
                label: Text('$confirmedCount'),
                child: const Icon(Icons.bookmark_rounded,
                    color: AppColors.primary),
              ),
              label: 'Bookings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.report_problem_outlined),
              selectedIcon:
                  Icon(Icons.report_problem_rounded, color: AppColors.primary),
              label: 'Complaint',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon:
                  Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Find a Ride';
      case 2:
        return 'My Bookings';
      case 3:
        return 'File a Complaint';
      case 4:
        return 'My Profile';
      default:
        return 'RideUz';
    }
  }
}

// ── SOS action tile ──────────────────────────────────────────────────────────

class _SOSActionTile extends StatelessWidget {
  const _SOSActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: color.withValues(alpha: enabled ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: enabled ? color : AppColors.textHint, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: enabled ? color : AppColors.textHint,
                        fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) Icon(Icons.phone_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
