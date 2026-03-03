import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// Reads the persisted token + role from SharedPreferences and routes
/// the user to the correct screen without any flicker.
///
/// Decision tree:
///   no token          → LoginScreen
///   token + DRIVER    → DriverHomeScreen
///   token + PASSENGER → PassengerHomeScreen
///   token + no role   → RoleSelectionScreen  (role not yet chosen)
///   token expired     → LoginScreen  (fetchMe clears the bad token)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Defer so the first frame renders before we do async work.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final service = AuthService();
    final token = await service.getSavedToken();

    if (!mounted) return;

    if (token == null) {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
      return;
    }

    // Token present — verify it's valid and get the canonical role from server.
    // fetchMe() also saves the role to SharedPreferences for offline-first starts.
    try {
      final role = await service.fetchMe();
      if (!mounted) return;

      switch (role) {
        case 'driver':
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.routeDriverHome);
        case 'passenger':
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.routePassengerHome);
        default:
          // Authenticated but role not yet chosen
          Navigator.of(context)
              .pushReplacementNamed(AppConstants.routeRoleSelect);
      }
    } catch (_) {
      // Token was invalid/expired (fetchMe already cleared it) or network error
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated logo ──────────────────────────────
            FadeTransition(
              opacity: Tween<double>(begin: 0.6, end: 1.0).animate(_pulse),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5B8DEF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ride, your way',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
