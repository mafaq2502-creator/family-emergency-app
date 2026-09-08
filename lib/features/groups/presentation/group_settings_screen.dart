// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/circle_join_service.dart';
import '../../../services/group_service.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.group,
    required this.members,
  });
  final FamilyGroup group;
  final List<FamilyMember> members;
  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _service = GroupService();
  final _inviteService = CircleJoinService();
  late Set<String> _recipients;
  bool _saving = false;
  bool _creatingInvite = false;
  CircleInviteResult? _invite;
  @override
  void initState() {
    super.initState();
    _recipients = widget.group.emergencyRecipientIds.toSet();
  }

  Future<void> _createInvite() async {
    if (_creatingInvite) return;
    setState(() => _creatingInvite = true);
    try {
      final invite = await _inviteService.createInvite(widget.group.id);
      if (!mounted) return;
      setState(() => _invite = invite);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation could not be created. Please try again.'),
          backgroundColor: kEmergency,
        ),
      );
    } finally {
      if (mounted) setState(() => _creatingInvite = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Group Settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(widget.group.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        const Text(
          'Invite Family Members',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Generate a secure code that expires after seven days. Only registered AliveCircle users can redeem it.',
        ),
        const SizedBox(height: 12),
        if (_invite case final invite?)
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_rounded, color: kEmerald),
              title: SelectableText(
                invite.code,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              subtitle: Text(
                'Expires ${invite.expiresAt.toLocal().toString().split('.').first}',
              ),
              trailing: IconButton(
                tooltip: 'Copy invitation code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation code copied.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _creatingInvite ? null : _createInvite,
            icon: _creatingInvite
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              _invite == null
                  ? 'Generate Invitation Code'
                  : 'Generate New Code',
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Emergency Notifications',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose active app members who receive SOS alerts from this group.',
        ),
        const SizedBox(height: 12),
        ...widget.members
            .where(
              (m) => m.userId != null && m.status.toLowerCase() != 'pending',
            )
            .map((m) {
              final id = m.userId!;
              return CheckboxListTile(
                value: _recipients.contains(id),
                onChanged: (value) => setState(
                  () => value == true
                      ? _recipients.add(id)
                      : _recipients.remove(id),
                ),
                title: Text(m.name),
                subtitle: Text(m.email ?? 'Registered member'),
              );
            }),
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _saving || _recipients.isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await _service.setEmergencyRecipients(
                        widget.group,
                        _recipients.toList(),
                      );
                      if (mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmergency,
              foregroundColor: Colors.white,
            ),
            child: Text(_saving ? 'Saving...' : 'Save Emergency Recipients'),
          ),
        ),
      ],
    ),
  );
}
