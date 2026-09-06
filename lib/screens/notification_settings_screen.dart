import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _emerald = Color(0xFF10B981);
const _navy = Color(0xFF112A55);
const _darkBackground = Color(0xFF07131D);
const _darkCard = Color(0xFF132431);
const _darkMuted = Color(0xFFAFC0CF);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, required this.initialSettings, required this.isFamilyOwner});

  final Map<String, dynamic> initialSettings;
  final bool isFamilyOwner;

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _missedCheckInAlerts;
  late bool _emergencyAlerts;
  late bool _batteryAlerts;
  late bool _offlineAlerts;
  late bool _locationSharing;
  late bool _ownerMissedCheckInAlerts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _missedCheckInAlerts = settings['missedCheckInAlerts'] as bool? ?? true;
    _emergencyAlerts = settings['emergencyAlerts'] as bool? ?? true;
    _batteryAlerts = settings['batteryAlerts'] as bool? ?? false;
    _offlineAlerts = settings['offlineAlerts'] as bool? ?? false;
    _locationSharing = settings['locationSharing'] as bool? ?? false;
    _ownerMissedCheckInAlerts = settings['ownerMissedCheckInAlerts'] as bool? ?? true;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'notificationSettings': {
          'missedCheckInAlerts': _missedCheckInAlerts,
          'emergencyAlerts': _emergencyAlerts,
          'batteryAlerts': _batteryAlerts,
          'offlineAlerts': _offlineAlerts,
          'locationSharing': _locationSharing,
          // Server scheduling must respect this owner-only family-wide preference.
          'ownerMissedCheckInAlerts': widget.isFamilyOwner ? _ownerMissedCheckInAlerts : false,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save notification settings. Please try again.'), backgroundColor: Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _navy;
    final muted = isDark ? _darkMuted : const Color(0xFF64748B);
    return Scaffold(
      backgroundColor: isDark ? _darkBackground : const Color(0xFFF8FBFA),
      appBar: AppBar(
        backgroundColor: isDark ? _darkBackground : const Color(0xFFF8FBFA),
        foregroundColor: titleColor,
        elevation: 0,
        title: const Text('Notification Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _emerald)) : const Text('Save', style: TextStyle(color: _emerald, fontWeight: FontWeight.w800)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('Personal alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile('Missed daily check-in', 'Alert me when a family member misses their 10:00 AM deadline.', Icons.favorite_rounded, _missedCheckInAlerts, (value) => setState(() => _missedCheckInAlerts = value)),
            _settingTile('Emergency alerts', 'Receive emergency SOS alerts from family members.', Icons.warning_amber_rounded, _emergencyAlerts, (value) => setState(() => _emergencyAlerts = value)),
            _settingTile('Low battery alerts', 'Receive alerts when a shared device has low battery.', Icons.battery_alert_rounded, _batteryAlerts, (value) => setState(() => _batteryAlerts = value)),
            _settingTile('Device offline alerts', 'Receive alerts when a shared device goes offline.', Icons.phonelink_erase_rounded, _offlineAlerts, (value) => setState(() => _offlineAlerts = value)),
          ]),
          const SizedBox(height: 18),
          Text('Privacy & sharing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile('Location sharing', 'Allow approved family members to view your live location.', Icons.location_on_rounded, _locationSharing, (value) => setState(() => _locationSharing = value)),
          ]),
          const SizedBox(height: 18),
          Text('Family owner controls', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            _settingTile('Notify the family about missed check-ins', 'At a member’s local 10:00 AM deadline, notify opted-in family members.', Icons.groups_rounded, _ownerMissedCheckInAlerts, widget.isFamilyOwner ? (value) => setState(() => _ownerMissedCheckInAlerts = value) : null),
          ]),
          if (!widget.isFamilyOwner) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Only the family-circle owner can change family-wide alert rules.', style: TextStyle(fontSize: 11, color: muted))),
          const SizedBox(height: 18),
          Text('Daily check-in uses the member’s own device time zone: 10:00 AM to 9:59 AM. Push delivery requires the family backend and notification permission.', style: TextStyle(fontSize: 11, height: 1.4, color: muted)),
        ],
      ),
    );
  }

  Widget _settingsCard(bool isDark, List<Widget> children) => Container(
        decoration: BoxDecoration(color: isDark ? _darkCard : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? const Color(0xFF233846) : const Color(0xFFE7EDF0))),
        child: Column(children: children),
      );

  Widget _settingTile(String title, String detail, IconData icon, bool value, ValueChanged<bool>? onChanged) => SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        value: value,
        onChanged: onChanged,
        activeThumbColor: _emerald,
        secondary: Icon(icon, color: onChanged == null ? Colors.grey : _emerald),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onChanged == null ? Colors.grey : null)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 11, height: 1.25)),
      );
}
