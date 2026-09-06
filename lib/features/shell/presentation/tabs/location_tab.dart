part of '../family_shell.dart';

extension _LocationTab on _HomeScreenState {
  Widget _buildLocationTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kNavy;
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 4), Text('View your family members on map.', style: TextStyle(fontSize: 12, color: mutedColor)), const Spacer(), Center(child: _locationEmptyArtwork(isDark)), const SizedBox(height: 25), Center(child: Text('Location map will be available soon.', style: TextStyle(fontSize: 12, color: mutedColor))), const Spacer(flex: 2),
    ])));
  }

  Widget _locationEmptyArtwork(bool isDark) => SizedBox(width: 195, height: 150, child: Stack(alignment: Alignment.center, children: [
    Positioned(bottom: 2, child: Transform.rotate(angle: -.18, child: Container(width: 150, height: 72, decoration: BoxDecoration(color: const Color(0xFFBDECEE), borderRadius: BorderRadius.circular(8))))),
    Positioned(bottom: 21, child: Transform.rotate(angle: -.18, child: Container(width: 156, height: 3, color: Colors.white70))), Positioned(bottom: 40, child: Transform.rotate(angle: -.18, child: Container(width: 156, height: 3, color: Colors.white70))), const Positioned(left: 30, bottom: 38, child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 32)), const Positioned(right: 25, bottom: 20, child: Icon(Icons.park_rounded, color: Color(0xFF69CBBE), size: 36)), const Positioned(right: 25, top: 43, child: Icon(Icons.cloud_rounded, color: Color(0xFFDCECF8), size: 44)), Container(width: 67, height: 76, decoration: const BoxDecoration(color: kEmerald, shape: BoxShape.circle), child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 43)),
  ]));
}
