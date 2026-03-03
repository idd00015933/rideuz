import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../screens/driver_dashboard_screen.dart';
import '../screens/available_rides_screen.dart';
import '../screens/driver_ride_history_screen.dart';
import '../screens/driver_profile_screen.dart';
import '../../passenger/screens/create_ride_screen.dart';

/// Root shell for the Driver role.
/// Handles the bottom navigation and persists screen state via IndexedStack.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Dashboard needs a callback to switch tabs → build lazily
    _screens = [
      DriverDashboardScreen(onTabSwitch: _switchTab), // 0 · Home
      const CreateRideScreen(), // 1 · Publish
      const AvailableRidesScreen(), // 2 · My Rides
      const DriverRideHistoryScreen(), // 3 · History
      const DriverProfileScreen(), // 4 · Profile
    ];
  }

  void _switchTab(int index) => setState(() => _selectedIndex = index);

  Future<void> _logout() async {
    await AuthService().clearToken();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppConstants.routeLogin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideProvider>();
    // Badge count = ongoing rides
    final ongoingCount = rides.ongoingRides.length;

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
              icon: Icon(Icons.add_road_outlined),
              selectedIcon:
                  Icon(Icons.add_road_rounded, color: AppColors.primary),
              label: 'Publish',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: ongoingCount > 0,
                label: Text('$ongoingCount'),
                child: const Icon(Icons.list_alt_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: ongoingCount > 0,
                label: Text('$ongoingCount'),
                child: const Icon(Icons.list_alt_rounded,
                    color: AppColors.primary),
              ),
              label: 'My Rides',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon:
                  Icon(Icons.history_rounded, color: AppColors.primary),
              label: 'History',
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
        return 'Publish a Ride';
      case 2:
        return 'My Rides';
      case 3:
        return 'Trip History';
      case 4:
        return 'My Profile';
      default:
        return 'RideUz';
    }
  }
}
