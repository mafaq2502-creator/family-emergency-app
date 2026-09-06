import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/family_member_service.dart';
import '../../members/presentation/member_profile_screen.dart';

class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({super.key, required this.group});
  final FamilyGroup group;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(group.name)), body: StreamBuilder<List<FamilyMember>>(stream: FamilyMemberService().watchGroupMembers(group.id), builder: (context, snapshot) {
    final members = snapshot.data ?? const <FamilyMember>[];
    if (members.isEmpty) return const Center(child: Text('No members in this group yet.'));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: members.length, itemBuilder: (_, index) {
      final member = members[index];
      return Card(child: ListTile(leading: CircleAvatar(backgroundColor: kEmerald.withValues(alpha: .16), child: Text(member.name.isEmpty ? '?' : member.name[0])), title: Text(member.name), subtitle: Text(member.relation ?? member.status), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfileScreen(member: member)))));
    });
  }));
}
