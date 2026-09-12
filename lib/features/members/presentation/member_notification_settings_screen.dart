import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_member.dart';
import '../../../models/notification_settings.dart';
import 'member_notification_settings_editor.dart';
import '../../../core/widgets/light_ui.dart';

class MemberNotificationSettingsScreen extends StatefulWidget {
  const MemberNotificationSettingsScreen({
    super.key,
    required this.member,
    required this.onSave,
  });

  final FamilyMember member;
  final Future<void> Function(FamilyMember member) onSave;

  @override
  State<MemberNotificationSettingsScreen> createState() =>
      _MemberNotificationSettingsScreenState();
}

class _MemberNotificationSettingsScreenState
    extends State<MemberNotificationSettingsScreen> {
  late NotificationSettings _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.member.notificationSettings;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        FamilyMember(
          id: widget.member.id,
          userId: widget.member.userId,
          name: widget.member.name,
          status: widget.member.status,
          phone: widget.member.phone,
          email: widget.member.email,
          relation: widget.member.relation,
          locationAccess: widget.member.locationAccess,
          batteryAccess: widget.member.batteryAccess,
          notificationSettings: _settings,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.member.name} Alerts'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Notification preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        const Text('These preferences apply only to this member.'),
        MemberNotificationSettingsEditor(
          settings: _settings,
          onChanged: (settings) => setState(() => _settings = settings),
        ),
        const SizedBox(height: 8),
        const LightToggleRow(
          icon: Icons.monitor_heart_rounded,
          title: 'Screen-time report',
          subtitle: 'Available after device telemetry is connected',
          value: false,
          onChanged: null,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmerald,
              foregroundColor: Colors.white,
            ),
            child: _saving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save settings'),
          ),
        ),
      ],
    ),
  );
}
