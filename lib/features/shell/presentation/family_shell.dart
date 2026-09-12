import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_navigation.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/domain/circle_error_mapper.dart';
import '../../../core/domain/circle_policies.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../core/widgets/app_theme_mode_selector.dart';
import '../../../core/widgets/profile_image.dart';
import '../../../core/widgets/bounded_dropdown_form_field.dart';
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
import '../../../services/push_notification_service.dart';
import '../../../app/notification_navigation.dart';
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
  const HomeScreen({
    super.key,
    this.initialInviteCode,
    this.initialInviteError,
    this.onInviteHandled,
  });

  final String? initialInviteCode;
  final String? initialInviteError;
  final VoidCallback? onInviteHandled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 2;
  bool _isCountingDown = false;
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
  void _openPlansFromProfile() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PlansScreen()),
  );

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
  bool _isPremium = false;
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
    PushNotificationService.instance.pendingTap.addListener(
      _openPendingNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openPendingNotification(),
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialInvite());
  }

  void _openPendingNotification() {
    if (!mounted) return;
    final pending = PushNotificationService.instance.pendingTap;
    final payload = pending.value;
    if (payload == null) return;
    pending.value = null;
    unawaited(openNotificationPayload(payload));
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialInviteCode != oldWidget.initialInviteCode ||
        widget.initialInviteError != oldWidget.initialInviteError) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialInvite());
    }
  }

  Future<void> _openInitialInvite() async {
    if (!mounted) return;
    final error = widget.initialInviteError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: kEmergency),
      );
      widget.onInviteHandled?.call();
      return;
    }
    final code = widget.initialInviteCode;
    if (code == null) return;
    widget.onInviteHandled?.call();
    final circleId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => JoinCircleScreen(initialCode: code)),
    );
    if (!mounted || circleId == null) return;
    _watchGroups();
    setState(() => _currentIndex = 0);
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
              if (!groups.any((group) => group.id == currentId)) {
                _progressMemberId = null;
              }
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
    if (!_isPremium && _groups.any((group) => group.isOwner)) {
      _showPlanLimit(
        'Your Free Plan allows you to create 1 Circle. Upgrade to Premium to create more.',
      );
      return;
    }
    setState(() => _isCreatingGroup = true);
    final controller = TextEditingController();
    try {
      final formKey = GlobalKey<FormState>();
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
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

  void _openGroupSettings([FamilyGroup? targetGroup]) {
    final group = targetGroup ?? _selectedGroup;
    if (group == null || !group.canManage) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: group)),
    );
  }

  Future<void> _openGroupHome(FamilyGroup group) async {
    setState(() => _selectedGroup = group);
    final result = await Navigator.push<CircleDetailExit>(
      context,
      MaterialPageRoute(builder: (_) => GroupMembersScreen(group: group)),
    );
    if (!mounted || result == null) return;
    setState(() {
      _groups = _groups.where((item) => item.id != group.id).toList();
      _selectedGroup = _groups.firstOrNull;
      _currentIndex = 0;
    });
    _watchMembers();
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
        _isPremium = profile.isPremium;
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

  Future<bool> _saveAccountPhoto(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await _profileService.saveProfilePhoto(user, photoUrl);
    if (mounted) setState(() => _profilePhotoUrl = photoUrl);
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
      builder: (dialogContext) => AppAlertDialog(
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
    if (_isCountingDown) return;
    final group = _selectedGroup;
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    final recipients = group?.emergencyRecipientIds
        .where((id) => id != senderId && group.memberIds.contains(id))
        .toList();
    if (group == null || recipients == null || recipients.isEmpty) {
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

    setState(() => _isCountingDown = true);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmergencyCountdownDialog(groupName: group.name),
    );
    if (!mounted) return;
    setState(() => _isCountingDown = false);
    if (confirmed == true) await _sendEmergency(group, recipients);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
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
    PushNotificationService.instance.pendingTap.removeListener(
      _openPendingNotification,
    );
    _groupsSubscription?.cancel();
    _membersSubscription?.cancel();
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
            PlanSelectionContent(action: _notificationBell()),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: _buildNavigationBar(),
      ),
    );
  }

  Future<void> _sendEmergency(
    FamilyGroup group,
    List<String> recipientIds,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _emergencyService.create(
        groupId: group.id,
        sender: user,
        senderName: _profileNameController.text.trim().isEmpty
            ? 'A group member'
            : _profileNameController.text.trim(),
        recipientIds: recipientIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent successfully.'),
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
      builder: (dialogContext) => AppAlertDialog(
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

  Widget _buildNavigationBar() => AppBottomNavigation(
    selectedIndex: _currentIndex,
    onSelected: (index) => setState(() => _currentIndex = index),
  );

  Future<void> _openPremiumFeature(VoidCallback action) async {
    if (_isPremium) {
      action();
      return;
    }
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        icon: const Icon(Icons.workspace_premium_rounded, color: kEmerald),
        title: const Text('Premium feature'),
        content: const Text('This feature is available with Premium.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
    if (upgrade == true && mounted) _openPlansFromProfile();
  }

  void _showPlanLimit(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Upgrade to Premium',
          onPressed: () => setState(() => _currentIndex = 3),
        ),
      ),
    );
  }
}

class EmergencyCountdownDialog extends StatefulWidget {
  const EmergencyCountdownDialog({super.key, required this.groupName});
  final String groupName;

  @override
  State<EmergencyCountdownDialog> createState() =>
      _EmergencyCountdownDialogState();
}

class _EmergencyCountdownDialogState extends State<EmergencyCountdownDialog> {
  int _seconds = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds == 1) {
        _timer?.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    icon: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: kEmergency.withValues(alpha: .11),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.sos_rounded, color: kEmergency, size: 32),
    ),
    title: const Text('Emergency Alert'),
    content: Text(
      'Emergency notification will be sent in $_seconds seconds.\n\nSelected recipients in ${widget.groupName} will be alerted.',
      textAlign: TextAlign.center,
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
    ],
  );
}
