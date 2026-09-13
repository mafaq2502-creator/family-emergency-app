part of '../family_shell.dart';

extension _MembersTab on _HomeScreenState {
  Widget _buildFamilyTab() => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        actions: [_notificationBell()],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Circles'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        children: [_buildCirclesTab(), const SafetyUsersScreen(embedded: true)],
      ),
    ),
  );
  Widget _buildCirclesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final visibleGroups = _groups
        .where((group) => _showOwnedCircles ? group.isOwner : !group.isOwner)
        .toList();
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          children: [
            Text(
              'Open a Circle to view its active registered members.',
              style: TextStyle(fontSize: 14, color: mutedColor),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${group.isOwner ? 'owner' : group.role.value} • ${group.memberCount} active ${group.memberCount == 1 ? 'member' : 'members'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: mutedColor),
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
              height: 52,
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
                  _isCreatingGroup
                      ? 'Creating Circle…'
                      : 'Create another Circle',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _joinAnotherCircle,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Join another Circle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinAnotherCircle() async {
    if (!_isPremium && _groups.any((group) => !group.isOwner)) {
      _showPlanLimit(
        'Your Free Plan allows you to join 1 additional Circle. Upgrade to Premium to join more.',
      );
      return;
    }
    final circleId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => JoinCircleScreen(pendingCircleId: _pendingJoinCircleId),
      ),
    );
    if (!mounted) return;
    await _loadProfile();
    if (!mounted || circleId == null) return;

    final cached = _groups.where((group) => group.id == circleId).firstOrNull;
    if (cached != null) {
      _openGroupHome(cached);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final group = await _groupService
          .watchGroupForUser(circleId, user.uid)
          .firstWhere((value) => value != null)
          .timeout(const Duration(seconds: 5));
      if (mounted && group != null) _openGroupHome(group);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membership approved. Your Circle is syncing now.'),
        ),
      );
    }
  }

  Widget _circleScopeButton(String label, bool owned, bool isDark) {
    final selected = _showOwnedCircles == owned;
    return Expanded(
      child: InkWell(
        onTap: () => _setCircleScope(owned),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? kEmerald : kLightPrimary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: isDark ? kEmerald : kLightPrimary,
                    width: 1.5,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white60 : kLightMuted),
              fontSize: AppTypography.tabLabel,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
