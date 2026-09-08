import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../models/user_profile.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/profile_service.dart';
import '../../domain/auth_error_mapper.dart';
import '../../domain/auth_validators.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.user,
    required this.existingProfile,
    required this.isRecovery,
    required this.profileService,
    required this.authService,
    required this.onCompleted,
  });

  final User user;
  final UserProfile existingProfile;
  final bool isRecovery;
  final ProfileService profileService;
  final AuthService authService;
  final VoidCallback onCompleted;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  String? _relationship;
  Country _country = CountryService().findByCode('PK')!;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existingProfile.name);
    _email = TextEditingController(
      text: widget.user.email ?? widget.existingProfile.email,
    );
    _phone = TextEditingController(text: widget.existingProfile.phone);
    _relationship =
        AuthValidators.relationships.contains(
          widget.existingProfile.relationship,
        )
        ? widget.existingProfile.relationship
        : null;
    final country = CountryService().findByCode(
      widget.existingProfile.phoneCountryIso,
    );
    if (country != null) _country = country;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    final raw = _phone.text.trim();
    final digits = AuthValidators.digitsOnly(raw);
    if (raw.startsWith('+')) return '+$digits';
    return '+${_country.phoneCode}$digits';
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.profileService.completeProfile(
        widget.user,
        name: _name.text.trim(),
        phone: _normalizedPhone(),
        countryIso: _country.countryCode,
        countryCode: '+${_country.phoneCode}',
        relationship: _relationship!,
      );
      if (mounted) widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthErrorMapper.message(
              error,
              fallback: 'We could not save your profile. Please try again.',
            ),
          ),
          backgroundColor: kEmergency,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final muted = isDark ? kDarkMuted : kLightMuted;
    final photo = widget.existingProfile.photoUrl ?? widget.user.photoURL;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : widget.authService.signOut,
                  child: const Text('Sign out'),
                ),
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: kEmerald.withValues(alpha: .14),
                backgroundImage: photo == null || photo.isEmpty
                    ? null
                    : NetworkImage(photo),
                child: photo == null || photo.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: kEmerald,
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                widget.isRecovery
                    ? 'Recover Your Profile'
                    : 'Complete Your Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.isRecovery
                    ? 'Your sign-in is safe. Add the missing account details to continue.'
                    : 'Tell your family who you are before setting up a Circle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 28),
              AppTextFormField(
                controller: _name,
                label: 'Full Name',
                placeholder: 'Enter your full name',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.name,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              AppTextFormField(
                controller: _email,
                label: 'Email',
                placeholder: 'Email address',
                prefixIcon: Icons.mail_outline_rounded,
                enabled: false,
              ),
              const SizedBox(height: 12),
              AppTextFormField(
                controller: _phone,
                label: 'Phone Number',
                placeholder: 'Enter your phone number',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                prefix: InkWell(
                  onTap: _busy
                      ? null
                      : () => showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          favorite: const ['PK', 'AE', 'SA', 'GB', 'US'],
                          onSelect: (country) =>
                              setState(() => _country = country),
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_country.flagEmoji),
                        const SizedBox(width: 5),
                        Text('+${_country.phoneCode}'),
                        const Icon(Icons.arrow_drop_down_rounded),
                      ],
                    ),
                  ),
                ),
                validator: (value) => AuthValidators.phone(
                  value?.trim().startsWith('+') == true
                      ? value
                      : '+${_country.phoneCode}${value ?? ''}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.favorite_outline_rounded),
                ),
                hint: const Text('Select your relationship'),
                items: AuthValidators.relationships
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _relationship = value),
                validator: AuthValidators.relationship,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kEmerald,
                    foregroundColor: Colors.white,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
