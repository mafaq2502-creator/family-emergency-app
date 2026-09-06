import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/notification_settings.dart';

class MemberNotificationSettingsEditor extends StatelessWidget {
  const MemberNotificationSettingsEditor({super.key, required this.settings, required this.onChanged});

  final NotificationSettings settings;
  final ValueChanged<NotificationSettings> onChanged;

  NotificationSettings _copy({bool? missedCheckInAlerts, bool? emergencyAlerts, bool? batteryAlerts, bool? offlineAlerts, bool? locationSharing}) => NotificationSettings(missedCheckInAlerts: missedCheckInAlerts ?? settings.missedCheckInAlerts, emergencyAlerts: emergencyAlerts ?? settings.emergencyAlerts, batteryAlerts: batteryAlerts ?? settings.batteryAlerts, offlineAlerts: offlineAlerts ?? settings.offlineAlerts, locationSharing: locationSharing ?? settings.locationSharing, ownerMissedCheckInAlerts: settings.ownerMissedCheckInAlerts);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : kNavy;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 10), Text('Member Notifications', style: TextStyle(fontWeight: FontWeight.w800, color: title)), Text('Choose alerts for this member only.', style: TextStyle(fontSize: 11, color: muted)),
    _toggle('Missed daily check-in', settings.missedCheckInAlerts, (value) => onChanged(_copy(missedCheckInAlerts: value))), _toggle('Emergency alerts', settings.emergencyAlerts, (value) => onChanged(_copy(emergencyAlerts: value))), _toggle('Low battery alerts', settings.batteryAlerts, (value) => onChanged(_copy(batteryAlerts: value))), _toggle('Offline alerts', settings.offlineAlerts, (value) => onChanged(_copy(offlineAlerts: value))), _toggle('Location sharing', settings.locationSharing, (value) => onChanged(_copy(locationSharing: value))),
  ]);
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Builder(builder: (context) => SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : kNavy, fontSize: 13)), value: value, activeThumbColor: kEmerald, onChanged: onChanged));
}
