// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/circle_join_service.dart';
import '../../../services/group_service.dart';
import '../../../core/widgets/light_ui.dart';
import 'share_circle_screen.dart';

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

  Future<void> _renameCircle() async {
    final controller = TextEditingController(text: widget.group.name);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.edit_rounded, color: kEmerald),
        title: const Text('Rename Circle'),
        content: TextField(
          controller: controller,
          maxLength: 60,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Circle name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == widget.group.name) return;
    await _service.renameGroup(widget.group, value);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Circle renamed.')));
    }
  }

  Future<void> _deleteCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: kEmergency),
        title: const Text('Delete Circle?'),
        content: Text(
          '“${widget.group.name}” and its member and emergency records will be permanently removed.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmergency,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Circle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteGroup(widget.group);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Group Settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LightSettingRow(
          icon: Icons.edit_rounded,
          title: 'Rename Circle',
          subtitle: widget.group.name,
          onTap: _renameCircle,
        ),
        const SizedBox(height: 9),
        LightSettingRow(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Owner Information',
          subtitle: widget.group.ownerId,
        ),
        const SizedBox(height: 9),
        LightSettingRow(
          icon: Icons.manage_accounts_rounded,
          title: 'Member Roles',
          subtitle: 'Owner, parent, adult and child permissions',
        ),
        const SizedBox(height: 20),
        LightSettingRow(
          icon: Icons.ios_share_rounded,
          title: 'Share Circle',
          subtitle: 'QR code, invitation code and joining link',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareCircleScreen(group: widget.group),
            ),
          ),
        ),
        const SizedBox(height: 22),
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
        const SizedBox(height: 28),
        const LightSectionTitle('Circle management'),
        LightSettingRow(
          icon: Icons.logout_rounded,
          title: 'Leave Circle',
          subtitle: widget.group.isOwner
              ? 'Transfer ownership before leaving'
              : 'Leave this Circle',
          destructive: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave Circle is not connected yet.')),
          ),
        ),
        const SizedBox(height: 9),
        LightSettingRow(
          icon: Icons.swap_horiz_rounded,
          title: 'Transfer Ownership',
          subtitle: 'Choose another active adult or parent',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ownership transfer is not connected yet.'),
            ),
          ),
        ),
        const SizedBox(height: 9),
        LightSettingRow(
          icon: Icons.delete_forever_rounded,
          title: 'Delete Circle',
          subtitle: 'Only the owner can permanently delete this Circle',
          destructive: true,
          onTap: widget.group.isOwner ? _deleteCircle : null,
        ),
      ],
    ),
  );
}
