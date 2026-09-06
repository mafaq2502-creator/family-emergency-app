import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:async';

import 'screens/login_screen.dart';
import 'screens/notification_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FamilyEmergencyApp());
}

const kEmerald = Color(0xFF10B981);
const kNavy = Color(0xFF112A55);
const kEmergency = Color(0xFFEF4444);
const kDarkBackground = Color(0xFF07131D);
const kDarkSurface = Color(0xFF10212D);
const kDarkCard = Color(0xFF132431);
const kDarkCardElevated = Color(0xFF182C3A);
const kDarkMuted = Color(0xFFAFC0CF);

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);

class FamilyEmergencyApp extends StatelessWidget {
  const FamilyEmergencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Family Emergency',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: kEmerald,
            textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
            primaryTextTheme: GoogleFonts.manropeTextTheme(ThemeData.light().primaryTextTheme),
            colorScheme: ColorScheme.fromSeed(
              seedColor: kEmerald,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FBFA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: kNavy,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: kEmerald,
            textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
            primaryTextTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().primaryTextTheme),
            colorScheme: ColorScheme.fromSeed(seedColor: kEmerald, brightness: Brightness.dark, surface: kDarkCard),
            scaffoldBackgroundColor: kDarkBackground,
            appBarTheme: const AppBarTheme(
              backgroundColor: kDarkSurface,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardColor: kDarkCard,
            dividerColor: const Color(0xFF233846),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kDarkCard,
              hintStyle: const TextStyle(color: kDarkMuted),
              labelStyle: const TextStyle(color: kDarkMuted),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF233846))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kEmerald)),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

