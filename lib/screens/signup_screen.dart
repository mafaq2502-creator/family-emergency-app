import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

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
  bool _loading = false;
  Country _selectedCountry = CountryService().findByCode('PK')!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deviceCountry = Localizations.localeOf(context).countryCode;
      final suggestedCountry = CountryService().findByCode(deviceCountry);
      if (suggestedCountry != null && mounted) setState(() => _selectedCountry = suggestedCountry);
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
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept the Terms & Conditions'), backgroundColor: kEmergency));
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      await credential.user!.updateDisplayName(_name.text.trim());
      final normalizedNumber = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
      final phoneE164 = normalizedNumber.isEmpty ? '' : '+${_selectedCountry.phoneCode}$normalizedNumber';
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': phoneE164,
        'phoneCountryIso': _selectedCountry.countryCode,
        'phoneCountryCode': '+${_selectedCountry.phoneCode}',
        'isFamilyOwner': true,
        'notificationSettings': {
          'missedCheckInAlerts': true,
          'emergencyAlerts': true,
          'batteryAlerts': false,
          'offlineAlerts': false,
          'locationSharing': false,
          'ownerMissedCheckInAlerts': true,
        },
        // The supplied sign-up design has no relationship input; Profile can change it later.
        'role': 'Self',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.code == 'email-already-in-use' ? 'This email is already registered' : 'Could not create account'),
          backgroundColor: kEmergency,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? kDarkBackground : const Color(0xFFF8FBFA),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned(left: -52, top: 42, child: _SignUpSoftCircle(size: 132)),
              const Positioned(right: -42, bottom: -48, child: _SignUpSoftCircle(size: 154)),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 37),
                        const Text('Create Your Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kNavy)),
                        const SizedBox(height: 4),
                        const Text('Join Family Emergency to keep\nyour loved ones safe.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        _field(_name, 'Full Name', Icons.person_outline_rounded, validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null),
                        const SizedBox(height: 8),
                        _field(_email, 'Email', Icons.mail_outline_rounded, type: TextInputType.emailAddress, validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null),
                        const SizedBox(height: 8),
                        _phoneField(),
                        const SizedBox(height: 8),
                        _field(_password, 'Password', Icons.lock_outline_rounded, obscure: _hidePassword, validator: (value) => value == null || value.length < 6 ? 'Minimum 6 characters' : null, trailing: _visibilityButton(_hidePassword, () => setState(() => _hidePassword = !_hidePassword))),
                        const SizedBox(height: 8),
                        _field(_confirmPassword, 'Confirm Password', Icons.lock_outline_rounded, obscure: _hideConfirmation, validator: (value) => value != _password.text ? 'Passwords do not match' : null, trailing: _visibilityButton(_hideConfirmation, () => setState(() => _hideConfirmation = !_hideConfirmation))),
                        const SizedBox(height: 9),
                        InkWell(
                          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_acceptedTerms ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20, color: _acceptedTerms ? kEmerald : const Color(0xFF64748B)),
                              const SizedBox(width: 7),
                              const Expanded(child: Text('I agree to the Terms & Conditions\nand Privacy Policy', style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF314761)))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signUp,
                            style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Sign Up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? ', style: TextStyle(fontSize: 12, color: Color(0xFF52647D))),
                            TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB), backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0x1A60A5FA) : const Color(0x142563EB), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))), child: const Text('Login', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .15, decoration: TextDecoration.underline, decorationThickness: 1.5))),
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
        onPressed: onTap,
        icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19, color: const Color(0xFF64748B)),
      );

  Widget _phoneField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? kDarkMuted : const Color(0xFF64748B);
    return TextFormField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: isDark ? Colors.white : kNavy, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Phone Number',
        hintStyle: TextStyle(color: muted, fontSize: 12),
        prefixIconConstraints: const BoxConstraints(minWidth: 102),
        prefixIcon: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showCountryPicker(
            context: context,
            showPhoneCode: true,
            favorite: const ['PK', 'AE', 'SA', 'GB', 'US'],
            countryListTheme: CountryListThemeData(
              backgroundColor: isDark ? kDarkCard : Colors.white,
              textStyle: TextStyle(color: isDark ? Colors.white : kNavy),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            onSelect: (country) => setState(() => _selectedCountry = country),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_selectedCountry.flagEmoji), const SizedBox(width: 4), Text('+${_selectedCountry.phoneCode}', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w700)), const Icon(Icons.keyboard_arrow_down_rounded, size: 16)]),
          ),
        ),
        filled: true,
        fillColor: isDark ? kDarkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF233846) : const Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kEmerald)),
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
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        validator: validator,
        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : kNavy, fontSize: 13),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? kDarkMuted : const Color(0xFF64748B), fontSize: 12),
          prefixIcon: prefix ?? Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? kDarkMuted : const Color(0xFF52647D), size: 20),
          suffixIcon: trailing,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark ? kDarkCard : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF233846) : const Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kEmerald)),
        ),
      );
}

class _SignUpSoftCircle extends StatelessWidget {
  final double size;
  const _SignUpSoftCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Color(0x1410B981), shape: BoxShape.circle),
      );
}
