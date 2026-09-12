import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../models/family_group.dart';
import '../../../services/app_notification_service.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../core/widgets/bounded_dropdown_form_field.dart';
import 'notification_bell_button.dart';
import '../../../app/notification_navigation.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key, required this.groups});
  final List<FamilyGroup> groups;
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _service = AppNotificationService();
  String? _groupId;
  bool _unreadOnly = false;
  int _streamVersion = 0;

  Future<void> _markAllRead(User user) async {
    try {
      await _service.markAllRead(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications marked as read.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications could not be updated. Try again.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          NotificationBellButton(groups: widget.groups),
          TextButton(
            onPressed: () => _markAllRead(user),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.appSurfaceMuted,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      _filterButton('All', !_unreadOnly),
                      _filterButton('Unread', _unreadOnly),
                    ],
                  ),
                ),
                if (widget.groups.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  BoundedDropdownFormField<String?>(
                    initialValue: _groupId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.groups_rounded),
                      labelText: 'Family Circle',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Circles'),
                      ),
                      ...widget.groups.map(
                        (group) => DropdownMenuItem<String?>(
                          value: group.id,
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _groupId = value),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              key: ValueKey(_streamVersion),
              stream: _service.watch(user),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LightStateView(
                    icon: Icons.cloud_off_rounded,
                    title: 'Notifications unavailable',
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => setState(() => _streamVersion++),
                  );
                }
                if (!snapshot.hasData) {
                  return const LightStateView(
                    icon: Icons.sync_rounded,
                    title: 'Loading notifications',
                    message: 'Getting your latest family updates…',
                    busy: true,
                  );
                }
                final notices = (snapshot.data ?? [])
                    .where(
                      (item) =>
                          (_groupId == null || item.groupId == _groupId) &&
                          (!_unreadOnly || !item.isRead),
                    )
                    .toList();
                if (notices.isEmpty) {
                  return LightStateView(
                    icon: _unreadOnly
                        ? Icons.done_all_rounded
                        : Icons.notifications_none_rounded,
                    title: _unreadOnly
                        ? 'You’re all caught up'
                        : 'No notifications yet',
                    message: _unreadOnly
                        ? 'There are no unread family updates.'
                        : 'Family and safety updates will appear here.',
                  );
                }
                return ListView.separated(
                  itemCount: notices.length,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    final item = notices[index];
                    return LightCard(
                      padding: EdgeInsets.zero,
                      onTap: () async {
                        await _service.markRead(user, item.id);
                        await openNotificationPayload({
                          'type': item.type,
                          'groupId': item.groupId,
                          if (item.emergencyId != null)
                            'emergencyId': item.emergencyId,
                          if (item.deviceId != null) 'deviceId': item.deviceId,
                          if (item.memberUserId != null)
                            'memberUserId': item.memberUserId,
                        });
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.isRead
                              ? Colors.grey.shade200
                              : kEmerald.withValues(alpha: .16),
                          child: Icon(
                            item.type.startsWith('emergency')
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_outlined,
                            color: item.isRead ? Colors.grey : kEmergency,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: item.isRead
                            ? Icon(
                                Icons.done_all_rounded,
                                color: context.appMuted,
                                size: 18,
                              )
                            : const LightStatusChip(label: 'New'),
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

  Widget _filterButton(String label, bool selected) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _unreadOnly = label == 'Unread'),
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
