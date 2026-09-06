// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../services/group_service.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key, required this.group, required this.members});
  final FamilyGroup group;
  final List<FamilyMember> members;
  @override State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _service = GroupService();
  late Set<String> _recipients;
  bool _saving = false;
  @override void initState() { super.initState(); _recipients = widget.group.emergencyRecipientIds.toSet(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Group Settings')), body: ListView(padding: const EdgeInsets.all(24), children: [Text(widget.group.name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20), const Text('Emergency Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('Choose active app members who receive SOS alerts from this group.'), const SizedBox(height: 12), ...widget.members.where((m) => m.userId != null && m.status.toLowerCase() != 'pending').map((m) { final id = m.userId!; return CheckboxListTile(value: _recipients.contains(id), onChanged: (value) => setState(() => value == true ? _recipients.add(id) : _recipients.remove(id)), title: Text(m.name), subtitle: Text(m.email ?? 'Registered member')); }), const SizedBox(height: 18), SizedBox(height: 48, child: ElevatedButton(onPressed: _saving || _recipients.isEmpty ? null : () async { setState(() => _saving = true); try { await _service.setEmergencyRecipients(widget.group, _recipients.toList()); if (mounted) Navigator.pop(context); } finally { if (mounted) setState(() => _saving = false); } }, style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white), child: Text(_saving ? 'Saving...' : 'Save Emergency Recipients')))]));
}
