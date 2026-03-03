import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/shared/screens/splash_screen.dart';
import '../../features/driver/screens/driver_shell.dart';
import '../../features/driver/screens/driver_active_ride_screen.dart';
import '../../features/passenger/screens/passenger_shell.dart';
import '../../features/passenger/screens/passenger_ride_status_screen.dart';
import '../constants/app_constants.dart';

/// Central route table.  All screen names are defined in [AppConstants].
/// Arguments are passed via [RouteSettings.arguments] where needed.
class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> get routes => {
        AppConstants.routeSplash: (_) => const SplashScreen(),
        AppConstants.routeLogin: (_) => const LoginScreen(),

        // OTP screen expects OtpScreenArgs passed as arguments
        AppConstants.routeOtp: (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as OtpScreenArgs;
          return OtpScreen(
            phoneNumber: args.phoneNumber,
            mockOtp: args.mockOtp,
          );
        },

        AppConstants.routeRoleSelect: (_) => const RoleSelectionScreen(),

        // ── Driver shell (hosts bottom nav) ────────────────────────────────
        AppConstants.routeDriverHome: (_) => const DriverShell(),
        // Detail screens pushed on top of the shell
        AppConstants.routeDriverActiveRide: (_) =>
            const DriverActiveRideScreen(),

        // ── Passenger shell (hosts bottom nav + SOS FAB) ───────────────────
        AppConstants.routePassengerHome: (_) => const PassengerShell(),
        // Detail screens pushed on top of the shell
        AppConstants.routeRideStatus: (_) => const PassengerRideStatusScreen(),
      };
}

/// Arguments bundle for OtpScreen when navigated via named route.
class OtpScreenArgs {
  const OtpScreenArgs({required this.phoneNumber, this.mockOtp});
  final String phoneNumber;
  final String? mockOtp;
}
