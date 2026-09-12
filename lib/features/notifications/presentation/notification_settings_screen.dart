import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/notification_settings.dart';
import '../../../services/notification_settings_service.dart';
import '../../../services/push_notification_service.dart';

const _emerald = kEmerald;
const _navy = kLightNavy;
const _darkBackground = kDarkBackground;
const _darkMuted = kDarkMuted;

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.isCircleOwner,
  });

  final Map<String, dynamic> initialSettings;
  final bool isCircleOwner;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  late bool _missedCheckInAlerts;
  late bool _emergencyAlerts;
  late bool _batteryAlerts;
  late bool _offlineAlerts;
  late bool _locationSharing;
  late bool _ownerMissedCheckInAlerts;
  bool _saving = false;
  final _settingsService = NotificationSettingsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService.instance.refreshPermissionState();
    final settings = widget.initialSettings;
    _missedCheckInAlerts = settings['missedCheckInAlerts'] as bool? ?? true;
    _emergencyAlerts = settings['emergencyAlerts'] as bool? ?? true;
    _batteryAlerts = settings['batteryAlerts'] as bool? ?? false;
    _offlineAlerts = settings['offlineAlerts'] as bool? ?? false;
    _locationSharing = settings['locationSharing'] as bool? ?? false;
    _ownerMissedCheckInAlerts =
        settings['ownerMissedCheckInAlerts'] as bool? ?? true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PushNotificationService.instance.bindCurrentUser().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _enablePush() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: const Text('Allow safety notifications?'),
        content: const Text(
          'Android notifications let this device show emergency SOS, family activity, and device safety alerts. Your in-app notification history remains available if you decline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await PushNotificationService.instance.requestPermission();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _settingsService.save(
        user,
        NotificationSettings(
          missedCheckInAlerts: _missedCheckInAlerts,
          emergencyAlerts: _emergencyAlerts,
          batteryAlerts: _batteryAlerts,
          offlineAlerts: _offlineAlerts,
          locationSharing: _locationSharing,
          ownerMissedCheckInAlerts: widget.isCircleOwner
              ? _ownerMissedCheckInAlerts
              : false,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save notification settings. Please try again.',
            ),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _navy;
    final muted = isDark ? _darkMuted : kLightMuted;
    return Scaffold(
      backgroundColor: isDark ? _darkBackground : Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? _darkBackground : Colors.transparent,
        foregroundColor: titleColor,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _emerald,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: _emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          ValueListenableBuilder<PushPermissionState>(
            valueListenable: PushNotificationService.instance.permission,
            builder: (context, state, _) => AppSurfaceCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: Icon(
                  state == PushPermissionState.granted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: state == PushPermissionState.granted
                      ? _emerald
                      : kEmergency,
                ),
                title: Text(
                  state == PushPermissionState.granted
                      ? 'Android notifications are on'
                      : 'Android notifications are off',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  state == PushPermissionState.granted
                      ? 'This device can receive notification-shade alerts.'
                      : 'Enable permission to receive alerts outside the app.',
                ),
                trailing: state == PushPermissionState.granted
                    ? const Icon(Icons.check_circle_rounded, color: _emerald)
                    : TextButton(
                        onPressed: state == PushPermissionState.settingsRequired
                            ? PushNotificationService.instance.openSettings
                            : _enablePush,
                        child: Text(
                          state == PushPermissionState.settingsRequired
                              ? 'Settings'
                              : 'Enable',
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<String?>(
            valueListenable: PushNotificationService.instance.syncError,
            builder: (_, error, _) => error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error),
                  ),
          ),
          Text(
            'Personal alerts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile(
              'Missed daily check-in',
              'Alert me when a family member misses their 10:00 AM deadline.',
              Icons.favorite_rounded,
              _missedCheckInAlerts,
              (value) => setState(() => _missedCheckInAlerts = value),
            ),
            _settingTile(
              'Emergency alerts',
              'Receive emergency SOS alerts from family members.',
              Icons.warning_amber_rounded,
              _emergencyAlerts,
              (value) => setState(() => _emergencyAlerts = value),
            ),
            _settingTile(
              'Low battery alerts',
              'Receive alerts when a shared device has low battery.',
              Icons.battery_alert_rounded,
              _batteryAlerts,
              (value) => setState(() => _batteryAlerts = value),
            ),
            _settingTile(
              'Device offline alerts',
              'Receive alerts when a shared device goes offline.',
              Icons.phonelink_erase_rounded,
              _offlineAlerts,
              (value) => setState(() => _offlineAlerts = value),
            ),
          ]),
          const SizedBox(height: 18),
          Text(
            'Privacy & sharing',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile(
              'Location sharing',
              'Allow approved family members to view your live location.',
              Icons.location_on_rounded,
              _locationSharing,
              (value) => setState(() => _locationSharing = value),
            ),
          ]),
          const SizedBox(height: 18),
          Text(
            'Family owner controls',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile(
              'Notify the family about missed check-ins',
              'At a member’s local 10:00 AM deadline, notify opted-in family members.',
              Icons.groups_rounded,
              _ownerMissedCheckInAlerts,
              widget.isCircleOwner
                  ? (value) => setState(() => _ownerMissedCheckInAlerts = value)
                  : null,
            ),
          ]),
          if (!widget.isCircleOwner)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Only the family-circle owner can change family-wide alert rules.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Daily check-in uses the member’s own device time zone: 10:00 AM to 9:59 AM. Push delivery requires the family backend and notification permission.',
            style: TextStyle(fontSize: 13, height: 1.4, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(bool isDark, List<Widget> children) =>
      AppSurfaceCard(child: Column(children: children));

  Widget _settingTile(
    String title,
    String detail,
    IconData icon,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    value: value,
    onChanged: onChanged,
    activeThumbColor: _emerald,
    secondary: Icon(icon, color: onChanged == null ? Colors.grey : _emerald),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: onChanged == null ? Colors.grey : null,
      ),
    ),
    subtitle: Text(detail, style: const TextStyle(fontSize: 13, height: 1.25)),
  );
}
