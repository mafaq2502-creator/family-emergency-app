import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/invite_code_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/circle_invite.dart';
import '../../../models/family_group.dart';
import '../../../services/circle_join_service.dart';
import '../../../services/group_service.dart';

class ShareCircleScreen extends StatefulWidget {
  const ShareCircleScreen({super.key, required this.group, this.joinService});

  final FamilyGroup group;
  final CircleJoinService? joinService;

  @override
  State<ShareCircleScreen> createState() => _ShareCircleScreenState();
}

class _ShareCircleScreenState extends State<ShareCircleScreen> {
  late final CircleJoinService _service =
      widget.joinService ?? CircleJoinService();
  final GroupService _groupService = GroupService();
  CircleInvite? _invite;
  Timer? _expiryTimer;
  bool _busy = false;
  int _tab = 0;

  void _selectInvite(CircleInvite invite) {
    _expiryTimer?.cancel();
    final remaining = invite.expiresAt.difference(DateTime.now());
    if (remaining > Duration.zero &&
        invite.status == CircleInviteStatus.active) {
      _expiryTimer = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
    setState(() => _invite = invite);
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate({bool replace = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (replace && _invite?.status == CircleInviteStatus.active) {
        await _service.revokeInvite(_invite!);
      }
      final invite = await _service.createInvite(widget.group);
      if (mounted) _selectInvite(invite);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(CircleInvite invite) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Revoke invitation?'),
        content: const Text(
          'This code and QR will stop accepting new join requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.revokeInvite(invite);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label copied.')));
    }
  }

  Future<void> _share(CircleInvite invite) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Join ${widget.group.name}',
        text:
            'Join ${widget.group.name} in Family Emergency.\n'
            '${InviteCodePolicy.inviteUrl(invite.code)}',
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is CircleInviteException
        ? error.message
        : CircleErrorMapper.message(
            error,
            fallback: 'Invitation could not be updated. Please try again.',
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kEmergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? viewerId;
    try {
      viewerId = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      viewerId = widget.joinService == null ? null : widget.group.ownerId;
    }
    return LightPage(
      title: 'Invite Member',
      subtitle: widget.group.name,
      child: viewerId == null
          ? const LightStateView(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message: 'Please sign in again to manage invitations.',
            )
          : StreamBuilder<FamilyGroup?>(
              stream: widget.joinService != null
                  ? Stream.value(widget.group)
                  : _groupService.watchGroupForUser(
                      widget.group.id,
                      viewerId,
                    ),
              initialData: widget.group,
              builder: (context, groupSnapshot) {
                final group = groupSnapshot.data;
                if (group == null) {
                  return const LightStateView(
                    icon: Icons.group_off_rounded,
                    title: 'Circle unavailable',
                    message: 'This Circle is no longer active.',
                  );
                }
                return StreamBuilder<List<CircleInvite>>(
                  stream: _service.watchInvites(group.id),
                  builder: (context, inviteSnapshot) {
                    final invites = inviteSnapshot.data ?? const [];
                    final selected = invites
                            .where((item) => item.id == _invite?.id)
                            .firstOrNull ??
                        _invite;
                    final capacityInvites = selected != null &&
                            !invites.any((item) => item.id == selected.id)
                        ? [...invites, selected]
                        : invites;
                    return selected == null
                        ? _emptyState(group, invites)
                        : _inviteContent(group, selected, capacityInvites);
                  },
                );
              },
            ),
    );
  }

  bool _hasCapacity(FamilyGroup group, List<CircleInvite> invites) {
    final activeReservations = invites
        .where((invite) => invite.isUsable)
        .length;
    return group.memberCount + activeReservations < group.memberLimit;
  }

  Widget _capacity(FamilyGroup group, List<CircleInvite> invites) {
    final hasCapacity = _hasCapacity(group, invites);
    return Column(
      children: [
        Text('${group.memberCount} of ${group.memberLimit} members'),
        if (!hasCapacity)
          Text(
            group.isPremiumOwned
                ? 'Circle member limit reached.'
                : 'Free Plan member limit reached.',
            style: const TextStyle(color: kEmergency),
          ),
      ],
    );
  }

  Widget _emptyState(FamilyGroup group, List<CircleInvite> invites) => Column(
    children: [
      _capacity(group, invites),
      const SizedBox(height: 14),
      const LightStateView(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Create a secure invitation',
        message: 'The invitation expires in 7 days and every new member requires approval.',
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _busy || !_hasCapacity(group, invites) ? null : _generate,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.key_rounded),
          label: Text(_busy ? 'Generating…' : 'Generate Invitation'),
        ),
      ),
      if (invites.isNotEmpty) ...[
        const SizedBox(height: 22),
        const LightSectionTitle('Invitation history'),
        for (final invite in invites) ...[
          LightCard(
            padding: EdgeInsets.zero,
            onTap: () => _selectInvite(invite),
            child: ListTile(
              leading: Icon(
                invite.isUsable ? Icons.link_rounded : Icons.link_off_rounded,
                color: invite.isUsable ? kEmerald : kEmergency,
              ),
              title: Text(
                invite.circleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                invite.isUsable
                    ? 'Single-use invitation'
                    : invite.status.name,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ],
  );

  Widget _inviteContent(
    FamilyGroup group,
    CircleInvite invite,
    List<CircleInvite> invites,
  ) {
    final usable = invite.isUsable;
    final status = usable
        ? 'Active'
        : invite.status == CircleInviteStatus.revoked
        ? 'Revoked'
        : invite.status == CircleInviteStatus.consumed
        ? 'Consumed'
        : invite.status == CircleInviteStatus.exhausted
        ? 'Consumed'
        : 'Expired';
    return Column(
      children: [
        _capacity(group, invites),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Secure invitation',
                style: TextStyle(
                  color: context.appHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            LightStatusChip(
              label: status,
              color: usable ? kEmerald : kEmergency,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _tabs(),
        const SizedBox(height: 18),
        _tabContent(invite, usable),
        const SizedBox(height: 12),
        Text(
          'Expires ${MaterialLocalizations.of(context).formatMediumDate(invite.expiresAt.toLocal())} • '
          '${invite.useCount == 1 ? 'Used once' : 'Single-use invitation'}',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: usable && !_busy ? () => _share(invite) : null,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share Invitation'),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: usable && !_busy ? () => _revoke(invite) : null,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Revoke'),
            ),
            OutlinedButton.icon(
            onPressed: _busy || (!usable && !_hasCapacity(group, invites))
                ? null
                : () => _generate(replace: usable),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Generate New'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.appSurfaceMuted,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: ['QR Code', 'Share Link'].indexed.map((entry) {
        final selected = _tab == entry.$1;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _tab = entry.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: selected ? kPrimaryGradient : null,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.$2,
                maxLines: 1,
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
      }).toList(),
    ),
  );

  Widget _tabContent(CircleInvite invite, bool usable) {
    final payload = InviteCodePolicy.qrPayload(invite.code);
    if (_tab == 0) {
      return LightCard(
        child: Column(
          children: [
            Opacity(
              opacity: usable ? 1 : .28,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: payload,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              usable
                  ? 'Scan to preview this Circle and request approval.'
                  : 'This QR can no longer be used.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_tab == 1) {
      return LightCard(
        child: Column(
          children: [
            SelectableText(
              payload,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appHeading, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: usable ? () => _copy(payload, 'Invite link') : null,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Link'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
