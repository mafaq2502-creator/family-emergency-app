import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/family_member.dart';
import 'member_notification_settings_screen.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key, required this.member, this.onDelete, this.onSave});

  final FamilyMember member;
  final Future<void> Function()? onDelete;
  final Future<void> Function(FamilyMember member)? onSave;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final muted = isDark ? kDarkMuted : const Color(0xFF64748B);
    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : const Color(0xFFF8FBFA),
      appBar: AppBar(title: const Text('Member Profile')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: CircleAvatar(radius: 42, backgroundColor: kEmerald.withValues(alpha: .15), child: Text(member.name.isEmpty ? '?' : member.name[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kEmerald)))),
        const SizedBox(height: 14), Center(child: Text(member.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor))), const SizedBox(height: 4), Center(child: Text(member.status, style: TextStyle(color: muted))), const SizedBox(height: 24),
        _detail(context, Icons.favorite_rounded, 'Relationship', member.relation ?? 'Not specified'), _detail(context, Icons.mail_outline_rounded, 'Email', member.email ?? 'Not available'), _detail(context, Icons.phone_outlined, 'Phone', member.phone ?? 'Not available'), _detail(context, Icons.location_on_outlined, 'Location access', member.locationAccess ? 'Allowed' : 'Not allowed'), _detail(context, Icons.battery_charging_full_rounded, 'Battery status access', member.batteryAccess ? 'Allowed' : 'Not allowed'),
        if (onSave != null) ...[
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () => _editDetails(context), icon: const Icon(Icons.edit_outlined), label: const Text('Edit member details'))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberNotificationSettingsScreen(member: member, onSave: onSave!))), icon: const Icon(Icons.notifications_active_outlined), label: const Text('Edit member notifications'))),
        ],
        if (onDelete != null) ...[const SizedBox(height: 24), SizedBox(height: 48, child: ElevatedButton.icon(onPressed: () async { await onDelete!(); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remove Member'), style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white)))],
      ]),
    );
  }

  Future<void> _editDetails(BuildContext context) async {
    final name = TextEditingController(text: member.name);
    final email = TextEditingController(text: member.email);
    final phone = TextEditingController(text: member.phone);
    var relation = member.relation ?? 'Other';
    const relations = ['Father', 'Mother', 'Brother', 'Sister', 'Son', 'Daughter', 'Husband', 'Wife', 'Other'];
    if (!relations.contains(relation)) relation = 'Other';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Edit member details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: relation, isExpanded: true, decoration: const InputDecoration(labelText: 'Relationship'), items: relations.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setSheetState(() => relation = value ?? relation)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await onSave!(FamilyMember(id: member.id, userId: member.userId, name: name.text.trim(), status: member.status, email: email.text.trim().isEmpty ? null : email.text.trim(), phone: phone.text.trim().isEmpty ? null : phone.text.trim(), relation: relation, locationAccess: member.locationAccess, batteryAccess: member.batteryAccess, notificationSettings: member.notificationSettings));
              if (context.mounted) Navigator.pop(context, true);
            }, child: const Text('Save changes'))),
          ]),
        ),
      ),
    );
    name.dispose(); email.dispose(); phone.dispose();
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  Widget _detail(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(icon, color: kEmerald), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: TextStyle(fontSize: 13, color: isDark ? kDarkMuted : const Color(0xFF64748B)))]))]));
  }
}
