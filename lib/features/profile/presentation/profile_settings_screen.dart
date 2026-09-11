import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../features/auth/domain/auth_error_mapper.dart';
import '../../../features/auth/domain/auth_validators.dart';
import '../../../services/account_security_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, this.securityService});
  final AccountSecurityActions? securityService;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final AccountSecurityActions _security =
      widget.securityService ?? AccountSecurityService();
  late Future<SecurityOverview> _overview = _security.loadOverview();

  void _reload() => setState(() => _overview = _security.loadOverview());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security')),
    body: FutureBuilder<SecurityOverview>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SecurityError(
            message: AuthErrorMapper.message(
              snapshot.error ?? StateError('Missing security state'),
              fallback: 'We could not load your security settings.',
            ),
            onRetry: _reload,
          );
        }
        return _SecurityContent(
          overview: snapshot.data!,
          security: _security,
          onRefresh: _reload,
        );
      },
    ),
  );
}

class _SecurityContent extends StatefulWidget {
  const _SecurityContent({
    required this.overview,
    required this.security,
    required this.onRefresh,
  });
  final SecurityOverview overview;
  final AccountSecurityActions security;
  final VoidCallback onRefresh;

  @override
  State<_SecurityContent> createState() => _SecurityContentState();
}

class _SecurityContentState extends State<_SecurityContent> {
  bool _sendingVerification = false;

