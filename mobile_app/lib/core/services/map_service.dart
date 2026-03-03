import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Free, no-API-key map services used by RideUz.
///
///  • Nominatim (openstreetmap.org) → reverse-geocode lat/lng → human address
///  • OSRM public API               → driving route geometry between two points
///
/// Both services require an honest User-Agent string per their ToS.
class MapService {
  static const _userAgent = 'RideUz/1.0 (contact@rideuz.uz)';
  static const _backendBase = 'http://127.0.0.1:8000';

  // ── Reverse geocoding ──────────────────────────────────────────────────────

  /// Convert [lat]/[lng] to a human-readable address string.
  /// Uses Django backend proxy first (works on web without CORS issues).
  /// Falls back to direct Nominatim call on non-web platforms.
  Future<String> reverseGeocode(double lat, double lng) async {
    // 1) Backend proxy (primary path for all platforms, mandatory for web)
    try {
      final proxyUri = Uri.parse(
        '$_backendBase/api/maps/reverse/?lat=${lat.toStringAsFixed(7)}&lng=${lng.toStringAsFixed(7)}',
      );
      final proxyRes = await http.get(proxyUri);
      if (proxyRes.statusCode == 200) {
        final data = jsonDecode(proxyRes.body) as Map<String, dynamic>;
        final address = (data['address'] ?? '').toString().trim();
        if (address.isNotEmpty) return address;
      }
    } catch (_) {}

    // 2) Direct call fallback (mobile/desktop only; web would still hit CORS)
    if (!kIsWeb) {
      try {
        final uri = Uri.https(
          'nominatim.openstreetmap.org',
          '/reverse',
          {
            'lat': lat.toStringAsFixed(7),
            'lon': lng.toStringAsFixed(7),
            'format': 'json',
            'accept-language': 'en',
          },
        );
        final res = await http.get(uri, headers: {'User-Agent': _userAgent});
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final display = data['display_name']?.toString() ?? '';
          if (display.isNotEmpty) {
            final parts = display.split(',');
            return parts.take(3).join(',').trim();
          }
        }
      } catch (_) {}
    }

    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  // ── Routing ────────────────────────────────────────────────────────────────

  /// Fetch a driving route from [pickup] to [destination] using the OSRM
  /// public routing API.  Returns a list of [LatLng] waypoints that form the
  /// encoded polyline.  Returns a straight-line fallback on failure.
  Future<List<LatLng>> fetchRoute(LatLng pickup, LatLng destination) async {
    try {
      // OSRM expects coordinates as lng,lat (note: longitude FIRST)
      final coords = '${pickup.longitude},${pickup.latitude};'
          '${destination.longitude},${destination.latitude}';
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null) {
            return coords
                .cast<List>()
                .map((c) => LatLng(
                      (c[1] as num).toDouble(), // lat
                      (c[0] as num).toDouble(), // lng
                    ))
                .toList();
          }
        }
      }
    } catch (_) {}
    // Straight-line fallback — two points only
    return [pickup, destination];
  }
}
