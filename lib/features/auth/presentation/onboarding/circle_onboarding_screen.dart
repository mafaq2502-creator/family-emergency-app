import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/domain/invite_code_policy.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../core/widgets/light_ui.dart';
import '../../../../models/circle_join_request.dart';
import '../../../../services/circle_join_service.dart';
import '../../../../services/group_service.dart';
import '../../../groups/presentation/qr_scanner_screen.dart';
import '../../../notifications/presentation/notification_bell_button.dart';
import '../../domain/auth_error_mapper.dart';
import '../../domain/auth_validators.dart';

class CircleOnboardingScreen extends StatefulWidget {
  const CircleOnboardingScreen({
    super.key,
    required this.user,
    required this.groupService,
    required this.onSignOut,
    required this.onCompleted,
    this.joinService,
    this.pendingCircleId,
    this.initialInviteCode,
    this.onInviteHandled,
    this.profileName = '',
    this.profilePhone = '',
  });

  final User user;
  final GroupService groupService;
  final Future<void> Function() onSignOut;
  final CircleJoinActions? joinService;
  final String? pendingCircleId;
  final String? initialInviteCode;
  final VoidCallback? onInviteHandled;
  final String profileName;
  final String profilePhone;
  final VoidCallback onCompleted;

  @override
  State<CircleOnboardingScreen> createState() => _CircleOnboardingScreenState();
}

class _CircleOnboardingScreenState extends State<CircleOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _createForm = GlobalKey<FormState>();
  final _circleName = TextEditingController();
  late final _inviteCode = TextEditingController(
    text: widget.initialInviteCode,
  );
  late final CircleJoinActions _joinService =
      widget.joinService ?? CircleJoinService();
  bool _busy = false;
  late final TabController _tabController;
  final List<bool> _tabHasValidationError = [false, false];
  String? _pendingCircleId;
  String? _pendingCircleName;

  @override
  void initState() {
    super.initState();
    _pendingCircleId = widget.pendingCircleId;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialInviteCode == null ? 0 : 1,
    );
    if (widget.initialInviteCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInviteHandled?.call();
        _join();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _circleName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final valid = _createForm.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _tabHasValidationError[0] = true);
      _tabController.animateTo(0);
      return;
    }
    if (_tabHasValidationError[0]) {
      setState(() => _tabHasValidationError[0] = false);
    }
    setState(() => _busy = true);
    try {
      await widget.groupService.createGroup(
        widget.user,
        _circleName.text.trim(),
      );
      if (mounted) widget.onCompleted();
    } catch (error) {
      _showError(
        AuthErrorMapper.message(
          error,
          fallback: 'We could not create your Circle. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_busy) return;
    final validation = InviteCodePolicy.validate(_inviteCode.text);
    if (validation != null) {
      setState(() => _tabHasValidationError[1] = true);
      _tabController.animateTo(1);
      _showError(validation);
      return;
    }
    if (_tabHasValidationError[1]) {
      setState(() => _tabHasValidationError[1] = false);
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
          const NotificationBellButton(),
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
                'Set Up Your Family Circle',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Create a new Circle or join one with a secure invitation.',
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
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF233846) : kLightBorder,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: kEmerald, width: 3),
                    insets: EdgeInsets.symmetric(horizontal: 22),
                  ),
                  labelColor: kEmerald,
                  unselectedLabelColor: muted,
                  labelStyle: const TextStyle(
                    fontSize: AppTypography.tabLabel,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: AppTypography.tabLabel,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    _onboardingTab('Create Circle', 0),
                    _onboardingTab('Join Circle', 1),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_createPanel(), _joinPanel()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboardingTab(String label, int index) => Tab(
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (_tabHasValidationError[index])
          Positioned(
            right: -4,
            top: 4,
            child: DecoratedBox(
              key: ValueKey('circle-tab-error-$index'),
              decoration: const BoxDecoration(
                color: kEmergency,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 7, height: 7),
            ),
          ),
      ],
    ),
  );

  Widget _createPanel() => Form(
    key: _createForm,
    child: Column(
      children: [
        const SizedBox(height: 8),
        AppTextFormField(
          controller: _circleName,
          label: 'Family Circle Name',
          placeholder: 'Example: Khan Family',
          prefixIcon: Icons.groups_rounded,
          enabled: !_busy,
          validator: AuthValidators.circleName,
          onFieldSubmitted: (_) => _create(),
        ),
        const SizedBox(height: 18),
        _actionButton('Create Family Circle', _create),
      ],
    ),
  );

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

  Widget _actionButton(String label, VoidCallback action) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _busy ? null : action,
      style: ElevatedButton.styleFrom(
        backgroundColor: kEmerald,
        foregroundColor: Colors.white,
      ),
      child: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}
