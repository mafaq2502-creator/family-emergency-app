part of '../family_shell.dart';

extension _MembersTab on _HomeScreenState {
  Widget _buildFamilyTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        children: [
          Text(
            'Family Circles',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create circles and manage your family members.',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const SizedBox(height: 12),
          _groupSelector(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.group_add_outlined, size: 19),
                    label: const Text('Add Group'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? kEmerald : kLightPrimary,
                      side: BorderSide(
                        color: isDark ? kEmerald : kLightPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _selectedGroup?.canManage == true
                        ? _showAddMemberDialog
                        : null,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                    label: const Text('Add Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? kEmerald : kLightPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedGroup?.canManage == true)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openGroupSettings,
                icon: const Icon(Icons.settings_outlined, size: 17),
                label: const Text('Group Settings'),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            _selectedGroup == null
                ? 'Create a group first, then add members to it.'
                : '${_selectedGroup!.name} Members',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 9),
          ...List.generate(
            familyMembers.length,
            (index) => _memberListCard(familyMembers[index], index, isDark),
          ),
        ],
      ),
    );
  }

  Widget _memberListCard(FamilyMember member, int index, bool isDark) {
    final name = member.name;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final phone =
        member.phone ??
        const [
          '+92 300 1234567',
          '+92 300 2345678',
          '+92 300 3456789',
          '+92 300 4567890',
        ][index % 4];
    final relation = member.relation ?? name;
    final avatarColors = const [
      Color(0xFFE9EEF0),
      Color(0xFFF3E8E7),
      Color(0xFFF0E8DF),
      Color(0xFFF5E8E8),
    ];
    final avatarIcons = const [
      Icons.face_rounded,
      Icons.face_3_rounded,
      Icons.face_rounded,
      Icons.face_3_rounded,
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _openMemberProfile(member, index),
      child: Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kLightSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: avatarColors[index % 4],
                  child: Icon(
                    avatarIcons[index % 4],
                    color: const Color(0xFF536878),
                    size: 30,
                  ),
                ),
                const Positioned(
                  right: -1,
                  top: -1,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(radius: 4.5, backgroundColor: kEmerald),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relation,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 28, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert_rounded, color: mutedColor, size: 20),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name options will be available soon')),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 29, height: 34),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: kEmergency,
                size: 20,
              ),
              onPressed: () => _removeFamilyMember(index),
            ),
          ],
        ),
      ),
    );
  }
}
