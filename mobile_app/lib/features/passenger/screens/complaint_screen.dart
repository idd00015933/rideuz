import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../ride/providers/ride_provider.dart';
import '../providers/complaint_provider.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  int? _selectedRideId;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RideProvider>().fetchMyBookings());
  }

  @override
  void dispose() {
    _isDisposed = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture context-derived objects before the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_selectedRideId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Please select a ride.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final prov = context.read<ComplaintProvider>();
    final description = _descCtrl.text.trim();

    final ok = await prov.fileComplaint(
      rideId: _selectedRideId!,
      description: description,
    );

    if (!mounted) return;

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Complaint submitted. Thank you.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(prov.errorMessage ?? 'Could not submit.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    final ridesProv = context.watch<RideProvider>();
    final complaintProv = context.watch<ComplaintProvider>();

    // Only allow complaints on completed rides (from bookings)
    final completedRides = ridesProv.bookings
        .where((r) => r['ride_status'] == 'COMPLETED')
        .toList();

    final isLoading = complaintProv.isLoading || ridesProv.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('File a Complaint'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.report_problem_rounded,
                      color: AppColors.error, size: 36),
                ),
              ),
              const SizedBox(height: 24),
              // ── Ride selector ──────────────────────────────────────────
              Text('Select Ride',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              if (ridesProv.isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (completedRides.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No completed rides found. Complete a ride before filing a complaint.',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedRideId,
                  decoration: const InputDecoration(
                    hintText: 'Choose a completed ride',
                    prefixIcon: Icon(Icons.local_taxi_rounded),
                  ),
                  items: completedRides.map((r) {
                    final id =
                        r['ride'] is int ? r['ride'] as int : r['id'] as int;
                    final label =
                        '${r['ride_origin'] ?? r['origin']} → ${r['ride_destination'] ?? r['destination']}';
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        label.length > 40
                            ? '${label.substring(0, 37)}…'
                            : label,
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedRideId = v),
                ),
              const SizedBox(height: 20),
              // ── Description ────────────────────────────────────────────
              Text('Description',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue in detail…',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(Icons.edit_note_rounded),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Please write at least 10 characters.'
                    : null,
              ),
              const SizedBox(height: 36),
              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (isLoading || completedRides.isEmpty) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Submit Complaint',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
