import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';

/// Full-screen map that shows the route between [origin] and [destination].
/// If [liveTracking] is true, also shows a moving blue dot for the passenger.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.originLabel,
    required this.destinationLabel,
    this.liveTracking = false,
  });

  final LatLng origin;
  final LatLng destination;
  final String originLabel;
  final String destinationLabel;
  final bool liveTracking;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  List<LatLng> _polyline = [];
  LatLng? _currentPos;
  Timer? _trackTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
    if (widget.liveTracking) {
      _startTracking();
    }
  }

  @override
  void dispose() {
    _trackTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoute() async {
    try {
      final o = widget.origin;
      final d = widget.destination;
      final url = 'http://router.project-osrm.org/route/v1/driving/'
          '${o.longitude},${o.latitude};${d.longitude},${d.latitude}'
          '?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final coords = (body['routes'][0]['geometry']['coordinates'] as List)
            .map((c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        setState(() {
          _polyline = coords;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startTracking() async {
    await _updatePosition();
    _trackTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _updatePosition());
  }

  Future<void> _updatePosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission eff = perm;
      if (perm == LocationPermission.denied) {
        eff = await Geolocator.requestPermission();
      }
      if (eff == LocationPermission.whileInUse ||
          eff == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
        );
        if (mounted) {
          setState(() => _currentPos = LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds(widget.origin, widget.destination);
    // Expand bounds slightly so both pins are visible
    final sw = LatLng(
      bounds.southWest.latitude - 0.05,
      bounds.southWest.longitude - 0.05,
    );
    final ne = LatLng(
      bounds.northEast.latitude + 0.05,
      bounds.northEast.longitude + 0.05,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.originLabel} → ${widget.destinationLabel}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.surface,
        actions: [
          if (widget.liveTracking && _currentPos != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                avatar: const Icon(Icons.gps_fixed_rounded,
                    size: 14, color: Colors.white),
                label: Text('Live',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
                backgroundColor: AppColors.secondary,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(sw, ne),
                padding: const EdgeInsets.all(32),
              ),
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rideuz.app',
              ),

              // Route polyline
              if (_polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polyline,
                      strokeWidth: 4.5,
                      color: AppColors.primary,
                    ),
                  ],
                ),

              // Origin + destination markers
              MarkerLayer(
                markers: [
                  // Origin (green)
                  Marker(
                    point: widget.origin,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.trip_origin_rounded,
                        color: AppColors.secondary, size: 32),
                  ),
                  // Destination (red)
                  Marker(
                    point: widget.destination,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on_rounded,
                        color: AppColors.error, size: 36),
                  ),
                  // Live position (blue)
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_loading)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('Loading route…',
                          style: GoogleFonts.poppins(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // Legend
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendItem(
                      icon: Icons.trip_origin_rounded,
                      color: AppColors.secondary,
                      label: widget.originLabel),
                  _LegendItem(
                      icon: Icons.location_on_rounded,
                      color: AppColors.error,
                      label: widget.destinationLabel),
                  if (widget.liveTracking)
                    _LegendItem(
                        icon: Icons.person_rounded,
                        color: AppColors.primary,
                        label: 'You'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