// ====================== HOME SCREEN ======================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isCountingDown = false;
  int _countdown = 3;
  bool _alertSent = false;
  Timer? _timer;

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

  static const List<String> _roles = [
    'Self', 'Father', 'Mother', 'Son', 'Daughter', 'Husband', 'Wife',
    'Grandfather', 'Grandmother', 'Grandson', 'Granddaughter',
    'Brother', 'Sister',
  ];

  final List<Map<String, dynamic>> familyMembers = [
    {'name': 'Father', 'status': 'Online'},
    {'name': 'Mother', 'status': 'Online'},
    {'name': 'Brother', 'status': 'Online'},
    {'name': 'Sister', 'status': 'Online'},
  ];

  @override
  void initState() {
    super.initState();
    _profileNameController.addListener(_updateProfileDirtyState);
    _loadDeviceTimeZone();
    _loadProfile();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final data = snapshot.data();
      final savedCheckIn = data?['lastDailyCheckInAt'];
      if (!mounted) return;
      setState(() {
        _initialProfileName = data?['name'] as String? ??
            user.displayName ??
            user.email?.split('@').first ??
            '';
        _profileRole = data?['role'] as String?;
        _initialProfileRole = _profileRole;
        _profileNameController.text = _initialProfileName;
        _profileEmail = data?['email'] as String? ?? user.email ?? '';
        _profilePhone = data?['phone'] as String? ?? '';
        _lastDailyCheckIn = savedCheckIn is Timestamp ? savedCheckIn.toDate() : null;
        _isFamilyOwner = data?['isFamilyOwner'] as bool? ?? true;
        _notificationSettings = Map<String, dynamic>.from(data?['notificationSettings'] as Map? ?? const {});
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _profileNameController.text.trim(),
        'role': _profileRole,
      }, SetOptions(merge: true));
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
          _alertSent = true;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Emergency Alert Sent to Family!')),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
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
                  onPressed: () {
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

                    // Abhi ke liye sirf list mein add kar rahe hain
                    setState(() {
                      familyMembers.add({
                        'name': nameController.text.trim(),
                        'status': 'Pending',
                        'email': emailController.text.trim(),
                        'relation': selectedRelation,
                        'locationAccess': locationAccess,
                        'batteryAccess': batteryAccess,
                      });
                    });

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
    _timer?.cancel();
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastDailyCheckInAt': FieldValue.serverTimestamp(),
        'lastDailyCheckInTimeZone': _deviceTimeZone,
        'lastDailyCheckInLocalDate': '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      }, SetOptions(merge: true));
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
      child: SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? kDarkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    for (final item in items.take(2)) _navItem(item.$1, item.$2, item.$3),
                    const Spacer(flex: 2),
                    for (final item in items.skip(2)) _navItem(item.$1, item.$2, item.$3),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -14,
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 2),
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
                    const SizedBox(height: 0),
                    Text('Home', style: TextStyle(color: _currentIndex == 2 ? kEmerald : Colors.grey, fontSize: 11)),
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

  // ================= HOME TAB =================
  Widget _buildHomeTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${_profileNameController.text.isEmpty ? 'Afaq' : _profileNameController.text}', style: TextStyle(fontSize: 21, height: 1, fontWeight: FontWeight.bold, color: titleColor)),
                      const SizedBox(height: 6),
                      Row(children: [Text('Your family is safe', style: TextStyle(fontSize: 12, color: mutedColor)), const SizedBox(width: 5), const Icon(Icons.favorite, size: 15, color: kEmergency)]),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.groups_rounded, color: kEmerald, size: 37),
                    Positioned(right: -2, top: -2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: kEmergency, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF101916) : const Color(0xFFF8FBFA), width: 1.5)))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: familyMembers.length.clamp(0, 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .93),
              itemBuilder: (_, index) => _homeMemberCard(familyMembers[index], index, isDark),
            ),
            const SizedBox(height: 13),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 156,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: _isMarkingAlive ? null : _markAlive,
                      icon: _isMarkingAlive
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kEmerald))
                          : Icon(_checkedInToday ? Icons.check_circle_rounded : Icons.favorite_rounded, size: 18),
                      label: const Text("I'm Alive", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _checkedInToday ? kEmerald : (isDark ? const Color(0xFF9FE8D2) : const Color(0xFF087F6C)),
                        side: BorderSide(color: _checkedInToday ? kEmerald : (isDark ? const Color(0xFF2D806E) : const Color(0xFF9DDCCB))),
                        backgroundColor: _checkedInToday ? (isDark ? const Color(0xFF123A31) : const Color(0xFFE8F8F1)) : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_checkedInToday ? 'Checked in today' : 'Tap once each day', style: TextStyle(fontSize: 10, color: mutedColor)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 143,
                height: 43,
                child: ElevatedButton.icon(
                  onPressed: _startSOS,
                  icon: const Icon(Icons.warning_amber_rounded, size: 19),
                  label: const Text('Emergency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white, elevation: 6, shadowColor: kEmergency.withValues(alpha: .45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeMemberCard(Map<String, dynamic> member, int index, bool isDark) {
    final name = member['name'] as String;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF52647B);
    final battery = const ['85%', '72%', '60%', '40%'][index];
    final batteryColor = index == 3 ? const Color(0xFFFFB21A) : kEmerald;
    final avatarColors = const [Color(0xFFE9EEF0), Color(0xFFF2E9E8), Color(0xFFF0E8DF), Color(0xFFF5E8E8)];
    final avatarIcons = const [Icons.face_rounded, Icons.face_3_rounded, Icons.face_rounded, Icons.face_3_rounded];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE9EDF0)),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 22, backgroundColor: avatarColors[index], child: Icon(avatarIcons[index], color: const Color(0xFF536878), size: 29)),
              const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5.5, backgroundColor: Colors.white, child: CircleAvatar(radius: 4, backgroundColor: kEmerald))),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 5),
          const Row(children: [Icon(Icons.circle, size: 8, color: kEmerald), SizedBox(width: 4), Text('Online', style: TextStyle(color: kEmerald, fontSize: 11, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 7),
          Row(children: [Icon(Icons.battery_5_bar_rounded, size: 16, color: batteryColor), const SizedBox(width: 4), Text(battery, style: TextStyle(fontSize: 11, color: mutedColor))]),
          const SizedBox(height: 4),
          Row(children: [Icon(Icons.location_on_rounded, size: 14, color: mutedColor), const SizedBox(width: 3), Flexible(child: Text('Lahore, PK', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: mutedColor)))]),
        ],
      ),
    );
  }

  // ================= FAMILY TAB =================
  Widget _buildFamilyTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Family Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 4),
            Text('Add and manage your family members.', style: TextStyle(fontSize: 12, color: mutedColor)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: _showAddMemberDialog,
                icon: const Icon(Icons.add_rounded, size: 24),
                label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 13),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: familyMembers.length,
                itemBuilder: (context, index) => _memberListCard(familyMembers[index], index, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberListCard(Map<String, dynamic> member, int index, bool isDark) {
    final name = member['name'] as String;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF60728C);
    final phone = member['phone'] as String? ?? const ['+92 300 1234567', '+92 300 2345678', '+92 300 3456789', '+92 300 4567890'][index % 4];
    final relation = member['relation'] as String? ?? name;
    final avatarColors = const [Color(0xFFE9EEF0), Color(0xFFF3E8E7), Color(0xFFF0E8DF), Color(0xFFF5E8E8)];
    final avatarIcons = const [Icons.face_rounded, Icons.face_3_rounded, Icons.face_rounded, Icons.face_3_rounded];
    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE9EDF0)),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(radius: 23, backgroundColor: avatarColors[index % 4], child: Icon(avatarIcons[index % 4], color: const Color(0xFF536878), size: 30)),
              const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 6, backgroundColor: Colors.white, child: CircleAvatar(radius: 4.5, backgroundColor: kEmerald))),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.bold, color: titleColor)),
                const SizedBox(height: 4),
                Text(phone, style: TextStyle(fontSize: 11, height: 1, color: mutedColor)),
                const SizedBox(height: 4),
                Text(relation, style: TextStyle(fontSize: 11, height: 1, color: mutedColor)),
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 28, height: 34),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: mutedColor, size: 20),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name options will be available soon'))),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 29, height: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline_rounded, color: kEmergency, size: 20),
            onPressed: () => setState(() => familyMembers.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ================= LOCATION TAB =================
  Widget _buildLocationTab() {
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
            Center(child: _locationEmptyArtwork(isDark)),
            const SizedBox(height: 25),
            Center(child: Text('Location map will be available soon.', style: TextStyle(fontSize: 12, color: mutedColor))),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _locationEmptyArtwork(bool isDark) => SizedBox(
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

  Widget _buildPlanTab() {
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
                  Expanded(child: _planCard(title: 'Free', subtitle: 'Basic features for\nsmall families.', price: '\$0', features: const ['Up to 5 members', 'Basic alerts', 'Location tracking'], selected: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _planCard(title: 'Premium', subtitle: 'Advanced features\nfor complete safety.', price: '\$4.99', features: const ['Unlimited members', 'Real-time alerts', 'Location history', 'Priority support'])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard({required String title, required String subtitle, required String price, required List<String> features, bool selected = false}) {
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
  Widget _buildProfileTab() {
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
            _profileRow(icon: Icons.person_rounded, iconColor: const Color(0xFF778BA0), label: 'User Name', value: _profileNameController.text, isDark: isDark, editable: TextField(controller: _profileNameController, style: TextStyle(fontSize: 11, color: mutedColor), decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero))),
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
                    itemHeight: 42,
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

  Widget _profileRow({required IconData icon, required Color iconColor, required String label, required String value, required bool isDark, Widget? editable, bool locked = false, bool plan = false, VoidCallback? onTap, double height = 54, bool showTrailing = true}) {
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

  Widget _themeSelector(Color cardColor, Color enabledText, Color mutedText) {
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
}
