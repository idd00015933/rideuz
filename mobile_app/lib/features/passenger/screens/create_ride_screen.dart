import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../../shared/widgets/city_search_field.dart';
import '../../shared/widgets/route_map_screen.dart';

/// Driver publishes a new ride with origin, destination, departure time,
/// price per seat, payment method, and visual seat selection.
class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  LatLng? _originCoords;
  LatLng? _destinationCoords;

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  String _paymentMethod = 'BOTH';

  // Seat selection — user taps on the visual seat map
  final Set<String> _selectedSeats = {
    'FRONT_RIGHT',
    'BACK_LEFT',
    'BACK_MIDDLE',
    'BACK_RIGHT'
  };

  @override
  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _departureDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _departureTime = time);
  }

  String? _combinedDepartureTime() {
    if (_departureDate == null || _departureTime == null) return null;
    final dt = DateTime(
      _departureDate!.year,
      _departureDate!.month,
      _departureDate!.day,
      _departureTime!.hour,
      _departureTime!.minute,
    );
    return dt.toIso8601String();
  }

  void _openRoutePreview() {
    if (_originCoords == null || _destinationCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Pick both cities from the autocomplete to preview the route.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RouteMapScreen(
        origin: _originCoords!,
        destination: _destinationCoords!,
        originLabel: _originCtrl.text,
        destinationLabel: _destinationCtrl.text,
      ),
    ));
  }

  Future<void> _publishRide() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departureDate == null || _departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure date & time.')),
      );
      return;
    }
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat.')),
      );
      return;
    }

    final provider = context.read<RideProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ride = await provider.createRide(
      origin: _originCtrl.text.trim(),
      destination: _destinationCtrl.text.trim(),
      departureTime: _combinedDepartureTime()!,
      pricePerSeat: double.parse(_priceCtrl.text.trim()),
      paymentMethod: _paymentMethod,
      seats: _selectedSeats.toList(),
      description: _descCtrl.text.trim(),
      originLat: _originCoords?.latitude,
      originLng: _originCoords?.longitude,
      destinationLat: _destinationCoords?.latitude,
      destinationLng: _destinationCoords?.longitude,
    );

    if (!mounted) return;
    if (ride != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ride published successfully! 🎉')),
      );
      // Clear form
      _originCtrl.clear();
      _destinationCtrl.clear();
      _priceCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _originCoords = null;
        _destinationCoords = null;
        _departureDate = null;
        _departureTime = null;
        _selectedSeats
            .addAll(['FRONT_RIGHT', 'BACK_LEFT', 'BACK_MIDDLE', 'BACK_RIGHT']);
      });
    } else if (provider.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<RideProvider>().isLoading;
    final canPreview = _originCoords != null && _destinationCoords != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Publish a Ride'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Route ──────────────────────────────────────────────────
              _SectionTitle('Route'),
              const SizedBox(height: 8),
              CitySearchField(
                controller: _originCtrl,
                label: 'From',
                hint: 'e.g. Tashkent',
                prefixIcon: const Icon(Icons.trip_origin_rounded,
                    color: AppColors.secondary),
                onSelected: (city, coords) {
                  _originCtrl.text = city;
                  setState(() => _originCoords = coords);
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              CitySearchField(
                controller: _destinationCtrl,
                label: 'To',
                hint: 'e.g. Samarkand',
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: AppColors.error),
                onSelected: (city, coords) {
                  _destinationCtrl.text = city;
                  setState(() => _destinationCoords = coords);
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // ── Preview Route button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canPreview ? _openRoutePreview : null,
                  icon: const Icon(Icons.map_rounded),
                  label: Text(canPreview
                      ? 'Preview Route on Map'
                      : 'Select cities to preview map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color:
                          canPreview ? AppColors.primary : AppColors.textHint,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Departure ──────────────────────────────────────────────
              _SectionTitle('Departure'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        _departureDate == null
                            ? 'Pick Date'
                            : '${_departureDate!.day}/${_departureDate!.month}/${_departureDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        _departureTime == null
                            ? 'Pick Time'
                            : _departureTime!.format(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Price ──────────────────────────────────────────────────
              _SectionTitle('Price per Seat (UZS)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 50000',
                  prefixIcon: Icon(Icons.attach_money_rounded,
                      color: AppColors.secondary),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Invalid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Payment method ─────────────────────────────────────────
              _SectionTitle('Payment Method'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['CASH', 'CARD', 'BOTH'].map((m) {
                  final selected = _paymentMethod == m;
                  return ChoiceChip(
                    label: Text(m[0] + m.substring(1).toLowerCase()),
                    selected: selected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.poppins(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    onSelected: (_) => setState(() => _paymentMethod = m),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Seat Selection (Visual map) ────────────────────────────
              _SectionTitle('Available Seats'),
              const SizedBox(height: 4),
              Text('Tap seats to toggle availability',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              _CarSeatMap(
                selectedSeats: _selectedSeats,
                onToggle: (pos) {
                  setState(() {
                    if (_selectedSeats.contains(pos)) {
                      _selectedSeats.remove(pos);
                    } else {
                      _selectedSeats.add(pos);
                    }
                  });
                },
              ),

              const SizedBox(height: 24),

              // ── Description ────────────────────────────────────────────
              _SectionTitle('Description (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Any notes for passengers...',
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _publishRide,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Publish Ride'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Visual car seat map ──────────────────────────────────────────────────────

class _CarSeatMap extends StatelessWidget {
  const _CarSeatMap({required this.selectedSeats, required this.onToggle});
  final Set<String> selectedSeats;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECFC)),
      ),
      child: Column(
        children: [
          // Front row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DriverSeat(),
              const SizedBox(width: 24),
              _SeatButton(
                label: 'Front\nRight',
                position: 'FRONT_RIGHT',
                isSelected: selectedSeats.contains('FRONT_RIGHT'),
                onTap: () => onToggle('FRONT_RIGHT'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Back row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SeatButton(
                label: 'Back\nLeft',
                position: 'BACK_LEFT',
                isSelected: selectedSeats.contains('BACK_LEFT'),
                onTap: () => onToggle('BACK_LEFT'),
              ),
              const SizedBox(width: 12),
              _SeatButton(
                label: 'Back\nMiddle',
                position: 'BACK_MIDDLE',
                isSelected: selectedSeats.contains('BACK_MIDDLE'),
                onTap: () => onToggle('BACK_MIDDLE'),
              ),
              const SizedBox(width: 12),
              _SeatButton(
                label: 'Back\nRight',
                position: 'BACK_RIGHT',
                isSelected: selectedSeats.contains('BACK_RIGHT'),
                onTap: () => onToggle('BACK_RIGHT'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverSeat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.airline_seat_recline_extra_rounded,
              color: AppColors.textSecondary, size: 24),
          Text('Driver',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.label,
    required this.position,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String position;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : AppColors.textHint.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.event_seat_rounded : Icons.event_seat_outlined,
              color: isSelected ? AppColors.secondary : AppColors.textHint,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppColors.secondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
