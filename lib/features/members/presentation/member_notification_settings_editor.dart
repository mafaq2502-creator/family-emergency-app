import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/notification_settings.dart';
import '../../../core/widgets/light_ui.dart';

class MemberNotificationSettingsEditor extends StatelessWidget {
  const MemberNotificationSettingsEditor({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final NotificationSettings settings;
  final ValueChanged<NotificationSettings> onChanged;

  NotificationSettings _copy({
    bool? missedCheckInAlerts,
    bool? emergencyAlerts,
    bool? batteryAlerts,
    bool? offlineAlerts,
    bool? locationSharing,
  }) => NotificationSettings(
    missedCheckInAlerts: missedCheckInAlerts ?? settings.missedCheckInAlerts,
    emergencyAlerts: emergencyAlerts ?? settings.emergencyAlerts,
    batteryAlerts: batteryAlerts ?? settings.batteryAlerts,
    offlineAlerts: offlineAlerts ?? settings.offlineAlerts,
    locationSharing: locationSharing ?? settings.locationSharing,
    ownerMissedCheckInAlerts: settings.ownerMissedCheckInAlerts,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : kLightNavy;
    final muted = isDark ? Colors.white60 : kLightMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Member Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, color: title),
        ),
        Text(
          'Choose alerts for this member only.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        _toggle(
          Icons.event_busy_rounded,
          'Missed daily check-in',
          settings.missedCheckInAlerts,
          (value) => onChanged(_copy(missedCheckInAlerts: value)),
        ),
        _toggle(
          Icons.sos_rounded,
          'Emergency alerts',
          settings.emergencyAlerts,
          (value) => onChanged(_copy(emergencyAlerts: value)),
        ),
        _toggle(
          Icons.battery_alert_rounded,
          'Low battery alerts',
          settings.batteryAlerts,
          (value) => onChanged(_copy(batteryAlerts: value)),
        ),
        _toggle(
          Icons.signal_wifi_connected_no_internet_4_rounded,
          'Offline alerts',
          settings.offlineAlerts,
          (value) => onChanged(_copy(offlineAlerts: value)),
        ),
        _toggle(
          Icons.location_on_rounded,
          'Location sharing',
          settings.locationSharing,
          (value) => onChanged(_copy(locationSharing: value)),
        ),
      ],
    );
  }

  Widget _toggle(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LightToggleRow(
      icon: icon,
      title: label,
      value: value,
      onChanged: onChanged,
    ),
  );
}
