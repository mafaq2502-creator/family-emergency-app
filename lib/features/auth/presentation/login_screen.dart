import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/app_page_background.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_form_field.dart';
import '../../../services/auth_service.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_validators.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthActions? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthActions _authService = widget.authService ?? AuthService();
  bool _hidePassword = true;
  bool _loading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authService.signIn(
        email: AuthValidators.normalizeEmail(_email.text),
        password: _password.text,
      );
    } catch (error) {
      _showError(AuthErrorMapper.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (error) {
      if (!AuthErrorMapper.isCancellation(error)) {
        _showError(
          AuthErrorMapper.message(
            error,
            fallback: 'Google sign-in could not be completed.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kEmergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final muted = isDark ? kDarkMuted : kLightMuted;
    return Scaffold(
      body: AppPageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const AppBrandMark(size: 70),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Sign in to your safe Circle account',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 28),
                      AppTextFormField(
                        controller: _email,
                        label: 'Email',
                        placeholder: 'Enter your email',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_loading,
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: 18),
                      AppTextFormField(
                        controller: _password,
                        label: 'Password',
                        placeholder: 'Enter your password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_loading,
                        validator: AuthValidators.loginPassword,
                        onFieldSubmitted: (_) => _login(),
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 34,
                                height: 40,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: kLightPrimary,
                                  onChanged: _loading
                                      ? null
                                      : (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                ),
                              ),
                              Text(
                                'Remember me',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ForgotPasswordScreen(
                                        initialEmail: _email.text,
                                        authService: _authService,
                                      ),
                                    ),
                                  ),
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                      AppPrimaryButton(
                        label: 'Login',
                        isLoading: _loading,
                        onPressed: _loading ? null : _login,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR', style: TextStyle(color: muted)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _providerButton(
                        label: 'Continue with Google',
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _googleLogin,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: muted),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SignUpScreen(
                                        authService: _authService,
                                      ),
                                    ),
                                  ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
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

  Widget _providerButton({
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton.icon(
      onPressed: _loading ? null : onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? kDarkCard
            : Colors.white.withValues(alpha: .92),
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : kLightNavy,
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF233846)
              : kLightBorder,
        ),
      ),
    ),
  );
}
