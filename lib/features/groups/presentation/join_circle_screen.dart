import 'package:flutter/material.dart';

import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/invite_code_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_form_field.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/circle_invite.dart';
import '../../../models/circle_join_request.dart';
import '../../../services/circle_join_service.dart';
import 'qr_scanner_screen.dart';

class JoinCircleScreen extends StatefulWidget {
  const JoinCircleScreen({
    super.key,
    this.joinService,
    this.initialCode,
    this.pendingCircleId,
    this.onApproved,
  });

  final CircleJoinService? joinService;
  final String? initialCode;
  final String? pendingCircleId;
  final VoidCallback? onApproved;

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CircleJoinService _service =
      widget.joinService ?? CircleJoinService();
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  CircleInvite? _preview;
  JoinSubmissionResult? _submission;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code == null || !mounted) return;
    _code.text = code;
    await _validate();
  }

  Future<void> _validate() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final invite = await _service.validateInvite(_code.text);
      if (mounted) setState(() => _preview = invite);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _preview == null) return;
    setState(() => _busy = true);
    try {
      final result = await _service.submitJoinRequest(_preview!.code);
      if (!mounted) return;
      if (result.status == JoinSubmissionStatus.existingMember) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already a member of this Circle.'),
          ),
        );
        Navigator.pop(context, result.circleId);
      } else {
        setState(() => _submission = result);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is CircleInviteException
        ? error.message
        : CircleErrorMapper.message(
            error,
            fallback: 'The invitation could not be checked. Please try again.',
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kEmergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCircleId = _submission?.circleId ?? widget.pendingCircleId;
    return LightPage(
      title: 'Join Family Circle',
      subtitle: _submission?.circleName,
      child: pendingCircleId == null
          ? (_preview == null ? _codeEntry() : _previewCard(_preview!))
          : _pendingRequest(pendingCircleId),
    );
  }

  Widget _codeEntry() => Form(
    key: _formKey,
    child: Column(
      children: [
        const LightStateView(
          icon: Icons.mark_email_unread_outlined,
          title: 'Use a secure invitation',
          message: 'Enter the invitation code or scan its QR. You will review the Circle before requesting approval.',
        ),
        const SizedBox(height: 18),
        AppTextFormField(
          controller: _code,
          label: 'Invitation Code',
          placeholder: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
          prefixIcon: Icons.key_rounded,
          enabled: !_busy,
          validator: InviteCodePolicy.validate,
          onFieldSubmitted: (_) => _validate(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _validate,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_busy ? 'Checking…' : 'Check Invitation'),
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR Code'),
          ),
        ),
      ],
    ),
  );

  Widget _previewCard(CircleInvite invite) => Column(
    children: [
      LightCard(
        child: Column(
          children: [
            const Icon(Icons.groups_rounded, color: kEmerald, size: 48),
            const SizedBox(height: 10),
            Text(
              invite.circleName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appHeading,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Membership requires approval from a Circle owner or parent. This invitation expires '
              '${MaterialLocalizations.of(context).formatMediumDate(invite.expiresAt.toLocal())}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_busy ? 'Sending Request…' : 'Request to Join'),
        ),
      ),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _preview = null),
        child: const Text('Use a different code'),
      ),
    ],
  );

  Widget _pendingRequest(String circleId) => StreamBuilder<CircleJoinRequest?>(
    stream: _service.watchMyRequest(circleId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return LightStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load request',
          message: 'Check your connection and reopen this screen.',
          actionLabel: 'Retry',
          onAction: () => setState(() {}),
        );
      }
      final request = snapshot.data;
      if (request == null) {
        return const LightStateView(
          icon: Icons.hourglass_top_rounded,
          title: 'Awaiting approval',
          message: 'Your join request is being prepared.',
        );
      }
      return switch (request.status) {
        JoinRequestStatus.pending => LightStateView(
          icon: Icons.hourglass_top_rounded,
          title: 'Awaiting approval',
          message: 'A Circle owner or parent must approve your request before membership is created.',
          actionLabel: _busy ? null : 'Cancel Request',
          onAction: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await _service.cancelRequest(request);
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    _showError(error);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
        JoinRequestStatus.approved => LightStateView(
          icon: Icons.verified_rounded,
          title: 'Request approved',
          message: 'You are now an active member of this Family Circle.',
          actionLabel: 'Continue',
          onAction: widget.onApproved ?? () => Navigator.pop(context, circleId),
        ),
        JoinRequestStatus.rejected => LightStateView(
          icon: Icons.cancel_outlined,
          title: 'Request declined',
          message: 'No membership was created. You may use another invitation.',
          actionLabel: 'Enter Another Code',
          onAction: () async {
            await _service.clearPendingRequestReference();
            if (mounted) {
              setState(() {
                _submission = null;
                _preview = null;
              });
            }
          },
        ),
        _ => LightStateView(
          icon: Icons.info_outline_rounded,
          title: 'Request closed',
          message: 'This request is no longer active.',
          actionLabel: 'Enter Another Code',
          onAction: () => setState(() {
            _submission = null;
            _preview = null;
          }),
        ),
      };
    },
  );
}
