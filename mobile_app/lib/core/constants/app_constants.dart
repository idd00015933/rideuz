class AppConstants {
  AppConstants._();

  static const appName = 'RideUz';

  // ── Auth flow ───────────────────────────────
  static const routeSplash = '/';
  static const routeLogin = '/login';
  static const routeOtp = '/otp';
  static const routeRoleSelect = '/role-select';

  // ── Driver ──────────────────────────────────
  static const routeDriverHome = '/driver/home';
  static const routeDriverProfile = '/driver/profile';
  static const routeAvailableRides = '/driver/available-rides';
  static const routeDriverActiveRide = '/driver/active-ride';
  static const routeDriverHistory = '/driver/history';

  // ── Passenger ───────────────────────────────
  static const routePassengerHome = '/passenger/home';
  static const routePassengerProfile = '/passenger/profile';
  static const routeCreateRide = '/passenger/create-ride';
  static const routeRideStatus = '/passenger/ride-status';
  static const routePassengerHistory = '/passenger/history';
  static const routeComplaint = '/passenger/complaint';
}
