import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../models/family_group.dart';
import '../../../services/app_notification_service.dart';

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
          TextButton(
            onPressed: () => _service.markAllRead(user),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _groupId == null,
                  onSelected: (_) => setState(() => _groupId = null),
                ),
                ...widget.groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(group.name),
                      selected: _groupId == group.id,
                      onSelected: (_) => setState(() => _groupId = group.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: _service.watch(user),
              builder: (context, snapshot) {
                final notices = (snapshot.data ?? [])
                    .where(
                      (item) => _groupId == null || item.groupId == _groupId,
                    )
                    .toList();
                if (notices.isEmpty) {
                  return const Center(child: Text('No notifications yet.'));
                }
                return ListView.separated(
                  itemCount: notices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = notices[index];
                    return ListTile(
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
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(item.body),
                      onTap: () => _service.markRead(user, item.id),
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
}
