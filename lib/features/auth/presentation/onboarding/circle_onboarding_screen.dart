import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/domain/invite_code_policy.dart';
import '../../../../core/widgets/light_ui.dart';
import '../../../../models/circle_join_request.dart';
import '../../../../services/circle_join_service.dart';
import '../../../groups/presentation/qr_scanner_screen.dart';
import '../../domain/auth_error_mapper.dart';

class CircleOnboardingScreen extends StatefulWidget {
  const CircleOnboardingScreen({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.onCompleted,
    required this.onContinueWithoutCircle,
    this.joinService,
    this.pendingCircleId,
    this.initialInviteCode,
    this.onInviteHandled,
    this.profileName = '',
    this.profilePhone = '',
  });

  final User user;
  final Future<void> Function() onSignOut;
  final CircleJoinActions? joinService;
  final String? pendingCircleId;
  final String? initialInviteCode;
  final VoidCallback? onInviteHandled;
  final String profileName;
  final String profilePhone;
  final VoidCallback onCompleted;
  final Future<void> Function() onContinueWithoutCircle;

  @override
  State<CircleOnboardingScreen> createState() => _CircleOnboardingScreenState();
}

class _CircleOnboardingScreenState extends State<CircleOnboardingScreen> {
  late final _inviteCode = TextEditingController(
    text: widget.initialInviteCode,
  );
  late final CircleJoinActions _joinService =
      widget.joinService ?? CircleJoinService();
  bool _busy = false;
  String? _pendingCircleId;
  String? _pendingCircleName;

  @override
  void initState() {
    super.initState();
    _pendingCircleId = widget.pendingCircleId;
    if (widget.initialInviteCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInviteHandled?.call();
        _join();
      });
    }
  }

  @override
  void dispose() {
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    final validation = InviteCodePolicy.validate(_inviteCode.text);
    if (validation != null) {
      _showError(validation);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _joinService.joinWithCode(_inviteCode.text);
      if (!mounted) return;
      if (result.status == JoinSubmissionStatus.existingMember) {
        widget.onCompleted();
      } else {
        setState(() {
          _pendingCircleId = result.circleId;
          _pendingCircleName = result.circleName;
        });
      }
    } on FirebaseFunctionsException catch (error) {
      final message = switch (error.code) {
        'not-found' => 'This invitation code is not valid.',
        'failed-precondition' =>
          error.message ?? 'This invitation can no longer be used.',
        'already-exists' => 'You already belong to this Circle.',
        'permission-denied' => 'You cannot use this invitation.',
        'unauthenticated' => 'Your session expired. Please sign in again.',
        _ => 'We could not join the Circle. Please try again.',
      };
      _showError(message);
    } catch (error) {
      _showError(
        AuthErrorMapper.message(
          error,
          fallback: 'We could not join the Circle. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kEmergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final muted = isDark ? kDarkMuted : kLightMuted;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.diversity_1_rounded, color: kEmerald, size: 58),
              const SizedBox(height: 12),
              Text(
                'Join a Family Circle',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Join an existing Circle with a secure invitation. You can create your own Circle later from Family.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 22),
              if (widget.profileName.isNotEmpty ||
                  widget.profilePhone.isNotEmpty) ...[
                Text(
                  widget.profileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.profilePhone.isNotEmpty)
                  Text(widget.profilePhone, textAlign: TextAlign.center),
                const SizedBox(height: 18),
              ],
              Expanded(
                child: _joinPanel(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : widget.onContinueWithoutCircle,
                child: const Text('Continue to Family'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _joinPanel() => _pendingCircleId != null
      ? _pendingPanel()
      : Column(
          children: [
            const SizedBox(height: 8),
            const LightStateView(
              icon: Icons.link_rounded,
              title: 'Use a secure invitation',
              message: 'Open the shared invite link or scan its QR code. The Circle owner must still approve your request.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _scanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Invitation QR'),
              ),
            ),
          ],
        );

  Future<void> _scanQr() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code == null || !mounted) return;
    _inviteCode.text = code;
    await _join();
  }

  Widget _pendingPanel() {
    final service = _joinService;
    if (service is! CircleJoinService) {
      return const LightStateView(
        icon: Icons.hourglass_top_rounded,
        title: 'Awaiting approval',
        message: 'A Circle owner or parent must approve your join request.',
      );
    }
    return StreamBuilder<CircleJoinRequest?>(
      stream: service.watchMyRequest(_pendingCircleId!),
      builder: (context, snapshot) {
        final request = snapshot.data;
        if (request?.status == JoinRequestStatus.approved) {
          return LightStateView(
            icon: Icons.verified_rounded,
            title: 'Request approved',
            message:
                'You are now a member of ${_pendingCircleName ?? 'the Family Circle'}.',
            actionLabel: 'Continue',
            onAction: widget.onCompleted,
          );
        }
        if (request?.status == JoinRequestStatus.rejected ||
            request?.status == JoinRequestStatus.cancelled) {
          return LightStateView(
            icon: Icons.cancel_outlined,
            title: 'Request closed',
            message:
                'No membership was created. You may use another invitation.',
            actionLabel: 'Scan Another Invitation',
            onAction: () async {
              await service.clearPendingRequestReference();
              if (mounted) {
                setState(() {
                  _pendingCircleId = null;
                  _pendingCircleName = null;
                  _inviteCode.clear();
                });
              }
            },
          );
        }
        return LightStateView(
          icon: Icons.hourglass_top_rounded,
          title: 'Awaiting approval',
          message: 'A Circle owner or parent must approve your join request.',
          actionLabel: request?.isPending == true && !_busy
              ? 'Cancel Request'
              : null,
          onAction: request?.isPending == true && !_busy
              ? () async {
                  setState(() => _busy = true);
                  try {
                    await service.cancelRequest(request!);
                    if (mounted) {
                      setState(() {
                        _pendingCircleId = null;
                        _pendingCircleName = null;
                      });
                    }
                  } catch (error) {
                    _showError(
                      'The request could not be cancelled. Please retry.',
                    );
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              : null,
        );
      },
    );
  }

}
