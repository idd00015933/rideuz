import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/driver_provider.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _carCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  final _picker = ImagePicker();
  XFile? _selectedProfileImage;
  String _existingProfileImageUrl = '';

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<DriverProvider>();
      await prov.fetchProfile();
      if (!mounted) return;
      final profile = prov.profile;
      if (profile != null) {
        _nameCtrl.text = profile['full_name']?.toString() ?? '';
        _carCtrl.text = profile['car_model']?.toString() ?? '';
        _plateCtrl.text = profile['plate_number']?.toString() ?? '';
        _existingProfileImageUrl =
            profile['profile_picture_url']?.toString() ?? '';
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _nameCtrl.dispose();
    _carCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (!mounted) return;
    if (img != null) {
      setState(() => _selectedProfileImage = img);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<DriverProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (_selectedProfileImage == null &&
        _existingProfileImageUrl.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Driver profile picture is required.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      return;
    }

    final fullName = _nameCtrl.text.trim();
    final carModel = _carCtrl.text.trim();
    final plateNumber = _plateCtrl.text.trim().toUpperCase();

    final bool ok = prov.hasProfile
        ? await prov.updateProfile(
            fullName: fullName,
            carModel: carModel,
            plateNumber: plateNumber,
            profilePicture: _selectedProfileImage,
          )
        : await prov.createProfile(
            fullName: fullName,
            carModel: carModel,
            plateNumber: plateNumber,
            profilePicture: _selectedProfileImage!,
          );

    if (!mounted) return;

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('Profile saved ✓', style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(prov.errorMessage ?? 'Could not save profile.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();

    final prov = context.watch<DriverProvider>();
    final profile = prov.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(prov.hasProfile ? 'Edit Profile' : 'Set Up Profile'),
        backgroundColor: AppColors.surface,
      ),
      body: prov.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile != null) ...[
                      _OnlineToggle(
                        isOnline: prov.isOnline,
                        isLoading: prov.isLoading,
                        onToggle: prov.toggleOnline,
                      ),
                      const SizedBox(height: 28),
                    ],
                    Text('Full Name',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Azizbek Karimov',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    Text('Profile Picture',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProfileImage != null
                                  ? _selectedProfileImage!.name
                                  : (_existingProfileImageUrl.isNotEmpty
                                      ? 'Current photo selected'
                                      : 'No image selected'),
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_rounded, size: 16),
                            label: const Text('Choose'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedProfileImage == null &&
                        _existingProfileImageUrl.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Required',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.error)),
                      ),
                    const SizedBox(height: 20),
                    Text('Car Model',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _carCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Chevrolet Malibu',
                        prefixIcon: Icon(Icons.directions_car_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    Text('Plate Number',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _plateCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 01A123BC',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: prov.isLoading ? null : _submit,
                        child: prov.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                prov.hasProfile
                                    ? 'Save Changes'
                                    : 'Create Profile',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle({
    required this.isOnline,
    required this.isLoading,
    required this.onToggle,
  });

  final bool isOnline;
  final bool isLoading;
  final Future<bool> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
            color: isOnline ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOnline ? 'You are Online' : 'You are Offline',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isOnline ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: isOnline,
              activeThumbColor: AppColors.success,
              onChanged: (_) => onToggle(),
            ),
        ],
      ),
    );
  }
}
