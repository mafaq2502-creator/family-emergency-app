part of '../family_shell.dart';

extension _MembersTab on _HomeScreenState {
  Widget _buildFamilyTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Family Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
      const SizedBox(height: 4),
      Text('Add and manage your family members.', style: TextStyle(fontSize: 12, color: mutedColor)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 38, child: ElevatedButton.icon(onPressed: _showAddMemberDialog, icon: const Icon(Icons.add_rounded, size: 24), label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
      const SizedBox(height: 13),
      Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: familyMembers.length, itemBuilder: (context, index) => _memberListCard(familyMembers[index], index, isDark))),
    ])));
  }

  Widget _memberListCard(FamilyMember member, int index, bool isDark) {
    final name = member.name;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF60728C);
    final phone = member.phone ?? const ['+92 300 1234567', '+92 300 2345678', '+92 300 3456789', '+92 300 4567890'][index % 4];
    final relation = member.relation ?? name;
    final avatarColors = const [Color(0xFFE9EEF0), Color(0xFFF3E8E7), Color(0xFFF0E8DF), Color(0xFFF5E8E8)];
    final avatarIcons = const [Icons.face_rounded, Icons.face_3_rounded, Icons.face_rounded, Icons.face_3_rounded];
    return InkWell(borderRadius: BorderRadius.circular(13), onTap: () => _openMemberProfile(member, index), child: Container(height: 70, margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.fromLTRB(12, 9, 8, 9), decoration: BoxDecoration(color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE9EDF0)), boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))]), child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [CircleAvatar(radius: 23, backgroundColor: avatarColors[index % 4], child: Icon(avatarIcons[index % 4], color: const Color(0xFF536878), size: 30)), const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 6, backgroundColor: Colors.white, child: CircleAvatar(radius: 4.5, backgroundColor: kEmerald)))]),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(name, style: TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 4), Text(phone, style: TextStyle(fontSize: 11, height: 1, color: mutedColor)), const SizedBox(height: 4), Text(relation, style: TextStyle(fontSize: 11, height: 1, color: mutedColor))])),
      IconButton(constraints: const BoxConstraints.tightFor(width: 28, height: 34), padding: EdgeInsets.zero, icon: Icon(Icons.more_vert_rounded, color: mutedColor, size: 20), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name options will be available soon')))),
      IconButton(constraints: const BoxConstraints.tightFor(width: 29, height: 34), padding: EdgeInsets.zero, icon: const Icon(Icons.delete_outline_rounded, color: kEmergency, size: 20), onPressed: () => _removeFamilyMember(index)),
    ])));
  }
}
