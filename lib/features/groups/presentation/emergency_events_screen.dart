import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/emergency_event.dart';
import '../../../models/family_group.dart';
import '../../../services/emergency_service.dart';
import '../../../core/widgets/light_ui.dart';
import 'emergency_detail_screen.dart';

class EmergencyEventsScreen extends StatefulWidget {
  const EmergencyEventsScreen({
    super.key,
    required this.group,
    required this.currentUserName,
  });
  final FamilyGroup group;
  final String currentUserName;

  @override
  State<EmergencyEventsScreen> createState() => _EmergencyEventsScreenState();
}

class _EmergencyEventsScreenState extends State<EmergencyEventsScreen> {
  String _filter = 'active';
  String? _busyEventId;

  Future<void> _runAction(
    EmergencyEvent event,
    String successMessage,
    Future<void> Function() action,
  ) async {
    if (_busyEventId != null) return;
    setState(() => _busyEventId = event.id);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: kEmerald),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency status could not be updated. Try again.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyEventId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.name} SOS activity'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.appSurfaceMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  _filterButton('active', 'Active'),
                  _filterButton('acknowledged', 'Acknowledged'),
                  _filterButton('resolved', 'Resolved'),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyEvent>>(
              stream: EmergencyService().watchEvents(widget.group.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LightStateView(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load emergencies',
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const LightStateView(
                    icon: Icons.sync_rounded,
                    title: 'Loading activity',
                    message: 'Getting the latest emergency status…',
                    busy: true,
                  );
                }
                final events = snapshot.data!
                    .where((event) => event.status == _filter)
                    .toList();
                if (events.isEmpty) {
                  return const LightStateView(
                    icon: Icons.health_and_safety_rounded,
                    title: 'No emergency alerts',
                    message: 'SOS activity for this Circle will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final active = event.status != 'resolved';
                    final canResolve =
                        user != null &&
                        (widget.group.canManage || event.senderId == user.uid);
                    return LightCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmergencyDetailScreen(
                            group: widget.group,
                            event: event,
                            currentUserName: widget.currentUserName,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  active
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_rounded,
                                  color: active ? kEmergency : kEmerald,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'SOS from ${event.senderName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  event.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: active ? kEmergency : kEmerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (event.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  'Sent ${MaterialLocalizations.of(context).formatMediumDate(event.createdAt!)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.createdAt!))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appMuted,
                                  ),
                                ),
                              ),
                            if (event.acknowledgedByName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  'Acknowledged by ${event.acknowledgedByName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appMuted,
                                  ),
                                ),
                              ),
                            if (active)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    if (event.status == 'active' &&
                                        user != null)
                                      OutlinedButton(
                                        onPressed: _busyEventId == null
                                            ? () => _runAction(
                                                event,
                                                'Emergency acknowledged.',
                                                () => EmergencyService()
                                                    .acknowledge(
                                                      groupId: widget.group.id,
                                                      emergencyId: event.id,
                                                      user: user,
                                                      name: widget
                                                          .currentUserName,
                                                    ),
                                              )
                                            : null,
                                        child: Text(
                                          _busyEventId == event.id
                                              ? 'Updating…'
                                              : 'Acknowledge',
                                        ),
                                      ),
                                    if (canResolve)
                                      ElevatedButton(
                                        onPressed: _busyEventId == null
                                            ? () => _runAction(
                                                event,
                                                'Emergency resolved.',
                                                () =>
                                                    EmergencyService().resolve(
                                                      groupId: widget.group.id,
                                                      emergencyId: event.id,
                                                    ),
                                              )
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kEmergency,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Resolve'),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String value, String label) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? kPrimaryGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : context.appMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
