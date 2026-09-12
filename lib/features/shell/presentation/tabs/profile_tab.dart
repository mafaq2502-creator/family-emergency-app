part of '../family_shell.dart';

extension _ProfileTab on _HomeScreenState {
  Widget _buildProfileTab() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator(color: kEmerald));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          _notificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              key: const Key('profile-read-only-avatar'),
              radius: 22,
              backgroundColor: context.appSuccessSurface,
              foregroundImage: ProfileImageData.provider(_profilePhotoUrl),
              child: Text(
                _profileNameController.text.isEmpty
                    ? '?'
                    : _profileNameController.text[0].toUpperCase(),
                style: TextStyle(
                  color: context.appPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your account information.',
                style: TextStyle(fontSize: 14, color: mutedColor),
              ),
              const SizedBox(height: 15),
              _profileRow(
                icon: Icons.verified_user_outlined,
                iconColor: kEmerald,
                label: 'Signed-in Account',
                value: _profileEmail.isEmpty ? 'Authenticated' : _profileEmail,
                isDark: isDark,
                showTrailing: false,
              ),
              const SizedBox(height: 7),
              _profileRow(
                icon: Icons.manage_accounts_rounded,
                iconColor: kEmerald,
                label: 'Account Settings',
                value: 'Personal information and address',
                isDark: isDark,
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountSettingsScreen(
                        initialName: _profileNameController.text,
                        email: _profileEmail,
                        initialPhotoUrl: _profilePhotoUrl,
                        initialAddress: _profileAddress,
                        onSaveAddress: _saveAccountAddress,
                        relationship: _profileRole,
                        relationships: _HomeScreenState._roles,
                        onSave: _saveAccountSettings,
                        onSavePhoto: _saveAccountPhoto,
                        onUpdatePassword: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileSettingsScreen(),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (result == true && mounted) _loadProfile();
                },
              ),
              const SizedBox(height: 7),
              _profileRow(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFFF7A47),
                label: 'Plans',
                value: 'Free Plan',
                isDark: isDark,
                plan: true,
                onTap: _openPlansFromProfile,
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
                icon: Icons.devices_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'My Devices',
                value: 'Registration, heartbeat and Circle pairing',
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceListScreen()),
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
              AppThemeModeSelector(
                mode: appThemeMode.value,
                onChanged: setAppThemeMode,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
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
    double height = 68,
    bool showTrailing = true,
  }) {
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final row = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    fontSize: 15,
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
                        Expanded(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1,
                              color: mutedColor,
                            ),
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
}
