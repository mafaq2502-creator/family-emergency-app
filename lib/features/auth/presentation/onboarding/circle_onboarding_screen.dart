import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_form_field.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/circle_join_service.dart';
import '../../../../services/group_service.dart';
import '../../domain/auth_error_mapper.dart';
import '../../domain/auth_validators.dart';

class CircleOnboardingScreen extends StatefulWidget {
  const CircleOnboardingScreen({
    super.key,
    required this.user,
    required this.groupService,
    required this.authService,
    required this.onCompleted,
    this.joinService,
  });

  final User user;
  final GroupService groupService;
  final AuthService authService;
  final CircleJoinActions? joinService;
  final VoidCallback onCompleted;

  @override
  State<CircleOnboardingScreen> createState() => _CircleOnboardingScreenState();
}

class _CircleOnboardingScreenState extends State<CircleOnboardingScreen> {
  final _createForm = GlobalKey<FormState>();
  final _joinForm = GlobalKey<FormState>();
  final _circleName = TextEditingController();
  final _inviteCode = TextEditingController();
  late final CircleJoinActions _joinService =
      widget.joinService ?? CircleJoinService();
  bool _busy = false;

  @override
  void dispose() {
    _circleName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !_createForm.currentState!.validate()) return;
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
    if (_busy || !_joinForm.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _joinService.joinWithCode(_inviteCode.text);
      if (mounted) widget.onCompleted();
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _busy ? null : widget.authService.signOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.diversity_1_rounded,
                  color: kEmerald,
                  size: 58,
                ),
                const SizedBox(height: 12),
                Text(
                  'Set Up Your Family Circle',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Create a new Circle or join one with a secure invitation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 22),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TabBar(
                    indicatorColor: kEmerald,
                    labelColor: kEmerald,
                    tabs: [
                      Tab(text: 'Create Circle'),
                      Tab(text: 'Join Circle'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: TabBarView(children: [_createPanel(), _joinPanel()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createPanel() => Form(
    key: _createForm,
    autovalidateMode: AutovalidateMode.onUserInteraction,
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

  Widget _joinPanel() => Form(
    key: _joinForm,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      children: [
        const SizedBox(height: 8),
        AppTextFormField(
          controller: _inviteCode,
          label: 'Invitation Code',
          placeholder: 'Enter your 6–12 character code',
          prefixIcon: Icons.key_rounded,
          enabled: !_busy,
          validator: AuthValidators.inviteCode,
          onFieldSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 18),
        _actionButton('Join Family Circle', _join),
      ],
    ),
  );

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
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}
