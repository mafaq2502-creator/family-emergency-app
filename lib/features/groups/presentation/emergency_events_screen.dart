import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/emergency_event.dart';
import '../../../models/family_group.dart';
import '../../../services/emergency_service.dart';

class EmergencyEventsScreen extends StatelessWidget {
  const EmergencyEventsScreen({super.key, required this.group, required this.currentUserName});
  final FamilyGroup group;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text('${group.name} SOS activity')),
      body: StreamBuilder<List<EmergencyEvent>>(
        stream: EmergencyService().watchEvents(group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Emergency activity could not be loaded.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          if (events.isEmpty) return const Center(child: Text('No SOS alerts in this group.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = events[index];
              final active = event.status != 'resolved';
              final canResolve = user != null && (group.canManage || event.senderId == user.uid);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(active ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: active ? kEmergency : kEmerald), const SizedBox(width: 8), Expanded(child: Text('SOS from ${event.senderName}', style: const TextStyle(fontWeight: FontWeight.w800))), Text(event.status.toUpperCase(), style: TextStyle(fontSize: 11, color: active ? kEmergency : kEmerald, fontWeight: FontWeight.w800))]),
                    if (event.createdAt != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text('Sent ${MaterialLocalizations.of(context).formatMediumDate(event.createdAt!)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.createdAt!))}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    if (event.acknowledgedByName != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text('Acknowledged by ${event.acknowledgedByName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    if (active) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, children: [
                      if (event.status == 'active' && user != null) OutlinedButton(onPressed: () => EmergencyService().acknowledge(groupId: group.id, emergencyId: event.id, user: user, name: currentUserName), child: const Text('Acknowledge')),
                      if (canResolve) ElevatedButton(onPressed: () => EmergencyService().resolve(groupId: group.id, emergencyId: event.id), style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white), child: const Text('Resolve')),
                    ])),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
