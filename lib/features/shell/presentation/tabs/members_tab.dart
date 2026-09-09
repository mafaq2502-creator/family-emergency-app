part of '../family_shell.dart';

extension _MembersTab on _HomeScreenState {
  Widget _buildFamilyTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final visibleGroups = _groups
        .where((group) => _showOwnedCircles ? group.isOwner : !group.isOwner)
        .toList();
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurface : kLightSurfaceMuted,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                _circleScopeButton('Owned', true, isDark),
                _circleScopeButton('Joined', false, isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (visibleGroups.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? kDarkCard : kLightSurface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDark ? Colors.white12 : kLightBorder,
                ),
              ),
              child: Text(
                _showOwnedCircles
                    ? 'You do not own a Circle yet.'
                    : 'You have not joined another Circle yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: mutedColor, fontSize: 11),
              ),
            )
          else
            ...visibleGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => _openGroupHome(group),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCard : kLightSurface,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isDark ? Colors.white12 : kLightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: kEmerald.withValues(alpha: .13),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: kEmerald,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                group == _selectedGroup
                                    ? '${group.isOwner ? 'Owner' : group.role.value} • ${familyMembers.length} members'
                                    : '${group.isOwner ? 'Owner' : group.role.value} • Open to view members',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _groupSelector(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 145,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.group_add_outlined, size: 19),
                  label: const Text('Add Group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? kEmerald : kLightPrimary,
                    side: BorderSide(color: isDark ? kEmerald : kLightPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 145,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _selectedGroup?.canManage == true
                      ? _showAddMemberDialog
                      : null,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                  label: const Text('Manual Member'),
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
              SizedBox(
                width: 145,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: _selectedGroup == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShareCircleScreen(group: _selectedGroup!),
                          ),
                        ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Invite User'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manual members are local Circle records. Invite User is for registered app accounts.',
            style: TextStyle(fontSize: 10, color: mutedColor),
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
          if (_selectedGroup != null && familyMembers.isEmpty)
            const LightStateView(
              icon: Icons.group_add_rounded,
              title: 'No members yet',
              message: 'Add a manual record or invite a registered app user.',
            ),
          ...List.generate(
            familyMembers.length,
            (index) => _memberListCard(familyMembers[index], index, isDark),
          ),
        ],
      ),
    );
  }

  Widget _circleScopeButton(String label, bool owned, bool isDark) {
    final selected = _showOwnedCircles == owned;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setCircleScope(owned),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: selected && !isDark ? kPrimaryGradient : null,
            color: selected && isDark ? kEmerald : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white60 : kLightMuted),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberListCard(FamilyMember member, int index, bool isDark) {
    final name = member.name;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final phone = member.phone?.trim().isNotEmpty == true
        ? member.phone!
        : 'Phone not available';
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
                if (member.status.toLowerCase() == 'online')
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 4.5,
                        backgroundColor: kEmerald,
                      ),
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
              onPressed: () => _openMemberProfile(member, index),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 29, height: 34),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: kEmergency,
                size: 20,
              ),
              onPressed: _selectedGroup?.canManage == true
                  ? () => _confirmRemoveFamilyMember(index)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
