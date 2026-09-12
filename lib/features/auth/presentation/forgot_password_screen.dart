import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_form_field.dart';
import '../../../services/auth_service.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.authService,
  });

  final String initialEmail;
  final AuthActions? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  late final AuthActions _authService = widget.authService ?? AuthService();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _authService.sendPasswordResetEmail(_email.text);
      if (!mounted) return;
      _showSentConfirmation();
    } catch (error) {
      if (!mounted) return;
      if (error is FirebaseAuthException &&
          (error.code == 'user-not-found' ||
              error.code == 'invalid-credential')) {
        _showSentConfirmation();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthErrorMapper.message(error)),
          backgroundColor: kEmergency,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSentConfirmation() {
    if (!mounted) return;
    setState(() => _sent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If an account exists for this email, a reset link has been sent.',
        ),
        backgroundColor: kEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final muted = isDark ? kDarkMuted : kLightMuted;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.lock_reset_rounded, size: 64, color: kEmerald),
              const SizedBox(height: 18),
              Text(
                'Reset your password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Enter your account email and we will send password reset instructions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 28),
              AppTextFormField(
                controller: _email,
                label: 'Email',
                placeholder: 'Enter your email address',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                enabled: !_busy,
                validator: AuthValidators.email,
                onFieldSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_sent ? 'Send Again' : 'Send Reset Link'),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 14),
                Text(
                  'Check your inbox and spam folder, then return to Login.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
