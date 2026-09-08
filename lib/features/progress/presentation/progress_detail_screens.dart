import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';

class ScreenTimeDetailScreen extends StatelessWidget {
  const ScreenTimeDetailScreen({super.key, this.memberName = 'All members'});
  final String memberName;

  @override
  Widget build(BuildContext context) {
    const values = [26.0, 38.0, 22.0, 61.0, 44.0, 72.0, 54.0];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return LightPage(
      title: 'Screen Time',
      subtitle: memberName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _periodSelector(),
          const SizedBox(height: 14),
          LightCard(
            child: Column(
              children: [
                const Text(
                  '2h 30m',
                  style: TextStyle(
                    color: kLightNavy,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Total Screen Time',
                  style: TextStyle(color: kLightMuted, fontSize: 11),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      values.length,
                      (index) => Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 18,
                              height: values[index],
                              decoration: BoxDecoration(
                                gradient: kPrimaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              labels[index],
                              style: const TextStyle(
                                color: kLightMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const LightSectionTitle('App Usage'),
          ...const [
            (
              'YouTube',
              '1h 10m',
              Icons.play_circle_fill_rounded,
              Color(0xFFEF4444),
            ),
            ('TikTok', '45m', Icons.music_note_rounded, Color(0xFF111827)),
            ('WhatsApp', '25m', Icons.chat_rounded, Color(0xFF10B981)),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LightSettingRow(
                icon: item.$3,
                title: item.$1,
                subtitle: 'Usage for selected period',
                trailing: Text(
                  item.$2,
                  style: TextStyle(color: item.$4, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: kLightSurfaceMuted,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: ['Today', 'Week', 'Month']
          .map(
            (label) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: label == 'Today' ? kPrimaryGradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: label == 'Today' ? Colors.white : kLightMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class CheckInHistoryScreen extends StatelessWidget {
  const CheckInHistoryScreen({super.key, this.memberName = 'All members'});
  final String memberName;

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Today', '07:08 AM', true),
      ('Yesterday', '07:22 AM', true),
      ('May 3, 2026', 'No check-in', false),
      ('May 2, 2026', '08:04 AM', true),
      ('May 1, 2026', '07:41 AM', true),
    ];
    return LightPage(
      title: 'Check-In History',
      subtitle: memberName,
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: LightCard(
                child: Row(
                  children: [
                    Icon(
                      entry.$3
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: entry.$3 ? kEmerald : kEmergency,
                      size: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$1,
                            style: const TextStyle(
                              color: kLightNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            entry.$2,
                            style: const TextStyle(
                              color: kLightMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LightStatusChip(
                      label: entry.$3 ? 'Checked in' : 'Missed',
                      color: entry.$3 ? kEmerald : kEmergency,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'All times use the member’s local timezone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kLightMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ProgressDetailsScreen extends StatelessWidget {
  const ProgressDetailsScreen({super.key, this.memberName = 'All members'});
  final String memberName;

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Progress Details',
    subtitle: memberName,
    child: Column(
      children: [
        LightSettingRow(
          icon: Icons.schedule_rounded,
          title: 'Screen Time',
          subtitle: 'Daily values and weekly or monthly trend',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScreenTimeDetailScreen(memberName: memberName),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LightSettingRow(
          icon: Icons.verified_rounded,
          title: 'Check-In History',
          subtitle: 'Checked-in and missed days in local time',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CheckInHistoryScreen(memberName: memberName),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const LightStateView(
          icon: Icons.insights_rounded,
          title: 'More progress is coming',
          message: 'Device telemetry will appear here after a device is paired and sharing is enabled.',
        ),
      ],
    ),
  );
}