  void _notice(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? kEmerald : kEmergency,
      ),
    );
  }

  Future<void> _sendVerification() async {
    if (_sendingVerification) return;
    setState(() => _sendingVerification = true);
    try {
      await widget.security.sendEmailVerification();
      if (mounted) _notice('Verification email sent.', success: true);
    } catch (error) {
      if (mounted) _notice(AuthErrorMapper.message(error));
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _SectionTitle('Account protection'),
          const SizedBox(height: 12),
          AppSurfaceCard(
            child: Column(
              children: [
                _SecurityRow(
                  icon: overview.emailVerified
                      ? Icons.verified_user_rounded
                      : Icons.mark_email_unread_rounded,
                  title: 'Email verification',
                  subtitle: overview.emailVerified
                      ? '${overview.email}\nVerified'
                      : '${overview.email}\nVerification required',
                  trailing: overview.emailVerified
                      ? const Icon(Icons.check_circle_rounded, color: kEmerald)
                      : TextButton(
                          onPressed: _sendingVerification
                              ? null
                              : _sendVerification,
                          child: Text(
                            _sendingVerification ? 'Sending…' : 'Send',
                          ),
                        ),
                ),
                if (overview.supportsPassword) ...[
                  const Divider(height: 1),
                  _SecurityRow(
                    icon: Icons.lock_reset_rounded,
                    title: 'Change password',
                    subtitle: 'Verify your current password first',
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UpdatePasswordScreen(
                            securityService: widget.security,
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        _notice('Password updated securely.', success: true);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SecurityRow(
                    icon: Icons.alternate_email_rounded,
                    title: 'Change email',
                    subtitle: 'The new address must be verified',
                    onTap: () async {
                      final requested = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeEmailScreen(
                            securityService: widget.security,
                            currentEmail: overview.email,
                          ),
                        ),
                      );
                      if (requested == true && context.mounted) {
                        widget.onRefresh();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          if (!overview.supportsPassword) ...[
            const SizedBox(height: 10),
            const Text(
              'Password changes are managed by your sign-in provider.',
              style: TextStyle(fontSize: 12, color: kLightMuted),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Current session'),
          const SizedBox(height: 12),
          AppSurfaceCard(
            child: _SecurityRow(
              icon: Icons.smartphone_rounded,
              title: 'This device',
              subtitle:
                  'Signed in ${_date(overview.lastSignInAt)}\nProviders: ${_providers(overview.providerIds)}',
              trailing: const Chip(label: Text('Current')),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Firebase does not provide this app with a list of other active sessions. Selective device logout is unavailable.',
            style: TextStyle(fontSize: 12, height: 1.4, color: kLightMuted),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Account'),
          const SizedBox(height: 12),
          AppSurfaceCard(
            child: Column(
              children: [
                _SecurityRow(
                  icon: Icons.calendar_month_rounded,
                  title: 'Account created',
                  subtitle: _date(overview.createdAt),
                ),
                const Divider(height: 1),
                _SecurityRow(
                  icon: Icons.delete_outline_rounded,
                  iconColor: kEmergency,
                  title: 'Delete account',
                  subtitle: 'Review dependencies and availability',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountDeletionPreparationScreen(
                        securityService: widget.security,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'Unavailable';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  static String _providers(List<String> values) => values
      .map(
        (value) => switch (value) {
          'password' => 'Email',
          'google.com' => 'Google',
          'apple.com' => 'Apple',
          _ => value,
        },
      )
      .join(', ');
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key, this.securityService});
  final AccountSecurityActions? securityService;

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  late final AccountSecurityActions _security =
      widget.securityService ?? AccountSecurityService();
  final _hidden = <bool>[true, true, true];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _security.changePassword(
        currentPassword: _current.text,
        newPassword: _newPassword.text,
      );
      _clearPasswords();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _clearPasswords(keepNew: true);
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearPasswords({bool keepNew = false}) {
    _current.clear();
    if (!keepNew) {
      _newPassword.clear();
      _confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Verify your current password before choosing a new one.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 24),
            _passwordField(
              'Current Password',
              _current,
              0,
              (value) => value == null || value.isEmpty
                  ? 'Enter your current password'
                  : null,
            ),
            const SizedBox(height: 18),
            _passwordField('New Password', _newPassword, 1, (value) {
              final validation = AuthValidators.password(value);
              if (validation != null) return validation;
              return value == _current.text
                  ? 'New password must be different'
                  : null;
            }),
            const SizedBox(height: 18),
            _passwordField(
              'Confirm New Password',
              _confirm,
              2,
              (value) =>
                  AuthValidators.confirmPassword(value, _newPassword.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: kEmergency)),
            ],
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: _busy ? 'Updating…' : 'Update Password',
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your current Firebase session remains signed in after a successful password update.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: kLightMuted),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _passwordField(
    String label,
    TextEditingController controller,
    int index,
    String? Function(String?) validator,
  ) => TextFormField(
    controller: controller,
    obscureText: _hidden[index],
    enabled: !_busy,
    autocorrect: false,
    enableSuggestions: false,
    autovalidateMode: AutovalidateMode.onUnfocus,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        onPressed: _busy
            ? null
            : () => setState(() => _hidden[index] = !_hidden[index]),
        icon: Icon(
          _hidden[index]
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({
    super.key,
    required this.securityService,
    required this.currentEmail,
  });
  final AccountSecurityActions securityService;
  final String currentEmail;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.securityService.requestEmailChange(
        currentPassword: _password.text,
        newEmail: _email.text,
      );
      _password.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: kEmerald),
          title: const Text('Check your new email'),
          content: const Text(
            'Firebase sent a verification link. Your current email stays active until the new address is verified.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _password.clear();
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Email')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Current email\n${widget.currentEmail}'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.newUsername],
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: AuthValidators.email,
              decoration: const InputDecoration(
                labelText: 'New Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your current password'
                  : null,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: kEmergency)),
            ],
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: _busy ? 'Sending…' : 'Send Verification Link',
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    ),
  );
}

class AccountDeletionPreparationScreen extends StatefulWidget {
  const AccountDeletionPreparationScreen({
    super.key,
    required this.securityService,
  });
  final AccountSecurityActions securityService;

  @override
  State<AccountDeletionPreparationScreen> createState() =>
      _AccountDeletionPreparationScreenState();
}

class _AccountDeletionPreparationScreenState
    extends State<AccountDeletionPreparationScreen> {
  late Future<AccountDeletionReadiness> _readiness = widget.securityService
      .inspectDeletionReadiness();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete Account')),
    body: FutureBuilder<AccountDeletionReadiness>(
      future: _readiness,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SecurityError(
            message: AuthErrorMapper.message(
              snapshot.error ?? StateError('Missing deletion state'),
              fallback: 'Could not check account dependencies.',
            ),
            onRetry: () => setState(
              () => _readiness = widget.securityService
                  .inspectDeletionReadiness(),
            ),
          );
        }
        final readiness = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              readiness.canRequestDeletion
                  ? Icons.admin_panel_settings_outlined
                  : Icons.warning_amber_rounded,
              size: 54,
              color: readiness.canRequestDeletion ? kEmerald : kEmergency,
            ),
            const SizedBox(height: 18),
            Text(
              readiness.canRequestDeletion
                  ? 'Secure deletion is being prepared'
                  : 'Resolve Circle ownership first',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (!readiness.canRequestDeletion) ...[
              const Text(
                'Deleting an owner could orphan family data. Delete or transfer these Circles first:',
              ),
              const SizedBox(height: 12),
              for (final name in readiness.ownedCircleNames)
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: Text(name),
                ),
            ] else
              const Text(
                'Hard deletion is disabled until a backend-owned cleanup transaction can remove memberships, pending requests, notifications, device/location records and the Firebase Auth identity together. No data has been deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45),
              ),
            const SizedBox(height: 18),
            const Text(
              'This protection prevents partial deletion and damage to other family members’ records.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kLightMuted),
            ),
          ],
        );
      },
    ),
  );
}

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = kEmerald,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    leading: CircleAvatar(
      backgroundColor: iconColor.withValues(alpha: .12),
      child: Icon(icon, color: iconColor),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
    onTap: onTap,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

class _SecurityError extends StatelessWidget {
  const _SecurityError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security_rounded, size: 48, color: kEmergency),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _friendlyError(Object error) {
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Check the entered details.';
  }
  if (error is FirebaseAuthException &&
      (error.code == 'wrong-password' || error.code == 'invalid-credential')) {
    return 'The current password is incorrect.';
  }
  if (error is FirebaseAuthException && error.code == 'email-already-in-use') {
    return 'This email change could not be completed.';
  }
  return AuthErrorMapper.message(
    error,
    fallback: 'The security change could not be completed. Please retry.',
  );
}
