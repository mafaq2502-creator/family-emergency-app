import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../models/family_member.dart';
import '../../../models/notification_settings.dart';
import '../../../models/family_group.dart';
import '../../../models/app_notification.dart';
import '../../../services/profile_service.dart';
import '../../../services/family_member_service.dart';
import '../../../services/group_service.dart';
import '../../../services/group_migration_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/app_notification_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../members/presentation/member_profile_screen.dart';
import '../../members/presentation/member_notification_settings_editor.dart';
import '../../groups/presentation/group_settings_screen.dart';
import '../../groups/presentation/group_members_screen.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
import '../../notifications/presentation/notification_banner.dart';
import '../../profile/presentation/profile_settings_screen.dart';

part 'tabs/home_tab.dart';
part 'tabs/members_tab.dart';
part 'tabs/location_tab.dart';
part 'tabs/plan_tab.dart';
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

  final _profileNameController = TextEditingController();
  String? _profileRole;
  String _initialProfileName = '';
  String? _initialProfileRole;
  String _profileEmail = '';
  String _profilePhone = '';
  bool _isProfileLoading = true;
  bool _isSavingProfile = false;
  bool _isProfileDirty = false;
  DateTime? _lastDailyCheckIn;
  bool _isMarkingAlive = false;
  String _deviceTimeZone = 'UTC';
  bool _isFamilyOwner = true;
  Map<String, dynamic> _notificationSettings = {};
  final ProfileService _profileService = ProfileService();
  final FamilyMemberService _memberService = FamilyMemberService();
  final GroupService _groupService = GroupService();
  final GroupMigrationService _migrationService = GroupMigrationService();
  final EmergencyService _emergencyService = EmergencyService();
  final AppNotificationService _appNotificationService = AppNotificationService();
  List<FamilyGroup> _groups = const [];
  FamilyGroup? _selectedGroup;
  StreamSubscription<List<FamilyGroup>>? _groupsSubscription;
  StreamSubscription<List<FamilyMember>>? _membersSubscription;

  static const List<String> _roles = [
    'Self', 'Father', 'Mother', 'Son', 'Daughter', 'Husband', 'Wife',
    'Grandfather', 'Grandmother', 'Grandson', 'Granddaughter',
    'Brother', 'Sister',
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
  }

  Future<void> _prepareGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try { await _migrationService.migrateLegacyMembers(user); } catch (_) {}
    _watchGroups();
  }

  void _watchGroups() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupService.watchGroups(user).listen((groups) {
      if (!mounted) return;
      _groupRetryTimer?.cancel();
      _groupLoadErrorShown = false;
      setState(() {
        _groups = groups;
        final currentId = _selectedGroup?.id;
        _selectedGroup = groups.where((group) => group.id == currentId).cast<FamilyGroup?>().firstOrNull ?? (groups.isEmpty ? null : groups.first);
      });
      _watchMembers();
    }, onError: (_) {
      if (!mounted) return;
      if (!_groupLoadErrorShown) {
        _groupLoadErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not sync groups. Retrying…'),
          backgroundColor: kEmergency,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
      _groupRetryTimer?.cancel();
      _groupRetryTimer = Timer(const Duration(seconds: 3), _watchGroups);
    });
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Create group'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Group name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create'))]));
    if (name == null || name.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final groupId = await _groupService.createGroup(user, name);
      if (!mounted) return;
      final createdGroup = FamilyGroup(id: groupId, name: name, ownerId: user.uid, role: 'owner', emergencyRecipientIds: [user.uid]);
      setState(() {
        _groups = [..._groups.where((group) => group.id != groupId), createdGroup];
        _selectedGroup = createdGroup;
        familyMembers = const [];
      });
      _watchMembers();
      _watchGroups();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name created.'), backgroundColor: kEmerald));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create group. Check Firestore rules and connection.'), backgroundColor: kEmergency));
    }
  }

  Widget _groupSelector() => Row(children: [Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<FamilyGroup>(value: _selectedGroup, hint: const Text('Select group'), isExpanded: true, items: _groups.map((group) => DropdownMenuItem(value: group, child: Text(group.name))).toList(), onChanged: (group) { setState(() => _selectedGroup = group); _watchMembers(); }))), IconButton(onPressed: _createGroup, icon: const Icon(Icons.add_circle_outline_rounded, color: kEmerald), tooltip: 'Add group')]);

  void _openGroupSettings() { final group = _selectedGroup; if (group == null || !group.canManage) return; Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: group, members: familyMembers))); }

  void _openGroupHome(FamilyGroup group) { setState(() => _selectedGroup = group); Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMembersScreen(group: group))); }

  Widget _notificationBell() { final user = FirebaseAuth.instance.currentUser; if (user == null) return const SizedBox(); return StreamBuilder<List<AppNotification>>(stream: _appNotificationService.watch(user), builder: (context, snapshot) { final unread = (snapshot.data ?? []).where((item) => !item.isRead).length; return IconButton(onPressed: () => showNotificationBanner(context, user), icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none_rounded, color: kEmerald))); }); }

  void _watchMembers() {
    final group = _selectedGroup;
    _membersSubscription?.cancel();
    if (group == null) {
      if (mounted) setState(() => familyMembers = const []);
      return;
    }
    _membersSubscription = _memberService.watchGroupMembers(group.id).listen((members) {
      if (mounted) setState(() => familyMembers = members);
    }, onError: (_) {});
  }

  Future<void> _loadDeviceTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      if (mounted) setState(() => _deviceTimeZone = timezone.identifier);
    } catch (_) {
      if (mounted) setState(() => _deviceTimeZone = DateTime.now().timeZoneName);
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isProfileLoading = false);
      return;
    }
    try {
      final profile = await _profileService.load(user);
      if (!mounted) return;
      setState(() {
        _initialProfileName = profile.name;
        _profileRole = profile.role;
        _initialProfileRole = _profileRole;
        _profileNameController.text = _initialProfileName;
        _profileEmail = profile.email;
        _profilePhone = profile.phone;
        _lastDailyCheckIn = profile.lastDailyCheckIn;
        _isFamilyOwner = profile.isFamilyOwner;
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
    final changed = _profileNameController.text.trim() != _initialProfileName ||
        _profileRole != _initialProfileRole;
    if (mounted && changed != _isProfileDirty) {
      setState(() => _isProfileDirty = changed);
    }
  }

  void _changeProfileRole(String? value) {
    setState(() => _profileRole = value);
    _updateProfileDirtyState();
  }

  Future<void> _saveProfile() async {
    if (!_isProfileDirty || _isSavingProfile) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSavingProfile = true);
    try {
      await _profileService.saveBasicProfile(user, name: _profileNameController.text.trim(), role: _profileRole);
      if (!mounted) return;
      setState(() {
        _initialProfileName = _profileNameController.text.trim();
        _initialProfileRole = _profileRole;
        _isProfileDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved'), backgroundColor: Colors.green),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save profile. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<bool> _confirmProfileExit() async {
    if (!_isProfileDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('You have unsaved profile changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
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

  void _startSOS() {
    if (_isCountingDown || _alertSent) return;
    final group = _selectedGroup;
    if (group == null || group.emergencyRecipientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure emergency recipients in Group Settings first.'), backgroundColor: kEmergency));
      return;
    }

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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedRelation;
    bool locationAccess = true;
    bool batteryAccess = true;
    NotificationSettings memberNotifications = const NotificationSettings();

    final List<String> relations = [
      'Father',
      'Mother',
      'Husband',
      'Wife',
      'Son',
      'Daughter',
      'Grandfather',
      'Grandmother',
      'Grandson',
      'Granddaughter',
      'Brother',
      'Sister',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Family Member',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRelation,
                      dropdownColor: const Color(0xFF1A1A1A),
                      decoration: InputDecoration(
                        labelText: 'Relationship',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: relations
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedRelation = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Access Permissions',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Location',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: locationAccess,
                      activeThumbColor: kEmerald,
                      onChanged: (value) {
                        setDialogState(() => locationAccess = value);
                      },
                    ),
                    MemberNotificationSettingsEditor(settings: memberNotifications, onChanged: (settings) => setDialogState(() => memberNotifications = settings)),
                    SwitchListTile(
                      title: const Text(
                        'Battery Status',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: batteryAccess,
                      activeThumbColor: kEmerald,
                      onChanged: (value) {
                        setDialogState(() => batteryAccess = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty ||
                        selectedRelation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final member = FamilyMember(name: nameController.text.trim(), status: 'Pending', email: emailController.text.trim(), relation: selectedRelation, locationAccess: locationAccess, batteryAccess: batteryAccess, notificationSettings: memberNotifications);
                    final group = _selectedGroup;
                    if (group == null || !group.canManage) return;
                    try {
                      await _memberService.createInGroup(group.id, member);
                    } catch (_) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save member. Check your connection and Firestore setup.'), backgroundColor: kEmergency));
                      return;
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${nameController.text.trim()} added successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text(
                    'Add Member',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    _membersSubscription?.cancel();
    _timer?.cancel();
    _groupRetryTimer?.cancel();
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
          _buildPlanTab(),
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
      await _emergencyService.create(groupId: group.id, sender: user, senderName: _profileNameController.text.trim().isEmpty ? 'A group member' : _profileNameController.text.trim(), recipientIds: group.emergencyRecipientIds);
      if (!mounted) return;
      setState(() => _alertSent = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SOS sent to ${group.name} emergency recipients.'), backgroundColor: kEmergency));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send SOS. Please try again.'), backgroundColor: kEmergency));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove member.'), backgroundColor: kEmergency));
    });
  }

  Future<void> _updateFamilyMember(FamilyMember member) async {
    final group = _selectedGroup;
    if (group == null || member.id == null || !group.canManage) return;
    await _memberService.updateInGroup(group.id, member);
  }

  Future<void> _openMemberProfile(FamilyMember member, int index) => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfileScreen(member: member, onDelete: () async => _removeFamilyMember(index), onSave: _updateFamilyMember)));

  bool get _checkedInToday {
    final checkIn = _lastDailyCheckIn;
    if (checkIn == null) return false;
    final now = DateTime.now();
    return checkIn.year == now.year && checkIn.month == now.month && checkIn.day == now.day;
  }

  Future<void> _markAlive() async {
    if (_checkedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You're already checked in for today."), backgroundColor: kEmerald));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to check in.'), backgroundColor: kEmergency));
      return;
    }

    setState(() => _isMarkingAlive = true);
    final now = DateTime.now();
    try {
      await _profileService.recordDailyCheckIn(
        user,
        timeZone: _deviceTimeZone,
        localDate: '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      setState(() => _lastDailyCheckIn = now);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Today's check-in is confirmed. Stay safe!"), backgroundColor: kEmerald));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save today\'s check-in. Please try again.'), backgroundColor: kEmergency));
      }
    } finally {
      if (mounted) setState(() => _isMarkingAlive = false);
    }
  }

  Widget _buildNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const items = [
      (Icons.location_on_rounded, 'Location', 1),
      (Icons.groups_rounded, 'Members', 0),
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
                color: isDark ? kDarkSurface : Colors.white,
                elevation: 10,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                  children: [
                    for (final item in items.take(2)) _navItem(item.$1, item.$2, item.$3),
                    const Spacer(flex: 2),
                    for (final item in items.skip(2)) _navItem(item.$1, item.$2, item.$3),
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
                hoverColor: kEmerald.withValues(alpha: .14),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: kEmerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? kDarkBackground : const Color(0xFFF8FBFA), width: 4),
                      ),
                      child: const Icon(Icons.home_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 1),
                    Text('Home', style: TextStyle(color: _currentIndex == 2 ? kEmerald : Colors.grey, fontSize: 11, fontWeight: FontWeight.w700)),
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
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        hoverColor: kEmerald.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? kEmerald : Colors.grey),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: selected ? kEmerald : Colors.grey, fontSize: 11)),
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
            _profileRow(icon: Icons.phone_rounded, iconColor: const Color(0xFF778BA0), label: 'Phone Number', value: _profilePhone.isEmpty ? 'Not available' : _profilePhone, isDark: isDark, locked: true),
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
              value: _isFamilyOwner ? 'Personal & family owner controls' : 'Personal notification preferences',
              isDark: isDark,
              onTap: () async {
                final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => NotificationSettingsScreen(initialSettings: _notificationSettings, isFamilyOwner: _isFamilyOwner)));
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
