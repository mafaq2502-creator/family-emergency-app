import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_page_background.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../services/auth_service.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/email_verification_policy.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.verification,
    required this.onContinue,
    this.allowTestingBypass,
  });

  final String email;
  final EmailVerificationActions verification;
  final ValueChanged<bool> onContinue;
  final bool? allowTestingBypass;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _resendTimer;
  bool _checking = false;
  bool _resending = false;
  bool _verified = false;
  int _resendSeconds = 0;
  String? _message;
  bool _messageIsError = false;

  bool get _testingBypassAllowed =>
      widget.allowTestingBypass ?? EmailVerificationPolicy.autoVerifyForTesting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(silent: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || _verified) return;
    setState(() {
      _checking = true;
      if (!silent) _message = null;
    });
    try {
      final verified = await widget.verification.refreshEmailVerification();
      if (!mounted) return;
      setState(() {
        _verified = verified;
        _messageIsError = false;
        _message = verified
            ? 'Email verified. Select Next to continue.'
            : silent
            ? _message
            : 'Email is not verified yet. Open the link in your inbox, then check again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = AuthErrorMapper.message(
          error,
          fallback: 'Verification status could not be checked. Please retry.',
        );
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0) return;
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await widget.verification.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _messageIsError = false;
        _message = 'A new verification link was sent to ${widget.email}.';
        _resendSeconds = 60;
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _resendSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _resendSeconds = 0);
        } else {
          setState(() => _resendSeconds--);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = AuthErrorMapper.message(
          error,
          fallback: 'The verification email could not be sent. Please retry.',
        );
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppPageBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: LightCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: (_verified ? kEmerald : kLightPrimary)
                          .withValues(alpha: .12),
                      child: Icon(
                        _verified
                            ? Icons.mark_email_read_rounded
                            : Icons.mark_email_unread_rounded,
                        size: 36,
                        color: _verified ? kEmerald : kLightPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appHeading,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a verification link to',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appMuted),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appHeading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _testingBypassAllowed
                          ? 'Open the email and select Verify Email. For testing, you can select Next and continue this session without completing the link.'
                          : 'Open the email and select Verify Email. Return to this app when verification is complete.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appMuted, height: 1.45),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _messageIsError ? kEmergency : kEmerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _checking ? null : () => _check(),
                        icon: _checking
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _checking ? 'Checking…' : 'Check verification',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resending || _resendSeconds > 0
                          ? null
                          : _resend,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend in ${_resendSeconds}s'
                            : _resending
                            ? 'Sending…'
                            : 'Resend verification email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _checking || _resending
                                ? null
                                : widget.verification.signOut,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _verified || _testingBypassAllowed
                                ? () => widget.onContinue(_verified)
                                : null,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
