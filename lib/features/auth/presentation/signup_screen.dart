import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_form_field.dart';
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
  String? _relationship;
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
      final normalizedNumber = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
      final rawPhone = _phone.text.trim();
      final phoneE164 = rawPhone.startsWith('+')
          ? '+$normalizedNumber'
          : '+${_selectedCountry.phoneCode}$normalizedNumber';
      await _authService.signUp(
        name: _name.text.trim(),
        email: AuthValidators.normalizeEmail(_email.text),
        password: _password.text,
        phone: phoneE164,
        countryIso: _selectedCountry.countryCode,
        countryCode: '+${_selectedCountry.phoneCode}',
        relationship: _relationship!,
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

  Future<void> _socialSignUp({required bool apple}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await (apple
          ? _authService.signInWithApple()
          : _authService.signInWithGoogle());
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted && !AuthErrorMapper.isCancellation(error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthErrorMapper.message(
                error,
                fallback:
                    '${apple ? 'Apple' : 'Google'} sign-up could not be completed.',
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
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    const SizedBox(height: 37),
                    const Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kLightNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Join Family Emergency to keep\nyour loved ones safe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: kLightMuted),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _name,
                      'Full Name',
                      Icons.person_outline_rounded,
                      validator: AuthValidators.name,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      _email,
                      'Email',
                      Icons.mail_outline_rounded,
                      type: TextInputType.emailAddress,
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 8),
                    _phoneField(),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _relationship,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        hintText: 'Select your relationship',
                        prefixIcon: Icon(Icons.favorite_outline_rounded),
                      ),
                      items: AuthValidators.relationships
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (value) => setState(() => _relationship = value),
                      validator: AuthValidators.relationship,
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                            color: _acceptedTerms ? kEmerald : kLightMuted,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'I agree to the Terms & Conditions\nand Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Color(0xFF314761),
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
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(fontSize: 12, color: kLightMuted),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _socialSignUp(apple: false),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _socialSignUp(apple: true),
                        icon: const Icon(Icons.apple_rounded),
                        label: const Text('Sign up with Apple'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF52647D),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF2563EB),
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0x1A60A5FA)
                                : const Color(0x142563EB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .15,
                              decoration: TextDecoration.underline,
                              decorationThickness: 1.5,
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
      color: kLightMuted,
    ),
  );

  Widget _phoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? kDarkMuted : kLightMuted;
    return TextFormField(
      controller: _phone,
      enabled: !_loading,
      keyboardType: TextInputType.phone,
      validator: (value) => AuthValidators.phone(
        value?.trim().startsWith('+') == true
            ? value
            : '+${_selectedCountry.phoneCode}${value ?? ''}',
      ),
      style: TextStyle(color: isDark ? Colors.white : kLightNavy, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter your phone number',
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintStyle: TextStyle(color: muted, fontSize: 12),
        prefixIconConstraints: const BoxConstraints(minWidth: 102),
        prefixIcon: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _loading
              ? null
              : () => showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  favorite: const ['PK', 'AE', 'SA', 'GB', 'US'],
                  countryListTheme: CountryListThemeData(
                    backgroundColor: isDark ? kDarkCard : Colors.white,
                    textStyle: TextStyle(
                      color: isDark ? Colors.white : kLightNavy,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  onSelect: (country) =>
                      setState(() => _selectedCountry = country),
                ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedCountry.flagEmoji),
                const SizedBox(width: 4),
                Text(
                  '+${_selectedCountry.phoneCode}',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ],
            ),
          ),
        ),
        filled: true,
        fillColor: isDark ? kDarkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kEmerald),
        ),
      ),
    );
  }

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
