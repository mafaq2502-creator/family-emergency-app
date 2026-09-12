import '../../../core/widgets/country_name_field.dart';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_form_field.dart';
import '../../../core/domain/mobile_phone_number.dart';
import '../../../core/widgets/mobile_phone_field.dart';
import '../../../services/auth_service.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/auth_validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.authService});

  final AuthActions? authService;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _loading = false;
  late final AuthActions _authService = widget.authService ?? AuthService();
  Country _selectedCountry = CountryService().findByCode('PK')!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deviceCountry = Localizations.localeOf(context).countryCode;
      final suggestedCountry = CountryService().findByCode(deviceCountry);
      if (suggestedCountry != null && mounted) {
        setState(() => _selectedCountry = suggestedCountry);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _showTermsError = true);
      return;
    }
    setState(() => _loading = true);
    try {
      final phoneE164 = MobilePhoneNumber.normalize(
        _phone.text,
        _selectedCountry.phoneCode,
      );
      await _authService.signUp(
        name: _name.text.trim(),
        email: AuthValidators.normalizeEmail(_email.text),
        password: _password.text,
        phone: phoneE164,
        countryIso: _selectedCountry.countryCode,
        countryCode: '+${_selectedCountry.phoneCode}',
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (error is ProfileCreationException) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthErrorMapper.message(error)),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignUp() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted && !AuthErrorMapper.isCancellation(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthErrorMapper.message(
                error,
                fallback: 'Google sign-up could not be completed.',
              ),
            ),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? kDarkBackground
        : Colors.transparent,
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned(
            left: -52,
            top: 42,
            child: _SignUpSoftCircle(size: 132),
          ),
          const Positioned(
            right: -42,
            bottom: -48,
            child: _SignUpSoftCircle(size: 154),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 37),
                    Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.appHeading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join Family Emergency to keep\nyour loved ones safe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: context.appMuted),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _name,
                      'Full Name',
                      Icons.person_outline_rounded,
                      validator: AuthValidators.name,
                    ),
                    const SizedBox(height: 18),
                    _field(
                      _email,
                      'Email',
                      Icons.mail_outline_rounded,
                      type: TextInputType.emailAddress,
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 18),
                    CountryNameField(
                      countryIso: _selectedCountry.countryCode,
                      enabled: !_loading,
                      onChanged: (country) =>
                          setState(() => _selectedCountry = country),
                    ),
                    const SizedBox(height: 18),
                    MobilePhoneField(
                      controller: _phone,
                      country: _selectedCountry,
                      enabled: !_loading,
                      textInputAction: TextInputAction.next,
                      onCountryChanged: (country) =>
                          setState(() => _selectedCountry = country),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      _password,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscure: _hidePassword,
                      validator: AuthValidators.password,
                      trailing: _visibilityButton(
                        _hidePassword,
                        () => setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      _confirmPassword,
                      'Confirm Password',
                      Icons.lock_outline_rounded,
                      obscure: _hideConfirmation,
                      validator: (value) =>
                          AuthValidators.confirmPassword(value, _password.text),
                      trailing: _visibilityButton(
                        _hideConfirmation,
                        () => setState(
                          () => _hideConfirmation = !_hideConfirmation,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    InkWell(
                      onTap: _loading
                          ? null
                          : () => setState(() {
                              _acceptedTerms = !_acceptedTerms;
                              _showTermsError = false;
                            }),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _acceptedTerms
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: _acceptedTerms ? kEmerald : context.appMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'I agree to the Terms & Conditions\nand Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: context.appMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showTermsError)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 27, top: 5),
                          child: Text(
                            'Please accept the Terms & Conditions.',
                            style: TextStyle(color: kEmergency, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kEmerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appMuted,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _googleSignUp,
                        icon: const Text(
                          'G',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        label: const Text('Sign up with Google'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appMuted,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: kEmerald,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .15,
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
        ],
      ),
    ),
  );

  Widget _visibilityButton(bool hidden, VoidCallback onTap) => IconButton(
    onPressed: _loading ? null : onTap,
    icon: Icon(
      hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 19,
      color: context.appMuted,
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
    Widget? prefix,
    Widget? trailing,
    String? Function(String?)? validator,
  }) => AppTextFormField(
    controller: controller,
    label: label,
    placeholder: 'Enter $label',
    prefix: prefix,
    prefixIcon: prefix == null ? icon : null,
    suffixIcon: trailing,
    keyboardType: type,
    obscureText: obscure,
    validator: validator,
  );
}

class _SignUpSoftCircle extends StatelessWidget {
  final double size;
  const _SignUpSoftCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0x1410B981),
      shape: BoxShape.circle,
    ),
  );
}
