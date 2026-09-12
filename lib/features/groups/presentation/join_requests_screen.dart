import 'package:flutter/material.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/circle_join_request.dart';
import '../../../models/family_group.dart';
import '../../../services/circle_join_service.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.group, this.joinService});

  final FamilyGroup group;
  final CircleJoinService? joinService;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late final CircleJoinService _service =
      widget.joinService ?? CircleJoinService();
  final Set<String> _busyRequests = {};

  Future<void> _review(CircleJoinRequest request, bool approve) async {
    if (_busyRequests.contains(request.userUid)) return;
    final verb = approve ? 'Approve' : 'Reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text('$verb join request?'),
        content: Text(
          approve
              ? '${request.displayName} will become an active Circle member.'
              : '${request.displayName} will not be added to this Circle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: approve
                ? null
                : FilledButton.styleFrom(backgroundColor: kEmergency),
            child: Text(verb),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyRequests.add(request.userUid));
    try {
      await _service.reviewRequest(widget.group, request, approve: approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Join request approved.' : 'Join request rejected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is CircleInviteException
            ? error.message
            : CircleErrorMapper.message(
                error,
                fallback: 'The request could not be reviewed. Please retry.',
              );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: kEmergency),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.userUid));
    }
  }

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Join Requests',
    subtitle: widget.group.name,
    child: !widget.group.canManage
        ? const LightStateView(
            icon: Icons.lock_outline_rounded,
            title: 'Manager access required',
            message: 'Only a Circle owner or parent can review join requests.',
          )
        : StreamBuilder<List<CircleJoinRequest>>(
            stream: _service.watchPendingRequests(widget.group.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return LightStateView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Requests unavailable',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data!;
              if (requests.isEmpty) {
                return const LightStateView(
                  icon: Icons.mark_email_read_outlined,
                  title: 'No pending requests',
                  message: 'New requests made with an active invitation appear here.',
                );
              }
              return Column(
                children: [
                  for (final request in requests) ...[
                    _requestCard(request),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
  );

  Widget _requestCard(CircleJoinRequest request) {
    final busy = _busyRequests.contains(request.userUid);
    return LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LightAvatar(name: request.displayName),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appHeading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${request.relationship} • ${request.role.value}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.appMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _review(request, false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : () => _review(request, true),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
