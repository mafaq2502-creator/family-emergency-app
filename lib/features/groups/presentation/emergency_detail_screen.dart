import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/emergency_event.dart';
import '../../../models/family_group.dart';
import '../../../services/emergency_service.dart';

class EmergencyDetailScreen extends StatelessWidget {
  const EmergencyDetailScreen({
    super.key,
    required this.group,
    required this.event,
    required this.currentUserName,
  });
  final FamilyGroup group;
  final EmergencyEvent event;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return LightPage(
      title: 'Emergency Alert',
      subtitle: group.name,
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: kEmergency.withValues(alpha: .11),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos_rounded, color: kEmergency, size: 42),
          ),
          const SizedBox(height: 12),
          Text(
            event.senderName,
            style: const TextStyle(
              color: kLightNavy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text('Needs your help', style: TextStyle(color: kEmergency)),
          const SizedBox(height: 18),
          _row(Icons.groups_rounded, 'Family Circle', group.name),
          _row(
            Icons.schedule_rounded,
            'Time',
            event.createdAt == null
                ? 'Just now'
                : MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(event.createdAt!)),
          ),
          _row(Icons.battery_3_bar_rounded, 'Battery', 'Not available'),
          _row(Icons.location_on_rounded, 'Location', 'Not available'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calling is not connected yet.'),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: user == null || event.status != 'active'
                      ? null
                      : () => EmergencyService().acknowledge(
                          groupId: group.id,
                          emergencyId: event.id,
                          user: user,
                          name: currentUserName,
                        ),
                  child: const Text('Acknowledge'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.person_rounded),
            label: const Text('Open Member Profile'),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LightSettingRow(icon: icon, title: label, subtitle: value),
  );
}
