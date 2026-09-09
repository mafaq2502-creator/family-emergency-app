import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.initialName,
    required this.email,
    required this.phone,
    required this.country,
    required this.relationship,
    required this.relationships,
    required this.onSave,
    required this.onUpdatePassword,
  });

  final String initialName;
  final String email;
  final String phone;
  final String country;
  final String? relationship;
  final List<String> relationships;
  final Future<bool> Function(String name, String? relationship) onSave;
  final VoidCallback onUpdatePassword;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String? _relationship;
  late String _savedName;
  late String? _savedRelationship;
  bool _saving = false;
  String? _saveError;

  bool get _dirty =>
      _name.text.trim() != _savedName || _relationship != _savedRelationship;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName)
      ..addListener(_refresh);
    _relationship = widget.relationship;
    _savedName = widget.initialName.trim();
    _savedRelationship = widget.relationship;
  }

  void _refresh() {
    if (mounted) setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _name.dispose();
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
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
    final saved = await widget.onSave(_name.text.trim(), _relationship);
    if (!mounted) return saved;
    setState(() {
      _saving = false;
      if (saved) {
        _savedName = _name.text.trim();
        _savedRelationship = _relationship;
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
      if (didPop) return;
      if (await _confirmExit() && mounted) Navigator.pop(context);
    },
    child: LightPage(
      title: 'Account Settings',
      subtitle: 'Keep your personal details up to date',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LightSectionTitle('Personal information'),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter your full name'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 11),
            _lockedField('Email', widget.email, Icons.mail_outline_rounded),
            const SizedBox(height: 11),
            _lockedField('Phone Number', widget.phone, Icons.phone_outlined),
            const SizedBox(height: 11),
            _lockedField('Country', widget.country, Icons.flag_outlined),
            const SizedBox(height: 11),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'Select your relationship',
                prefixIcon: Icon(Icons.favorite_outline_rounded),
              ),
              items: widget.relationships
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _relationship = value;
                _saveError = null;
              }),
              validator: (value) =>
                  value == null ? 'Select a relationship' : null,
            ),
            const SizedBox(height: 12),
            LightSettingRow(
              icon: Icons.lock_reset_rounded,
              title: 'Update Password',
              subtitle: 'Open password security settings',
              onTap: widget.onUpdatePassword,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
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
                label: Text(_saving ? 'Saving…' : 'Save Changes'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Email, phone and country come from your verified account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kLightMuted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _lockedField(String label, String value, IconData icon) =>
      TextFormField(
        initialValue: value.isEmpty ? 'Not available' : value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.lock_outline_rounded),
        ),
      );
}
