part of '../family_shell.dart';

extension _LocationTab on _HomeScreenState {
  Widget _buildLocationTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          _notificationBell(),
          IconButton(
            tooltip: 'Progress settings',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Progress uses the Circle, member and date filters below.',
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          children: [
            BoundedDropdownFormField<FamilyGroup>(
              initialValue: _selectedGroup,
              decoration: const InputDecoration(
                labelText: 'Family Circle',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
              hint: const Text('Select a Circle'),
              items: _groups
                  .map(
                    (group) => DropdownMenuItem(
                      value: group,
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _selectProgressGroup,
            ),
            const SizedBox(height: 10),
            BoundedDropdownFormField<String?>(
              initialValue: familyMembers.any((m) => m.id == _progressMemberId)
                  ? _progressMemberId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Member / Child',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All members'),
                ),
                ...familyMembers
                    .where((m) => m.id != null)
                    .map(
                      (member) => DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(
                          member.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              ],
              onChanged: _selectProgressMember,
            ),
            const SizedBox(height: 12),
            ProgressPeriodSelector(
              value: _progressPeriod,
              onChanged: _selectProgressPeriod,
            ),
            const SizedBox(height: 15),
            ScreenTimeOverviewCard(
              circleId: _selectedGroup?.id,
              memberUserId: _progressMemberId == null
                  ? null
                  : familyMembers
                        .where((member) => member.id == _progressMemberId)
                        .map((member) => member.userId ?? member.id)
                        .firstOrNull,
              periodLabel: _progressPeriod,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreenTimeDetailScreen(
                    memberName: _progressMemberId == null
                        ? 'All members'
                        : familyMembers
                                  .where((m) => m.id == _progressMemberId)
                                  .map((m) => m.name)
                                  .firstOrNull ??
                              'Selected member',
                    circleId: _selectedGroup?.id,
                    memberUserId: _progressMemberId == null
                        ? null
                        : familyMembers
                              .where((member) => member.id == _progressMemberId)
                              .map((member) => member.userId ?? member.id)
                              .firstOrNull,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _progressMetric(
                    icon: Icons.battery_5_bar_rounded,
                    label: 'Battery',
                    value: 'Not available',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _progressMetric(
                    icon: Icons.storage_rounded,
                    label: 'Storage',
                    value: 'Not available',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _progressMetric(
                    icon: Icons.sync_rounded,
                    label: 'Last Sync',
                    value: 'No device sync',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _progressMetric(
                    icon: Icons.verified_rounded,
                    label: 'Check-in',
                    value: _checkedInToday
                        ? 'Checked in today'
                        : 'No check-in today',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProgressDetailsScreen(
                      memberName: _progressMemberId == null
                          ? 'All members'
                          : familyMembers
                                    .where((m) => m.id == _progressMemberId)
                                    .map((m) => m.name)
                                    .firstOrNull ??
                                'Selected member',
                      latestCheckIn: _progressMemberId == null
                          ? _lastDailyCheckIn
                          : null,
                      circleId: _selectedGroup?.id,
                      memberUserId: _progressMemberId == null
                          ? null
                          : familyMembers
                                .where(
                                  (member) => member.id == _progressMemberId,
                                )
                                .map((member) => member.userId ?? member.id)
                                .firstOrNull,
                    ),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressMetric({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: isDark ? kDarkCard : kLightSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
    ),
    child: Row(
      children: [
        Icon(icon, color: isDark ? kEmerald : kLightPrimary, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white60 : kLightMuted,
                  fontSize: 13,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );

  // Kept for the legacy location illustration while the Progress UI is phased in.
  // ignore: unused_element
  Widget _locationEmptyArtwork(bool isDark) => SizedBox(
    width: 195,
    height: 150,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 2,
          child: Transform.rotate(
            angle: -.18,
            child: Container(
              width: 150,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFBDECEE),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 21,
          child: Transform.rotate(
            angle: -.18,
            child: Container(width: 156, height: 3, color: Colors.white70),
          ),
        ),
        Positioned(
          bottom: 40,
          child: Transform.rotate(
            angle: -.18,
            child: Container(width: 156, height: 3, color: Colors.white70),
          ),
        ),
        const Positioned(
          left: 30,
          bottom: 38,
          child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 32),
        ),
        const Positioned(
          right: 25,
          bottom: 20,
          child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 36),
        ),
        const Positioned(
          right: 25,
          top: 43,
          child: Icon(Icons.cloud_rounded, color: Color(0xFFDCECF8), size: 44),
        ),
        Container(
          width: 67,
          height: 76,
          decoration: const BoxDecoration(
            color: kEmerald,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
      ],
    ),
  );
}
