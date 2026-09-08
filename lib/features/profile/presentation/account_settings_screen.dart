import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({
    super.key,
    required this.nameController,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.relationships,
    required this.onRelationshipChanged,
    required this.onSave,
    required this.saving,
  });

  final TextEditingController nameController;
  final String email;
  final String phone;
  final String? relationship;
  final List<String> relationships;
  final ValueChanged<String?> onRelationshipChanged;
  final Future<void> Function() onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Account Settings',
    subtitle: 'Keep your personal details up to date',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LightSectionTitle('Personal information'),
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 11),
        TextFormField(
          initialValue: email,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
            suffixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 11),
        TextFormField(
          initialValue: phone,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            prefixIcon: Icon(Icons.phone_outlined),
            suffixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 11),
        const TextField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Country',
            hintText: 'From registered phone number',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        const SizedBox(height: 11),
        DropdownButtonFormField<String>(
          initialValue: relationship,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Relationship',
            prefixIcon: Icon(Icons.favorite_outline_rounded),
          ),
          items: relationships
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onRelationshipChanged,
        ),
        const SizedBox(height: 12),
        LightSettingRow(
          icon: Icons.lock_reset_rounded,
          title: 'Update Password',
          subtitle: 'Change your account password securely',
          onTap: () => Navigator.pop(context, 'security'),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(saving ? 'Saving…' : 'Save Changes'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Email and phone are locked to protect your account identity.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kLightMuted, fontSize: 10),
        ),
      ],
    ),
  );
}
