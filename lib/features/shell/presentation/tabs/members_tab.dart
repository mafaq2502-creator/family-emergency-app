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
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
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
            'Open a Circle to view its active registered members.',
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
          const SizedBox(height: 12),
          if (visibleGroups.isEmpty)
            LightStateView(
              icon: Icons.diversity_1_rounded,
              title: _showOwnedCircles
                  ? 'No owned Circles'
                  : 'No joined Circles',
              message: _showOwnedCircles
                  ? 'Create a family Circle to become its owner.'
                  : 'Circles joined with your registered account appear here.',
              actionLabel: _showOwnedCircles ? 'Create Circle' : null,
              onAction: _showOwnedCircles ? _createGroup : null,
            )
          else
            for (final group in visibleGroups) ...[
              LightCard(
                onTap: () => _openGroupHome(group),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kEmerald.withValues(alpha: .13),
                      child: const Icon(Icons.groups_rounded, color: kEmerald),
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
                          const SizedBox(height: 3),
                          Text(
                            '${group.isOwner ? 'owner' : group.role.value} • ${group.memberCount} active ${group.memberCount == 1 ? 'member' : 'members'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: mutedColor),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 9),
            ],
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isCreatingGroup ? null : _createGroup,
              icon: _isCreatingGroup
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_outlined),
              label: Text(
                _isCreatingGroup ? 'Creating Circle…' : 'Create another Circle',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Secure registered-user invitations are handled through the existing invite-code flow. Manual compatibility records are no longer shown as active Circle memberships.',
            style: TextStyle(fontSize: 10, color: mutedColor),
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
}
