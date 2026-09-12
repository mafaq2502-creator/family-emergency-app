import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/circle_policies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../../../models/circle_membership.dart';
import '../../../models/family_group.dart';
import '../../../services/group_service.dart';
import 'share_circle_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.group,
    this.memberships = const [],
    this.groupService,
    this.viewerId,
  });

  final FamilyGroup group;
  final List<CircleMembership> memberships;
  final GroupService? groupService;
  final String? viewerId;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late final GroupService _service = widget.groupService ?? GroupService();
  late final Set<String> _recipients = widget.group.emergencyRecipientIds
      .toSet();
  bool _busy = false;

  String? get _viewerId =>
      widget.viewerId ?? FirebaseAuth.instance.currentUser?.uid;

  Future<void> _rename(FamilyGroup group) async {
    if (_busy) return;
    final controller = TextEditingController(text: group.name);
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.edit_rounded, color: kEmerald),
          title: const Text('Rename Circle'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: CircleNamePolicy.maxLength,
            decoration: InputDecoration(
              labelText: 'Circle name',
              errorText: error,
            ),
            onSubmitted: (_) {
              final validation = CircleNamePolicy.validate(controller.text);
              if (validation != null) {
                setDialogState(() => error = validation);
              } else {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final validation = CircleNamePolicy.validate(controller.text);
                if (validation != null) {
                  setDialogState(() => error = validation);
                  return;
                }
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name == group.name.trim() || !mounted) return;
    await _run(
      () => _service.renameGroup(group, name),
      fallback: 'The Circle could not be renamed. Please try again.',
      success: 'Circle renamed.',
    );
  }

  Future<void> _leave(FamilyGroup group) async {
    if (_busy || group.isOwner) return;
    final confirmed = await _confirm(
      title: 'Leave Circle?',
      message:
          'You will lose access to ${group.name} and its member information.',
      action: 'Leave Circle',
    );
    if (!confirmed || !mounted) return;
    final succeeded = await _run(
      () => _service.leaveGroup(group),
      fallback: 'You could not leave this Circle. Please try again.',
    );
    if (succeeded && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _delete(FamilyGroup group) async {
    if (_busy || !group.isOwner) return;
    final confirmed = await _confirm(
      title: 'Delete Circle?',
      message:
          '${group.name} will be closed for every member. Its records will be retained as a protected lifecycle tombstone.',
      action: 'Delete Circle',
    );
    if (!confirmed || !mounted) return;
    final succeeded = await _run(
      () => _service.deleteGroup(group),
      fallback: 'The Circle could not be deleted. Please try again.',
    );
    if (succeeded && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _saveRecipients(FamilyGroup group) async {
    if (_recipients.isEmpty) return;
    await _run(
      () => _service.setEmergencyRecipients(group, _recipients.toList()),
      fallback: 'Emergency recipients could not be saved. Please try again.',
      success: 'Emergency recipients updated.',
    );
  }

  Future<bool> _run(
    Future<void> Function() action, {
    required String fallback,
    String? success,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), backgroundColor: kEmerald),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CircleErrorMapper.message(error, fallback: fallback)),
            backgroundColor: kEmergency,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: kEmergency),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: kEmergency),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final viewerId = _viewerId;
    if (viewerId == null) {
      return _unavailable('Please sign in again to manage this Circle.');
    }
    return StreamBuilder<FamilyGroup?>(
      stream: _service.watchGroupForUser(widget.group.id, viewerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _unavailable(CircleErrorMapper.message(snapshot.error!));
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LightStateView(
              icon: Icons.sync_rounded,
              title: 'Loading settings',
              message: 'Checking your current Circle permissions…',
              busy: true,
            ),
          );
        }
        final group = snapshot.data;
        if (group == null) {
          return _unavailable(
            'This Circle is no longer active or your access was removed.',
          );
        }
        return _settings(group, viewerId);
      },
    );
  }

  Widget _settings(FamilyGroup group, String viewerId) => LightPage(
    title: 'Circle Settings',
    subtitle: group.name,
    actions: const [NotificationBellButton()],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_busy) const SizedBox(height: 12),
        if (CirclePermissionPolicy.canRename(group.role)) ...[
          LightSettingRow(
            icon: Icons.edit_rounded,
            title: 'Rename Circle',
            subtitle: group.name,
            onTap: _busy ? null : () => _rename(group),
          ),
          const SizedBox(height: 9),
        ],
        LightSettingRow(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Your Circle role',
          subtitle: group.role.value,
        ),
        if (group.canManage) ...[
          const SizedBox(height: 9),
          LightSettingRow(
            icon: Icons.ios_share_rounded,
            title: 'Invite registered member',
            subtitle: 'Generate a secure Phase 6 invitation code',
            onTap: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareCircleScreen(group: group),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          const LightSectionTitle('Emergency recipients'),
          StreamBuilder<List<CircleMembership>>(
            stream: _service.watchMemberships(group.id),
            initialData: widget.memberships.isEmpty ? null : widget.memberships,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(CircleErrorMapper.message(snapshot.error!));
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              final members = snapshot.data!;
              if (members.isEmpty) {
                return const Text(
                  'No active registered members are available.',
                );
              }
              return Column(
                children: [
                  for (final member in members)
                    CheckboxListTile(
                      value: _recipients.contains(member.userId),
                      onChanged: _busy
                          ? null
                          : (value) => setState(
                              () => value == true
                                  ? _recipients.add(member.userId)
                                  : _recipients.remove(member.userId),
                            ),
                      title: Text(member.displayName),
                      subtitle: Text(
                        '${member.relationship} • ${member.role.value}',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy || _recipients.isEmpty
                  ? null
                  : () => _saveRecipients(group),
              child: const Text('Save Emergency Recipients'),
            ),
          ),
        ],
        const SizedBox(height: 26),
        const LightSectionTitle('Circle lifecycle'),
        if (group.isOwner)
          const LightSettingRow(
            icon: Icons.logout_rounded,
            title: 'Leave Circle',
            subtitle: 'The owner must transfer ownership or delete the Circle',
          )
        else
          LightSettingRow(
            icon: Icons.logout_rounded,
            title: 'Leave Circle',
            subtitle: 'Remove your active membership from this Circle',
            destructive: true,
            onTap: _busy ? null : () => _leave(group),
          ),
        if (group.isOwner) ...[
          const SizedBox(height: 9),
          const LightSettingRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Transfer Ownership',
            subtitle: 'Reserved for a later lifecycle extension',
          ),
          const SizedBox(height: 9),
          LightSettingRow(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Circle',
            subtitle: 'Close this Circle for every member',
            destructive: true,
            onTap: _busy ? null : () => _delete(group),
          ),
        ],
      ],
    ),
  );

  Widget _unavailable(String message) => Scaffold(
    appBar: AppBar(
      title: const Text('Circle Settings'),
      actions: const [NotificationBellButton()],
    ),
    body: LightStateView(
      icon: Icons.lock_outline_rounded,
      title: 'Settings unavailable',
      message: message,
      actionLabel: 'Go back',
      onAction: () => Navigator.maybePop(context),
    ),
  );
}
