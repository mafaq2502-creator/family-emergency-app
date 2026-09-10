import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../models/paired_device.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key, required this.member, this.group});
  final FamilyMember member;
  final FamilyGroup? group;

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _code = TextEditingController();
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _code.removeListener(_refresh);
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Pair Device',
    subtitle: 'Permissions and consent are required',
    child: Column(
      children: [
        _step(
          '1',
          'Select Circle',
          widget.group?.name ?? 'Current Circle',
          Icons.groups_rounded,
        ),
        const SizedBox(height: 9),
        _step('2', 'Select Member', widget.member.name, Icons.person_rounded),
        const SizedBox(height: 9),
        _step(
          '3',
          'QR pairing',
          'Scanner is not connected',
          Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 18),
        LightCard(
          child: Column(
            children: [
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  color: context.appSurfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kEmerald, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 48,
                      color: context.appMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unavailable',
                      style: TextStyle(color: context.appMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              const Text('or enter pairing code'),
              const SizedBox(height: 9),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'PAIR-1234',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: _consent,
          onChanged: (value) => setState(() => _consent = value == true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'I understand that device data is shared only with consent.',
            style: TextStyle(fontSize: 11, color: context.appHeading),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _consent && _code.text.trim().isNotEmpty
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Device pairing backend is not connected yet.',
                      ),
                    ),
                  )
                : null,
            child: const Text('Pair Device'),
          ),
        ),
      ],
    ),
  );

  Widget _step(String number, String title, String value, IconData icon) =>
      LightCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: kEmerald,
              child: Text(number, style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 19, color: context.appPrimary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 10, color: context.appMuted),
                  ),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appHeading,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.memberName, this.device});
  final String memberName;
  final PairedDevice? device;

  @override
  Widget build(BuildContext context) {
    final name = device?.name ?? 'No device paired';
    final online = device?.isOnline(DateTime.now()) ?? false;
    return LightPage(
      title: 'Device Detail',
      subtitle: 'Assigned to $memberName',
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.appSuccessSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smartphone_rounded,
              size: 50,
              color: context.appPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              color: context.appHeading,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          LightStatusChip(
            label: device == null
                ? 'Not paired'
                : online
                ? 'Online'
                : 'Offline / last seen unknown',
            color: online ? kEmerald : context.appMuted,
          ),
          const SizedBox(height: 22),
          _metric(
            Icons.battery_5_bar_rounded,
            'Battery',
            device?.batteryLevel == null
                ? 'Not available'
                : '${device!.batteryLevel}%',
          ),
          _metric(
            Icons.storage_rounded,
            'Storage',
            device?.storageUsedPercent == null
                ? 'Not available'
                : '${device!.storageUsedPercent}% used',
          ),
          _metric(
            Icons.sync_rounded,
            'Last Sync',
            device?.lastSeenAt?.toLocal().toString() ?? 'No sync yet',
          ),
          _metric(Icons.schedule_rounded, 'Screen Time', 'No telemetry yet'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: device == null
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Device unpairing is not connected yet.'),
                      ),
                    ),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Unpair Device'),
              style: OutlinedButton.styleFrom(foregroundColor: kEmergency),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LightSettingRow(icon: icon, title: label, subtitle: value),
  );
}
