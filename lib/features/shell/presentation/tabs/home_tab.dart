part of '../family_shell.dart';

extension _HomeTab on _HomeScreenState {
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
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, ${_profileNameController.text.isEmpty ? 'Afaq' : _profileNameController.text}', style: TextStyle(fontSize: 21, height: 1, fontWeight: FontWeight.bold, color: titleColor)),
                const SizedBox(height: 6),
                Row(children: [Text('Your family is safe', style: TextStyle(fontSize: 12, color: mutedColor)), const SizedBox(width: 5), const Icon(Icons.favorite, size: 15, color: kEmergency)]),
              ])),
              Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.groups_rounded, color: kEmerald, size: 37),
                Positioned(right: -2, top: -2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: kEmergency, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF101916) : const Color(0xFFF8FBFA), width: 1.5)))),
              ]),
            ]),
            const SizedBox(height: 15),
            GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: familyMembers.length.clamp(0, 4), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .93), itemBuilder: (_, index) => _homeMemberCard(familyMembers[index], index, isDark)),
            const SizedBox(height: 13),
            Center(child: Column(children: [
              SizedBox(width: 156, height: 38, child: OutlinedButton.icon(
                onPressed: _isMarkingAlive ? null : _markAlive,
                icon: _isMarkingAlive ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kEmerald)) : Icon(_checkedInToday ? Icons.check_circle_rounded : Icons.favorite_rounded, size: 18),
                label: const Text("I'm Alive", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(foregroundColor: _checkedInToday ? kEmerald : (isDark ? const Color(0xFF9FE8D2) : const Color(0xFF087F6C)), side: BorderSide(color: _checkedInToday ? kEmerald : (isDark ? const Color(0xFF2D806E) : const Color(0xFF9DDCCB))), backgroundColor: _checkedInToday ? (isDark ? const Color(0xFF123A31) : const Color(0xFFE8F8F1)) : Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
              )),
              const SizedBox(height: 4),
              Text(_checkedInToday ? 'Checked in today' : 'Tap once each day', style: TextStyle(fontSize: 10, color: mutedColor)),
            ])),
            const SizedBox(height: 10),
            Center(child: SizedBox(width: 143, height: 43, child: ElevatedButton.icon(onPressed: _startSOS, icon: const Icon(Icons.warning_amber_rounded, size: 19), label: const Text('Emergency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: kEmergency, foregroundColor: Colors.white, elevation: 6, shadowColor: kEmergency.withValues(alpha: .45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)))))),
          ],
        ),
      ),
    );
  }

  Widget _homeMemberCard(FamilyMember member, int index, bool isDark) {
    final name = member.name;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF52647B);
    final battery = const ['85%', '72%', '60%', '40%'][index];
    final batteryColor = index == 3 ? const Color(0xFFFFB21A) : kEmerald;
    final avatarColors = const [Color(0xFFE9EEF0), Color(0xFFF2E9E8), Color(0xFFF0E8DF), Color(0xFFF5E8E8)];
    final avatarIcons = const [Icons.face_rounded, Icons.face_3_rounded, Icons.face_rounded, Icons.face_3_rounded];
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _openMemberProfile(member, index), child: Container(padding: const EdgeInsets.fromLTRB(12, 10, 10, 9), decoration: BoxDecoration(color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE9EDF0)), boxShadow: isDark ? null : const [BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [CircleAvatar(radius: 22, backgroundColor: avatarColors[index], child: Icon(avatarIcons[index], color: const Color(0xFF536878), size: 29)), const Positioned(right: -1, top: -1, child: CircleAvatar(radius: 5.5, backgroundColor: Colors.white, child: CircleAvatar(radius: 4, backgroundColor: kEmerald)))]),
      const SizedBox(height: 6), Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 5), const Row(children: [Icon(Icons.circle, size: 8, color: kEmerald), SizedBox(width: 4), Text('Online', style: TextStyle(color: kEmerald, fontSize: 11, fontWeight: FontWeight.w500))]), const SizedBox(height: 7), Row(children: [Icon(Icons.battery_5_bar_rounded, size: 16, color: batteryColor), const SizedBox(width: 4), Text(battery, style: TextStyle(fontSize: 11, color: mutedColor))]), const SizedBox(height: 4), Row(children: [Icon(Icons.location_on_rounded, size: 14, color: mutedColor), const SizedBox(width: 3), Flexible(child: Text('Lahore, PK', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: mutedColor)))])
    ])));
  }
}
