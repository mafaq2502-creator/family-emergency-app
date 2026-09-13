import 'package:flutter/material.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/circle_policies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/circle_membership.dart';
import '../../../models/family_group.dart';
import '../../../services/group_service.dart';
import '../../../services/device_service.dart';
import '../../devices/presentation/device_screens.dart';

class CircleMemberDetailScreen extends StatefulWidget {
  const CircleMemberDetailScreen({
    super.key,
    required this.group,
    required this.initialMember,
    required this.viewerId,
    this.groupService,
    this.deviceService,
  });
  final FamilyGroup group;
  final CircleMembership initialMember;
  final String viewerId;
  final GroupService? groupService;
  final DeviceActions? deviceService;

  @override
  State<CircleMemberDetailScreen> createState() =>
      _CircleMemberDetailScreenState();
}

class _CircleMemberDetailScreenState extends State<CircleMemberDetailScreen> {
  late final GroupService _service = widget.groupService ?? GroupService();
  bool _removing = false;

  Future<void> _remove(FamilyGroup group, CircleMembership member) async {
    if (_removing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        icon: const Icon(Icons.person_remove_rounded, color: kEmergency),
        title: const Text('Remove member?'),
        content: Text(
          'Remove ${member.displayName} from ${group.name}? Their registered account will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: kEmergency),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await _service.removeMember(group, member.userId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CircleErrorMapper.message(
              error,
              fallback: 'This member could not be removed. Please try again.',
            ),
          ),
          backgroundColor: kEmergency,
        ),
      );
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<FamilyGroup?>(
    stream: _service.watchGroupForUser(widget.group.id, widget.viewerId),
    builder: (context, groupSnapshot) {
      if (groupSnapshot.hasError) {
        return _state(
          'Member could not be loaded',
          CircleErrorMapper.message(groupSnapshot.error!),
        );
      }
      if (!groupSnapshot.hasData &&
          groupSnapshot.connectionState == ConnectionState.waiting) {
        return _loading();
      }
      final group = groupSnapshot.data;
      if (group == null) {
        return _state(
          'Circle access unavailable',
          'Your access was removed or this Circle is no longer active.',
        );
      }
      return StreamBuilder<CircleMembership?>(
        stream: _service.watchMembership(group.id, widget.initialMember.userId),
        builder: (context, memberSnapshot) {
          if (memberSnapshot.hasError) {
            return _state(
              'Member could not be loaded',
              CircleErrorMapper.message(memberSnapshot.error!),
            );
          }
          if (!memberSnapshot.hasData &&
              memberSnapshot.connectionState == ConnectionState.waiting) {
            return _loading();
          }
          final member = memberSnapshot.data;
          if (member == null) {
            return _state(
              'Member unavailable',
              'This person is no longer an active member of the Circle.',
            );
          }
          return _detail(group, member);
        },
      );
    },
  );

  Widget _detail(FamilyGroup group, CircleMembership member) {
    final canRemove = CirclePermissionPolicy.canRemove(
      actorRole: group.role,
      target: member,
      actorUserId: widget.viewerId,
    );
    return LightPage(
      title: 'Member Detail',
      subtitle: group.name,
      child: Column(
        children: [
          LightAvatar(name: member.displayName, radius: 42),
          const SizedBox(height: 12),
          Text(
            member.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appHeading,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              LightStatusChip(label: member.role.value),
              LightStatusChip(label: member.status.name, color: kEmerald),
            ],
          ),
          const SizedBox(height: 22),
          if (member.userId == widget.viewerId)
            LightSettingRow(
              icon: Icons.favorite_outline_rounded,
              title: 'Relationship',
              subtitle: member.relationship,
            ),
          const SizedBox(height: 9),
          if (member.userId == widget.viewerId)
            LightSettingRow(
              icon: Icons.mail_outline_rounded,
              title: 'Email',
              subtitle: member.email ?? 'Not shared',
            ),
          const SizedBox(height: 9),
          MemberDeviceSection(
            group: group,
            memberUserId: member.userId,
            memberName: member.displayName,
            viewerId: widget.viewerId,
            deviceService: widget.deviceService,
          ),
          const SizedBox(height: 9),
          const LightSettingRow(
            icon: Icons.query_stats_rounded,
            title: 'Progress',
            subtitle: 'Open Progress to view available shared activity and Screen Time data.',
          ),
          if (canRemove) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _removing ? null : () => _remove(group, member),
                icon: _removing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove_rounded),
                label: Text(_removing ? 'Removing…' : 'Remove Member'),
                style: ElevatedButton.styleFrom(backgroundColor: kEmergency),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loading() => const Scaffold(
    body: LightStateView(
      icon: Icons.sync_rounded,
      title: 'Loading member',
      message: 'Checking the latest membership and Circle access…',
      busy: true,
    ),
  );

  Widget _state(String title, String message) => Scaffold(
    appBar: AppBar(title: const Text('Member Detail')),
    body: LightStateView(
      icon: Icons.person_off_rounded,
      title: title,
      message: message,
      actionLabel: 'Go back',
      onAction: () => Navigator.maybePop(context),
    ),
  );
}
