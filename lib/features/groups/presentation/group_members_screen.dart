import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/circle_membership.dart';
import '../../../models/family_group.dart';
import '../../../services/group_service.dart';
import '../../members/presentation/circle_member_detail_screen.dart';
import 'emergency_events_screen.dart';
import 'group_settings_screen.dart';
import 'share_circle_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.group,
    this.groupService,
    this.viewerId,
  });
  final FamilyGroup group;
  final GroupService? groupService;
  final String? viewerId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  late final GroupService _service = widget.groupService ?? GroupService();
  int _retryKey = 0;
  String? get _viewerId =>
      widget.viewerId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final viewerId = _viewerId;
    if (viewerId == null) {
      return _UnavailableCircle(
        title: 'Sign in required',
        message: 'Please sign in again to open this family Circle.',
        onReturn: () => Navigator.maybePop(context),
      );
    }
    return StreamBuilder<FamilyGroup?>(
      key: ValueKey(_retryKey),
      stream: _service.watchGroupForUser(widget.group.id, viewerId),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasError) {
          return _UnavailableCircle(
            title: 'Circle could not be loaded',
            message: CircleErrorMapper.message(groupSnapshot.error!),
            actionLabel: 'Retry',
            onReturn: () => setState(() => _retryKey++),
          );
        }
        if (!groupSnapshot.hasData &&
            groupSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LightStateView(
              icon: Icons.sync_rounded,
              title: 'Loading Circle',
              message: 'Getting the latest Circle details…',
              busy: true,
            ),
          );
        }
        final group = groupSnapshot.data;
        if (group == null) {
          return _UnavailableCircle(
            title: 'Circle unavailable',
            message: 'This Circle was deleted, archived, or your access was removed.',
            onReturn: () => Navigator.maybePop(context),
          );
        }
        return _circle(context, group, viewerId);
      },
    );
  }

  Widget _circle(BuildContext context, FamilyGroup group, String viewerId) =>
      Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded),
              tooltip: 'SOS activity',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmergencyEventsScreen(
                    group: group,
                    currentUserName: 'You',
                  ),
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<List<CircleMembership>>(
          stream: _service.watchMemberships(group.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return LightStateView(
                icon: Icons.cloud_off_rounded,
                title: 'Members could not be loaded',
                message: CircleErrorMapper.message(snapshot.error!),
                actionLabel: 'Retry',
                onAction: () => setState(() => _retryKey++),
              );
            }
            if (!snapshot.hasData) {
              return const LightStateView(
                icon: Icons.sync_rounded,
                title: 'Loading members',
                message: 'Getting active Circle memberships…',
                busy: true,
              );
            }
            final members = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                LightCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          LightAvatar(name: group.name, radius: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.appHeading,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    LightStatusChip(label: group.role.value),
                                    LightStatusChip(
                                      label: '${members.length} members',
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (group.canManage)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShareCircleScreen(group: group),
                                  ),
                                ),
                                icon: const Icon(Icons.ios_share_rounded),
                                label: const Text('Invite'),
                              ),
                            ),
                          if (group.canManage) const SizedBox(width: 9),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupSettingsScreen(
                                    group: group,
                                    memberships: members,
                                    groupService: _service,
                                    viewerId: viewerId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.settings_rounded),
                              label: const Text('Settings'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const LightSectionTitle('Active members'),
                if (members.isEmpty)
                  const LightStateView(
                    icon: Icons.group_off_rounded,
                    title: 'No active members',
                    message: 'No active membership records are available.',
                  ),
                for (final member in members) ...[
                  LightCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: LightAvatar(name: member.displayName),
                      title: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${member.relationship} • ${member.role.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CircleMemberDetailScreen(
                            group: group,
                            initialMember: member,
                            viewerId: viewerId,
                            groupService: _service,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            );
          },
        ),
      );
}

class _UnavailableCircle extends StatelessWidget {
  const _UnavailableCircle({
    required this.title,
    required this.message,
    required this.onReturn,
    this.actionLabel = 'Return to Family Circles',
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Family Circle')),
    body: LightStateView(
      icon: Icons.group_off_rounded,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onReturn,
    ),
  );
}
