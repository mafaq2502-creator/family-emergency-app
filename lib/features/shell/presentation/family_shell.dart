import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/circle_policies.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../core/widgets/app_theme_mode_selector.dart';
import '../../../models/family_member.dart';
import '../../../models/family_group.dart';
import '../../../models/circle_role.dart';
import '../../../models/app_notification.dart';
import '../../../services/profile_service.dart';
import '../../../services/family_member_service.dart';
import '../../../services/group_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/app_notification_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_heartbeat_controller.dart';
import '../../devices/presentation/device_screens.dart';
import '../../members/presentation/member_profile_screen.dart';
import '../../groups/presentation/group_settings_screen.dart';
import '../../groups/presentation/group_members_screen.dart';
import '../../groups/presentation/join_circle_screen.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
import '../../notifications/presentation/notification_banner.dart';
import '../../profile/presentation/profile_settings_screen.dart';
import '../../profile/presentation/account_settings_screen.dart';
import '../../progress/presentation/progress_detail_screens.dart';
import 'tabs/plan_tab.dart';

part 'tabs/home_tab.dart';
part 'tabs/members_tab.dart';
part 'tabs/location_tab.dart';
part 'tabs/profile_tab.dart';

// ====================== HOME SCREEN ======================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  bool _isCountingDown = false;
  int _countdown = 3;
  bool _alertSent = false;
  Timer? _timer;
  Timer? _groupRetryTimer;
  bool _groupLoadErrorShown = false;
  bool _isCreatingGroup = false;
  bool _showOwnedCircles = true;
  String _progressPeriod = 'Today';
  String? _progressMemberId;

  void _selectProgressGroup(FamilyGroup? group) {
    setState(() {
      _selectedGroup = group;
      _progressMemberId = null;
    });
    _watchMembers();
  }

  void _selectProgressMember(String? id) =>
      setState(() => _progressMemberId = id);
  void _selectProgressPeriod(String period) =>
      setState(() => _progressPeriod = period);
  void _openPlanTab() => setState(() => _currentIndex = 3);

  void _setCircleScope(bool owned) {
    setState(() => _showOwnedCircles = owned);
  }

  final _profileNameController = TextEditingController();
  String? _profileRole;
  String _initialProfileName = '';
  String? _initialProfileRole;
  String _profileEmail = '';
  String? _profilePhotoUrl;
  Map<String, String> _profileAddress = {};
  String? _pendingJoinCircleId;
  bool _isProfileLoading = true;
  bool _isSavingProfile = false;
  bool _isProfileDirty = false;
  DateTime? _lastDailyCheckIn;
  bool _isMarkingAlive = false;
  String _deviceTimeZone = 'UTC';
  Map<String, dynamic> _notificationSettings = {};
  final ProfileService _profileService = ProfileService();
  final FamilyMemberService _memberService = FamilyMemberService();
  final GroupService _groupService = GroupService();
  final EmergencyService _emergencyService = EmergencyService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();
  final DeviceHeartbeatController _deviceHeartbeat =
      DeviceHeartbeatController();
  List<FamilyGroup> _groups = const [];
  FamilyGroup? _selectedGroup;
  StreamSubscription<List<FamilyGroup>>? _groupsSubscription;
  StreamSubscription<List<FamilyMember>>? _membersSubscription;

  static const List<String> _roles = [
    'Self',
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Husband',
    'Wife',
    'Grandfather',
    'Grandmother',
    'Grandson',
    'Granddaughter',
    'Brother',
    'Sister',
  ];

  List<FamilyMember> familyMembers = const [];

  @override
  void initState() {
    super.initState();
    _profileNameController.addListener(_updateProfileDirtyState);
    _loadDeviceTimeZone();
    _loadProfile();
    _watchMembers();
    _prepareGroups();
    unawaited(
      _deviceHeartbeat.start(
        onCurrentDeviceRevoked: () => AuthService().signOut(),
      ),
    );
  }

  Future<void> _prepareGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _watchGroups();
  }

  void _watchGroups() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupService
        .watchGroups(user)
        .listen(
          (groups) {
            if (!mounted) return;
            _groupRetryTimer?.cancel();
            _groupLoadErrorShown = false;
            setState(() {
              _groups = groups;
              final currentId = _selectedGroup?.id;
              _selectedGroup =
                  groups
                      .where((group) => group.id == currentId)
                      .cast<FamilyGroup?>()
                      .firstOrNull ??
                  (groups.isEmpty ? null : groups.first);
            });
            _watchMembers();
          },
          onError: (_) {
            if (!mounted) return;
            if (!_groupLoadErrorShown) {
              _groupLoadErrorShown = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not sync groups. Retrying…'),
                  backgroundColor: kEmergency,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            _groupRetryTimer?.cancel();
            _groupRetryTimer = Timer(const Duration(seconds: 3), _watchGroups);
          },
        );
  }

  Future<void> _createGroup() async {
    if (_isCreatingGroup) return;
    setState(() => _isCreatingGroup = true);
    final controller = TextEditingController();
    try {
      final formKey = GlobalKey<FormState>();
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create Circle'),
          content: Form(
            key: formKey,
            child: TextFormField(
              autovalidateMode: AutovalidateMode.onUnfocus,
              controller: controller,
              autofocus: true,
              maxLength: CircleNamePolicy.maxLength,
              validator: CircleNamePolicy.validate,
              decoration: const InputDecoration(labelText: 'Circle name'),
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(
                    dialogContext,
                    CircleNamePolicy.normalize(controller.text),
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(
                    dialogContext,
                    CircleNamePolicy.normalize(controller.text),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (name == null || !mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final groupId = await _groupService.createGroup(user, name);
      if (!mounted) return;
      final createdGroup = FamilyGroup(
        id: groupId,
        name: name,
        ownerId: user.uid,
        role: CircleRole.owner,
        emergencyRecipientIds: [user.uid],
        memberIds: [user.uid],
      );
      setState(() {
        _groups = [
          ..._groups.where((group) => group.id != groupId),
          createdGroup,
        ];
        _selectedGroup = createdGroup;
        familyMembers = const [];
      });
      _watchMembers();
      _watchGroups();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name created.'), backgroundColor: kEmerald),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CircleErrorMapper.message(
                error,
                fallback:
                    'Could not create the family Circle. Please try again.',
              ),
            ),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _isCreatingGroup = false);
    }
  }

  void _openGroupSettings() {
    final group = _selectedGroup;
    if (group == null || !group.canManage) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: group)),
    );
  }

  void _openGroupHome(FamilyGroup group) {
    setState(() => _selectedGroup = group);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupMembersScreen(group: group)),
    );
  }

  Widget _notificationBell() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    return StreamBuilder<List<AppNotification>>(
      stream: _appNotificationService.watch(user),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? [])
            .where((item) => !item.isRead)
            .length;
        return IconButton(
          onPressed: () =>
              showNotificationBanner(context, user, groups: _groups),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: kEmerald,
            ),
          ),
        );
      },
    );
  }

  void _watchMembers() {
    final group = _selectedGroup;
    _membersSubscription?.cancel();
    if (group == null) {
      if (mounted) setState(() => familyMembers = const []);
      return;
    }
    _membersSubscription = _memberService.watchGroupMembers(group.id).listen((
      members,
    ) {
      if (mounted) setState(() => familyMembers = members);
    }, onError: (_) {});
  }

  Future<void> _loadDeviceTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      if (mounted) setState(() => _deviceTimeZone = timezone.identifier);
    } catch (_) {
      if (mounted) {
        setState(() => _deviceTimeZone = DateTime.now().timeZoneName);
      }
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isProfileLoading = false);
      return;
    }
    try {
      await _profileService.syncCanonicalIdentity(user);
      final profile = await _profileService.load(user);
      if (!mounted) return;
      setState(() {
        _initialProfileName = profile.name;
        _profileRole = profile.relationship;
        _initialProfileRole = _profileRole;
        _profileNameController.text = _initialProfileName;
        _profileEmail = profile.email;
        _profilePhotoUrl = profile.photoUrl;
        _profileAddress = profile.address;
        _pendingJoinCircleId = profile.pendingJoinCircleId;
        _lastDailyCheckIn = profile.lastDailyCheckIn;
        _notificationSettings = profile.notificationSettings.toMap();
        _isProfileLoading = false;
        _isProfileDirty = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _profileEmail = user.email ?? '';
          _isProfileLoading = false;
        });
      }
    }
  }

  void _updateProfileDirtyState() {
    final changed =
        _profileNameController.text.trim() != _initialProfileName ||
        _profileRole != _initialProfileRole;
    if (mounted && changed != _isProfileDirty) {
      setState(() => _isProfileDirty = changed);
    }
  }

  Future<void> _saveProfile() async {
    if (!_isProfileDirty || _isSavingProfile) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSavingProfile = true);
    try {
      await _profileService.saveBasicProfile(
        user,
        name: _profileNameController.text.trim(),
        relationship: _profileRole,
      );
      if (!mounted) return;
      setState(() {
        _initialProfileName = _profileNameController.text.trim();
        _initialProfileRole = _profileRole;
        _isProfileDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save profile. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<bool> _saveAccountAddress(Map<String, String> address) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await _profileService.saveAddress(user, address);
    if (mounted) setState(() => _profileAddress = Map.of(address));
    return true;
  }

  Future<bool> _saveAccountSettings(String name, String? relationship) async {
    _profileNameController.text = name;
    _profileRole = relationship;
    _updateProfileDirtyState();
    await _saveProfile();
    return !_isProfileDirty;
  }

  Future<bool> _confirmProfileExit() async {
    if (!_isProfileDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('You have unsaved profile changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveProfile();
              if (dialogContext.mounted && !_isProfileDirty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _startSOS() async {
    if (_isCountingDown || _alertSent) return;
    final group = _selectedGroup;
    if (group == null || group.emergencyRecipientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure emergency recipients in Group Settings first.',
          ),
          backgroundColor: kEmergency,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: kEmergency.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sos_rounded, color: kEmergency, size: 32),
        ),
        title: const Text('Send Emergency Alert?'),
        content: Text(
          'This will alert the selected recipients in ${group.name}.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('Send SOS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmergency,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isCountingDown = true;
      _countdown = 3;
      _alertSent = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          _isCountingDown = false;
          _sendEmergency(group);
        }
      });
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: kEmergency, size: 34),
        title: const Text('Logout Confirmation'),
        content: const Text(
          'Are you sure you want to log out?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmergency,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService().signOut();
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _membersSubscription?.cancel();
    _timer?.cancel();
    _groupRetryTimer?.cancel();
    unawaited(_deviceHeartbeat.dispose());
    _profileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _currentIndex != 4 || !_isProfileDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _currentIndex != 4 || !_isProfileDirty) return;
        final canLeave = await _confirmProfileExit();
        if (!mounted || !canLeave) return;
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildFamilyTab(),
            _buildLocationTab(),
            _buildHomeTab(),
            const PlanSelectionContent(),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: _buildNavigationBar(),
      ),
    );
  }

  Future<void> _sendEmergency(FamilyGroup group) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _emergencyService.create(
        groupId: group.id,
        sender: user,
        senderName: _profileNameController.text.trim().isEmpty
            ? 'A group member'
            : _profileNameController.text.trim(),
        recipientIds: group.emergencyRecipientIds,
      );
      if (!mounted) return;
      setState(() => _alertSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SOS sent to ${group.name} emergency recipients.'),
          backgroundColor: kEmergency,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send SOS. Please try again.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    }
  }

  void _removeFamilyMember(int index) {
    final member = familyMembers[index];
    final group = _selectedGroup;
    if (member.id == null || group == null || !group.canManage) {
      setState(() => familyMembers.removeAt(index));
      return;
    }
    _memberService.deleteInGroup(group.id, member.id!).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove member.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    });
  }

  Future<void> _confirmRemoveFamilyMember(int index) async {
    final member = familyMembers[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_remove_rounded, color: kEmergency),
        title: const Text('Remove member?'),
        content: Text(
          'Remove ${member.name} from ${_selectedGroup?.name ?? 'this Circle'}? This does not delete their registered account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmergency,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) _removeFamilyMember(index);
  }

  Future<void> _updateFamilyMember(FamilyMember member) async {
    final group = _selectedGroup;
    if (group == null || member.id == null || !group.canManage) return;
    await _memberService.updateInGroup(group.id, member);
  }

  Future<void> _openMemberProfile(FamilyMember member, int index) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberProfileScreen(
            member: member,
            onDelete: () => _confirmRemoveFamilyMember(index),
            onSave: _updateFamilyMember,
          ),
        ),
      );

  bool get _checkedInToday {
    final checkIn = _lastDailyCheckIn;
    if (checkIn == null) return false;
    final now = DateTime.now();
    return checkIn.year == now.year &&
        checkIn.month == now.month &&
        checkIn.day == now.day;
  }

  Future<void> _markAlive() async {
    if (_checkedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're already checked in for today."),
          backgroundColor: kEmerald,
        ),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to check in.'),
          backgroundColor: kEmergency,
        ),
      );
      return;
    }

    setState(() => _isMarkingAlive = true);
    final now = DateTime.now();
    try {
      await _profileService.recordDailyCheckIn(
        user,
        timeZone: _deviceTimeZone,
        localDate:
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      setState(() => _lastDailyCheckIn = now);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Today's check-in is confirmed. Stay safe!"),
          backgroundColor: kEmerald,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save today\'s check-in. Please try again.',
            ),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAlive = false);
    }
  }

  Widget _buildNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const items = [
      (Icons.bar_chart_rounded, 'Progress', 1),
      (Icons.groups_rounded, 'Family', 0),
      (Icons.workspace_premium_rounded, 'Plan', 3),
      (Icons.person_rounded, 'Profile', 4),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: PhysicalShape(
                clipper: const _WaveNavigationClipper(),
                color: isDark ? kDarkSurface : kLightSurface,
                elevation: 10,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      for (final item in items.take(2))
                        _navItem(item.$1, item.$2, item.$3),
                      const Spacer(flex: 2),
                      for (final item in items.skip(2))
                        _navItem(item.$1, item.$2, item.$3),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -8,
              child: InkResponse(
                onTap: () => setState(() => _currentIndex = 2),
                radius: 40,
                hoverColor: (isDark ? kEmerald : kLightAccent).withValues(
                  alpha: .14,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [kLightAccent, kLightPrimary],
                              ),
                        color: isDark ? kEmerald : null,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? kDarkBackground : kLightBackground,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? kEmerald : kLightAccent)
                                .withValues(alpha: .28),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Home',
                      style: TextStyle(
                        color: _currentIndex == 2
                            ? (isDark ? kEmerald : kLightPrimary)
                            : (isDark ? Colors.grey : kLightMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? kEmerald : kLightPrimary;
    final inactiveColor = isDark ? Colors.grey : kLightMuted;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        hoverColor: activeColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? activeColor : inactiveColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= LOCATION TAB =================
  /* Legacy tab implementations archived during the incremental split.
  Widget _legacyBuildLocationTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 4),
            Text('View your family members on map.', style: TextStyle(fontSize: 12, color: mutedColor)),
            const Spacer(),
            Center(child: _legacyLocationEmptyArtwork(isDark)),
            const SizedBox(height: 25),
            Center(child: Text('Location map will be available soon.', style: TextStyle(fontSize: 12, color: mutedColor))),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _legacyLocationEmptyArtwork(bool isDark) => SizedBox(
        width: 195,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 2, child: Transform.rotate(angle: -.18, child: Container(width: 150, height: 72, decoration: BoxDecoration(color: const Color(0xFFBDECEE), borderRadius: BorderRadius.circular(8))))),
            Positioned(bottom: 21, child: Transform.rotate(angle: -.18, child: Container(width: 156, height: 3, color: Colors.white70))),
            Positioned(bottom: 40, child: Transform.rotate(angle: -.18, child: Container(width: 156, height: 3, color: Colors.white70))),
            const Positioned(left: 30, bottom: 38, child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 32)),
            const Positioned(right: 25, bottom: 20, child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 36)),
            const Positioned(right: 25, top: 43, child: Icon(Icons.cloud_rounded, color: Color(0xFFDCECF8), size: 44)),
            Container(
              width: 67,
              height: 76,
              decoration: const BoxDecoration(color: kEmerald, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 43),
            ),
          ],
        ),
      );

  Widget _legacyBuildPlanTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Your Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 4),
            Text('Get more features to keep your family\nextra safe.', style: TextStyle(fontSize: 12, color: mutedColor)),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _legacyPlanCard(title: 'Free', subtitle: 'Basic features for\nsmall families.', price: '\$0', features: const ['Up to 5 members', 'Basic alerts', 'Location tracking'], selected: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _legacyPlanCard(title: 'Premium', subtitle: 'Advanced features\nfor complete safety.', price: '\$4.99', features: const ['Unlimited members', 'Real-time alerts', 'Location history', 'Priority support'])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyPlanCard({required String title, required String subtitle, required String price, required List<String> features, bool selected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE9EDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: selected ? const Color(0xFFEAF4FF) : const Color(0xFFFFF4D9), shape: BoxShape.circle), child: Icon(selected ? Icons.send_rounded : Icons.workspace_premium_rounded, color: selected ? const Color(0xFF2586F6) : const Color(0xFFFFAE00), size: 23)),
          const SizedBox(height: 8),
          Text('$title Plan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kNavy)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, height: 1.12, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
          const SizedBox(height: 10),
          RichText(text: TextSpan(children: [TextSpan(text: price, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kNavy)), TextSpan(text: ' / month', style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF52647B)))])),
          const SizedBox(height: 10),
          for (final feature in features) Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check, size: 15, color: kEmerald), const SizedBox(width: 4), Expanded(child: Text(feature, style: TextStyle(fontSize: 9.5, height: 1.1, color: isDark ? Colors.white70 : const Color(0xFF314761))))]),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 35,
            child: ElevatedButton(
              onPressed: selected ? null : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium upgrade will be available soon.'))),
              style: ElevatedButton.styleFrom(backgroundColor: selected ? const Color(0xFFF1F3F4) : kEmerald, foregroundColor: selected ? const Color(0xFF64748B) : Colors.white, disabledBackgroundColor: const Color(0xFFF1F3F4), disabledForegroundColor: const Color(0xFF64748B), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              child: Text(selected ? 'Current Plan' : 'Upgrade Now', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PROFILE TAB =================
  Widget _legacyBuildProfileTab() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator(color: kEmerald));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('My Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 4), Text('Manage your account information.', style: TextStyle(fontSize: 12, color: mutedColor))])),
                TextButton(
                  onPressed: _isProfileDirty && !_isSavingProfile ? _saveProfile : null,
                  child: _isSavingProfile
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kEmerald, strokeWidth: 2))
                      : Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: _isProfileDirty ? kEmerald : mutedColor)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _legacyProfileRow(icon: Icons.person_rounded, iconColor: const Color(0xFF778BA0), label: 'User Name', value: _profileNameController.text, isDark: isDark, editable: TextField(controller: _profileNameController, style: TextStyle(fontSize: 11, color: mutedColor), decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero))),
            const SizedBox(height: 7),
            _profileRow(icon: Icons.mail_rounded, iconColor: const Color(0xFF778BA0), label: 'Email', value: _profileEmail.isEmpty ? 'Not available' : _profileEmail, isDark: isDark, locked: true),
            const SizedBox(height: 7),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFD95B69),
              label: 'Relationship',
              value: _profileRole ?? 'Self',
              isDark: isDark,
              height: 66,
              showTrailing: false,
              editable: SizedBox(
                height: 24,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _profileRole,
                    isExpanded: true,
                    isDense: true,
                    itemHeight: kMinInteractiveDimension,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor, size: 18),
                    dropdownColor: isDark ? kDarkCard : Colors.white,
                    style: TextStyle(fontSize: 11, color: mutedColor),
                    items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                    onChanged: _changeProfileRole,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            _profileRow(icon: Icons.workspace_premium_rounded, iconColor: const Color(0xFFFF7A47), label: 'Current Plan', value: 'Free Plan', isDark: isDark, plan: true),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFF2563EB),
              label: 'Notification Settings',
              value: (_selectedGroup?.isOwner ?? false) ? 'Personal & family owner controls' : 'Personal notification preferences',
              isDark: isDark,
              onTap: () async {
                final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NotificationSettingsScreen(initialSettings: _notificationSettings, isCircleOwner: _selectedGroup?.isOwner ?? false)));
                if (saved == true && mounted) _loadProfile();
              },
            ),
            const SizedBox(height: 7),
            _profileRow(
              icon: Icons.manage_accounts_rounded,
              iconColor: const Color(0xFF7C3AED),
              label: 'Profile Settings',
              value: 'Password and account security',
              isDark: isDark,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen())),
            ),
            const SizedBox(height: 18),
            Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
            const SizedBox(height: 8),
            _themeSelector(isDark ? kDarkCard : Colors.white, titleColor, mutedColor),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded), label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ],
        ),
      ),
    );
  }

  Widget _legacyProfileRow({required IconData icon, required Color iconColor, required String label, required String value, required bool isDark, Widget? editable, bool locked = false, bool plan = false, VoidCallback? onTap, double height = 54, bool showTrailing = true}) {
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final row = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF233846) : const Color(0xFFE9EDF0)), boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))]),
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: iconColor.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 18)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 5), editable ?? Row(children: [if (plan) const Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFFFAE00)), if (plan) const SizedBox(width: 3), Text(value, style: TextStyle(fontSize: 11, height: 1, color: mutedColor))])])),
        if (showTrailing) ...[const SizedBox(width: 7), Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: mutedColor, size: 19)],
      ]),
    );
    if (onTap == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: row);
  }

  Widget _legacyThemeSelector(Color cardColor, Color enabledText, Color mutedText) {
    const choices = [(ThemeMode.system, 'System', Icons.brightness_auto_rounded), (ThemeMode.light, 'Light', Icons.light_mode_rounded), (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded)];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: choices.map((choice) {
          final selected = appThemeMode.value == choice.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => appThemeMode.value = choice.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: selected ? Colors.green : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Icon(choice.$3, size: 19, color: selected ? Colors.white : mutedText),
                  const SizedBox(height: 3),
                  Text(choice.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : enabledText)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  */
}

class _WaveNavigationClipper extends CustomClipper<Path> {
  const _WaveNavigationClipper();

  @override
  Path getClip(Size size) {
    final center = size.width / 2;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 22)
      ..quadraticBezierTo(0, 10, 18, 10)
      ..lineTo(center - 60, 10)
      ..cubicTo(center - 43, 10, center - 44, 0, center - 27, 0)
      ..quadraticBezierTo(center, -2, center + 27, 0)
      ..cubicTo(center + 44, 0, center + 43, 10, center + 60, 10)
      ..lineTo(size.width - 18, 10)
      ..quadraticBezierTo(size.width, 10, size.width, 22)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
