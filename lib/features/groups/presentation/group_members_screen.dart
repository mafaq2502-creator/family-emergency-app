import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/family_member_service.dart';
import '../../../services/group_service.dart';
import '../../members/presentation/member_profile_screen.dart';
import 'emergency_events_screen.dart';

class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({super.key, required this.group});
  final FamilyGroup group;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Rename group'), content: TextField(controller: controller, autofocus: true, maxLength: 60, decoration: const InputDecoration(labelText: 'Group name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))]));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await GroupService().renameGroup(group, name);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group renamed.'), backgroundColor: kEmerald));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not rename group.'), backgroundColor: kEmergency));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete group?'), content: Text('“${group.name}” and its member/emergency records will be permanently removed.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white), child: const Text('Delete group'))]));
    if (confirmed != true) return;
    try {
      await GroupService().deleteGroup(group);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete group.'), backgroundColor: kEmergency));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(group.name), actions: [
          IconButton(icon: const Icon(Icons.warning_amber_rounded), tooltip: 'SOS activity', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmergencyEventsScreen(group: group, currentUserName: 'You')))),
          if (group.canManage) PopupMenuButton<String>(onSelected: (value) => value == 'rename' ? _rename(context) : _delete(context), itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename group')), PopupMenuItem(value: 'delete', child: Text('Delete group'))]),
        ]),
        body: StreamBuilder<List<FamilyMember>>(
          stream: FamilyMemberService().watchGroupMembers(group.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Members could not be loaded.'));
            final members = snapshot.data ?? const <FamilyMember>[];
            if (members.isEmpty) return const Center(child: Text('No members in this group yet.'));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: members.length, itemBuilder: (_, index) {
              final member = members[index];
              return Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: kEmerald.withValues(alpha: .16), child: Text(member.name.isEmpty ? '?' : member.name[0])),
                title: Text(member.name),
                subtitle: Text(member.relation ?? member.status),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfileScreen(member: member, onSave: group.canManage ? (updated) => FamilyMemberService().updateInGroup(group.id, updated) : null, onDelete: group.canManage && member.id != null ? () => FamilyMemberService().deleteInGroup(group.id, member.id!) : null))),
              ));
            });
          },
        ),
      );
}
