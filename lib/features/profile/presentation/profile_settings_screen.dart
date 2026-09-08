import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/app_primary_button.dart';

const _emerald = kEmerald;
const _navy = kLightNavy;
const _danger = kEmergency;
const _darkBackground = kDarkBackground;
const _darkCard = kDarkCard;
const _darkMuted = kDarkMuted;

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _navy;
    final muted = isDark ? _darkMuted : kLightMuted;
    return Scaffold(
      backgroundColor: isDark ? _darkBackground : Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? _darkBackground : Colors.transparent,
        foregroundColor: titleColor,
        elevation: 0,
        title: const Text(
          'Profile Settings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Text(
            'Account security',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A10B981),
                child: Icon(Icons.lock_reset_rounded, color: _emerald),
              ),
              title: const Text(
                'Update Password',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Use a new password to protect your account.',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Text(
            'Danger zone',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _danger,
            ),
          ),
          const SizedBox(height: 8),
          _settingsCard(isDark, [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1AEF4444),
                child: Icon(Icons.delete_forever_rounded, color: _danger),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _danger,
                ),
              ),
              subtitle: const Text(
                'Verify your email before account deletion.',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: _danger),
              onTap: () => showDialog(
                context: context,
                builder: (_) => const _DeleteAccountFlow(),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Text(
            'Demo flow only: password update, email delivery, password history, and account deletion will be connected to Firebase/backend later.',
            style: TextStyle(fontSize: 11, height: 1.4, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(bool isDark, List<Widget> children) =>
      AppSurfaceCard(child: Column(children: children));
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _continueDemo() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password update flow verified. Firebase update will be connected later.',
        ),
        backgroundColor: _emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : _navy;
    final muted = isDark ? _darkMuted : kLightMuted;
    return Scaffold(
      backgroundColor: isDark ? _darkBackground : Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? _darkBackground : Colors.transparent,
        foregroundColor: titleColor,
        elevation: 0,
        title: const Text(
          'Update Password',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Create a strong new password',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your new password must be different from the current password and contain at least 8 characters.',
                style: TextStyle(fontSize: 12, height: 1.35, color: muted),
              ),
              const SizedBox(height: 24),
              _passwordField(
                'Current Password',
                _current,
                _hideCurrent,
                () => setState(() => _hideCurrent = !_hideCurrent),
                null,
              ),
              const SizedBox(height: 12),
              _passwordField(
                'New Password',
                _newPassword,
                _hideNew,
                () => setState(() => _hideNew = !_hideNew),
                (value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  if (value == _current.text) {
                    return 'New password must be different';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _passwordField(
                'Confirm New Password',
                _confirm,
                _hideConfirm,
                () => setState(() => _hideConfirm = !_hideConfirm),
                (value) => value != _newPassword.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Update Password',
                onPressed: _continueDemo,
              ),
              const SizedBox(height: 14),
              Text(
                'Password history enforcement will be added when the secure backend is connected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller,
    bool hidden,
    VoidCallback toggle,
    String? Function(String?)? validator,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? _darkMuted : kLightMuted;
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      validator:
          validator ??
          (value) => value == null || value.isEmpty
              ? 'Enter your current password'
              : null,
      style: TextStyle(color: isDark ? Colors.white : _navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: muted),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: muted),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: muted,
          ),
        ),
        filled: true,
        fillColor: isDark ? _darkCard : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF233846) : const Color(0xFFE7EDF0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _emerald),
        ),
      ),
    );
  }
}

class _DeleteAccountFlow extends StatefulWidget {
  const _DeleteAccountFlow();

  @override
  State<_DeleteAccountFlow> createState() => _DeleteAccountFlowState();
}

class _DeleteAccountFlowState extends State<_DeleteAccountFlow> {
  int _step = 0;
  final _code = TextEditingController();
  final _email =
      FirebaseAuth.instance.currentUser?.email ?? 'your email address';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _confirmEmailStep();
    if (_step == 1) return _codeStep();
    return _finalDeleteStep();
  }

  AlertDialog _dialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
    content: content,
    actions: actions,
  );

  Widget _confirmEmailStep() => _dialog(
    title: 'Verify your email',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'To continue deleting your account, verify this email address:',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _email,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A verification code will be sent after you press Verify.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () => setState(() => _step = 1),
        style: ElevatedButton.styleFrom(
          backgroundColor: _emerald,
          foregroundColor: Colors.white,
        ),
        child: const Text('Verify'),
      ),
    ],
  );

  Widget _codeStep() => _dialog(
    title: 'Enter verification code',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter the code sent to $_email.'),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
        ),
        const Text(
          'Demo-only test code: 123456',
          style: TextStyle(fontSize: 11, color: _danger),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() => _step = 0),
        child: const Text('Back'),
      ),
      ElevatedButton(
        onPressed: () {
          if (_code.text.trim() == '123456') {
            setState(() => _step = 2);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid verification code'),
                backgroundColor: _danger,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _emerald,
          foregroundColor: Colors.white,
        ),
        child: const Text('Verify'),
      ),
    ],
  );

  Widget _finalDeleteStep() => _dialog(
    title: 'Delete account?',
    content: const Text(
      'Your email is verified. This action will permanently delete your account and cannot be undone.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Deletion flow verified. Account deletion will be connected later.',
              ),
              backgroundColor: _danger,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _danger,
          foregroundColor: Colors.white,
        ),
        child: const Text('Delete Account'),
      ),
    ],
  );
}
