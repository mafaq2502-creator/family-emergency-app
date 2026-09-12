import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../notifications/presentation/notification_bell_button.dart';

const progressPeriods = ['Today', 'Yesterday', 'Last week', 'Last month'];

class ProgressPeriodSelector extends StatelessWidget {
  const ProgressPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: progressPeriods
        .map(
          (period) => ChoiceChip(
            label: Text(period),
            selected: period == value,
            onSelected: (_) => onChanged(period),
            selectedColor: context.appPrimary,
            labelStyle: TextStyle(
              color: period == value ? Colors.white : context.appMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide.none,
          ),
        )
        .toList(),
  );
}

class ScreenTimeDetailScreen extends StatefulWidget {
  const ScreenTimeDetailScreen({super.key, this.memberName = 'All members'});
  final String memberName;

  @override
  State<ScreenTimeDetailScreen> createState() => _ScreenTimeDetailScreenState();
}

class _ScreenTimeDetailScreenState extends State<ScreenTimeDetailScreen> {
  String _period = 'Today';

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Screen Time',
    subtitle: widget.memberName,
    actions: const [NotificationBellButton()],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressPeriodSelector(
          value: _period,
          onChanged: (value) => setState(() => _period = value),
        ),
        const SizedBox(height: 18),
        LightStateView(
          icon: Icons.schedule_rounded,
          title: 'Screen-time data unavailable',
          message:
              'No device telemetry is available for ${widget.memberName} in $_period. Pairing and consent are required before usage can be shown.',
        ),
        const SizedBox(height: 18),
        const LightSectionTitle('App Usage'),
        LightCard(
          child: Row(
            children: [
              Icon(Icons.apps_rounded, color: context.appMuted),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'App-by-app usage will appear after a supported device is paired.',
                  style: TextStyle(color: context.appMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({
    super.key,
    this.memberName = 'All members',
    this.latestCheckIn,
  });
  final String memberName;
  final DateTime? latestCheckIn;

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  String _period = 'Today';

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.latestCheckIn;
    return LightPage(
      title: 'Check-In History',
      subtitle: widget.memberName,
      actions: const [NotificationBellButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressPeriodSelector(
            value: _period,
            onChanged: (value) => setState(() => _period = value),
          ),
          const SizedBox(height: 18),
          if (checkIn != null && _period == 'Today')
            LightCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: kEmerald),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest check-in',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          MaterialLocalizations.of(context)
                              .formatTimeOfDay(TimeOfDay.fromDateTime(checkIn)),
                          style: TextStyle(
                            color: context.appMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const LightStatusChip(label: 'Checked in'),
                ],
              ),
            )
          else
            LightStateView(
              icon: Icons.event_note_rounded,
              title: 'No history available',
              message: _period == 'Today'
                  ? 'No check-in has been recorded for this selection today.'
                  : 'Historical check-in storage is not connected for $_period.',
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Times are displayed in the device’s local timezone.',
              style: TextStyle(color: context.appMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressDetailsScreen extends StatelessWidget {
  const ProgressDetailsScreen({
    super.key,
    this.memberName = 'All members',
    this.latestCheckIn,
  });
  final String memberName;
  final DateTime? latestCheckIn;

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Progress Details',
    subtitle: memberName,
    actions: const [NotificationBellButton()],
    child: Column(
      children: [
        LightSettingRow(
          icon: Icons.schedule_rounded,
          title: 'Screen Time',
          subtitle: 'Usage appears only after supported device telemetry',
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
          subtitle: latestCheckIn == null
              ? 'No check-in is available'
              : 'Latest check-in is available',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CheckInHistoryScreen(
                memberName: memberName,
                latestCheckIn: latestCheckIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const LightStateView(
          icon: Icons.insights_rounded,
          title: 'Device progress is not connected',
          message: 'Battery, storage and usage need a paired device with explicit sharing consent.',
        ),
      ],
    ),
  );
}
