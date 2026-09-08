part of '../family_shell.dart';

extension _ProfileTab on _HomeScreenState {
  Widget _buildProfileTab() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator(color: kEmerald));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your account information.',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kLightSuccessSurface,
                  child: Text(
                    _profileNameController.text.isEmpty
                        ? '?'
                        : _profileNameController.text[0].toUpperCase(),
                    style: const TextStyle(
                      color: kLightPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _profileRow(
              icon: Icons.manage_accounts_rounded,
              iconColor: kEmerald,
              label: 'Account Settings',
              value: 'Name, email, phone and relationship',
              isDark: isDark,
              onTap: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsScreen(
                      nameController: _profileNameController,
                      email: _profileEmail,
                      phone: _profilePhone,
                      relationship: _profileRole,
                      relationships: _HomeScreenState._roles,
                      onRelationshipChanged: _changeProfileRole,
                      onSave: _saveProfile,
                      saving: _isSavingProfile,
                    ),
                  ),
                );
                if (result == 'security') {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileSettingsScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFFF7A47),
              label: 'Current Plan',
              value: 'Free Plan',
              isDark: isDark,
              plan: true,
            ),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFF2563EB),
              label: 'Notification Settings',
              value: (_selectedGroup?.isOwner ?? false)
                  ? 'Personal & family owner controls'
                  : 'Personal notification preferences',
              isDark: isDark,
              onTap: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationSettingsScreen(
                      initialSettings: _notificationSettings,
                      isCircleOwner: _selectedGroup?.isOwner ?? false,
                    ),
                  ),
                );
                if (saved == true && context.mounted) _loadProfile();
              },
            ),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.manage_accounts_rounded,
              iconColor: const Color(0xFF7C3AED),
              label: 'Profile Settings',
              value: 'Password and account security',
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Theme',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            _themeSelector(
              isDark ? kDarkCard : Colors.white,
              titleColor,
              mutedColor,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kEmergency,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    Widget? editable,
    bool locked = false,
    bool plan = false,
    VoidCallback? onTap,
    double height = 54,
    bool showTrailing = true,
  }) {
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final row = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF233846) : kLightBorder,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                editable ??
                    Row(
                      children: [
                        if (plan)
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 12,
                            color: Color(0xFFFFAE00),
                          ),
                        if (plan) const SizedBox(width: 3),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 7),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              color: mutedColor,
              size: 19,
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: row,
          );
  }

  Widget _themeSelector(Color cardColor, Color enabledText, Color mutedText) {
    const choices = [
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: choices.map((choice) {
          final selected = appThemeMode.value == choice.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => appThemeMode.value = choice.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient:
                      selected &&
                          Theme.of(context).brightness == Brightness.light
                      ? kPrimaryGradient
                      : null,
                  color:
                      selected &&
                          Theme.of(context).brightness == Brightness.dark
                      ? kEmerald
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      choice.$3,
                      size: 19,
                      color: selected ? Colors.white : mutedText,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      choice.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : enabledText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
