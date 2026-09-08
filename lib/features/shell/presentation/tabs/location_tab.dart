part of '../family_shell.dart';

extension _LocationTab on _HomeScreenState {
  Widget _buildLocationTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Progress settings',
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _groupSelector(),
          const SizedBox(height: 10),
          _progressFilter(
            label: familyMembers.isEmpty
                ? 'All members'
                : '${familyMembers.first.name} + ${familyMembers.length - 1}',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
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
                _periodChip('Today', true, isDark),
                _periodChip('Week', false, isDark),
                _periodChip('Month', false, isDark),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _screenTimeCard(isDark, titleColor, mutedColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _progressMetric(
                  icon: Icons.battery_5_bar_rounded,
                  label: 'Battery',
                  value: '78%',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _progressMetric(
                  icon: Icons.storage_rounded,
                  label: 'Storage',
                  value: '45 GB',
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
                  value: '07:50 AM',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _progressMetric(
                  icon: Icons.verified_rounded,
                  label: 'Check-in',
                  value: _checkedInToday ? 'Checked in' : 'Pending',
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
                    memberName: familyMembers.isEmpty
                        ? 'All members'
                        : familyMembers.first.name,
                  ),
                ),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressFilter({
    required String label,
    required IconData icon,
    required bool isDark,
  }) => Container(
    height: 49,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: isDark ? kDarkCard : kLightSurface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
    ),
    child: Row(
      children: [
        Icon(icon, color: isDark ? kEmerald : kLightPrimary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      ],
    ),
  );

  Widget _periodChip(String label, bool selected, bool isDark) => Expanded(
    child: Container(
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
  );

  Widget _screenTimeCard(bool isDark, Color titleColor, Color mutedColor) {
    const bars = [30.0, 48.0, 72.0, 52.0, 82.0, 63.0];
    const labels = ['8am', '10am', '12pm', '2pm', '4pm', '6pm'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D0B715E),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark
                      ? kEmerald.withValues(alpha: .15)
                      : kLightSuccessSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isDark ? kEmerald : kLightPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen Time',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '2h 30m',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.trending_down_rounded,
                color: isDark ? kEmerald : kLightPrimary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                bars.length,
                (index) => Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 16,
                      height: bars[index],
                      decoration: BoxDecoration(
                        gradient: kPrimaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(fontSize: 8, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                  fontSize: 10,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
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
