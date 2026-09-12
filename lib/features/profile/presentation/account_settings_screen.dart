import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';

import '../../../core/domain/mobile_phone_number.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../core/widgets/country_name_field.dart';
import '../../../core/widgets/bounded_dropdown_form_field.dart';
import '../../../core/widgets/profile_image.dart';
import '../../../core/widgets/mobile_phone_field.dart';
import '../../auth/domain/auth_validators.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.initialName,
    required this.email,
    this.initialPhone = '',
    this.initialPhoneCountryIso,
    this.initialPhotoUrl,
    this.initialAddress = const {},
    required this.onSaveAddress,
    required this.relationship,
    required this.relationships,
    required this.onSave,
    this.onSavePhone,
    this.onSavePhoto,
    this.pickProfilePhoto,
    required this.onUpdatePassword,
  });

  final String initialName;
  final String email;
  final String initialPhone;
  final String? initialPhoneCountryIso;
  final String? initialPhotoUrl;
  final Map<String, String> initialAddress;
  final Future<bool> Function(Map<String, String> address) onSaveAddress;
  final String? relationship;
  final List<String> relationships;
  final Future<bool> Function(String name, String? relationship) onSave;
  final Future<bool> Function(
    String phone,
    String countryIso,
    String countryCode,
  )?
  onSavePhone;
  final Future<bool> Function(String photoUrl)? onSavePhoto;
  final Future<String?> Function()? pickProfilePhoto;
  final VoidCallback onUpdatePassword;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late Country _phoneCountry;
  late String _savedPhone;
  late String _savedPhoneCountryIso;
  late String? _relationship;
  late String _savedName;
  late String? _savedRelationship;
  late String? _savedPhotoUrl;
  String? _draftPhotoUrl;
  bool _saving = false;
  String? _saveError;
  static const _addressLabels = {
    'line1': 'Street Address',
    'line2': 'Apartment / Address Line 2',
    'city': 'City',
    'region': 'State / Province',
    'postalCode': 'Postal Code',
  };
  late final Map<String, TextEditingController> _address;
  late Map<String, String> _savedAddress;
  String? _countryIso;
  int _tab = 0;

  Map<String, String> get _currentAddress => {
    for (final entry in _address.entries) entry.key: entry.value.text.trim(),
    'countryIso': _countryIso ?? '',
  };

  bool get _phoneDirty {
    if (_phone.text.trim().isEmpty && _savedPhone.isEmpty) return false;
    return MobilePhoneNumber.normalize(_phone.text, _phoneCountry.phoneCode) !=
            _savedPhone ||
        _phoneCountry.countryCode != _savedPhoneCountryIso;
  }

  bool get _dirty =>
      _name.text.trim() != _savedName ||
      _relationship != _savedRelationship ||
      _phoneDirty ||
      !mapEquals(_currentAddress, _savedAddress) ||
      _draftPhotoUrl != _savedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName)
      ..addListener(_refresh);
    _phoneCountry =
        CountryService().findByCode(
          widget.initialPhoneCountryIso ?? widget.initialAddress['countryIso'],
        ) ??
        CountryService().findByCode('PK')!;
    _phone = TextEditingController(
      text: MobilePhoneNumber.localFromStored(
        widget.initialPhone,
        _phoneCountry.phoneCode,
      ),
    )..addListener(_refresh);
    _savedPhone = widget.initialPhone;
    _savedPhoneCountryIso = _phoneCountry.countryCode;
    _relationship = widget.relationship;
    _savedName = widget.initialName.trim();
    _savedRelationship = widget.relationship;
    _savedPhotoUrl = widget.initialPhotoUrl;
    _draftPhotoUrl = _savedPhotoUrl;
    _address = {
      for (final key in _addressLabels.keys)
        key: TextEditingController(text: widget.initialAddress[key] ?? '')
          ..addListener(_refresh),
    };
    _countryIso = widget.initialAddress['countryIso'];
    _savedAddress = _currentAddress;
  }

  void _refresh() {
    if (mounted) setState(() => _saveError = null);
  }

  Future<void> _pickPhoto() async {
    try {
      String? selected;
      if (widget.pickProfilePhoto != null) {
        selected = await widget.pickProfilePhoto!();
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 65,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.length > ProfileImageData.maxBytes) {
          if (mounted) {
            setState(
              () => _saveError = 'Please choose a smaller profile image.',
            );
          }
          return;
        }
        selected = ProfileImageData.encodeJpeg(bytes);
      }
      if (selected == null || !mounted) return;
      setState(() {
        _draftPhotoUrl = selected;
        _saveError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Profile image could not be selected.');
      }
    }
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _name.dispose();
    _phone.removeListener(_refresh);
    _phone.dispose();
    for (final controller in _address.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AppAlertDialog(
            icon: const Icon(Icons.edit_note_rounded, color: kEmerald),
            title: const Text('Save changes?'),
            content: const Text('Your account details have unsaved changes.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard'),
              ),
              ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final saved = await _save(closeOnSuccess: false);
                        if (saved && dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _save({bool closeOnSuccess = true}) async {
    if (!_dirty || _saving || !_formKey.currentState!.validate()) return false;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    bool saved = false;
    try {
      final personalDirty =
          _name.text.trim() != _savedName ||
          _relationship != _savedRelationship;
      final currentPhone = MobilePhoneNumber.normalize(
        _phone.text,
        _phoneCountry.phoneCode,
      );
      final phoneDirty = _phoneDirty;
      final addressDirty = !mapEquals(_currentAddress, _savedAddress);
      final photoDirty = _draftPhotoUrl != _savedPhotoUrl;
      saved =
          !personalDirty ||
          await widget.onSave(_name.text.trim(), _relationship);
      if (saved && phoneDirty) {
        saved =
            widget.onSavePhone != null &&
            await widget.onSavePhone!(
              currentPhone,
              _phoneCountry.countryCode,
              MobilePhoneNumber.callingCode(_phoneCountry.phoneCode),
            );
      }
      if (saved && addressDirty) {
        saved = await widget.onSaveAddress(_currentAddress);
      }
      if (saved && photoDirty) {
        saved =
            widget.onSavePhoto != null &&
            await widget.onSavePhoto!(_draftPhotoUrl!);
      }
    } catch (_) {
      saved = false;
    }
    if (!mounted) return saved;
    setState(() {
      _saving = false;
      if (saved) {
        _savedName = _name.text.trim();
        _savedRelationship = _relationship;
        _savedPhone = MobilePhoneNumber.normalize(
          _phone.text,
          _phoneCountry.phoneCode,
        );
        _savedPhoneCountryIso = _phoneCountry.countryCode;
        _savedAddress = Map.of(_currentAddress);
        _savedPhotoUrl = _draftPhotoUrl;
      } else {
        _saveError = 'Changes could not be saved. Please try again.';
      }
    });
    if (saved && closeOnSuccess) Navigator.pop(context, true);
    return saved;
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || _saving) return;
      if (await _confirmExit() && context.mounted) Navigator.pop(context);
    },
    child: LightPage(
      title: 'Account Settings',
      subtitle: 'Keep your personal details up to date',
      child: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      key: const Key('account-profile-avatar'),
                      radius: 48,
                      backgroundColor: context.appSuccessSurface,
                      foregroundImage: ProfileImageData.provider(
                        _draftPhotoUrl,
                      ),
                      child: Text(
                        _name.text.trim().isEmpty
                            ? '?'
                            : _name.text.trim()[0].toUpperCase(),
                        style: TextStyle(
                          color: context.appPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      bottom: -5,
                      child: IconButton.filled(
                        key: const Key('edit-account-profile-photo'),
                        tooltip: 'Change profile image',
                        onPressed: _saving ? null : _pickPhoto,
                        icon: const Icon(Icons.camera_alt_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.appSurfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _accountTab('Personal', 0),
                    _accountTab('Address', 1),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Offstage(
                offstage: _tab != 0,
                child: Column(
                  children: [
                    const LightSectionTitle('Personal information'),
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      maxLength: 80,
                      validator: AuthValidators.name,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _lockedField(
                      'Email',
                      widget.email,
                      Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 18),
                    MobilePhoneField(
                      controller: _phone,
                      country: _phoneCountry,
                      enabled: !_saving,
                      required: widget.initialPhone.isNotEmpty,
                      textInputAction: TextInputAction.next,
                      onCountryChanged: (country) => setState(() {
                        _phoneCountry = country;
                        _saveError = null;
                      }),
                    ),
                    const SizedBox(height: 18),
                    BoundedDropdownFormField<String>(
                      autovalidateMode: AutovalidateMode.onUnfocus,
                      initialValue: _relationship,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        hintText: 'Select your relationship',
                        prefixIcon: Icon(Icons.favorite_outline_rounded),
                      ),
                      items: widget.relationships
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _relationship = value;
                        _saveError = null;
                      }),
                      validator: AuthValidators.relationship,
                    ),
                    const SizedBox(height: 18),
                    LightSettingRow(
                      icon: Icons.security_rounded,
                      title: 'Security Settings',
                      subtitle: 'Password, email verification and session',
                      onTap: widget.onUpdatePassword,
                    ),
                  ],
                ),
              ),
              Offstage(
                offstage: _tab != 1,
                child: Column(
                  children: [
                    const LightSectionTitle('Address'),
                    const Text('Add your address details (optional).'),
                    const SizedBox(height: 18),
                    for (final entry in _addressLabels.entries) ...[
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUnfocus,
                        controller: _address[entry.key],
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.streetAddress,
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: entry.value,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    CountryNameField(
                      countryIso: _countryIso,
                      onChanged: (country) => setState(() {
                        _countryIso = country.countryCode;
                        _saveError = null;
                      }),
                    ),
                  ],
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 18),
                Text(_saveError!, style: const TextStyle(color: kEmergency)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _dirty && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save Settings'),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Your email is linked to your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.appMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _lockedField(String label, String value, IconData icon) =>
      TextFormField(
        autovalidateMode: AutovalidateMode.onUnfocus,
        initialValue: value.isEmpty ? 'Not available' : value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
      );

  Widget _accountTab(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: selected ? context.appPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextButton(
          onPressed: () => setState(() => _tab = index),
          style: TextButton.styleFrom(
            foregroundColor: selected ? Colors.white : context.appText,
            textStyle: TextStyle(
              fontSize: AppTypography.tabLabel,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
