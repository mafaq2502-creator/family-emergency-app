part of '../family_shell.dart';

extension _HomeTab on _HomeScreenState {
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white70 : kLightMuted;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${_profileNameController.text.isEmpty ? 'Afaq' : _profileNameController.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your family is safe',
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.favorite, size: 14, color: kEmergency),
              ],
            ),
          ],
        ),
        actions: [
          _notificationBell(),
          Icon(
            Icons.groups_rounded,
            color: isDark ? kEmerald : kLightPrimary,
            size: 32,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final contentWidth = viewport.maxWidth - 48;
            final cardWidth = (contentWidth - 10) / 2;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight - 36),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Groups',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (_groups.isEmpty) ...[
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'No groups yet. Create one from Members.',
                            style: TextStyle(fontSize: 14, color: mutedColor),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        // A Wrap is deliberately used here instead of a nested GridView.
                        // This tab lives inside a SingleChildScrollView; a nested viewport
                        // can receive an unbounded height after authentication and crash.
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final group in _groups)
                              SizedBox(
                                width: cardWidth,
                                height: cardWidth / 1.25,
                                child: _groupHomeCard(group, isDark),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      const Spacer(),
                      _homeActions(isDark, mutedColor),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _homeActions(bool isDark, Color mutedColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isMarkingAlive ? null : _markAlive,
              icon: _isMarkingAlive
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kEmerald,
                      ),
                    )
                  : Icon(
                      _checkedInToday
                          ? Icons.check_circle_rounded
                          : Icons.favorite_rounded,
                      size: 18,
                    ),
              label: const Text(
                "I'm Alive",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _checkedInToday
                    ? kEmerald
                    : (isDark ? const Color(0xFF9FE8D2) : kLightPrimary),
                side: BorderSide(
                  color: _checkedInToday
                      ? kEmerald
                      : (isDark ? const Color(0xFF2D806E) : kLightAccent),
                ),
                backgroundColor: _checkedInToday
                    ? (isDark ? const Color(0xFF123A31) : kLightSuccessSurface)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _checkedInToday ? 'Checked in today' : 'Tap once each day',
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _startSOS,
              icon: const Icon(Icons.warning_amber_rounded, size: 19),
              label: const Text(
                'Emergency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmergency,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: kEmergency.withValues(alpha: .45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHomeCard(FamilyGroup group, bool isDark) => Material(
    color: isDark ? kDarkCard : kLightSurface,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: () => _openGroupHome(group),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.groups_rounded, color: kEmerald, size: 30),
            const Spacer(),
            Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : kLightNavy,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              group.canManage ? 'Owner/Admin' : 'Member',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : kLightMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ignore: unused_element
  Widget _homeMemberCard(FamilyMember member, int index, bool isDark) {
    final name = member.name;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final battery = const ['85%', '72%', '60%', '40%'][index];
    final batteryColor = index == 3 ? const Color(0xFFFFB21A) : kEmerald;
    final avatarColors = const [
      Color(0xFFE9EEF0),
      Color(0xFFF2E9E8),
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
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openMemberProfile(member, index),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColors[index],
                  child: Icon(
                    avatarIcons[index],
                    color: const Color(0xFF536878),
                    size: 29,
                  ),
                ),
                const Positioned(
                  right: -1,
                  top: -1,
                  child: CircleAvatar(
                    radius: 5.5,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(radius: 4, backgroundColor: kEmerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.circle, size: 8, color: kEmerald),
                SizedBox(width: 4),
                Text(
                  'Online',
                  style: TextStyle(
                    color: kEmerald,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  Icons.battery_5_bar_rounded,
                  size: 16,
                  color: batteryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  battery,
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: mutedColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Lahore, PK',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: mutedColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
