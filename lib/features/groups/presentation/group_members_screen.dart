import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/family_member_service.dart';
import '../../../services/group_service.dart';
import '../../../core/widgets/light_ui.dart';
import '../../members/presentation/member_profile_screen.dart';
import 'emergency_events_screen.dart';
import 'group_settings_screen.dart';
import 'share_circle_screen.dart';

class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({super.key, required this.group});
  final FamilyGroup group;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await GroupService().renameGroup(group, name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group renamed.'),
            backgroundColor: kEmerald,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not rename group.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '“${group.name}” and its member/emergency records will be permanently removed.',
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
            child: const Text('Delete group'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GroupService().deleteGroup(group);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete group.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(group.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.warning_amber_rounded),
          tooltip: 'SOS activity',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EmergencyEventsScreen(group: group, currentUserName: 'You'),
            ),
          ),
        ),
        if (group.canManage)
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'rename' ? _rename(context) : _delete(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename group')),
              PopupMenuItem(value: 'delete', child: Text('Delete group')),
            ],
          ),
      ],
    ),
    body: StreamBuilder<List<FamilyMember>>(
      stream: FamilyMemberService().watchGroupMembers(group.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LightStateView(
            icon: Icons.cloud_off_rounded,
            title: 'Members could not be loaded',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => (context as Element).markNeedsBuild(),
          );
        }
        if (!snapshot.hasData) {
          return const LightStateView(
            icon: Icons.sync_rounded,
            title: 'Loading Circle',
            message: 'Getting the latest Circle details…',
            busy: true,
          );
        }
        final members = snapshot.data ?? const <FamilyMember>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            LightCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const LightAvatar(name: 'Family', radius: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kLightNavy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                LightStatusChip(label: group.role.value),
                                LightStatusChip(
                                  label: '${members.length} members',
                                  color: const Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShareCircleScreen(group: group),
                            ),
                          ),
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Invite'),
                        ),
                      ),
                      if (group.canManage) ...[
                        const SizedBox(width: 9),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupSettingsScreen(
                                  group: group,
                                  members: members,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.settings_rounded),
                            label: const Text('Settings'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LightSectionTitle('Members / Children'),
            if (members.isEmpty)
              const LightStateView(
                icon: Icons.group_add_rounded,
                title: 'No members yet',
                message: 'Invite a registered family member to this Circle.',
              ),
            for (var index = 0; index < members.length; index++) ...[
              Builder(
                builder: (_) {
                  final member = members[index];
                  return LightCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: LightAvatar(
                        name: member.name,
                        online: member.status.toLowerCase() == 'online',
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.relation ?? member.status),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          LightStatusChip(
                            label: member.status,
                            color: member.status.toLowerCase() == 'pending'
                                ? const Color(0xFFF59E0B)
                                : kEmerald,
                          ),
                          const SizedBox(height: 3),
                          const Icon(Icons.chevron_right_rounded, size: 17),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberProfileScreen(
                            member: member,
                            onSave: group.canManage
                                ? (updated) => FamilyMemberService()
                                      .updateInGroup(group.id, updated)
                                : null,
                            onDelete: group.canManage && member.id != null
                                ? () => FamilyMemberService().deleteInGroup(
                                    group.id,
                                    member.id!,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 9),
            ],
          ],
        );
      },
    ),
  );
}
