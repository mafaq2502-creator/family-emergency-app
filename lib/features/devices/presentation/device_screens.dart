import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/domain/device_policies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/device_pairing_request.dart';
import '../../../models/family_group.dart';
import '../../../models/family_member.dart';
import '../../../models/paired_device.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_service.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key, this.deviceService});
  final DeviceActions? deviceService;

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late final DeviceActions _service = widget.deviceService ?? DeviceService();
  late Future<PairedDevice> _registration = _service.registerCurrentDevice();

  void _retry() =>
      setState(() => _registration = _service.registerCurrentDevice());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Devices'),
    ),
    body: FutureBuilder<PairedDevice>(
      future: _registration,
      builder: (context, registration) {
        if (registration.connectionState != ConnectionState.done) {
          return const LightStateView(
            icon: Icons.sync_rounded,
            title: 'Registering this device',
            message: 'Securing this app installation to your account…',
            busy: true,
          );
        }
        if (registration.hasError) {
          return LightStateView(
            icon: Icons.phonelink_erase_rounded,
            title: 'Device registration failed',
            message: _deviceError(registration.error!),
            actionLabel: 'Retry',
            onAction: _retry,
          );
        }
        return StreamBuilder<List<PairedDevice>>(
          stream: _service.watchMyDevices(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return LightStateView(
                icon: Icons.cloud_off_rounded,
                title: 'Devices could not be loaded',
                message: _deviceError(snapshot.error!),
                actionLabel: 'Retry',
                onAction: _retry,
              );
            }
            if (!snapshot.hasData) {
              return const LightStateView(
                icon: Icons.sync_rounded,
                title: 'Loading devices',
                message: 'Getting registered app installations…',
                busy: true,
              );
            }
            final devices = snapshot.data!;
            if (devices.isEmpty) {
              return LightStateView(
                icon: Icons.devices_other_rounded,
                title: 'No registered devices',
                message: 'Register this installation to continue.',
                actionLabel: 'Register Device',
                onAction: _retry,
              );
            }
            return RefreshIndicator(
              onRefresh: _service.heartbeat,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  const LightSectionTitle('Registered installations'),
                  const Text(
                    'A generated installation ID identifies the app safely without using a permanent hardware identifier.',
                  ),
                  const SizedBox(height: 16),
                  for (final device in devices) ...[
                    _DeviceCard(
                      device: device,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(
                            memberName: 'Your account',
                            device: device,
                            deviceService: _service,
                            accountDevice: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DevicePairingCodeScreen(deviceService: _service),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Pair This Device to a Circle'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class DevicePairingCodeScreen extends StatefulWidget {
  const DevicePairingCodeScreen({super.key, required this.deviceService});
  final DeviceActions deviceService;

  @override
  State<DevicePairingCodeScreen> createState() =>
      _DevicePairingCodeScreenState();
}

class _DevicePairingCodeScreenState extends State<DevicePairingCodeScreen> {
  late Future<DevicePairingRequest> _request = widget.deviceService
      .createPairingRequest();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pair This Device'),
    ),
    body: FutureBuilder<DevicePairingRequest>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LightStateView(
            icon: Icons.enhanced_encryption_rounded,
            title: 'Creating secure code',
            message: 'Registering a short-lived pairing request…',
            busy: true,
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return LightStateView(
            icon: Icons.qr_code_2_rounded,
            title: 'Code could not be created',
            message: _deviceError(snapshot.error ?? StateError('No code')),
            actionLabel: 'Retry',
            onAction: () => setState(
              () => _request = widget.deviceService.createPairingRequest(),
            ),
          );
        }
        final request = snapshot.data!;
        final remaining = request.expiresAt.difference(DateTime.now().toUtc());
        final expired = remaining <= Duration.zero;
        final payload = 'familyemergency://pair-device?code=${request.code}';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              request.deviceName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'On a Circle manager’s phone, open the intended member and scan or enter this code. Generating the code is this device owner’s consent.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: payload,
                  size: 210,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: kLightNavy,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: kLightNavy,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SelectableText(
              DevicePairingCodePolicy.format(request.code),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: LightStatusChip(
                label: expired
                    ? 'Expired — create a new code'
                    : 'Expires in ${_duration(remaining)}',
                color: expired ? kEmergency : kEmerald,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: expired
                  ? null
                  : () async {
                      await widget.deviceService.revokePairingRequest(
                        request.code,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              icon: const Icon(Icons.block_rounded),
              label: const Text('Cancel Pairing Code'),
              style: OutlinedButton.styleFrom(foregroundColor: kEmergency),
            ),
          ],
        );
      },
    ),
  );
}

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({
    super.key,
    this.member,
    this.group,
    this.memberUserId,
    this.memberName,
    this.deviceService,
  });
  final FamilyMember? member;
  final FamilyGroup? group;
  final String? memberUserId;
  final String? memberName;
  final DeviceActions? deviceService;

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  late final DeviceActions _service = widget.deviceService ?? DeviceService();
  bool _consent = false;
  bool _busy = false;
  String? _error;

  String get _name => widget.memberName ?? widget.member?.name ?? 'Member';
  String? get _userId => widget.memberUserId ?? widget.member?.userId;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DeviceQrScannerScreen()),
    );
    if (code != null && mounted) {
      _code.text = DevicePairingCodePolicy.format(code);
      setState(() => _error = null);
    }
  }

  Future<void> _pair() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final group = widget.group;
    final userId = _userId;
    if (group == null || userId == null || userId.isEmpty) {
      setState(
        () => _error =
            'Pairing requires a registered Circle member and active Circle.',
      );
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Confirm the pairing consent first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await _service.pairDeviceToMember(
        group: group,
        targetUserId: userId,
        code: _code.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AppAlertDialog(
          icon: const Icon(Icons.verified_rounded, color: kEmerald),
          title: const Text('Device paired'),
          content: Text('${device.name} is now paired to $_name.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, device);
    } catch (error) {
      if (mounted) setState(() => _error = _deviceError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LightPage(
    title: 'Pair Device',
    subtitle: 'Short-lived code and member approval',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _step(
            '1',
            'Circle',
            widget.group?.name ?? 'Unavailable',
            Icons.groups_rounded,
          ),
          const SizedBox(height: 10),
          _step('2', 'Member', _name, Icons.person_rounded),
          const SizedBox(height: 18),
          TextFormField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            autovalidateMode: AutovalidateMode.onUnfocus,
            validator: DevicePairingCodePolicy.validate,
            decoration: InputDecoration(
              labelText: 'Pairing Code',
              hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                tooltip: 'Scan pairing QR',
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _consent,
            onChanged: _busy
                ? null
                : (value) => setState(() => _consent = value == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I confirm this code came from the intended member’s device.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kEmergency),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _pair,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(_busy ? 'Pairing…' : 'Pair Device'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _step(String number, String title, String value, IconData icon) =>
      LightCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
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
                    style: TextStyle(fontSize: 13, color: context.appMuted),
                  ),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appHeading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({
    super.key,
    required this.memberName,
    this.device,
    this.deviceService,
    this.circleId,
    this.accountDevice = false,
    this.canUnpair = false,
  });
  final String memberName;
  final PairedDevice? device;
  final DeviceActions? deviceService;
  final String? circleId;
  final bool accountDevice;
  final bool canUnpair;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late final DeviceActions _service = widget.deviceService ?? DeviceService();
  Timer? _clock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _rename(PairedDevice device) async {
    final controller = TextEditingController(text: device.name);
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Rename Device'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: DevicePolicy.maxNameLength,
            validator: DevicePolicy.validateName,
            decoration: const InputDecoration(labelText: 'Device Name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name == device.name || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.renameMyDevice(device, name);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(PairedDevice device) async {
    final current = widget.accountDevice && device.isCurrentDevice;
    final unpair = !widget.accountDevice;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        icon: const Icon(Icons.phonelink_erase_rounded, color: kEmergency),
        title: Text(unpair ? 'Unpair device?' : 'Revoke device?'),
        content: Text(
          current
              ? 'This is the current device. Revoking it will sign this account out on this installation.'
              : unpair
              ? 'This keeps the account installation record but removes its access to this Circle.'
              : 'This device will stop sending heartbeat updates for this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kEmergency),
            child: Text(unpair ? 'Unpair' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (unpair) {
        await _service.unpairCircleDevice(widget.circleId!, device);
      } else {
        final revokedCurrent = await _service.revokeMyDevice(device);
        if (revokedCurrent) await AuthService().signOut();
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_deviceError(error)), backgroundColor: kEmergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    if (device == null) {
      return const Scaffold(
        body: LightStateView(
          icon: Icons.devices_other_rounded,
          title: 'No device paired',
          message: 'A registered device will appear here after secure pairing.',
        ),
      );
    }
    final presence = device.presenceAt(DateTime.now());
    final status = _presence(presence);
    return LightPage(
      title: 'Device Detail',
      subtitle: 'Assigned to ${widget.memberName}',
      child: AbsorbPointer(
        absorbing: _busy,
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
                _platformIcon(device.platform),
                size: 50,
                color: context.appPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              device.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appHeading,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (device.isCurrentDevice) ...[
              const SizedBox(height: 6),
              const LightStatusChip(label: 'This Device', color: kEmerald),
            ],
            const SizedBox(height: 7),
            LightStatusChip(label: status.$1, color: status.$2),
            const SizedBox(height: 22),
            _metric(Icons.devices_rounded, 'Platform', device.platform),
            _metric(Icons.info_outline_rounded, 'Model', device.model),
            _metric(
              Icons.factory_outlined,
              'Manufacturer',
              device.manufacturer ?? 'Not reported',
            ),
            _metric(
              Icons.android_rounded,
              'Android / API',
              [
                    device.osVersion,
                    if (device.androidApiLevel != null)
                      'API ${device.androidApiLevel}',
                  ].whereType<String>().join(' · ').isEmpty
                  ? 'Not reported'
                  : [
                      device.osVersion,
                      if (device.androidApiLevel != null)
                        'API ${device.androidApiLevel}',
                    ].whereType<String>().join(' · '),
            ),
            _metric(
              Icons.apps_rounded,
              'App Version',
              device.appVersion ?? 'Not reported',
            ),
            _metric(
              Icons.notifications_active_outlined,
              'Notifications',
              device.notificationsEnabled
                  ? 'Allowed'
                  : switch (device.notificationPermissionState) {
                      'settingsRequired' => 'Enable in Android Settings',
                      'denied' => 'Denied',
                      'notRequested' => 'Not requested',
                      _ => 'Not allowed',
                    },
            ),
            _metric(
              Icons.monitor_heart_outlined,
              'Last Heartbeat',
              _date(device.lastHeartbeatAt),
            ),
            _metric(
              Icons.visibility_outlined,
              'Last Seen',
              _date(device.lastSeenAt),
            ),
            _metric(
              Icons.link_rounded,
              'Paired / Registered',
              _date(device.pairedAt ?? device.registeredAt),
            ),
            _metric(
              Icons.schedule_rounded,
              'Screen Time Access',
              device.platform != 'android'
                  ? 'Unavailable on this platform'
                  : device.permissions['screenTime'] == true
                  ? 'Allowed'
                  : 'Not allowed',
            ),
            _metric(
              Icons.cloud_sync_outlined,
              'Screen Time Sync',
              _date(device.lastScreenTimeSyncAt),
            ),
            if (widget.accountDevice &&
                device.pairingStatus != DevicePairingStatus.revoked) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _rename(device),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Rename Device'),
                ),
              ),
            ],
            if ((widget.accountDevice || widget.canUnpair) &&
                device.pairingStatus != DevicePairingStatus.revoked &&
                device.pairingStatus != DevicePairingStatus.unpaired) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _remove(device),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_off_rounded),
                  label: Text(
                    widget.accountDevice ? 'Revoke Device' : 'Unpair Device',
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: kEmergency),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LightSettingRow(icon: icon, title: label, subtitle: value),
  );
}

class MemberDeviceSection extends StatelessWidget {
  const MemberDeviceSection({
    super.key,
    required this.group,
    required this.memberUserId,
    required this.memberName,
    required this.viewerId,
    this.deviceService,
  });
  final FamilyGroup group;
  final String memberUserId;
  final String memberName;
  final String viewerId;
  final DeviceActions? deviceService;

  @override
  Widget build(BuildContext context) {
    final canView = group.canManage || viewerId == memberUserId;
    if (!canView) {
      return const LightSettingRow(
        icon: Icons.lock_outline_rounded,
        title: 'Devices',
        subtitle: 'Visible only to the device owner and Circle managers',
      );
    }
    final service = deviceService ?? DeviceService();
    return StreamBuilder<List<PairedDevice>>(
      stream: service.watchMemberDevices(group.id, memberUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return LightSettingRow(
            icon: Icons.cloud_off_rounded,
            title: 'Devices unavailable',
            subtitle: _deviceError(snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return const LightSettingRow(
            icon: Icons.sync_rounded,
            title: 'Loading devices',
            subtitle: 'Checking secure Circle pairings…',
          );
        }
        final devices = snapshot.data!;
        return Column(
          children: [
            if (devices.isEmpty)
              const LightSettingRow(
                icon: Icons.devices_other_rounded,
                title: 'No paired devices',
                subtitle: 'The member can generate a code from My Devices.',
              ),
            for (final device in devices) ...[
              _DeviceCard(
                device: device,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeviceDetailScreen(
                      memberName: memberName,
                      device: device,
                      deviceService: service,
                      circleId: group.id,
                      canUnpair: group.canManage,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
            ],
            if (group.canManage) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DevicePairingScreen(
                        group: group,
                        memberUserId: memberUserId,
                        memberName: memberName,
                        deviceService: service,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Pair Member Device'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class DeviceQrScannerScreen extends StatefulWidget {
  const DeviceQrScannerScreen({super.key, this.controller});
  final MobileScannerController? controller;

  @override
  State<DeviceQrScannerScreen> createState() => _DeviceQrScannerScreenState();
}

class _DeviceQrScannerScreenState extends State<DeviceQrScannerScreen> {
  late final MobileScannerController _controller =
      widget.controller ?? MobileScannerController();
  bool _processing = false;
  String? _message;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      final code = DevicePairingCodePolicy.extract(barcode.rawValue ?? '');
      if (code != null) {
        _processing = true;
        await _controller.stop();
        if (mounted) Navigator.pop(context, code);
        return;
      }
    }
    if (mounted) {
      setState(
        () =>
            _message = 'This QR does not contain a valid device pairing code.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Scan Device Pairing QR'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) =>
                _DeviceCameraError(onRetry: () => _controller.start()),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: kEmerald, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _message ?? 'Place the device pairing QR inside the frame.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DeviceCameraError extends StatelessWidget {
  const _DeviceCameraError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 14),
            const Text(
              'Camera access is unavailable. Allow it in system settings, then retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry Camera'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});
  final PairedDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _presence(device.presenceAt(DateTime.now()));
    return LightCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: status.$2.withValues(alpha: .12),
          child: Icon(_platformIcon(device.platform), color: status.$2),
        ),
        title: Text(
          device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          device.isCurrentDevice
              ? 'This Device • ${status.$1}'
              : '${device.platform} • ${status.$1}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

(String, Color) _presence(DevicePresence presence) => switch (presence) {
  DevicePresence.online => ('Online', kEmerald),
  DevicePresence.stale => ('Stale', const Color(0xFFF59E0B)),
  DevicePresence.offline => ('Offline', kLightMuted),
  DevicePresence.revoked => ('Revoked', kEmergency),
  DevicePresence.unpaired => ('Unpaired', kLightMuted),
};

IconData _platformIcon(String platform) => switch (platform.toLowerCase()) {
  'android' => Icons.android_rounded,
  'ios' || 'macos' => Icons.phone_iphone_rounded,
  'windows' || 'linux' => Icons.computer_rounded,
  _ => Icons.devices_other_rounded,
};

String _date(DateTime? value) {
  if (value == null) return 'Not available';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _duration(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final minutes = safe.inMinutes;
  final seconds = safe.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _deviceError(Object error) {
  if (error is DeviceException) return error.message;
  return 'The device operation could not be completed. Check your connection and retry.';
}
