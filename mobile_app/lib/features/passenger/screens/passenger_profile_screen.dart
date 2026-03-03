import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/passenger_profile_provider.dart';

class PassengerProfileScreen extends StatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  State<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<PassengerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  final _cardLast4Ctrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  final _picker = ImagePicker();
  XFile? _selectedProfileImage;
  String _existingProfileImageUrl = '';

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<PassengerProfileProvider>();
      await prov.fetchProfile();
      if (!mounted) return;
      final p = prov.profile;
      if (p != null) {
        _nameCtrl.text = p['full_name']?.toString() ?? '';
        _existingProfileImageUrl = p['profile_picture_url']?.toString() ?? '';
        _cardHolderCtrl.text = p['card_holder_name']?.toString() ?? '';
        _cardLast4Ctrl.text = p['card_last4']?.toString() ?? '';
        _cardExpiryCtrl.text = p['card_expiry_mm_yy']?.toString() ?? '';
      }
      // Load emergency contact from local prefs
      final prefs = await SharedPreferences.getInstance();
      _emergencyCtrl.text = prefs.getString('emergency_contact') ?? '';
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _nameCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardLast4Ctrl.dispose();
    _cardExpiryCtrl.dispose();
    _emergencyCtrl.dispose();
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

    final prov = context.read<PassengerProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await prov.saveProfile(
      fullName: _nameCtrl.text.trim(),
      cardHolderName: _cardHolderCtrl.text.trim(),
      cardLast4: _cardLast4Ctrl.text.trim(),
      cardExpiryMmYy: _cardExpiryCtrl.text.trim(),
      profilePicture: _selectedProfileImage,
    );
    // Save emergency contact locally regardless of profile save result
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contact', _emergencyCtrl.text.trim());

    if (!mounted) return;

    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('Profile saved ✓', style: GoogleFonts.poppins(fontSize: 13)),
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
          content: Text(
            prov.errorMessage ?? 'Could not save profile.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
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

    final prov = context.watch<PassengerProfileProvider>();
    final isLoading = prov.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Passenger Profile'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Full Name *',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Aliya Rakhimova',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Text('Profile Picture (optional)',
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
              const SizedBox(height: 20),
              Text('Card Holder Name (optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardHolderCtrl,
                decoration: const InputDecoration(
                  hintText: 'Name on card',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Card Last 4 (optional)',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cardLast4Ctrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '1234',
                            prefixIcon: Icon(Icons.credit_card_rounded),
                          ),
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return null;
                            if (val.length != 4 || int.tryParse(val) == null) {
                              return '4 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expiry MM/YY (optional)',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cardExpiryCtrl,
                          maxLength: 5,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '12/28',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return null;
                            if (val.length != 5 || val[2] != '/') {
                              return 'MM/YY';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('🚨 Emergency Contact (optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error)),
              const SizedBox(height: 4),
              Text(
                'Saved locally. Used for the SOS button during active rides.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+998 90 123 45 67',
                  prefixIcon:
                      const Icon(Icons.sos_rounded, color: AppColors.error),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Save Changes',
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
