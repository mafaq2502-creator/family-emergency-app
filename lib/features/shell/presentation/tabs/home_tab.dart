part of '../family_shell.dart';

extension _HomeTab on _HomeScreenState {
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white70 : kLightMuted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
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
                        'Hello, ${_profileNameController.text.isEmpty ? 'there' : _profileNameController.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Stay connected with your family',
                            style: TextStyle(fontSize: 13, color: mutedColor),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.favorite,
                            size: 14,
                            color: kEmergency,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your Circles',
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
                            'No Circles yet. Create one from Family.',
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
            child: ElevatedButton.icon(
              onPressed: _isCountingDown ? null : _startSOS,
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
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Alerts only your selected emergency recipients',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton.icon(
              onPressed: _isMarkingAlive ? null : _markAlive,
              icon: _isMarkingAlive
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _checkedInToday ? 'Checked in today' : 'Tap once each day',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: mutedColor),
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
}
