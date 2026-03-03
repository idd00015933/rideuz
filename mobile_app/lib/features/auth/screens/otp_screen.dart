import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.mockOtp,
  });

  /// The 9-digit Uzbekistan number (without +998 prefix).
  final String phoneNumber;

  /// The OTP returned by the backend in demo mode.  Displayed as a hint so
  /// the tester can copy-paste it without reading the server log.
  final String? mockOtp;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _errorController = StreamController<ErrorAnimationType>();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _resendCooldown = 60;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  bool _hasError = false;
  String? _currentMockOtp; // updated when resend refreshes the OTP

  @override
  void initState() {
    super.initState();

    _currentMockOtp = widget.mockOtp;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      // Guard: the widget may have been disposed (e.g. navigation happened)
      // between when this tick was scheduled and when it fires.  Without this
      // check Flutter throws "setState called after dispose" (defunct lifecycle).
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _animController.dispose();
    _otpController.dispose();
    _errorController.close();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onVerify() async {
    if (_otpController.text.length < 6) {
      _errorController.add(ErrorAnimationType.shake);
      setState(() => _hasError = true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(_otpController.text);

    if (!mounted) return;

    if (success) {
      // Cancel timer BEFORE navigating to avoid setState-after-dispose crash.
      _timer?.cancel();

      // Determine role via GET /api/users/me/ and route accordingly:
      //   DRIVER    → DriverDashboard
      //   PASSENGER → PassengerDashboard
      //   no role   → RoleSelectionScreen
      final route = await auth.fetchMeAndRoute();
      if (!mounted) return;

      if (route == null) {
        // fetchMeAndRoute failed — show error, stay on OTP screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.errorMessage ?? 'Could not load profile. Try again.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (_) => false, // clear the entire auth stack
      );
    } else {
      // Shake the PIN field and surface the error from the provider
      _errorController.add(ErrorAnimationType.shake);
      setState(() => _hasError = true);
      final message = auth.errorMessage ?? 'Invalid OTP. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    }
  }

  Future<void> _onResend() async {
    if (_secondsLeft > 0) return;

    _otpController.clear();
    setState(() => _hasError = false);
    _startTimer();

    final auth = context.read<AuthProvider>();
    final result = await auth.requestOtp(widget.phoneNumber);

    if (!mounted) return;

    if (result.isSuccess) {
      // New OTP issued — update the hint
      setState(() => _currentMockOtp = result.otpCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New OTP sent to +998 ${widget.phoneNumber}',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    } else if (result.isAlreadyVerified) {
      // Already verified — OTP was sent to their phone; don't show red error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP sent to +998 ${widget.phoneNumber}',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
    } else {
      final message = auth.errorMessage ?? 'Could not resend OTP.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
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
    // Watch isLoading from the provider so the button reflects network state
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── Illustration ─────────────────────
                  Center(child: _OtpIllustration()),
                  const SizedBox(height: 32),

                  // ── Headline ─────────────────────────
                  Text(
                    'Verification Code',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      text: 'We sent a 6-digit code to ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: '+998 ${widget.phoneNumber}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Demo OTP hint ─────────────────────
                  if (_currentMockOtp != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Demo OTP: ',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _currentMockOtp!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // ── OTP Input ────────────────────────
                  Form(
                    key: _formKey,
                    child: PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: _otpController,
                      autoDisposeControllers: false,
                      errorAnimationController: _errorController,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.fade,
                      animationDuration: const Duration(milliseconds: 200),
                      enableActiveFill: true,
                      autoFocus: true,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(12),
                        fieldHeight: 58,
                        fieldWidth: 48,
                        activeFillColor: AppColors.surface,
                        inactiveFillColor: AppColors.surfaceVariant,
                        selectedFillColor: AppColors.surface,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.transparent,
                        selectedColor: AppColors.primary,
                        errorBorderColor: AppColors.error,
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (val) {
                        if (_hasError) setState(() => _hasError = false);
                      },
                      onCompleted: (_) => _onVerify(),
                    ),
                  ),

                  if (_hasError) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Please enter all 6 digits.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Verify Button ────────────────────
                  _VerifyButton(
                    isLoading: isLoading,
                    onPressed: _onVerify,
                  ),

                  const SizedBox(height: 28),

                  // ── Resend Row ───────────────────────
                  Center(
                    child: _secondsLeft > 0
                        ? RichText(
                            text: TextSpan(
                              text: "Didn't receive the code? Resend in ",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: '${_secondsLeft}s',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: _onResend,
                            child: Text.rich(
                              TextSpan(
                                text: "Didn't receive the code? ",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Resend',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _OtpIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF5B8DEF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4C7DE8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Verify & Continue',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
